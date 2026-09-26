-- rpg_commands_test.lua : 이벤트 커맨드(scripts/lua/rpg/commands.lua) 검증 (9단계).
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
	local Commands = require("scripts/lua/rpg/commands")

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

	-- ---- [9.5] 아이템 커맨드와 아이템 조건 (10단계) -------------------------
	local Inventory = require("scripts/lua/rpg/inventory")

	local itemCtx = fakeCtx()
	Commands.compile({
		{ code = "giveItem", item = "silver", count = 2 },
		{ code = "giveItem", item = "key" },
	})(nil, itemCtx)
	t.check_eq(Inventory.count(itemCtx.state, "silver"), 2, "giveItem이 개수만큼 준다")
	t.check_eq(Inventory.count(itemCtx.state, "key"), 1, "count가 없으면 하나")

	Commands.compile({ { code = "takeItem", item = "silver", count = 2 } })(nil, itemCtx)
	t.check_eq(Inventory.count(itemCtx.state, "silver"), 0, "takeItem이 뺀다")

	-- 모자라면 아무 일도 일어나지 않는다 (반쯤 빼고 실패하는 경우가 없다)
	Commands.compile({ { code = "takeItem", item = "key", count = 5 } })(nil, itemCtx)
	t.check_eq(Inventory.count(itemCtx.state, "key"), 1, "모자라면 그대로 둔다")

	-- 조건: 가졌는가와 개수 비교
	local bag = {}
	Inventory.give(bag, "key")
	Inventory.give(bag, "silver", 2)
	t.check(Commands.test({ item = "key" }, bag), "하나라도 가졌으면 참")
	t.check(not Commands.test({ item = "없는것" }, bag), "없으면 거짓")
	t.check(Commands.test({ item = "silver", op = ">=", value = 2 }, bag), "개수 비교 (>=)")
	t.check(not Commands.test({ item = "silver", op = ">=", value = 3 }, bag), "모자라면 거짓")
	t.check(Commands.test({ item = "없는것", op = "==", value = 0 }, bag),
		"없는 물건의 개수는 0")

	-- if 분기 안에서 그대로 쓰인다 (새 제어 구조가 아니다)
	local branchCtx = fakeCtx()
	branchCtx.state = bag
	Commands.compile({
		{ code = "if", cond = { item = "key" },
		  thenDo = { { code = "message", text = "열쇠가 맞는다" } },
		  elseDo = { { code = "message", text = "잠겨 있다" } } },
	})(nil, branchCtx)
	t.check_eq(branchCtx.call(1)[2], "열쇠가 맞는다", "아이템 조건이 if에서 돈다")

	-- 검증: item 인자가 없으면 맵을 열 때 잡힌다
	local okItem, itemErrors = Commands.validate({ { code = "giveItem" } })
	t.check(not okItem and #itemErrors == 1 and itemErrors[1]:find("item") ~= nil,
		"giveItem에 item이 없으면 검증에서 걸린다: " .. table.concat(itemErrors, ""))

	-- ---- [10] 커맨드 집합은 못 박아 둔다 ------------------------------------
	-- 9단계에서 15종으로 시작했고, 10단계에서 아이템 둘이 늘어 17종이다
	-- (docs/plans/11-game-systems.md 4.2). 여기 숫자를 고치지 않고는 커맨드가
	-- 늘지 않는다 — "그것 없이는 적을 수 없는 이벤트"가 나올 때만 더한다.
	local codes = Commands.codes()
	t.check_eq(#codes, 17, "커맨드는 17종: " .. table.concat(codes, ","))
	local expected = "choice,comment,giveItem,if,message,moveRoute,playBgm,playSe,scene,"
		.. "script,setFlag,setVar,showLocation,takeItem,transfer,turn,wait"
	t.check_eq(table.concat(codes, ","), expected,
		"목록이 문서(10-demo-v2.md 3.2 + 11-game-systems.md 4.2)와 같다")

	-- ---- [11] event.lua 가 커맨드를 받아들인다 ------------------------------
	local Event = require("scripts/lua/rpg/event")
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

	-- ---- [12] 조건의 꼴과 판정 순서 ----------------------------------------
	t.check_eq(table.concat(Commands.CONDITIONS, ","), "item,flag,var", "조건은 item, flag, var 순서")
	local both2 = {}
	Inventory.give(both2, "key")
	t.check(Commands.test({ item = "key", flag = "none" }, both2),
		"키가 둘이면 앞의 꼴(item)로 판정한다")
	t.check(not Commands.test({ flag = "none", var = "n", op = "==", value = 0 }, {}),
		"flag 와 var 가 함께 있으면 flag 로 판정한다")
	t.check_eq(table.concat(Commands.SET_VAR_OPS, ","), "=,+,-", "setVar 의 계산은 셋")

	-- ---- [13] describe: 필수 인자와 하위 목록 ------------------------------
	local desc = Commands.describe()
	local described = {}
	for code in pairs(desc) do described[#described + 1] = code end
	table.sort(described)
	t.check_eq(table.concat(described, ","), table.concat(Commands.codes(), ","),
		"describe 는 모든 커맨드를 적는다")
	t.check_eq(desc.message.required.text, "text", "message 의 text 는 필수 text 인자")
	t.check_eq(desc.message.required.name, nil, "message 의 name 은 필수가 아니다")
	t.check_eq(desc.moveRoute.required.route, "route", "moveRoute 의 route 는 필수 route 인자")
	t.check_eq(next(desc.script.required), nil, "script 의 name 은 validate 의 따로 규칙이 본다")
	local argNames = {}
	for _, arg in ipairs(desc.transfer.args) do argNames[#argNames + 1] = arg.name end
	t.check_eq(table.concat(argNames, ","), "map,x,y,dir", "transfer 의 인자는 스키마 순서로 넷")
	t.check_eq(desc.transfer.args[1].ref, "map", "transfer.map 은 map 참조")
	t.check_eq(table.concat(desc.transfer.args[4].values, ","), "down,left,right,up",
		"transfer.dir 은 네 방향 enum")
	t.check(desc.playBgm.args[2].min == 0 and desc.playBgm.args[2].max == 128,
		"playBgm.volume 은 0..128")
	t.check(Commands.argTypes().condition and not Commands.argTypes().charset,
		"검증이 아는 타입에 condition 은 있고 이벤트 칸의 charset 은 없다")
	local conds = Commands.describeConditions()
	t.check_eq(conds.item[3].name .. ":" .. conds.item[3].type, "value:integer", "item 조건의 value 는 정수")
	t.check_eq(table.concat(desc.choice.lists, ","), "branches", "choice 의 하위 목록은 branches")
	t.check_eq(desc.choice.perOption.branches, "options", "branches 는 항목마다 하나")
	t.check_eq(table.concat(desc["if"].lists, ","), "thenDo,elseDo", "if 의 하위 목록은 thenDo, elseDo")
	t.check_eq(#desc.message.lists, 0, "message 에는 하위 목록이 없다")
	desc.message.required.text = "number"
	desc.transfer.args[4].values[1] = "north"
	conds.item[1].name = "other"
	t.check_eq(Commands.describe().message.required.text, "text", "describe 는 사본을 돌려준다")
	t.check_eq(Commands.describe().transfer.args[4].values[1], "down", "인자 명세의 values 도 사본")
	t.check_eq(Commands.describeConditions().item[1].name, "item", "조건 명세도 사본")

	-- ---- [14] walk: 하위 목록까지 적힌 순서로 ------------------------------
	local visited = {}
	Commands.walk({
		{ code = "message", text = "a" },
		{ code = "choice", options = { "가", "나" }, branches = {
			{ { code = "message", text = "b" } },
			{ { code = "if", cond = { flag = "f" },
			    thenDo = { { code = "message", text = "c" } },
			    elseDo = { { code = "wait", ms = 1 } } } },
		} },
	}, function(cmd, path) visited[#visited + 1] = cmd.code .. path end)
	t.check_eq(table.concat(visited, " "),
		"message[1] choice[2] message[2].branches[1][1] if[2].branches[2][1] "
		.. "message[2].branches[2][1].thenDo[1] wait[2].branches[2][1].elseDo[1]",
		"walk 가 가지 안까지 경로와 함께 훑는다")

	-- ---- [15] problems: 경로와 이유를 따로, 앞에 붙일 경로 -----------------
	local probs = Commands.problems({ { code = "message" } }, nil, "events[2].commands")
	t.check_eq(#probs, 1, "문제 하나")
	t.check_eq(probs[1].path, "events[2].commands[1].text", "앞에 붙인 경로")
	t.check(type(probs[1].message) == "string" and probs[1].message ~= "", "이유가 따로 온다")

	-- ---- [16] 새 검사: 얼굴과 방향 ------------------------------------------
	local function pathsOf(list, env)
		local out = {}
		for _, p in ipairs(Commands.problems(list, env)) do out[#out + 1] = p.path end
		table.sort(out)
		return table.concat(out, " ")
	end
	local face = "./resources/faces/placeholder.png"
	t.check_eq(pathsOf({
		{ code = "message", text = "a", face = { set = "npc", index = 3 } },
		{ code = "message", text = "b", face = { file = face, index = 15 } },
		{ code = "message", text = "c", face = { set = "npc" } },
		{ code = "transfer", map = "inn", x = 1, y = 2, dir = "up" },
		{ code = "turn", target = "player", dir = "left" },
	}), "", "올바른 얼굴과 방향은 통과한다")
	t.check_eq(pathsOf({ { code = "message", text = "a", face = 3 } }), "[1].face",
		"얼굴이 객체가 아니다")
	t.check_eq(pathsOf({ { code = "message", text = "a", face = { set = "npc", file = face } } }),
		"[1].face", "set 과 file 이 둘 다 있다")
	t.check_eq(pathsOf({ { code = "message", text = "a", face = { index = 1 } } }), "[1].face",
		"set 도 file 도 없다")
	t.check_eq(pathsOf({ { code = "message", text = "a", face = { set = "monster", index = 1 } } }),
		"[1].face.set", "모르는 얼굴 이름")
	t.check_eq(pathsOf({ { code = "message", text = "a", face = { set = "npc", index = 16 } } }),
		"[1].face.index", "얼굴 번호는 0..15")
	t.check_eq(pathsOf({ { code = "message", text = "a", face = { set = "npc", index = 1.5 } } }),
		"[1].face.index", "얼굴 번호는 정수")
	t.check_eq(pathsOf({ { code = "transfer", map = "inn", dir = "north" } }), "[1].dir",
		"transfer 의 모르는 방향")
	t.check_eq(pathsOf({ { code = "transfer", map = "inn", dir = 2 } }), "[1].dir",
		"transfer 의 방향이 글이 아니다")
	t.check_eq(pathsOf({ { code = "turn", target = "player", dir = "sideways" } }), "[1].dir",
		"turn 의 모르는 방향")
	t.check_eq(pathsOf({ { code = "turn", target = "player", dir = 2 } }), "[1].dir",
		"turn 의 방향이 글이 아니면 한 번만 알린다")
	t.check_eq(pathsOf({ { code = "if", cond = { flag = "a" }, thenDo = {
		{ code = "message", text = "a", face = { set = "npc", index = 99 } } } } }),
		"[1].thenDo[1].face.index", "가지 안의 얼굴도 본다")

	-- 모양이 틀린 인자에도 검사가 죽지 않는다
	t.check_eq(pathsOf({ { code = "choice", options = 5 } }), "[1].options",
		"항목이 표가 아니면 타입 오류 하나")
	t.check_eq(pathsOf({ { code = "choice", options = { "가" }, branches = "없다" } }),
		"[1].branches", "가지 목록이 배열이 아니다")
	t.check_eq(pathsOf({ { code = "if", cond = { flag = "a" }, elseDo = "없다" } }),
		"[1].elseDo", "하위 목록이 배열이 아니다")

	-- ---- [17] JSON 의 null 과 객체: 목록은 칸 수만큼 본다 --------------------
	-- Json.Load 는 null 을 nil 로 둔다. 구멍 뒤의 커맨드도 검사해야 한다.
	local holey = { { code = "message", text = "first" } }
	holey[3] = { code = "message" }
	holey[4] = { code = "nosuch" }
	t.check_eq(pathsOf(holey), "[2] [3].text [4]", "null 커맨드와 그 뒤의 커맨드까지 본다")
	local branches = {}
	branches[2] = { { code = "message", text = "t", face = { file = face, index = 99 } } }
	t.check_eq(pathsOf({ { code = "choice", options = { "a", "b" }, branches = branches } }),
		"[1].branches[1] [1].branches[2][1].face.index", "null 가지는 배열이 아니고, 그 뒤의 가지도 본다")
	local thenList = { { code = "wait", ms = 1 } }
	thenList[3] = { code = "wait" }
	t.check_eq(pathsOf({ { code = "if", cond = { flag = "a" }, thenDo = thenList } }),
		"[1].thenDo[2] [1].thenDo[3].ms", "하위 목록 안의 null 도 칸이다")
	local options = { "가" }
	options[3] = 3
	t.check_eq(pathsOf({ { code = "choice", options = options } }),
		"[1].options[2] [1].options[3]", "선택지 항목은 글이다 (null 포함)")
	t.check_eq(pathsOf({ "글", { 1, 2 } }), "[1] [2]", "커맨드가 객체가 아니다 (배열 포함)")

	-- 배열 자리의 JSON 객체 (글 키가 있는 표)
	local listObject = Commands.problems({ first = { code = "message", text = "a" } }, nil,
		"events[1].commands")
	t.check(#listObject == 1 and listObject[1].path == "events[1].commands",
		"커맨드 목록 자리의 객체는 배열이 아니다")
	t.check_eq(pathsOf({ { code = "if", cond = { flag = "a" },
		thenDo = { k = { code = "wait", ms = 1 } } } }), "[1].thenDo", "thenDo 자리의 객체")
	t.check_eq(pathsOf({ { code = "choice", options = { "가" },
		branches = { ["1"] = {} } } }), "[1].branches", "branches 자리의 객체 (\"1\" 키도 글 키)")
	t.check_eq(pathsOf({ { code = "choice", options = { a = "가" } } }), "[1].options",
		"options 자리의 객체")
	t.check_eq(pathsOf({ { code = "if", cond = { flag = "a" }, thenDo = {}, elseDo = {} } }), "",
		"빈 표는 빈 목록이다 ({} 와 [] 를 가릴 수 없다)")

	-- ---- [18] 있는 인자는 필수든 선택이든 스키마의 타입이다 ----------------------
	local door = "./resources/audio/door.wav"
	t.check_eq(pathsOf({
		{ code = "message", text = "a", name = "선장" },
		{ code = "choice", options = { "가", "나" }, cancel = 2 },
		{ code = "wait", ms = 0 },
		{ code = "transfer", map = "inn", x = 0, y = 12.0, dir = "up" },
		{ code = "moveRoute", target = "player", route = { "up", "turn:left", "wait:100" },
		  wait = false, loop = true },
		{ code = "setFlag", key = "k", value = "글" },
		{ code = "setFlag", key = "k", value = 3 },
		{ code = "setVar", key = "v", op = "+", value = 2.5 },
		{ code = "giveItem", item = "shell", count = 1 },
		{ code = "takeItem", item = "shell", count = 2 },
		{ code = "if", cond = { item = "shell", op = ">", value = 0 } },
		{ code = "if", cond = { flag = "f", equals = false } },
		{ code = "if", cond = { var = "v", op = "~=", value = -1.5 } },
		{ code = "if", cond = {} },
		{ code = "playSe", file = door, id = "door" },
		{ code = "playBgm", file = door, volume = 128, fade = 0 },
		{ code = "showLocation", text = "항구", seconds = 2.5 },
		{ code = "scene", name = "title", fade = true, text = "끝" },
		{ code = "script", name = "s", args = { any = { 1, "x" } } },
		{ code = "comment", text = "메모" },
	}, { scripts = { s = function() end } }), "", "스키마 타입의 인자는 통과한다 (빈 조건 포함)")

	-- 검수가 게임을 멈추게 한 선택 인자들
	t.check_eq(pathsOf({
		{ code = "playSe", file = door, id = true },
		{ code = "playSe", file = door, id = { k = 1 } },
		{ code = "message", text = "hi", name = { a = 1 } },
		{ code = "message", text = "hi", name = true },
		{ code = "transfer", map = "inn", x = { a = 1 }, y = { 2 } },
		{ code = "transfer", map = "inn", x = "abc", y = 12 },
		{ code = "playBgm", file = door, volume = { a = 1 } },
		{ code = "playBgm", file = door, volume = "loud" },
		{ code = "scene", name = "title", text = { "x" } },
	}), "[1].id [2].id [3].name [4].name [5].x [5].y [6].x [7].volume [8].volume [9].text",
		"선택 인자의 틀린 타입을 그 인자의 경로에 낸다")

	t.check_eq(pathsOf({
		{ code = "choice", options = { "가" }, cancel = 1.5 },
		{ code = "wait", ms = "100" },
		{ code = "moveRoute", target = "player", route = { "up", 5 }, wait = "yes", loop = 1 },
		{ code = "setFlag", key = "k", value = { a = 1 } },
		{ code = "setVar", key = "k", op = "*", value = "3" },
		{ code = "giveItem", item = "shell", count = 0 },
		{ code = "takeItem", item = 5 },
		{ code = "showLocation", text = "X", seconds = -1 },
		{ code = "scene", name = "title", fade = 30 },
		{ code = "playSe", file = "" },
		{ code = "comment", text = 5 },
		{ code = "playBgm", file = door, volume = 200, fade = -1 },
		{ code = "moveRoute", target = "player", route = { a = "up" } },
		{ code = "turn", target = 3, dir = "up" },
	}), "[10].file [11].text [12].fade [12].volume [13].route [14].target [1].cancel [2].ms "
		.. "[3].loop [3].route[2] [3].wait [4].value [5].op [5].value [6].count [7].item "
		.. "[8].seconds [9].fade", "타입, enum 값, 범위, 빈 경로, 걸음 목록")

	t.check_eq(pathsOf({
		{ code = "if", cond = "a" },
		{ code = "if", cond = { item = 5, op = "=>", value = 1.5 } },
		{ code = "if", cond = { flag = "f", equals = { a = 1 } } },
		{ code = "if", cond = { var = "v", op = "==", value = "2" } },
		{ code = "if", cond = { item = "shell", value = -1 } },
		{ code = "if", cond = { 1, 2 } },
		{ code = "if", cond = { flag = "f", value = "안 본다" } },
	}), "[1].cond [2].cond.item [2].cond.op [2].cond.value [3].cond.equals [4].cond.value "
		.. "[5].cond.value [6].cond", "조건은 객체이고 판정하는 꼴의 인자만 본다")

	-- script 의 이름이 글이 아니면 타입 오류 하나 (등록 검사는 글일 때만)
	local scriptProbs = Commands.problems({ { code = "script", name = 5 } }, { scripts = {} })
	t.check(#scriptProbs == 1 and scriptProbs[1].path == "[1].name",
		"script.name 이 글이 아니면 한 번만 알린다")

	-- 틀린 인자가 든 이벤트는 Event.new 가 받지 않는다 (정의 파일도 같은 검사)
	local okBad = pcall(Event.new, { id = "bad_arg", commands = {
		{ code = "message", text = "a", name = true } } })
	t.check(not okBad, "선택 인자가 틀린 커맨드는 이벤트를 만들 때 걸린다")

	-- walk 도 구멍 뒤까지 훑는다 (resolveAssets 가 쓴다)
	local walked = {}
	local walkList = { { code = "message", text = "a" } }
	walkList[3] = { code = "choice", options = { "가", "나" }, branches = branches }
	Commands.walk(walkList, function(cmd, path) walked[#walked + 1] = cmd.code .. path end)
	t.check_eq(table.concat(walked, " "), "message[1] choice[3] message[3].branches[2][1]",
		"walk 가 null 칸을 건너뛰고 뒤를 훑는다")
end

return M
