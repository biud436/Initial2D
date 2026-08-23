-- aldebaran_player_test.lua : 카르토 이동 물리의 단위 테스트
-- (docs/plans/aldebaran-1-core.md 8절)
--
-- 가짜 충돌 지도를 주입해 물리를 프레임 단위로 재현한다. 엔진이 필요 없다.

local Player = require("scripts/games/aldebaran/player")

local M = {}

local DT = 1 / 60

--- solids: { ["tx,ty"] = true } 인 가짜 지도. 좌우 밖은 벽, 아래 밖은 낭떠러지.
local function makeProbe(solids)
	return function(px, py)
		if px < 0 or px >= 200 * 16 then return true end
		if py >= 200 * 16 then return false end
		if py < 0 then return false end
		return solids[math.floor(px / 16) .. "," .. math.floor(py / 16)] == true
	end
end

local function fillRow(solids, ty, x0, x1)
	for x = x0, x1 do solids[x .. "," .. ty] = true end
end

local function fillCol(solids, tx, y0, y1)
	for y = y0, y1 do solids[tx .. "," .. y] = true end
end

--- n 프레임 굴린다. inputs[i]가 있으면 그 프레임의 입력, 없으면 빈 입력.
local function step(p, probe, n, inputs)
	for i = 1, n do
		Player.update(p, (inputs and inputs[i]) or {}, DT, probe)
	end
end

--- 평평한 땅 (윗면 타일 24, 발 픽셀 384)과 그 위에 선 플레이어
local function flatGround()
	local solids = {}
	fillRow(solids, 24, 0, 199)
	local probe = makeProbe(solids)
	local p = Player.new(100, 384)
	step(p, probe, 3)   -- 첫 프레임에 착지를 확정
	return p, probe, solids
end

