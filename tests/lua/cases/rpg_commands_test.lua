-- rpg_commands_test.lua : 이벤트 커맨드(scripts/rpg/commands.lua) 검증 (9단계).
--
-- 커맨드는 데이터라 실행기 없이도 검사할 수 있다. 여기서는 컴파일한 함수를
-- 코루틴 없이 직접 부르고, ctx를 가짜로 주입해 "어떤 호출이 어떤 순서로
-- 나갔는가"를 본다. 코루틴 위에서의 대기 규칙은 6단계 실행기 테스트의 몫이다.

local M = {}

--- 호출을 기록하는 가짜 ctx. choice는 미리 정한 번호를 돌려준다.
local function fakeCtx(picks)
	local ctx = { calls = {}, state = {} }
	local pickIndex = 0

	local function log(...) ctx.calls[#ctx.calls + 1] = { ... } end

	function ctx.message(text, opts) log("message", text, opts and opts.name or nil) end
	function ctx.choice(options, opts)
		pickIndex = pickIndex + 1
		log("choice", #options, opts and opts.cancelIndex or nil)
		return (picks or {})[pickIndex] or 1
	end
	function ctx.wait(ms) log("wait", ms) end
	function ctx.transfer(map, x, y, dir) log("transfer", map, x, y, dir) end
	function ctx.moveRoute(target, route, opts) log("moveRoute", target, #route,
		opts and opts.wait or nil) end
	function ctx.turn(target, dir) log("turn", target, dir) end
	function ctx.playSe(file, id) log("playSe", file, id) end
	function ctx.playBgm(file, opts) log("playBgm", file, opts and opts.volume or nil) end
	function ctx.showLocation(text, seconds) log("showLocation", text, seconds) end
	function ctx.scene(name, opts) log("scene", name, opts and opts.fade or nil) end

	--- n번째 호출의 종류와 인자
	function ctx.call(n) return ctx.calls[n] or {} end
	function ctx.kinds()
		local out = {}
		for i, c in ipairs(ctx.calls) do out[i] = c[1] end
		return table.concat(out, ",")
	end
	return ctx
end

function M.run(t)
	local Commands = require("scripts/rpg/commands")

	-- ---- [1] 커맨드 목록은 순서대로 실행된다 --------------------------------
	local ctx = fakeCtx()
	Commands.compile({
		{ code = "message", text = "첫 줄" },
		{ code = "wait", ms = 300 },
		{ code = "message", text = "둘째 줄", name = "선장" },
	})(nil, ctx)

	t.check_eq(ctx.kinds(), "message,wait,message", "적은 순서 그대로")
	t.check_eq(ctx.call(1)[2], "첫 줄", "대사 전달")
	t.check_eq(ctx.call(2)[2], 300, "대기 시간 전달")
	t.check_eq(ctx.call(3)[3], "선장", "이름 전달")

	-- 이름도 얼굴도 없으면 opts를 만들지 않는다 (7단계 대화창의 기본 배치를 유지)
	t.check_eq(ctx.call(1)[3], nil, "이름이 없으면 opts 없음")

	-- ---- [2] 선택지: 고른 번호의 가지만 실행된다 ----------------------------
	local function choiceCmds()
		return {
			{ code = "choice", options = { "네", "아니요" }, cancel = 2, branches = {
				{ { code = "message", text = "네 쪽" }, { code = "setFlag", key = "yes" } },
				{ { code = "message", text = "아니요 쪽" } },
			} },
			{ code = "message", text = "공통 마무리" },
		}
	end

	local first = fakeCtx({ 1 })
	Commands.compile(choiceCmds())(nil, first)
	t.check_eq(first.kinds(), "choice,message,message", "1번 가지 실행")
	t.check_eq(first.call(2)[2], "네 쪽", "1번 가지의 대사")
	t.check_eq(first.state.yes, true, "가지 안의 setFlag")
	t.check_eq(first.call(3)[2], "공통 마무리", "가지 뒤의 커맨드도 계속된다")
	t.check_eq(first.call(1)[3], 2, "취소 번호 전달")

	local second = fakeCtx({ 2 })
	Commands.compile(choiceCmds())(nil, second)
	t.check_eq(second.call(2)[2], "아니요 쪽", "2번 가지의 대사")
	t.check_eq(second.state.yes, nil, "고르지 않은 가지는 실행되지 않는다")

	-- 가지가 없는 항목을 골라도 죽지 않는다
	local bare = fakeCtx({ 2 })
	Commands.compile({ { code = "choice", options = { "가", "나" }, branches = {
		{ { code = "message", text = "가" } },
	} } })(nil, bare)
	t.check_eq(bare.kinds(), "choice", "가지가 없으면 아무것도 하지 않는다")

	-- ---- [3] 조건 분기 -----------------------------------------------------
	local cmds = {
		{ code = "if", cond = { flag = "heardAltar" },
		  thenDo = { { code = "message", text = "들었다" } },
		  elseDo = { { code = "message", text = "못 들었다" } } },
	}

	local off = fakeCtx()
	Commands.compile(cmds)(nil, off)
	t.check_eq(off.call(1)[2], "못 들었다", "깃발이 없으면 elseDo")

	local on = fakeCtx()
	on.state.heardAltar = true
	Commands.compile(cmds)(nil, on)
	t.check_eq(on.call(1)[2], "들었다", "깃발이 있으면 thenDo")

	-- elseDo가 없으면 조용히 넘어간다
	local noElse = fakeCtx()
	Commands.compile({ { code = "if", cond = { flag = "x" },
		thenDo = { { code = "message", text = "안 나온다" } } } })(nil, noElse)
	t.check_eq(#noElse.calls, 0, "거짓이고 elseDo가 없으면 아무것도 안 한다")

	-- 그 반대도 마찬가지다. `참 and thenDo or elseDo`로 적으면 thenDo가 없는
	-- 참 분기가 elseDo로 새어 나간다 (한 번 그렇게 새어 6단계 회귀가 깨졌다).
	local noThen = fakeCtx()
	noThen.state.done = true
	Commands.compile({ { code = "if", cond = { flag = "done" },
		elseDo = { { code = "message", text = "새어 나오면 안 된다" } } } })(nil, noThen)
	t.check_eq(#noThen.calls, 0, "참이고 thenDo가 없으면 elseDo로 새지 않는다")

	-- 중첩 분기 (가지 안의 가지)
	local nested = fakeCtx({ 1 })
	nested.state.deep = true
	Commands.compile({
		{ code = "choice", options = { "가" }, branches = {
			{ { code = "if", cond = { flag = "deep" },
			    thenDo = { { code = "message", text = "안쪽까지" } } } },
		} },
	})(nil, nested)
	t.check_eq(nested.call(2)[2], "안쪽까지", "가지 안의 조건 분기")

	-- ---- [4] 조건 판정 규칙 (M.test) ---------------------------------------
	t.check(Commands.test(nil, {}), "조건이 없으면 참")
	t.check(Commands.test({ flag = "a" }, { a = true }), "참인 깃발")
	t.check(not Commands.test({ flag = "a" }, { a = false }), "거짓 깃발")
	t.check(not Commands.test({ flag = "a" }, {}), "없는 깃발")
	t.check(Commands.test({ flag = "a", equals = false }, { a = false }), "값 비교 (거짓과 같다)")
	t.check(Commands.test({ var = "n", op = ">=", value = 2 }, { n = 2 }), "수 비교 >=")
	t.check(not Commands.test({ var = "n", op = ">", value = 2 }, { n = 2 }), "수 비교 >")
	t.check(Commands.test({ var = "n", op = "<", value = 1 }, {}), "없는 변수는 0")

	-- ---- [5] 상태 조작 -----------------------------------------------------
	local vars = fakeCtx()
	Commands.compile({
		{ code = "setFlag", key = "seen" },
		{ code = "setFlag", key = "gone", value = false },
		{ code = "setVar", key = "silver", value = 5 },
		{ code = "setVar", key = "silver", op = "-", value = 2 },
		{ code = "setVar", key = "coins", op = "+", value = 3 },
	})(nil, vars)
	t.check_eq(vars.state.seen, true, "setFlag의 기본값은 참")
	t.check_eq(vars.state.gone, false, "setFlag에 값을 줄 수 있다")
	t.check_eq(vars.state.silver, 3, "setVar 대입과 빼기")
	t.check_eq(vars.state.coins, 3, "없던 변수는 0에서 더한다")

	-- ---- [6] 씬에 위임하는 커맨드 ------------------------------------------
	local host = fakeCtx()
	Commands.compile({
		{ code = "playSe", file = "./door.wav", id = "door" },
		{ code = "playBgm", file = "./inn.ogg", volume = 80 },
		{ code = "showLocation", text = "항구 마을", seconds = 2 },
		{ code = "transfer", map = "inn", x = 10, y = 12, dir = "up" },
	})(nil, host)
	t.check_eq(host.kinds(), "playSe,playBgm,showLocation,transfer", "위임 커맨드 넷")
	t.check_eq(host.call(2)[3], 80, "볼륨 전달")
	t.check_eq(host.call(3)[2], "항구 마을", "장소 이름 전달")
	t.check_eq(host.call(4)[5], "up", "전환 방향 전달")

	-- ---- [7] script 커맨드 (Lua 탈출구) ------------------------------------
	local inline = fakeCtx()
	local ran = nil
	Commands.compile({
		{ code = "script", run = function(self, c, args) ran = args and args.n or true
			c.message("함수가 부른 대사") end },
	})(nil, inline)
	t.check_eq(ran, true, "run 함수가 실행된다")
	t.check_eq(inline.call(1)[2], "함수가 부른 대사", "함수 안에서 ctx를 쓴다")

	local named = fakeCtx()
	local env = { scripts = { greet = function(self, c, args) c.message("등록된 " .. args.who) end } }
	Commands.compile({ { code = "script", name = "greet", args = { who = "선장" } } }, env)(nil, named)
	t.check_eq(named.call(1)[2], "등록된 선장", "이름으로 등록된 함수를 부른다")

	-- ---- [8] comment는 아무것도 하지 않는다 --------------------------------
	local quiet = fakeCtx()
	Commands.compile({ { code = "comment", text = "에디터용 메모" },
		{ code = "message", text = "본문" } })(nil, quiet)
	t.check_eq(quiet.kinds(), "message", "comment는 실행되지 않는다")

	-- ---- [9] 검증: 틀린 곳을 경로와 함께 알린다 -----------------------------
	local ok, errors = Commands.validate({
		{ code = "message", text = "좋다" },
		{ code = "없는커맨드" },
		{ code = "message" },
		{ code = "choice", options = { "가" }, branches = { { { code = "또없다" } } } },
	})
	t.check(not ok, "틀린 목록은 통과하지 못한다")
	t.check_eq(#errors, 3, "오류 세 건: " .. table.concat(errors, " | "))
	t.check(errors[1]:find("[2]", 1, true) ~= nil and errors[1]:find("없는커맨드") ~= nil,
		"두 번째 커맨드의 code: " .. errors[1])
	t.check(errors[2]:find("[3].text", 1, true) ~= nil, "빠진 인자의 자리: " .. errors[2])
	t.check(errors[3]:find("[4].branches[1][1]", 1, true) ~= nil,
		"중첩된 가지 안까지 따라 들어간다: " .. errors[3])

	local okList, noErrors = Commands.validate({
		{ code = "if", cond = { flag = "a" }, thenDo = { { code = "wait", ms = 10 } } },
	})
	t.check(okList and #noErrors == 0, "올바른 목록은 통과한다")

	-- 빈 선택지와 등록되지 않은 script 이름
	local _, badChoice = Commands.validate({ { code = "choice", options = {} } })
	t.check(#badChoice > 0, "항목 없는 선택지는 오류")
	local _, badScript = Commands.validate({ { code = "script", name = "없는이름" } })
	t.check(#badScript == 1 and badScript[1]:find("없는이름") ~= nil,
		"등록되지 않은 스크립트 이름: " .. table.concat(badScript, ""))

	-- ---- [10] 커맨드 집합은 못 박아 둔다 (v1 15종) --------------------------
	local codes = Commands.codes()
	t.check_eq(#codes, 15, "v1 커맨드는 15종: " .. table.concat(codes, ","))
	local expected = "choice,comment,if,message,moveRoute,playBgm,playSe,scene,"
		.. "script,setFlag,setVar,showLocation,transfer,turn,wait"
	t.check_eq(table.concat(codes, ","), expected, "목록이 문서(10-demo-v2.md 3.2)와 같다")

	-- ---- [11] event.lua 가 커맨드를 받아들인다 ------------------------------
	local Event = require("scripts/rpg/event")
	local ev = Event.new{ id = "sign", x = 1, y = 2, trigger = "action",
		commands = { { code = "message", text = "간판이다" } } }
	t.check(type(ev.script) == "function", "커맨드가 스크립트 함수로 컴파일된다")
	local evCtx = fakeCtx()
	ev.script(ev, evCtx)
	t.check_eq(evCtx.call(1)[2], "간판이다", "컴파일된 함수가 돈다")

	local okNew, err = pcall(Event.new, { id = "bad", commands = { { code = "엉터리" } } })
	t.check(not okNew, "잘못된 커맨드는 이벤트를 만들 때 걸린다")
	t.check(tostring(err):find("bad") ~= nil, "오류에 이벤트 id가 들어간다: " .. tostring(err))

	-- script(함수)와 commands를 함께 주면 함수가 이긴다 (탈출구 우선)
	local both = Event.new{ id = "both", script = function() end,
		commands = { { code = "message", text = "무시된다" } } }
	t.check(type(both.script) == "function" and both.commands ~= nil,
		"둘 다 주면 함수를 쓰고 커맨드는 데이터로만 남는다")
end

return M
