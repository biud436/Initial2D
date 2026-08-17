-- rpg_interpreter_test.lua : 이벤트 스크립트 실행기 검증 (6단계, docs/plans/06-rpg-events.md)
--
-- 로드맵에서 상태 관리 버그가 가장 숨기 쉬운 곳이다. 조작 잠금, 대기 재개,
-- 병렬 실행, 맵 전환 시 정리를 전부 여기서 본다. 엔진 없이 도는 순수 로직이다.

local M = {}

-- 테스트가 직접 여닫는 가짜 대화창
local function fakePort()
	local p = { busy = false, value = 1, messages = {}, choices = {} }
	function p.showMessage(text)
		table.insert(p.messages, text)
		p.busy = true
	end
	function p.showChoice(options)
		table.insert(p.choices, options)
		p.busy = true
	end
	function p.isBusy() return p.busy end
	function p.result() return p.value end
	function p.close() p.busy = false end
	return p
end

local function makeEvent(id, trigger, script)
	return { id = id, trigger = trigger, script = script }
end

local function pump(interp, n)
	for _ = 1, (n or 1) do interp:update() end
end

function M.run(t)
	local Interpreter = require("scripts/rpg/interpreter")
	local Character = require("scripts/rpg/character")

	-- ---- [1] 즉시 끝나는 스크립트는 조작을 잠그지 않는다 --------------------
	local ran = false
	local interp = Interpreter.new{ messagePort = fakePort() }
	interp:start(makeEvent("quick", "action", function(self, ctx) ran = true end))
	t.check(ran, "스크립트가 즉시 실행된다")
	t.check_eq(interp:isBusy(), false, "한 프레임에 끝나는 이벤트는 잠그지 않는다")

	-- ---- [2] 대화: 창이 닫힐 때까지 재개하지 않는다 -------------------------
	local port = fakePort()
	interp = Interpreter.new{ messagePort = port }
	local step = 0
	interp:start(makeEvent("talk", "action", function(self, ctx)
		step = 1
		ctx.message("첫 줄")
		step = 2
		ctx.message("둘째 줄")
		step = 3
	end))

	t.check_eq(step, 1, "첫 message에서 멈춘다")
	t.check_eq(interp:isBusy(), true, "대화 중에는 조작 잠금")
	t.check_eq(port.messages[1], "첫 줄", "대화창에 첫 줄이 전달된다")

	pump(interp, 5)
	t.check_eq(step, 1, "창이 열려 있는 동안에는 진행하지 않는다")

	port.close()
	pump(interp, 1)
	t.check_eq(step, 2, "창이 닫히면 다음 줄로")
	t.check_eq(port.messages[2], "둘째 줄", "둘째 줄 전달")

	port.close()
	pump(interp, 1)
	t.check_eq(step, 3, "스크립트 끝까지 진행")
	t.check_eq(interp:isBusy(), false, "끝나면 잠금 해제")

	-- ---- [3] 선택지: 고른 번호가 스크립트로 돌아온다 -----------------------
	port = fakePort()
	interp = Interpreter.new{ messagePort = port }
	local picked = nil
	interp:start(makeEvent("choose", "action", function(self, ctx)
		picked = ctx.choice({ "네", "아니요" })
	end))
	t.check_eq(#port.choices, 1, "선택지가 대화창으로 전달된다")
	t.check_eq(port.choices[1][2], "아니요", "항목이 그대로 전달된다")
	t.check_eq(picked, nil, "고르기 전에는 진행하지 않는다")

	port.value = 2
	port.close()
	pump(interp, 1)
	t.check_eq(picked, 2, "고른 번호가 ctx.choice의 반환값")

	-- 분기: 2번을 고르면 다른 대사가 나온다 (말 걸기 시나리오)
	port = fakePort()
	port.value = 2
	interp = Interpreter.new{ messagePort = port }
	interp:start(makeEvent("branch", "action", function(self, ctx)
		local pick = ctx.choice({ "네, 처음입니다", "아니요" })
		if pick == 1 then
			ctx.message("천천히 둘러보세요")
		else
			ctx.message("그럼 길은 잘 알겠군")
		end
	end))
	port.close(); pump(interp, 1)
	t.check_eq(port.messages[1], "그럼 길은 잘 알겠군", "선택에 따라 분기한다")

	-- ---- [4] wait: 프레임으로 환산해 기다린다 ------------------------------
	interp = Interpreter.new{ messagePort = fakePort() }
	local waited = false
	interp:start(makeEvent("waiter", "action", function(self, ctx)
		ctx.wait(100)     -- 100ms = 6프레임 (16.67ms 고정 스텝)
		waited = true
	end))
	pump(interp, 5)
	t.check_eq(waited, false, "대기 시간 전에는 재개하지 않는다")
	pump(interp, 3)
	t.check_eq(waited, true, "대기가 끝나면 재개한다")
	t.check_eq(interp:isBusy(), false, "끝나면 잠금 해제")

	-- ---- [5] 이동 루트: 루트가 끝날 때까지 기다린다 ------------------------
	local mover = Character.new{ tx = 5, ty = 5, speed = 1,
		canPass = function() return true end }
	interp = Interpreter.new{
		messagePort = fakePort(),
		host = { characterById = function(id) return id == "npc" and mover or nil end },
	}
	local routeDone = false
	interp:start(makeEvent("route", "action", function(self, ctx)
		ctx.moveRoute("npc", { "right", "right" })
		routeDone = true
	end))
	t.check(mover.route ~= nil, "moveRoute가 캐릭터에 루트를 건다")
	t.check_eq(routeDone, false, "루트가 끝나기 전에는 재개하지 않는다")

	-- 한 칸에 4프레임 (speed 1, dt 0.25). 실행기 update와 캐릭터 update를 함께 돌린다
	for _ = 1, 12 do
		mover:update(0.25)
		interp:update()
	end
	t.check_eq(mover.tx, 7, "루트대로 두 칸 이동", tostring(mover.tx))
	t.check_eq(routeDone, true, "루트가 끝나면 재개한다")

	-- wait = false 면 기다리지 않는다
	local mover2 = Character.new{ tx = 0, ty = 0, speed = 1, canPass = function() return true end }
	interp = Interpreter.new{
		messagePort = fakePort(),
		host = { characterById = function() return mover2 end },
	}
	local after = false
	interp:start(makeEvent("nowait", "action", function(self, ctx)
		ctx.moveRoute("npc", { "right", "right" }, { wait = false })
		after = true
	end))
	t.check(mover2.route ~= nil, "wait=false여도 루트는 걸린다")
	t.check_eq(after, false, "즉시 끝나는 요청도 재개는 다음 프레임 (무한 루프 방지)")
	pump(interp, 1)
	t.check_eq(after, true, "다음 프레임에 이어서 진행한다")

	-- ---- [6] 맵 전환: host에 전달하고 스크립트를 끝낸다 --------------------
	local transferred = nil
	interp = Interpreter.new{
		messagePort = fakePort(),
		host = { transfer = function(map, x, y) transferred = { map, x, y } end },
	}
	local afterTransfer = false
	interp:start(makeEvent("door", "touch", function(self, ctx)
		ctx.transfer("room", 3, 10)
		afterTransfer = true      -- 실행되면 안 된다
	end))
	t.check(transferred ~= nil, "host.transfer가 호출된다")
	t.check(transferred[1] == "room" and transferred[2] == 3 and transferred[3] == 10,
		"전환 인자가 그대로 전달된다")
	t.check_eq(afterTransfer, false, "전환 이후의 스크립트는 실행되지 않는다")
	t.check_eq(interp:isBusy(), false, "전환 뒤 조작 잠금이 남지 않는다")

	-- ---- [7] 병렬 이벤트 ----------------------------------------------------
	port = fakePort()
	interp = Interpreter.new{ messagePort = port }
	local ticks = 0
	local parallel = makeEvent("blink", "parallel", function(self, ctx)
		while true do
			ticks = ticks + 1
			ctx.wait(50)
		end
	end)
	interp:start(parallel)
	t.check_eq(interp:isBusy(), false, "병렬 이벤트는 조작을 잠그지 않는다")
	t.check_eq(interp:start(parallel), false, "같은 병렬 이벤트를 두 번 켜지 않는다")

	local before = ticks
	pump(interp, 12)
	t.check(ticks > before, "병렬 이벤트가 계속 돈다", tostring(ticks))

	-- 병렬이 도는 중에도 말 걸기가 된다
	local talked = false
	interp:start(makeEvent("npc", "action", function(self, ctx)
		ctx.message("안녕")
		talked = true
	end))
	t.check_eq(interp:isBusy(), true, "말을 걸면 잠긴다")
	local duringTalk = ticks
	pump(interp, 10)
	t.check(ticks > duringTalk, "대화 중에도 병렬 이벤트는 돈다")
	port.close()
	pump(interp, 1)
	t.check_eq(talked, true, "대화가 끝난다")
	t.check_eq(interp:isBusy(), false, "잠금 해제")

	-- 끝나는 병렬 이벤트는 목록에서 빠진다
	interp = Interpreter.new{ messagePort = fakePort() }
	interp:start(makeEvent("once", "parallel", function(self, ctx) ctx.wait(20) end))
	t.check_eq(#interp.parallels, 1, "병렬 목록에 들어간다")
	pump(interp, 5)
	t.check_eq(#interp.parallels, 0, "끝난 병렬 이벤트는 목록에서 빠진다")

	-- ---- [8] 막는 이벤트는 한 번에 하나 -------------------------------------
	port = fakePort()
	interp = Interpreter.new{ messagePort = port }
	interp:start(makeEvent("first", "action", function(self, ctx) ctx.message("첫 번째") end))
	local secondRan = false
	t.check_eq(interp:start(makeEvent("second", "action", function() secondRan = true end)),
		false, "이미 도는 중이면 새 이벤트를 시작하지 않는다")
	t.check_eq(secondRan, false, "두 번째 스크립트는 실행되지 않는다")
	port.close(); pump(interp, 1)
	t.check_eq(interp:isBusy(), false, "첫 이벤트가 끝나면 다시 받을 수 있다")

	-- ---- [9] 스크립트 오류는 게임을 멈추지 않는다 ---------------------------
	interp = Interpreter.new{ messagePort = fakePort() }
	interp:start(makeEvent("boom", "action", function(self, ctx)
		error("일부러 낸 오류")
	end))
	t.check_eq(#interp.errors, 1, "오류가 기록된다")
	t.check(interp.errors[1]:find("boom") ~= nil, "어느 이벤트인지 남는다", interp.errors[1])
	t.check_eq(interp:isBusy(), false, "오류가 나도 조작 잠금이 남지 않는다")

	-- 대기 중에 난 오류도 같다
	port = fakePort()
	interp = Interpreter.new{ messagePort = port }
	interp:start(makeEvent("boom2", "action", function(self, ctx)
		ctx.message("한 줄")
		error("재개 후 오류")
	end))
	port.close(); pump(interp, 1)
	t.check_eq(#interp.errors, 1, "재개 후의 오류도 기록된다")
	t.check_eq(interp:isBusy(), false, "잠금 해제")

	-- ---- [10] state 공유와 clear -------------------------------------------
	interp = Interpreter.new{ messagePort = fakePort() }
	interp:start(makeEvent("setter", "action", function(self, ctx)
		ctx.state.flag = 42
	end))
	local seen = nil
	interp:start(makeEvent("getter", "action", function(self, ctx)
		seen = ctx.state.flag
	end))
	t.check_eq(seen, 42, "이벤트끼리 state를 공유한다")

	port = fakePort()
	interp = Interpreter.new{ messagePort = port }
	interp:start(makeEvent("long", "action", function(self, ctx) ctx.message("...") end))
	interp:start(makeEvent("par", "parallel", function(self, ctx)
		while true do ctx.wait(50) end
	end))
	t.check(interp:isBusy() and #interp.parallels == 1, "실행 중 상태 확인")
	interp:clear()
	t.check_eq(interp:isBusy(), false, "clear가 막는 이벤트를 지운다")
	t.check_eq(#interp.parallels, 0, "clear가 병렬 이벤트도 지운다")

	-- ---- [11] 이벤트 자신(self)이 스크립트로 전달된다 ----------------------
	interp = Interpreter.new{ messagePort = fakePort() }
	local gotSelf = nil
	local ev = makeEvent("me", "action", function(self, ctx) gotSelf = self end)
	interp:start(ev)
	t.check_eq(gotSelf, ev, "스크립트의 첫 인자는 이벤트 자신")
end

return M
