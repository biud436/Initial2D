-- rpg_character_test.lua : 그리드 이동, 통행 판정, 이동 큐, 걷기 애니메이션,
-- 배회 결정성, 그리고 입력을 붙인 플레이어까지 (5단계, docs/plans/05-rpg-character.md).
--
-- character/player는 엔진 전역을 부르지 않으므로 여기서 전부 검증된다.
-- 통행 판정은 가짜 canPass 함수를, 입력은 tests/lua/input_replay.lua의
-- 가짜 Input을 주입한다 (09-testing.md 3.2절).

local M = {}

-- 이동 한 칸이 정확히 4프레임이 되도록 고른 값 (0.25는 이진 소수라 오차가 없다)
local DT = 0.25
local SPEED = 1

local function near(a, b, eps)
	return math.abs(a - b) <= (eps or 1e-9)
end

-- 20x20 격자. blocked에 "x,y" 키가 있으면 막힌 칸.
local function fakeWorld(blocked)
	blocked = blocked or {}
	return function(tx, ty)
		if tx < 0 or ty < 0 or tx > 19 or ty > 19 then return false end
		return blocked[tx .. "," .. ty] ~= true
	end
end

local function step(c, n)
	for _ = 1, (n or 1) do c:update(DT) end
end

function M.run(t)
	local Character = require("scripts/rpg/character")
	local Player = require("scripts/rpg/player")
	local Rng = require("scripts/rpg/rng")
	local replay = require("scripts/luatests/input_replay")

	-- ---- [1] 생성과 기본값 ------------------------------------------------
	local c = Character.new{}
	t.check(c.tx == 0 and c.ty == 0, "기본 위치 (0,0)")
	t.check_eq(c.dir, "down", "기본 방향은 아래")
	t.check_eq(c:isMoving(), false, "처음에는 정지 상태")
	t.check_eq(c:pattern(), 1, "정지 자세는 가운데 프레임")
	t.check_eq(c:frameIndex(), 25, "0번 캐릭터 정면 서기 = 25 (specs와 같은 값)")
	t.check(pcall(Character.new, { dir = "diagonal" }) == false, "모르는 방향은 생성 오류")

	-- ---- [2] 방향 전환과 앞 타일 -------------------------------------------
	c = Character.new{ tx = 5, ty = 5 }
	t.check_eq(c:turn("up"), true, "turn 성공")
	t.check_eq(c.dir, "up", "방향이 바뀐다")
	local fx, fy = c:frontTile()
	t.check(fx == 5 and fy == 4, "위를 볼 때 앞 타일은 한 칸 위", fx .. "," .. fy)
	c:turn("right")
	fx, fy = c:frontTile()
	t.check(fx == 6 and fy == 5, "오른쪽을 볼 때 앞 타일")
	t.check_eq(c:turn("nope"), false, "모르는 방향 turn은 false")
	t.check_eq(c.dir, "right", "실패한 turn은 방향을 바꾸지 않는다")

	-- ---- [3] 통행 판정 ------------------------------------------------------
	c = Character.new{ tx = 5, ty = 5, speed = SPEED, canPass = fakeWorld{ ["6,5"] = true } }
	t.check_eq(c:tryMove("right"), false, "막힌 칸으로는 이동하지 않는다")
	t.check(c.tx == 5 and c.ty == 5, "막히면 위치가 그대로")
	t.check_eq(c.dir, "right", "막혀도 그 방향을 바라본다 (R2K3식)")
	t.check_eq(c.blocked, true, "막힌 사실이 기록된다")
	t.check_eq(c:isMoving(), false, "막히면 이동이 시작되지 않는다")

	c = Character.new{ tx = 0, ty = 0, speed = SPEED, canPass = fakeWorld{} }
	t.check_eq(c:tryMove("left"), false, "맵 밖으로는 나가지 못한다")

	c = Character.new{ tx = 5, ty = 5, speed = SPEED, through = true,
		canPass = fakeWorld{ ["6,5"] = true } }
	t.check_eq(c:tryMove("right"), true, "through면 통행 판정을 무시한다")

	-- ---- [4] 그리드 보간 이동 -----------------------------------------------
	c = Character.new{ tx = 5, ty = 5, speed = SPEED, canPass = fakeWorld{} }
	t.check_eq(c:tryMove("right"), true, "빈 칸으로 이동 시작")
	t.check(c.tx == 6 and c.ty == 5, "타일 좌표는 출발 즉시 목적지가 된다")
	t.check_eq(c:isMoving(), true, "이동 중")
	t.check_eq(c.offsetX, -16, "출발 순간 오프셋은 타일 하나만큼 뒤")

	local px, py = c:pixelPos()
	t.check(px == 5 * 16 - 4 and py == 6 * 16 - 32,
		"출발 순간 픽셀 좌표는 아직 출발 칸", px .. "," .. py)

	step(c, 1)
	t.check(near(c.offsetX, -12), "1프레임 뒤 오프셋 -12", tostring(c.offsetX))
	step(c, 2)
	t.check(near(c.offsetX, -4), "3프레임 뒤 오프셋 -4", tostring(c.offsetX))
	step(c, 1)
	t.check_eq(c:isMoving(), false, "4프레임에 도착")
	t.check(c.offsetX == 0 and c.offsetY == 0, "도착하면 오프셋 0")
	t.check(c.tx == 6 and c.ty == 5, "도착 위치")
	px, py = c:pixelPos()
	t.check(px == 6 * 16 - 4 and py == 6 * 16 - 32, "도착 픽셀 좌표", px .. "," .. py)

	-- 세로 이동도 같은 규칙
	c:tryMove("down")
	t.check(c.tx == 6 and c.ty == 6 and c.offsetY == -16, "아래로 출발")
	step(c, 4)
	t.check(c.ty == 6 and c.offsetY == 0 and not c:isMoving(), "아래 이동 완료")

	-- ---- [5] 이동 큐: 이동 중 입력은 하나만 예약된다 -------------------------
	c = Character.new{ tx = 5, ty = 5, speed = SPEED, canPass = fakeWorld{} }
	c:request("right")
	c:request("down")     -- 이동 중이므로 예약
	c:request("up")       -- 마지막 것만 남는다
	t.check_eq(c.queued, "up", "예약 슬롯은 하나")
	step(c, 4)
	t.check(c.tx == 6 and c.ty == 4, "도착 즉시 예약된 방향으로 이어 이동", c.tx .. "," .. c.ty)
	t.check_eq(c:isMoving(), true, "이어지는 이동이 진행 중")

	c = Character.new{ tx = 5, ty = 5, speed = SPEED, canPass = fakeWorld{} }
	c:request("right")
	c:request("down")
	c:cancelQueued()
	step(c, 4)
	t.check(c.tx == 6 and c.ty == 5 and not c:isMoving(), "예약 취소 후에는 그 칸에서 멈춘다")

	-- 남은 진행분(carry)은 다음 칸으로 이어진다 — 칸마다 미세하게 느려지면 안 된다
	c = Character.new{ tx = 5, ty = 5, speed = SPEED, canPass = fakeWorld{} }
	c:request("right")
	for _ = 1, 3 do c:update(DT) end
	c:request("right")
	c:update(0.3)          -- 진행도 0.75 + 0.3 = 1.05 → 0.05가 다음 칸으로
	t.check(c.tx == 7, "한 프레임에 칸을 넘어서면 다음 칸으로 이어진다", tostring(c.tx))
	t.check(near(c.moveProgress, 0.05, 1e-9), "남은 진행분이 보존된다",
		tostring(c.moveProgress))
	t.check(near(c.offsetX, -16 * 0.95, 1e-6), "이어진 칸의 오프셋", tostring(c.offsetX))

	-- ---- [6] 걷기 애니메이션 -----------------------------------------------
	c = Character.new{ tx = 5, ty = 5, speed = SPEED, canPass = fakeWorld{} }
	t.check_eq(c:pattern(), 1, "정지 중에는 서 있는 자세")
	c:tryMove("right")
	step(c, 1)
	t.check_eq(c:pattern(), 1, "칸의 앞부분은 아직 서기")
	step(c, 1)   -- 진행도 0.5
	t.check_eq(c:pattern(), 2, "절반을 지나면 다음 걸음")
	step(c, 2)   -- 도착 (예약 없음 → 서기로 복귀)
	t.check_eq(c:pattern(), 1, "멈추면 서 있는 자세로 돌아온다")

	-- 계속 걸으면 왼발과 오른발이 번갈아 나온다
	c = Character.new{ tx = 5, ty = 5, speed = SPEED, canPass = fakeWorld{} }
	local seen = {}
	for _ = 1, 40 do
		c:request("right")
		c:update(DT)
		seen[c:pattern()] = true
	end
	t.check(seen[0] and seen[1] and seen[2],
		"연속 이동에서 걸음 세 자세가 모두 나온다")
	t.check_eq(c.dir, "right", "이동 중 방향 유지")

	-- 프레임 번호는 방향과 걸음에서 나온다 (specs와 같은 규칙).
	-- 1번 캐릭터의 블록은 x=72부터, 위쪽은 0행, 서기는 가운데 열 → 격자 4번 칸.
	c = Character.new{ tx = 5, ty = 5, charIndex = 1, dir = "up" }
	t.check_eq(c:frameIndex(), 4, "1번 캐릭터 위쪽 서기 프레임")

	-- ---- [7] 캐릭터끼리의 점유 ----------------------------------------------
	local roster = {}
	local function occupancy(tx, ty, who)
		if tx < 0 or ty < 0 or tx > 19 or ty > 19 then return false end
		for _, other in ipairs(roster) do
			if other ~= who and other.tx == tx and other.ty == ty then return false end
		end
		return true
	end
	local a = Character.new{ tx = 5, ty = 5, speed = SPEED, canPass = occupancy }
	local b = Character.new{ tx = 6, ty = 5, speed = SPEED, canPass = occupancy }
	roster = { a, b }
	t.check_eq(a:tryMove("right"), false, "다른 캐릭터가 선 칸으로는 못 간다")
	t.check_eq(b:tryMove("right"), true, "b는 비켜 갈 수 있다")
	t.check_eq(a:tryMove("right"), true, "b가 떠난 칸으로는 갈 수 있다")
	-- b는 아직 (7,5)로 이동 중이지만 목적지 칸을 이미 점유한다
	local d = Character.new{ tx = 7, ty = 6, speed = SPEED, canPass = occupancy }
	table.insert(roster, d)
	t.check_eq(d:tryMove("up"), false, "이동 중인 캐릭터의 목적지 칸도 막혀 있다")

	-- ---- [8] 그리기 순서 (y정렬) -------------------------------------------
	local far = Character.new{ tx = 3, ty = 2 }
	local nearC = Character.new{ tx = 8, ty = 9 }
	local same = Character.new{ tx = 1, ty = 2 }
	t.check_eq(Character.compareDepth(far, nearC), true, "위쪽 캐릭터를 먼저 그린다")
	t.check_eq(Character.compareDepth(nearC, far), false, "역방향은 반대")
	t.check_eq(Character.compareDepth(far, same), true, "같은 줄이면 등록 순서로 고정")
	t.check_eq(Character.compareDepth(same, far), false, "등록 순서 비교는 대칭")

	local list = { nearC, same, far }
	table.sort(list, Character.compareDepth)
	t.check(list[1] == far and list[2] == same and list[3] == nearC,
		"정렬 결과가 발 위치 오름차순")

	-- 이동 중에는 픽셀 단위로 순서가 바뀐다 (칸 경계에서 튀지 않는다)
	local mover = Character.new{ tx = 3, ty = 3, speed = SPEED, canPass = fakeWorld{} }
	local still = Character.new{ tx = 5, ty = 3 }
	t.check_eq(Character.compareDepth(mover, still), true, "같은 줄, 등록 순서")
	mover:tryMove("down")
	t.check_eq(Character.compareDepth(mover, still), true,
		"출발 순간에는 아직 같은 줄 (오프셋이 타일 하나만큼 뒤에 있다)")
	step(mover, 2)
	t.check_eq(Character.compareDepth(still, mover), true,
		"아래로 반쯤 내려간 캐릭터가 더 나중에 그려진다")

	-- ---- [9] place: 보간 없이 옮긴다 ---------------------------------------
	c = Character.new{ tx = 5, ty = 5, speed = SPEED, canPass = fakeWorld{} }
	c:tryMove("right")
	c:place(1, 2, "up")
	t.check(c.tx == 1 and c.ty == 2 and c.dir == "up", "place가 즉시 옮긴다")
	t.check(not c:isMoving() and c.offsetX == 0, "place는 이동 상태를 지운다")

	-- ---- [10] 배회: 시드가 같으면 경로가 같다 --------------------------------
	local function wanderTrace(seed, area)
		local w = Character.new{ tx = 10, ty = 10, speed = SPEED, canPass = fakeWorld{} }
		w:setWander{ rng = Rng.new(seed), minWait = 3, maxWait = 8, area = area }
		local trace = {}
		for _ = 1, 240 do
			w:update(DT)
			trace[#trace + 1] = w.tx .. "," .. w.ty .. "," .. w.dir
		end
		return table.concat(trace, " "), w
	end

	local t1 = wanderTrace(1234)
	local t2 = wanderTrace(1234)
	t.check_eq(t1, t2, "같은 시드는 같은 배회 경로")
	local t3 = wanderTrace(99)
	t.check(t1 ~= t3, "시드가 다르면 경로가 다르다")
	t.check(t1:find("10,10") ~= nil, "배회 경로가 시작 칸에서 출발한다")

	local area = { x = 9, y = 9, w = 3, h = 3 }
	local _, bounded = wanderTrace(7, area)
	t.check(bounded.tx >= 9 and bounded.tx < 12 and bounded.ty >= 9 and bounded.ty < 12,
		"배회 구역 밖으로 나가지 않는다", bounded.tx .. "," .. bounded.ty)

	local moved = false
	local _, roamer = wanderTrace(1234)
	if roamer.tx ~= 10 or roamer.ty ~= 10 then moved = true end
	t.check(moved, "배회가 실제로 캐릭터를 움직인다",
		roamer.tx .. "," .. roamer.ty)
	t.check(pcall(function() Character.new{}:setWander{} end) == false,
		"rng 없는 배회는 오류 (전역 난수 사용을 막는다)")

	-- ---- [10-b] 이동 루트 (6단계 moveRoute의 토대) --------------------------
	c = Character.new{ tx = 5, ty = 5, speed = SPEED, canPass = fakeWorld{} }
	t.check_eq(c:isRouteDone(), true, "루트가 없으면 끝난 것으로 본다")

	c:setRoute({ "right", "down" })
	t.check_eq(c:isRouteDone(), false, "루트를 걸면 아직 안 끝났다")
	step(c, 4)
	t.check(c.tx == 6 and c.ty == 5, "첫 명령 수행", c.tx .. "," .. c.ty)
	step(c, 5)
	t.check(c.tx == 6 and c.ty == 6, "둘째 명령 수행", c.tx .. "," .. c.ty)
	step(c, 2)
	t.check_eq(c:isRouteDone(), true, "명령을 다 쓰면 끝난다")

	-- turn: 이동 없이 방향만
	c = Character.new{ tx = 5, ty = 5, speed = SPEED, canPass = fakeWorld{} }
	c:setRoute({ "turn:left" })
	step(c, 2)
	t.check_eq(c.dir, "left", "turn 명령은 방향만 바꾼다")
	t.check(c.tx == 5 and c.ty == 5, "turn은 움직이지 않는다")

	-- wait:ms — 고정 스텝(16.67ms) 기준으로 프레임을 센다
	c = Character.new{ tx = 5, ty = 5, speed = SPEED, canPass = fakeWorld{} }
	c:setRoute({ "wait:100", "right" })   -- 100ms = 6프레임
	step(c, 4)
	t.check_eq(c.tx, 5, "대기 중에는 움직이지 않는다")
	step(c, 4)
	t.check_eq(c.tx, 6, "대기가 끝나면 다음 명령", tostring(c.tx))

	-- 막히면 기본은 재시도, skipBlocked면 건너뛴다
	c = Character.new{ tx = 5, ty = 5, speed = SPEED, canPass = fakeWorld{ ["6,5"] = true } }
	c:setRoute({ "right", "down" })
	step(c, 6)
	t.check(c.tx == 5 and c.ty == 5, "막힌 명령에서 기다린다", c.tx .. "," .. c.ty)
	t.check_eq(c:isRouteDone(), false, "막혀 있으면 루트가 끝나지 않는다")

	c = Character.new{ tx = 5, ty = 5, speed = SPEED, canPass = fakeWorld{ ["6,5"] = true } }
	c:setRoute({ "right", "down" }, { skipBlocked = true })
	step(c, 6)
	t.check(c.tx == 5 and c.ty == 6, "skipBlocked면 막힌 명령을 건너뛴다", c.tx .. "," .. c.ty)

	-- loop: 끝에서 처음으로 돌아간다 (순찰)
	c = Character.new{ tx = 5, ty = 5, speed = SPEED, canPass = fakeWorld{} }
	c:setRoute({ "right", "left" }, { loop = true })
	step(c, 40)
	t.check_eq(c:isRouteDone(), false, "loop 루트는 끝나지 않는다")
	t.check(c.tx >= 5 and c.tx <= 6, "제자리를 오간다", tostring(c.tx))

	-- clearRoute와 배회의 우선순위
	c:clearRoute()
	t.check_eq(c:isRouteDone(), true, "clearRoute 후에는 끝난 상태")

	c = Character.new{ tx = 5, ty = 5, speed = SPEED, canPass = fakeWorld{} }
	c:setWander{ rng = Rng.new(1), minWait = 1, maxWait = 1 }
	c:setRoute({ "wait:1000" })
	step(c, 20)
	t.check(c.tx == 5 and c.ty == 5, "루트가 배회보다 우선한다", c.tx .. "," .. c.ty)

	-- ---- [11] 플레이어 입력: 방향 전환과 걷기 -------------------------------
	local function newPlayer(scenario, opts)
		opts = opts or {}
		local char = Character.new{
			tx = opts.tx or 5, ty = opts.ty or 5, dir = opts.dir or "down",
			speed = SPEED, canPass = opts.canPass or fakeWorld{},
		}
		local r = replay.new(scenario)
		local p = Player.new{
			character = char, input = r.api, pad = opts.pad,
			turnFrames = opts.turnFrames or 2,
		}
		return char, p, r
	end

	local function drive(char, p, r, frames)
		for _ = 1, frames do
			r:tick()
			p:update()
			char:update(DT)
		end
	end

	-- 정지 중 다른 방향키: 먼저 몸만 돌린다
	local char, p, r = newPlayer{ { at = 1, press = "RIGHT" } }
	drive(char, p, r, 1)
	t.check_eq(char.dir, "right", "누른 순간 방향이 바뀐다")
	t.check(char.tx == 5 and not char:isMoving(), "방향 전환 프레임에는 움직이지 않는다")
	drive(char, p, r, 2)
	t.check(char.tx == 5 and not char:isMoving(), "turnFrames 동안은 제자리")
	drive(char, p, r, 1)
	t.check_eq(char:isMoving(), true, "계속 누르고 있으면 걷기 시작")

	-- 짧게 누르면(탭) 방향만 바뀌고 걷지 않는다
	char, p, r = newPlayer({ { at = 1, press = "UP" }, { at = 3, release = "UP" } },
		{ turnFrames = 5 })
	drive(char, p, r, 12)
	t.check_eq(char.dir, "up", "탭으로 방향만 전환")
	t.check(char.tx == 5 and char.ty == 5, "탭으로는 움직이지 않는다")

	-- 이미 그 방향을 보고 있으면 지연 없이 출발한다
	char, p, r = newPlayer({ { at = 1, press = "RIGHT" } }, { dir = "right" })
	drive(char, p, r, 1)
	t.check_eq(char:isMoving(), true, "같은 방향이면 즉시 출발")

	-- 벽을 향해 누르고 있어도 제자리에서 그 방향을 본다
	char, p, r = newPlayer({ { at = 1, press = "RIGHT" } },
		{ dir = "right", canPass = fakeWorld{ ["6,5"] = true } })
	drive(char, p, r, 20)
	t.check(char.tx == 5 and char.dir == "right" and not char:isMoving(),
		"막힌 방향으로는 계속 눌러도 제자리")

	-- 시나리오 재생: 오른쪽으로 걷다가 키를 떼면 칸에 맞춰 멈춘다.
	-- turnFrames=2, 한 칸 4프레임이므로 프레임 4에 출발해 7, 11, 15, 19에 칸이
	-- 바뀌고(5→10), 프레임 21의 키 떼기로 예약이 끊겨 23에 멈춘다.
	char, p, r = newPlayer({ { at = 1, press = "RIGHT" }, { at = 21, release = "RIGHT" } })
	drive(char, p, r, 30)
	t.check(not char:isMoving(), "키를 떼면 칸 경계에서 멈춘다")
	t.check_eq(char.tx, 10, "재생 결과 x좌표")
	t.check_eq(char.ty, 5, "재생 중 y좌표는 그대로")
	t.check_eq(char.offsetX, 0, "멈춘 자리는 칸에 정확히 맞는다")
	t.check_eq(char:pattern(), 1, "멈추면 서 있는 자세")

	-- 방향을 바꿔 가며 걷기: 오른쪽 두 칸 뒤 아래로
	char, p, r = newPlayer({
		{ at = 1, press = "RIGHT" }, { at = 12, release = "RIGHT" },
		{ at = 13, press = "DOWN" }, { at = 30, release = "DOWN" },
	})
	drive(char, p, r, 44)
	t.check(char.tx > 5 and char.ty > 5, "두 방향으로 이동했다",
		char.tx .. "," .. char.ty)
	t.check_eq(char.dir, "down", "마지막 방향은 아래")
	t.check(not char:isMoving() and char.offsetY == 0, "마지막에 칸에 맞춰 정지")

	-- 가상 D-패드가 키보드보다 우선한다 (터치 플랫폼)
	local padDir = "left"
	char, p, r = newPlayer({ { at = 1, press = "RIGHT" }, { at = 2, release = "RIGHT" } },
		{ pad = { pressed = function() return padDir end } })
	drive(char, p, r, 1)
	t.check_eq(char.dir, "left", "패드 입력이 키보드보다 우선")
	padDir = nil
	drive(char, p, r, 8)
	t.check(char.tx == 5 and char.ty == 5, "패드를 떼면 멈춘다", char.tx .. "," .. char.ty)
end

return M
