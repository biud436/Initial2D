-- rpg_event_test.lua : 이벤트 객체와 트리거 감지 검증 (6단계, docs/plans/06-rpg-events.md)
-- 트리거 4종(action, touch, auto, parallel)이 각각 언제 도는지가 핵심이다.

local M = {}

local function fakePort()
	local p = { busy = false, value = 1 }
	function p.showMessage() p.busy = true end
	function p.showChoice() p.busy = true end
	function p.isBusy() return p.busy end
	function p.result() return p.value end
	function p.close() p.busy = false end
	return p
end

function M.run(t)
	local Event = require("scripts/rpg/event")
	local Interpreter = require("scripts/rpg/interpreter")
	local Character = require("scripts/rpg/character")

	-- ---- [1] 생성 계약 ------------------------------------------------------
	local e = Event.new{ id = "a", x = 3, y = 4, trigger = "action" }
	t.check_eq(e.id, "a", "id")
	local ex, ey = e:tile()
	t.check(ex == 3 and ey == 4, "외형이 없으면 정의된 좌표가 위치")
	t.check_eq(e.trigger, "action", "트리거")
	t.check(pcall(Event.new, { id = "b", trigger = "nope" }) == false, "모르는 트리거는 오류")
	t.check(pcall(Event.new, { trigger = "action" }) == false, "id 없으면 오류")
	t.check(pcall(Event.new, { id = "c", script = 42 }) == false, "script는 함수여야 한다")

	-- ---- [2] 통행 판정 ------------------------------------------------------
	t.check_eq(e:isSolid(), false, "외형 없는 트리거는 통행을 막지 않는다")

	local withChar = Event.new{ id = "npc", x = 1, y = 1 }
	withChar.character = Character.new{ tx = 1, ty = 1 }
	t.check_eq(withChar:isSolid(), true, "외형이 있으면 막는다")

	local throughEv = Event.new{ id = "ghost", x = 1, y = 1, through = true }
	throughEv.character = Character.new{ tx = 1, ty = 1 }
	t.check_eq(throughEv:isSolid(), false, "through면 막지 않는다")

	local wall = Event.new{ id = "wall", x = 2, y = 2, solid = true }
	t.check_eq(wall:isSolid(), true, "solid를 직접 주면 외형 없이도 막는다")
	wall.enabled = false
	t.check_eq(wall:isSolid(), false, "꺼진 이벤트는 막지 않는다")

	-- 캐릭터가 움직이면 이벤트 위치도 따라간다
	withChar.character:place(5, 6)
	ex, ey = withChar:tile()
	t.check(ex == 5 and ey == 6, "외형이 있으면 캐릭터 좌표가 진실", ex .. "," .. ey)

	-- ---- [3] 관리자: 조회와 통행 판정 ---------------------------------------
	local player = Character.new{ tx = 10, ty = 10, dir = "up", speed = 1,
		canPass = function() return true end }
	local port = fakePort()
	local interp = Interpreter.new{ messagePort = port }
	local mgr = Event.newManager{ player = player, interpreter = interp }

	local talked = 0
	local npc = mgr:add(Event.new{
		id = "villager", x = 10, y = 9, trigger = "action",
		script = function(self, ctx) talked = talked + 1; ctx.message("안녕") end,
	})
	npc.character = Character.new{ tx = 10, ty = 9, dir = "down" }

	t.check_eq(mgr:get("villager"), npc, "id로 찾는다")
	t.check_eq(mgr:at(10, 9), npc, "칸으로 찾는다")
	t.check_eq(mgr:at(10, 8), nil, "빈 칸은 nil")
	t.check_eq(mgr:blocksTile(10, 9), true, "외형 있는 이벤트가 칸을 막는다")
	t.check_eq(mgr:blocksTile(10, 8), false, "빈 칸은 막지 않는다")

	-- ---- [4] action: 바라보는 칸 → 없으면 발밑 -----------------------------
	t.check_eq(mgr:actionTarget(), npc, "위를 볼 때 앞 칸의 이벤트를 집는다")
	player:turn("down")
	t.check_eq(mgr:actionTarget(), nil, "다른 곳을 보면 대상이 없다")
	player:turn("up")

	t.check_eq(mgr:confirm(), true, "결정키로 실행 시작")
	t.check_eq(talked, 1, "스크립트 실행")
	t.check_eq(interp:isBusy(), true, "대화 중 조작 잠금")
	t.check_eq(npc.character.dir, "down", "말을 걸면 플레이어를 돌아본다")
	t.check_eq(mgr:confirm(), false, "실행 중에는 새로 시작하지 않는다")
	port.close(); interp:update()
	t.check_eq(interp:isBusy(), false, "대화가 끝나면 잠금 해제")

	-- 발밑 이벤트도 잡는다 (앞 칸에 아무것도 없을 때)
	local underRan = false
	local under = mgr:add(Event.new{ id = "under", x = 10, y = 10, trigger = "action",
		script = function() underRan = true end })
	player:turn("down")     -- 앞 칸(10,11)에는 아무것도 없다
	t.check_eq(mgr:actionTarget(), under, "앞이 비면 발밑을 본다")
	mgr:confirm()
	t.check_eq(underRan, true, "발밑 이벤트 실행")

	-- ---- [5] touch: 칸을 옮긴 순간에만 --------------------------------------
	interp = Interpreter.new{ messagePort = fakePort() }
	player = Character.new{ tx = 4, ty = 4, speed = 1, canPass = function() return true end }
	mgr = Event.newManager{ player = player, interpreter = interp }
	local touched = 0
	mgr:add(Event.new{ id = "trap", x = 5, y = 4, trigger = "touch",
		script = function() touched = touched + 1 end })
	mgr:onMapStart()

	mgr:update()
	t.check_eq(touched, 0, "가만히 있으면 발동하지 않는다")

	player:tryMove("right")          -- 목적지 칸을 즉시 점유한다 (5단계 규약)
	mgr:update()
	t.check_eq(touched, 1, "칸에 들어서면 발동한다")
	mgr:update()
	t.check_eq(touched, 1, "같은 칸에 있는 동안 다시 발동하지 않는다")

	for _ = 1, 4 do player:update(0.25) end
	player:tryMove("right")
	mgr:update()
	t.check_eq(touched, 1, "다른 칸으로 옮기면 발동하지 않는다")

	-- 시작 칸에 놓인 touch 이벤트는 진입만으로 발동하지 않는다 (무한 발동 방지)
	interp = Interpreter.new{ messagePort = fakePort() }
	player = Character.new{ tx = 7, ty = 7, speed = 1, canPass = function() return true end }
	mgr = Event.newManager{ player = player, interpreter = interp }
	local startTouch = 0
	mgr:add(Event.new{ id = "start", x = 7, y = 7, trigger = "touch",
		script = function() startTouch = startTouch + 1 end })
	mgr:onMapStart()
	mgr:update()
	t.check_eq(startTouch, 0, "맵 진입 칸의 touch는 바로 발동하지 않는다")

	-- ---- [6] auto와 parallel: 맵 진입 시 -----------------------------------
	port = fakePort()
	interp = Interpreter.new{ messagePort = port }
	player = Character.new{ tx = 0, ty = 0 }
	mgr = Event.newManager{ player = player, interpreter = interp }

	local autoRan, parRan = 0, 0
	mgr:add(Event.new{ id = "intro", x = 0, y = 0, trigger = "auto",
		script = function(self, ctx) autoRan = autoRan + 1; ctx.message("어서 오세요") end })
	mgr:add(Event.new{ id = "loop", x = 1, y = 1, trigger = "parallel",
		script = function(self, ctx)
			while true do parRan = parRan + 1; ctx.wait(50) end
		end })

	mgr:onMapStart()
	t.check_eq(autoRan, 1, "auto는 맵 진입 시 실행된다")
	t.check_eq(interp:isBusy(), true, "auto는 조작을 잠근다")
	t.check(parRan > 0, "parallel도 함께 시작된다")

	local before = parRan
	for _ = 1, 8 do interp:update() end
	t.check(parRan > before, "auto가 도는 동안에도 parallel은 돈다")
	port.close(); interp:update()
	t.check_eq(interp:isBusy(), false, "auto가 끝나면 잠금 해제")

	-- ---- [7] clear: 맵 전환 시 정리 -----------------------------------------
	mgr:clear()
	t.check_eq(#mgr.events, 0, "이벤트 목록이 비워진다")
	t.check_eq(mgr:get("intro"), nil, "id 색인도 비워진다")
	t.check_eq(mgr:at(0, 0), nil, "조회도 비워진다")
end

return M
