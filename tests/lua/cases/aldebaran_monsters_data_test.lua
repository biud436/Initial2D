-- aldebaran_monsters_data_test.lua : 몬스터 규격서 스키마의 단위 테스트
-- (docs/plans/aldebaran-6-source-mining.md 3절 7항)
--
-- 이 표는 P5에서 적 열 종을 담을 그릇이다. 그릇의 모양이 지켜지는지, 그리고
-- stage.lua를 거쳐 게임에 그대로 닿는지를 본다. 원안 값(spec)은 사료라
-- 바뀌면 안 되므로 몇 개를 못 박아 둔다.

local Monsters = require("scripts/games/aldebaran/data/monsters")
local Stages = require("scripts/games/aldebaran/stages/init")
local Stage = Stages.get("forest")

local M = {}

local function count(tbl)
	local n = 0
	for _ in pairs(tbl) do n = n + 1 end
	return n
end

function M.run(t)
	-- [A] 스키마: 모든 종이 검사를 통과한다
	do
		local problems = Monsters.validate()
		t.check_eq(#problems, 0, "스키마 문제 없음: " .. table.concat(problems, " / "))
		t.check_eq(count(Monsters.species), 7, "종은 일곱이다 (숲 넷, 무덤 셋)")
	end

	-- [B] 검사기가 진짜로 잡는가 (통과만 보면 검사기가 죽어도 모른다)
	do
		t.check(Monsters.validateSpecies("x", {}) ~= nil, "빈 종은 걸러진다")
		t.check(Monsters.validateSpecies("x", "표가 아님") ~= nil, "표가 아니면 걸러진다")

		local broken = {}
		for k, v in pairs(Monsters.species.spider) do broken[k] = v end
		broken.hp = nil
		t.check(Monsters.validateSpecies("x", broken) ~= nil, "엔진 칸이 빠지면 걸러진다")

		local badspec = {}
		for k, v in pairs(Monsters.species.spider) do badspec[k] = v end
		badspec.spec = { element = "dark", ["오타칸"] = 1 }
		t.check(Monsters.validateSpecies("x", badspec) ~= nil, "spec의 모르는 칸은 걸러진다")

		local badtype = {}
		for k, v in pairs(Monsters.species.spider) do badtype[k] = v end
		badtype.spec = { attackType = "없는형" }
		t.check(Monsters.validateSpecies("x", badtype) ~= nil, "모르는 공격 방식은 걸러진다")

		local badtier = {}
		for k, v in pairs(Monsters.species.spider) do badtier[k] = v end
		badtier.spec = { stats = { moveSpeed = "초광속" } }
		t.check(Monsters.validateSpecies("x", badtier) ~= nil,
			"모르는 이동 속도 단계는 걸러진다")
	end

	-- [C] 원안 2.3.1절 표 6: 공격 방식 넷. 사료 표에 우리 것이 섞이면 안 된다
	do
		t.check_eq(count(Monsters.ATTACK_TYPES), 4, "원안의 공격 방식은 넷이다")
		for _, key in ipairs({ "melee", "charge", "throw", "suicide" }) do
			t.check(Monsters.ATTACK_TYPES[key] ~= nil, "원안의 공격 방식 " .. key)
		end
		t.check_eq(count(Monsters.EXTRA_ATTACK_TYPES), 2, "우리가 더한 것은 둘이다")
		for _, key in ipairs({ "air", "shield" }) do
			t.check(Monsters.ATTACK_TYPES[key] == nil, key .. "는 원안 표에 없다")
			t.check(Monsters.EXTRA_ATTACK_TYPES[key] ~= nil, "우리 공격 방식 " .. key)
			t.check(Monsters.EXTRA_ATTACK_TYPES[key].question ~= nil,
				key .. "는 묻는 질문이 적혀 있다")
		end
		t.check(Monsters.attackType("melee") ~= nil, "attackType은 원안 것을 찾는다")
		t.check(Monsters.attackType("air") ~= nil, "attackType은 우리 것도 찾는다")
		t.check(Monsters.attackType("없는형") == nil, "모르는 것은 nil")

		-- 자폭형은 A7에서 처음 쓰인다 (원안 표 6의 넷 중 마지막 빈 칸이었다)
		local used = {}
		for _, def in pairs(Monsters.species) do
			if def.spec and def.spec.attackType then used[def.spec.attackType] = true end
		end
		for _, key in ipairs({ "melee", "charge", "throw", "suicide", "air", "shield" }) do
			t.check(used[key], "공격 방식 " .. key .. "을 쓰는 종이 있다")
		end
	end

	-- [C2] 텔레그래프 부등식 (계획 aldebaran-7-tomb.md 5절):
	--      선딜 >= 회피 성립 프레임 + 인지 반응(15프레임).
	--
	--      **이 규칙은 1-1의 적에게는 아직 적용할 수 없다.** 부등식의 왼쪽 항은
	--      "회피 수단의 성립 프레임"인데, 지금 게임에는 무적 프레임을 가진 회피가
	--      없다 (대쉬는 그냥 빠른 이동이다). 진짜 회피는 P3의 일이고, 그때 1-1의
	--      수치도 함께 본다.
	--
	--      그래서 여기서는 둘로 나눠 검사한다.
	--        1) A7의 새 적 셋 — 부등식을 지켜 설계했으므로 지킨다.
	--        2) 1-1의 적 넷 — 지금 값을 못 박아 둔다. 누가 바꾸면 여기가 알려 준다.
	do
		local MIN_WINDUP = 32 / 60
		for _, key in ipairs({ "soul", "sentinel", "shard" }) do
			local def = Monsters.species[key]
			t.check(def.windup >= MIN_WINDUP - 1e-9,
				key .. "의 선딜이 32프레임 이상 (" .. tostring(def.windup) .. ")")
		end
		local shard = Monsters.species.shard
		t.check(shard.fuseTime >= 45 / 60 - 1e-9,
			"자폭 예고는 45프레임 이상 (" .. tostring(shard.fuseTime) .. ")")

		-- 1-1의 적은 셋 다 부등식을 깬다 (21, 18, 16프레임). 알고 두는 것이다.
		local known = { spider = 0.35, wolf = 0.3, blackwolf = 0.26, monkey = 0.4 }
		for key, want in pairs(known) do
			t.check_eq(Monsters.species[key].windup, want,
				"1-1 " .. key .. "의 선딜은 아직 " .. tostring(want) .. "초다 (P3에서 다시 본다)")
			t.check(want < MIN_WINDUP,
				"기록: " .. key .. "은 부등식을 깬다 — P3가 회피를 넣을 때 함께 고친다")
		end
	end

	-- [D] 원안 6.2.2절 표 37: 이동 속도 5단계
	do
		t.check_eq(#Monsters.SPEED_TIERS, 5, "이동 속도는 5단계다")
		t.check_eq(Monsters.SPEED_TIERS[1].scale, 0.3, "1단계는 0.3")
		t.check_eq(Monsters.SPEED_TIERS[5].scale, 3.0, "5단계는 3.0")
	end

	-- [E] 원안 표 39와 40의 값은 사료다. 바뀌면 채굴본과 어긋난 것이다
	do
		local spider = Monsters.species.spider.spec
		t.check_eq(spider.source.table, 39, "거미는 원안 표 39")
		t.check_eq(spider.source.section, "6.3", "거미는 원안 6.3절")
		t.check_eq(spider.element, "dark", "거미는 암 속성")
		t.check_eq(spider.weakness.light, true, "거미는 빛에 약하다 (P4의 상성)")
		t.check_eq(spider.reward.exp, 5, "거미 보상 경험치 5")
		t.check_eq(spider.reward.gold, 10, "거미 보상 골드 10")
		t.check_eq(spider.specials[1].chance, 0.2, "독침 발동 20%")
		t.check_eq(spider.specials[1].damage, 28, "독침 28 데미지 (원안)")
		t.check_eq(#spider.behaviorStages, 3, "거미의 단계별 행동은 셋")
		t.check_eq(spider.stats.maxHp, nil, "원안은 거미의 최대 HP를 비워 두었다")

		local wolf = Monsters.species.wolf.spec
		t.check_eq(wolf.source.table, 40, "늑대 인간은 원안 표 40")
		t.check_eq(wolf.stats.maxHp, 72, "늑대 인간 최대 HP 72 (원안)")
		t.check_eq(wolf.stats.maxMp, 40, "늑대 인간 최대 MP 40 (원안)")
		t.check_eq(wolf.stats.atk, 24, "늑대 인간 공격력 24 (원안)")
		t.check_eq(wolf.stats.def, 5, "늑대 인간 방어 5 (원안)")
		t.check_eq(wolf.stats.int, 41, "늑대 인간 지능 41 (원안)")
		t.check_eq(wolf.specials[1].mp, 23, "돌격은 MP 23을 쓴다 (원안)")
		t.check_eq(wolf.specials[1].damage, 27, "돌격 27 데미지 (원안)")
	end

	-- [E2] 무덤의 적 셋: 각자 다른 질문을 한다 (질문이 겹치면 적이 아니라 장식이다)
	do
		local soul = Monsters.species.soul
		t.check_eq(soul.flies, true, "순장된 영혼은 떠다닌다")
		t.check(soul.diveSpeed > soul.flySpeed, "내려찍기가 떠다니기보다 빠르다")
		t.check_eq(soul.spec.attackType, "air", "공중형")

		local sen = Monsters.species.sentinel
		t.check_eq(sen.guardFront, true, "무덤 번병은 앞을 막는다")
		t.check(sen.turnDelay > 0, "돌아서는 데 시간이 걸린다 (등이 열리는 시간)")
		t.check_eq(sen.spec.attackType, "shield", "방패형")

		local shard = Monsters.species.shard
		t.check_eq(shard.special, "fuse", "파괴의 조각은 심지가 탄다")
		t.check(shard.blastRadius > shard.attackRange, "폭발이 사거리보다 넓다")
		t.check_eq(shard.spec.attackType, "suicide", "자폭형 (원안 표 6)")
		t.check_eq(shard.spec.source.table, 6, "자폭형만은 원안에 출처가 있다")

		local types = {}
		for _, key in ipairs({ "soul", "sentinel", "shard" }) do
			local at = Monsters.species[key].spec.attackType
			t.check(not types[at], key .. "의 공격 방식이 다른 둘과 겹치지 않는다")
			types[at] = true
		end
	end

	-- [F] 원안에 규격서가 없는 종은 그 사실이 남아 있다
	do
		t.check_eq(Monsters.species.blackwolf.spec.source, nil,
			"검은 늑대는 원안에 규격서가 없다")
		t.check_eq(Monsters.species.monkey.spec.source, nil,
			"가면 원숭이는 원안에 규격서가 없다")
		t.check(#Monsters.species.blackwolf.spec.notes > 0, "그 사실이 note에 있다")
		t.check(#Monsters.species.monkey.spec.notes > 0, "그 사실이 note에 있다")
	end

	-- [G] 회귀: 스테이지를 거쳐도 게임이 읽던 값 그대로다 (A6는 수치를 바꾸지 않는다)
	do
		t.check(Stage.species == Monsters.species, "스테이지의 종별 표는 같은 표를 가리킨다")
		t.check_eq(Stage.species.spider.hp, 26, "거미 HP 26")
		t.check_eq(Stage.species.spider.atk, 9, "거미 공격 9")
		t.check_eq(Stage.species.spider.stingBonus, 8, "거미 독침 보너스 8 (구현값)")
		t.check_eq(Stage.species.wolf.hp, 48, "늑대 HP 48")
		t.check_eq(Stage.species.wolf.chargeAtk, 14, "늑대 돌격 14")
		t.check_eq(Stage.species.blackwolf.hp, 72, "검은 늑대 HP 72")
		t.check_eq(Stage.species.monkey.attackRange, 160, "짐도둑 사거리 160")
		t.check_eq(Stage.species.monkey.fleeRange, 64, "짐도둑 도주 거리 64")
	end

	-- [H] 배치가 부르는 종이 전부 표에 있다 (오타가 나면 스폰이 조용히 사라진다)
	do
		for i, s in ipairs(Stage.spawns) do
			t.check(Monsters.species[s.species] ~= nil,
				"배치 " .. i .. "의 종 '" .. tostring(s.species) .. "'이 표에 있다")
		end
	end
end

return M
