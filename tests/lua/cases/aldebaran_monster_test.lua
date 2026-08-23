-- aldebaran_monster_test.lua : 몬스터 상태 기계의 단위 테스트
-- (docs/plans/aldebaran-2-combat.md 4절, 8절)
--
-- 가짜 지도 위에서 순찰, 추적, 공격, 돌격, 회복, 죽음을 프레임 단위로 재현한다.

local Monster = require("scripts/games/aldebaran/monster")

local M = {}

local DT = 1 / 60
local FAR = 99999            -- 플레이어가 아주 멀다 (경계 밖)

local function makeProbe(solids)
	return function(px, py)
		if px < 0 or px >= 500 * 16 then return true end
		if py >= 100 * 16 then return false end
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

--- 종별 표의 최소형 (stage.lua의 실물과 같은 필드)
local function makeDef(extra)
	local def = {
		hp = 20, atk = 5, def = 1, exp = 1, gold = 1,
		walkSpeed = 30, chaseSpeed = 60,
		alertRange = 80, attackRange = 16,
		windup = 0.3, active = 0.1, recover = 0.4,
		halfW = 8, bodyH = 16,
		cols = 4, frames = { walk = { 0, 1 }, attack = 2, hurt = 3 },
	}
	for k, v in pairs(extra or {}) do def[k] = v end
	return def
end

local function step(m, probe, n, px, py)
	for _ = 1, n do
		Monster.update(m, DT, probe, px or FAR, py or m.y)
	end
end

--- 평평한 땅 (윗면 24)과 그 위의 몬스터
local function flat(defExtra, opts)
	local solids = {}
	fillRow(solids, 24, 0, 499)
	local probe = makeProbe(solids)
	local def = makeDef(defExtra)
	opts = opts or {}
	opts.x = opts.x or 400
	opts.y = opts.y or 384
	local m = Monster.new(def, opts)
	step(m, probe, 2)         -- 착지 확정
	return m, probe, solids, def
end