function M.run(t)
	-- [A] 걷기: 등속이다 (가속 없음)
	do
		local p, probe = flatGround()
		local x0 = p.x
		step(p, probe, 1, { { right = true } })
		local step1 = p.x - x0
		step(p, probe, 1, { { right = true } })
		local step2 = p.x - x0 - step1
		t.check(math.abs(step1 - Player.WALK_SPEED * DT) < 0.01, "걷기 한 프레임 = 속도 x dt",
			step1)
		t.check(math.abs(step2 - step1) < 0.001, "걷기는 등속 (가속 없음)")
		t.check_eq(p.facing, 1, "오른쪽을 본다")
		step(p, probe, 1, { { left = true } })
		t.check_eq(p.facing, -1, "왼쪽 입력이면 왼쪽을 본다")
		step(p, probe, 1, { { left = true, right = true } })
		t.check_eq(p.vx, 0, "양쪽을 같이 누르면 멈춘다")
	end

	-- [B] 벽에 막힌다
	do
		local p, probe, solids = flatGround()
		fillCol(solids, 8, 20, 24)      -- px 128~143 벽
		p.x = 200                        -- 벽의 오른쪽에서 왼쪽으로 걷는다
		local inputs = {}
		for i = 1, 120 do inputs[i] = { left = true } end
		step(p, probe, 120, inputs)
		t.check(p.x > 8 * 16 + 16, "벽을 뚫지 않는다", p.x)
		t.check(math.abs(p.x - (9 * 16 + Player.HALF_W)) < 1, "벽에 붙어 멈춘다", p.x)
	end

	-- [C] 점프 최고점: 3타일(48px)은 넘고 4타일(64px)은 못 넘는다
	do
		local p, probe = flatGround()
		local top = p.y
		step(p, probe, 1, { { jumpEdge = true } })
		t.check(p.jumped, "점프가 일어났다")
		for _ = 1, 120 do
			Player.update(p, {}, DT, probe)
			top = math.min(top, p.y)
			if p.onGround then break end
		end
		local rise = 384 - top
		t.check(rise > 48, "점프 상승이 3타일을 넘는다", rise)
		t.check(rise < 64, "점프 상승이 4타일에는 못 미친다", rise)
		t.check(p.onGround, "다시 착지한다")
	end

	-- [D] 2단 점프: 합쳐 5타일(80px)을 넘고 6타일(96px)은 못 넘는다
	do
		local p, probe = flatGround()
		local top = p.y
		step(p, probe, 1, { { jumpEdge = true } })
		local second = false
		for _ = 1, 200 do
			local input = {}
			if not second and p.vy >= 0 then      -- 최고점에서 한 번 더
				input.jumpEdge = true
				second = true
			end
			Player.update(p, input, DT, probe)
			top = math.min(top, p.y)
			if p.onGround then break end
		end
		local rise = 384 - top
		t.check(rise > 80, "2단 점프가 5타일을 넘는다", rise)
		t.check(rise < 96, "2단 점프도 6타일에는 못 미친다", rise)
	end

	-- [E] 공중 점프는 한 번만
	do
		local p, probe = flatGround()
		step(p, probe, 1, { { jumpEdge = true } })
		step(p, probe, 2)
		step(p, probe, 1, { { jumpEdge = true } })
		t.check_eq(p.airJumps, 0, "공중 점프를 쓰면 남은 횟수가 0")
		local vyBefore = p.vy
		step(p, probe, 1, { { jumpEdge = true } })
		t.check(p.vy > vyBefore - 1, "세 번째 점프는 없다 (속도가 다시 튀지 않는다)")
	end

	-- [F] 걸어서 떨어져도 공중 점프는 한 번 남는다
	do
		local solids = {}
		fillRow(solids, 24, 0, 10)          -- 절벽: x<=175까지만 땅
		local probe = makeProbe(solids)
		local p = Player.new(160, 384)
		step(p, probe, 3)
		local inputs = {}
		for i = 1, 30 do inputs[i] = { right = true } end
		step(p, probe, 30, inputs)          -- 오른쪽 끝을 지나 떨어진다
		t.check(not p.onGround, "절벽을 걸어 나가면 공중이다")
		local vyBefore = p.vy
		step(p, probe, 1, { { jumpEdge = true } })
		t.check(p.vy < vyBefore, "떨어지는 중에도 점프가 한 번 된다")
		t.check_eq(p.airJumps, 0, "그 한 번을 쓰면 끝")
	end

	-- [G] 2타일 턱에 뛰어 올라선다
	do
		local p, probe, solids = flatGround()
		fillRow(solids, 22, 10, 20)         -- 턱 윗면 22 (지면보다 2타일 위)
		fillRow(solids, 23, 10, 20)
		p.x = 140                            -- 턱 바로 앞 (모서리 154에서 14px)
		local inputs = {}
		inputs[1] = { jumpEdge = true, right = true }
		for i = 2, 90 do inputs[i] = { right = true } end
		step(p, probe, 90, inputs)
		t.check(p.onGround, "턱 위에 착지했다")
		t.check_eq(p.y, 22 * 16, "발이 턱 윗면에 있다")
	end

	-- [H] 더블탭 대쉬
	do
		local p, probe = flatGround()
		step(p, probe, 1, { { rightEdge = true, right = true } })
		step(p, probe, 3, { { right = false }, {}, {} })
		step(p, probe, 1, { { rightEdge = true, right = true } })
		t.check(p.dashed, "빠른 두 번 누름은 대쉬다")
		t.check(math.abs(p.vx - Player.DASH_SPEED) < 0.01, "대쉬 속도", p.vx)
		-- 대쉬가 끝나면 걷기 속도로
		local inputs = {}
		for i = 1, 30 do inputs[i] = { right = true } end
		step(p, probe, 30, inputs)
		t.check(math.abs(p.vx - Player.WALK_SPEED) < 0.01, "대쉬가 끝나면 걷기 속도", p.vx)
	end

	-- [I] 느린 두 번 누름은 대쉬가 아니다
	do
		local p, probe = flatGround()
		step(p, probe, 1, { { rightEdge = true, right = true } })
		step(p, probe, 20)                  -- 0.33초 — 판정 창(0.25초) 밖
		step(p, probe, 1, { { rightEdge = true, right = true } })
		t.check(not p.dashed, "판정 창을 지난 두 번째 누름은 그냥 걷기다")
	end

	-- [J] 낙하 최대 속도
	do
		local probe = makeProbe({})         -- 땅이 없다
		local p = Player.new(100, 0)
		step(p, probe, 120)
		t.check_eq(p.vy, Player.MAX_FALL, "낙하 속도가 상한에서 멈춘다")
	end

	-- [K] 천장에 머리를 부딪히면 상승이 멈춘다
	do
		local p, probe, solids = flatGround()
		fillRow(solids, 21, 0, 199)         -- 낮은 천장 (턱 위 공간 2타일)
		step(p, probe, 1, { { jumpEdge = true } })
		step(p, probe, 10)
		t.check(p.y >= 22 * 16 + Player.BODY_H, "머리가 천장을 뚫지 않는다", p.y)
	end

	-- [M] 달리기 기억과 공중 관성: 달리다 손을 떼고 점프해도 앞으로 나아간다
	--     (단일 터치 조작 — 패드와 점프 버튼을 동시에 누를 수 없다)
	do
		local p, probe = flatGround()
		local inputs = { { right = true }, { right = true }, {}, { jumpEdge = true } }
		step(p, probe, 4, inputs)            -- 달리고, 손을 떼고, 다음 프레임에 점프
		t.check(not p.onGround, "공중에 떠 있다")
		t.check(math.abs(p.vx - Player.WALK_SPEED) < 0.01,
			"손을 뗀 직후의 점프가 달리기 속도를 잇는다", p.vx)
		local x0 = p.x
		step(p, probe, 5)                    -- 입력 없음
		t.check(p.x > x0 + 5, "공중에서는 관성으로 나아간다", p.x - x0)
		for _ = 1, 90 do
			Player.update(p, {}, DT, probe)
			if p.onGround then break end
		end
		local xl = p.x
		step(p, probe, 3)
		t.check(math.abs(p.x - xl) < 0.001, "착지하면 멈춘다")
	end

	-- [N] 서 있다가 한참 뒤의 점프는 제자리 점프다 (기억 유예가 끝났다)
	do
		local p, probe = flatGround()
		step(p, probe, 2, { { right = true }, { right = true } })
		step(p, probe, 20)                   -- 0.33초 — 유예(0.18초)를 지난다
		step(p, probe, 1, { { jumpEdge = true } })
		t.check_eq(p.vx, 0, "유예가 지난 점프는 제자리 점프")
	end

	-- [L] 시트 칸 고르기
	do
		local p, probe = flatGround()
		t.check(Player.frame(p) <= 1, "서 있으면 서기 칸")
		step(p, probe, 1, { { right = true } })
		local f = Player.frame(p)
		t.check(f >= 2 and f <= 5, "걸으면 걷기 칸", f)
		step(p, probe, 1, { { jumpEdge = true } })
		t.check_eq(Player.frame(p), 6, "상승 중엔 점프 칸")
		step(p, probe, 1, { { left = true } })
		t.check(Player.frame(p) >= 12, "왼쪽을 보면 아랫줄 칸")
	end
end

return M
