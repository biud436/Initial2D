-- aldebaran_combat_test.lua : 전투와 성장 수식의 단위 테스트
-- (docs/plans/aldebaran-2-combat.md 3절, 8절)

local Combat = require("scripts/games/aldebaran/combat")
local Rng = require("scripts/rpg/rng")

local M = {}

function M.run(t)
	-- [A] 데미지: 하한 1
	t.check_eq(Combat.damage(10, 2), 8, "평타 = 공격 - 방어")
	t.check_eq(Combat.damage(5, 10), 1, "방어가 더 높아도 데미지는 1")
	t.check_eq(Combat.damage(10.9, 2), 8, "데미지는 내림")

	-- [B] 명중 굴림: 행운 0.2면 크리티컬 약 15%에 회피 없음, 행운 0이면
	--     크리티컬 없음에 회피 약 5% (시드 고정이라 수치가 결정적이다)
	do
		local rng = Rng.new(42)
		local crit, miss = 0, 0
		for _ = 1, 1000 do
			local r = Combat.roll(rng, 0.2)
			if r.kind == "crit" then crit = crit + 1 end
			if r.kind == "miss" then miss = miss + 1 end
		end
		t.check(crit > 100 and crit < 200, "행운 0.2의 크리티컬은 약 15%", crit)
		t.check_eq(miss, 0, "행운 0.2면 회피당하지 않는다")

		rng = Rng.new(42)
		crit, miss = 0, 0
		for _ = 1, 1000 do
			local r = Combat.roll(rng, 0)
			if r.kind == "crit" then crit = crit + 1 end
			if r.kind == "miss" then miss = miss + 1 end
		end
		t.check_eq(crit, 0, "행운 0이면 크리티컬이 없다")
		t.check(miss > 20 and miss < 90, "행운 0의 회피는 약 5%", miss)
	end

	-- [C] resolve: 배율까지 합친 최종 데미지
	do
		local fake = { float = function() return 0.99 end }   -- 크리티컬 구간
		local r = Combat.resolve(10, 2, fake, 0.2)
		t.check_eq(r.kind, "crit", "0.99 굴림 + 행운 0.2는 크리티컬")
		t.check_eq(r.dmg, 12, "크리티컬은 1.5배 내림 (8 -> 12)")
		fake.float = function() return 0.01 end
		r = Combat.resolve(10, 2, fake, 0)
		t.check_eq(r.kind, "miss", "0.01 굴림 + 행운 0은 회피")
		t.check_eq(r.dmg, 0, "회피는 데미지 0")
	end

	-- [D] 레벨 표의 경계
	t.check_eq(Combat.levelFor(0), 1, "경험치 0은 레벨 1")
	t.check_eq(Combat.levelFor(9), 1, "9는 아직 레벨 1")
	t.check_eq(Combat.levelFor(10), 2, "10에서 레벨 2")
	t.check_eq(Combat.levelFor(24), 2, "24는 레벨 2")
	t.check_eq(Combat.levelFor(25), 3, "25에서 레벨 3")
	t.check_eq(Combat.levelFor(140), 7, "140에서 최고 레벨 7")
	t.check_eq(Combat.levelFor(9999), 7, "그 위로도 7")

	-- [E] 성장치
	do
		local s1 = Combat.statsAt(1)
		t.check(s1.hp == 60 and s1.mp == 20 and s1.atk == 10 and s1.def == 2,
			"레벨 1은 시작 능력치")
		local s3 = Combat.statsAt(3)
		t.check(s3.hp == 84 and s3.mp == 30 and s3.atk == 16 and s3.def == 4,
			"레벨 3 = 시작 + 성장 x2")
	end

	-- [F] EXP 바의 비율
	t.check_eq(Combat.expRatio(5), 0.5, "레벨 1 구간의 절반")
	t.check_eq(Combat.expRatio(10), 0, "레벨이 오르면 바는 처음부터")
	t.check_eq(Combat.expRatio(140), 1, "최고 레벨은 가득")
	t.check_eq(Combat.expToNext(5), 5, "다음 레벨까지 5")
	t.check_eq(Combat.expToNext(140), nil, "최고 레벨은 다음이 없다")

	-- [H] 힘과 쿨타임 (기획서 5.3절)
	do
		local s = Combat.newSkills()
		t.check(not s.berserk, "처음에는 아무 힘도 없다")
		t.check(not Combat.canUse(s, "berserk", 99), "익히지 않으면 쓸 수 없다")
		s.berserk = true
		t.check(Combat.canUse(s, "berserk", 10), "익히고 MP가 있으면 쓸 수 있다")
		t.check(not Combat.canUse(s, "berserk", 9), "MP가 모자라면 못 쓴다")
		s.cooldown.berserk = 3
		t.check(not Combat.canUse(s, "berserk", 99), "쿨타임이 돌면 못 쓴다")
		Combat.tickCooldowns(s, 1)
		t.check_eq(s.cooldown.berserk, 2, "쿨타임이 시간만큼 줄어든다")
		Combat.tickCooldowns(s, 5)
		t.check_eq(s.cooldown.berserk, 0, "0 아래로는 내려가지 않는다")
		t.check(Combat.canUse(s, "berserk", 99), "다 식으면 다시 쓸 수 있다")
		t.check(not Combat.canUse(s, "edge", 99), "늘 켜져 있는 힘은 쓰는 것이 아니다")
		t.check_eq(#Combat.SKILL_ORDER, 5, "힘은 다섯이다")
	end

	-- [G] 버서커
	t.check(Combat.canBerserk(10, false), "MP가 넉넉하면 발동")
	t.check(not Combat.canBerserk(9, false), "MP가 모자라면 못 켠다")
	t.check(not Combat.canBerserk(20, true), "이미 켜져 있으면 못 켠다")
	t.check_eq(Combat.BERSERK.time, 4, "지속 4초")
end

return M