function M.run(t)
	-- [A] 순찰: 정해진 구간을 왕복한다
	do
		local m, probe = flat(nil, { x = 400, minX = 360, maxX = 440, dir = 1 })
		step(m, probe, 120)      -- 2초 = 60px — maxX(440)에 닿고 돌아선다
		t.check_eq(m.state, "patrol", "플레이어가 멀면 순찰")
		t.check(m.x < 440 + 1, "순찰 구간을 넘지 않는다", m.x)
		t.check_eq(m.dir, -1, "구간 끝에서 돌아선다")
	end

	-- [B] 순찰: 벽에서 돌아선다 (원안 6.2.3절)
	do
		local m, probe, solids = flat(nil, { x = 400, minX = 200, maxX = 600, dir = 1 })
		fillCol(solids, 27, 22, 24)          -- px 432 벽
		step(m, probe, 90)
		t.check_eq(m.dir, -1, "벽과 부딪치면 반대 방향")
		t.check(m.x < 432 - 7, "벽을 뚫지 않는다", m.x)
	end

	-- [C] 순찰: 벼랑에서 돌아선다 (스스로 떨어지지 않는다)
	do
		local solids = {}
		fillRow(solids, 24, 20, 30)          -- px 320~495만 땅
		local probe = makeProbe(solids)
		local m = Monster.new(makeDef(), { x = 400, y = 384, minX = 200, maxX = 700, dir = 1 })
		step(m, probe, 2)
		step(m, probe, 240)                  -- 4초면 구간을 몇 번 오간다
		t.check_eq(m.state, "patrol", "여전히 순찰")
		t.check(m.onGround, "떨어지지 않았다")
		t.check(m.x > 320 and m.x < 496, "벼랑 사이를 오간다", m.x)
	end

	-- [D] 경계 범위에 들어오면 추적, 벗어나면 복귀
	do
		local m, probe = flat(nil, { x = 400, minX = 360, maxX = 440 })
		step(m, probe, 1, 400 + 70, 384)     -- 경계(80) 안
		t.check_eq(m.state, "chase", "경계 안이면 추적")
		local x0 = m.x
		step(m, probe, 30, 560, 384)
		t.check(m.x > x0, "추적은 플레이어 쪽으로 다가간다")
		step(m, probe, 5, 400 + 200, 384)    -- 경계 x1.5(120) 밖
		t.check_eq(m.state, "patrol", "멀어지면 순찰로 돌아간다")
	end

	-- [E] 공격: 선딜레이 -> 판정 -> 후딜레이 -> 다시 추적
	do
		local m, probe = flat(nil, { x = 400 })
		local px = 410                        -- 공격 범위(16) 안
		step(m, probe, 1, px, 384)
		t.check_eq(m.state, "chase", "먼저 추적")
		step(m, probe, 1, px, 384)
		t.check_eq(m.state, "windup", "닿으면 움츠린다")
		t.check_eq(Monster.attackBox(m), nil, "선딜레이에는 판정이 없다")
		step(m, probe, math.floor(0.3 / DT) + 1, px, 384)
		t.check_eq(m.state, "strike", "선딜레이가 끝나면 공격")
		t.check(Monster.attackBox(m) ~= nil, "공격 판정 상자가 선다")
		t.check(not m.strikeHit, "판정은 아직 쓰지 않았다")
		step(m, probe, math.floor(0.1 / DT) + 1, px, 384)
		t.check_eq(m.state, "recover", "판정이 끝나면 후딜레이")
		step(m, probe, math.floor(0.4 / DT) + 1, px, 384)
		t.check(m.state == "windup" or m.state == "chase", "후딜레이가 끝나면 다시")
	end

	-- [F] 돌격형(늑대): 발견 시 1회, 그 뒤로는 쓰지 않는다
	do
		local m, probe = flat({ special = "charge", chargeSpeed = 150,
			chargeTime = 0.5, chargeAtk = 14 }, { x = 400, minX = 300, maxX = 500 })
		step(m, probe, 1, 470, 384)
		t.check_eq(m.state, "charge", "발견하면 돌격")
		t.check(Monster.attackBox(m) ~= nil, "돌격 중에는 몸이 판정이다")
		local x0 = m.x
		step(m, probe, 6, 470, 384)
		t.check(m.x - x0 > 60 * 6 * DT, "돌격은 추적보다 빠르다", m.x - x0)
		step(m, probe, math.floor(0.5 / DT) + 2, 470, 384)
		t.check(m.chargeUsed, "돌격은 한 번뿐")
		t.check_eq(m.state ~= "charge", true, "돌격이 끝났다")
		-- 다시 멀어졌다 돌아와도 돌격은 없다
		step(m, probe, 60, FAR, 384)
		t.check_eq(m.state, "patrol", "복귀")
		step(m, probe, 1, 470, 384)
		t.check_eq(m.state, "chase", "두 번째 발견은 그냥 추적")
	end

	-- [G] 추적 중에는 낮은 턱을 뛰어넘는다 (원안: 벽이 있어도 점프)
	do
		local m, probe, solids = flat(nil, { x = 400, minX = 200, maxX = 600 })
		fillCol(solids, 28, 23, 24)          -- 한 타일 턱 (px 448, 벽면은 몸이 439에서 막힘)
		step(m, probe, 60, 470, 384)         -- 경계(80) 안의 플레이어를 추적
		t.check(m.x > 445 or not m.onGround, "턱을 뛰어넘는 중이거나 넘었다", m.x)
		step(m, probe, 150, 470, 384)
		t.check(m.x > 445, "결국 턱을 넘어 쫓아간다", m.x)
		t.check(m.state == "windup" or m.state == "strike" or m.state == "recover"
			or m.state == "chase", "플레이어 곁에 닿았다", m.state)
	end

	-- [H] 비전투 회복 (원안: 4초마다 최대 HP의 1/20)
	do
		local m, probe = flat({ regen = true, hp = 40 }, { x = 400, minX = 360, maxX = 440 })
		m.hp = 10
		step(m, probe, math.floor(4 / DT) + 5)
		t.check_eq(m.hp, 12, "4초 뒤 최대 HP의 1/20(2)을 회복")
		step(m, probe, 3, 420, 384)           -- 전투가 시작되면
		m.hp = 10
		local before = m.hp
		step(m, probe, math.floor(4 / DT) + 5, 420, 384)
		t.check_eq(m.hp, before, "전투 중에는 회복하지 않는다")
	end

	-- [I] 피격: 경직과 밀림, 때린 쪽을 돌아본다
	do
		local m, probe = flat(nil, { x = 400, dir = 1 })
		local died = Monster.hurt(m, 5, 1)    -- 오른쪽에서 맞았다
		t.check(not died, "아직 살아 있다")
		t.check_eq(m.hp, 15, "체력이 줄었다")
		t.check_eq(m.state, "hurt", "경직")
		t.check_eq(m.dir, -1, "때린 쪽을 돌아본다")
		step(m, probe, math.floor(0.25 / DT) + 2, 500, 384)
		t.check_eq(m.state, "chase", "경직이 풀리면 반격하러 온다")
	end

	-- [J] 죽음: 소멸 연출 뒤에 사라진다
	do
		local m, probe = flat(nil, { x = 400 })
		local died = Monster.hurt(m, 999, 1)
		t.check(died, "치명타면 hurt가 true를 돌려준다")
		t.check_eq(m.state, "dying", "소멸 연출로")
		t.check_eq(Monster.attackBox(m), nil, "죽는 중에는 판정이 없다")
		t.check(not m.dead, "연출 동안에는 남아 있다")
		step(m, probe, math.floor(0.5 / DT) + 3)
		t.check(m.dead, "연출이 끝나면 사라진다")
		local hp0 = m.hp
		local again = Monster.hurt(m, 5, 1)
		t.check(not again and m.hp == hp0, "죽은 몬스터는 더 맞지 않는다")
	end

	-- [K] 시트 칸: 상태마다 다른 칸, 왼쪽 보기는 아랫줄
	do
		local m, probe = flat(nil, { x = 400, dir = 1 })
		local f = Monster.frame(m)
		t.check(f == 0 or f == 1, "순찰은 걷기 칸", f)
		m.dir = -1
		t.check(Monster.frame(m) >= 4, "왼쪽 보기는 아랫줄 (cols만큼 밀린다)")
		m.dir = 1
		m.state = "strike"
		t.check_eq(Monster.frame(m), 2, "공격 칸")
		m.state = "hurt"
		t.check_eq(Monster.frame(m), 3, "피격 칸")
	end
end

return M
