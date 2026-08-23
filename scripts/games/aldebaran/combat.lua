-- 알데바란 — 전투와 성장의 수식 (docs/design/aldebaran.md 7절)
--
-- 엔진에 닿지 않는 순수 함수 묶음. 난수는 시드 난수(scripts/rpg/rng.lua)를
-- 주입받는다 — 같은 시드는 같은 전투를 만든다.

local M = {}

-- ---- 데미지 ---------------------------------------------------------------

--- 평타 데미지 (하한 1)
function M.damage(atk, def)
	return math.max(1, math.floor(atk - def))
end

--- 명중 굴림. q = 0.45 + 난수(0..1) + 행운.
--   q >= 1.5 크리티컬 (1.5배), q < 0.5 회피 (0배), 그 외 일반 (1배).
-- 행운 0.2면 크리티컬 15%에 회피 없음, 행운 0이면 크리티컬 없음에 회피 5%.
function M.roll(rng, luck)
	local q = 0.45 + rng:float() + (luck or 0)
	if q >= 1.5 then
		return { kind = "crit", mult = 1.5 }
	elseif q < 0.5 then
		return { kind = "miss", mult = 0 }
	end
	return { kind = "normal", mult = 1 }
end

--- 굴림까지 합친 최종 데미지. { dmg, kind }를 돌려준다.
function M.resolve(atk, def, rng, luck)
	local r = M.roll(rng, luck)
	return { dmg = math.floor(M.damage(atk, def) * r.mult), kind = r.kind }
end

-- ---- 레벨 (기획서 7.2절) ---------------------------------------------------

-- 레벨 n+1이 되는 누적 경험치. 최고 레벨은 7이다.
M.EXP_TABLE = { 10, 25, 45, 70, 100, 140 }
M.MAX_LEVEL = #M.EXP_TABLE + 1

M.BASE = { hp = 60, mp = 20, atk = 10, def = 2, luck = 0.2 }
M.GROWTH = { hp = 12, mp = 5, atk = 3, def = 1 }

--- 누적 경험치의 레벨
function M.levelFor(exp)
	local level = 1
	for i, need in ipairs(M.EXP_TABLE) do
		if exp >= need then level = i + 1 end
	end
	return level
end

--- 레벨의 능력치 표
function M.statsAt(level)
	local n = math.max(0, math.min(level, M.MAX_LEVEL) - 1)
	return {
		hp = M.BASE.hp + M.GROWTH.hp * n,
		mp = M.BASE.mp + M.GROWTH.mp * n,
		atk = M.BASE.atk + M.GROWTH.atk * n,
		def = M.BASE.def + M.GROWTH.def * n,
		luck = M.BASE.luck,
	}
end

--- 다음 레벨까지 남은 경험치 (최고 레벨이면 nil)
function M.expToNext(exp)
	local level = M.levelFor(exp)
	if level >= M.MAX_LEVEL then return nil end
	return M.EXP_TABLE[level] - exp
end

--- 지금 레벨 구간에서의 진행 비율 (EXP 바가 그린다, 0..1)
function M.expRatio(exp)
	local level = M.levelFor(exp)
	if level >= M.MAX_LEVEL then return 1 end
	local floor = (level > 1) and M.EXP_TABLE[level - 1] or 0
	local ceil = M.EXP_TABLE[level]
	return (exp - floor) / (ceil - floor)
end

-- ---- 버서커 (기획서 7.3절) -------------------------------------------------

M.BERSERK = {
	cost = 10,          -- MP
	time = 4,           -- 초
	atkMult = 1.5,      -- 주는 데미지
	takenMult = 0.5,    -- 받는 데미지
}

--- 발동할 수 있는가
function M.canBerserk(mp, active)
	return (not active) and mp >= M.BERSERK.cost
end

return M
