-- 알데바란 — 몬스터 규격서 (docs/plans/aldebaran-6-source-mining.md 3절 6항)
--
-- 원안 스피카의 몬스터 규격서(표 39 밀림 전갈 거미, 표 40 늑대 인간)를 그릇으로
-- 삼은 표다. 채굴본은 docs/design/spica-source/tables.md에 있다.
--
-- 종 하나는 두 층으로 되어 있다.
--
--   평평한 칸  엔진이 그대로 읽는 값이다 (game.lua, monster.lua). A1에서 A5까지
--              정해 온 수치이며, 여기 손을 대면 게임이 바뀐다.
--   spec       원안 규격서의 칸이다. 코드는 아직 대부분 보지 않는다. 값이 원안에
--              없으면 nil로 둔다 — "비어 있다"와 "0이다"는 다르다.
--
-- 이 두 층을 나눈 이유는 원안이 채워 놓은 칸과 우리가 정한 칸을 섞지 않기
-- 위해서다. P5에서 적을 열 종으로 늘릴 때, 새 종은 spec부터 채우고 평평한 칸을
-- 그 spec에서 유도한다.
--
-- spec.source는 그 값이 어느 표 몇 절에서 왔는지다. 원안에 없어서 지어낸 것은
-- source가 없고 note에 그 사실을 적는다.

local M = {}

-- ---- 원안 2.3.1절 표 6: 적의 4가지 공격 방식 --------------------------------
-- 종마다 하나를 고른다. 체력/공격력/방어력의 상대적인 높낮이가 여기서 나온다.
-- suicide(자폭 형)는 아직 어느 종도 쓰지 않는다 — P5의 몫이다.

M.ATTACK_TYPES = {
	melee   = { name = "근접 형", hp = "많음", atk = "낮음", def = "보통",
	            pattern = "둔기 또는 신체 부위로 적에게 근접하여 공격을 한다." },
	charge  = { name = "돌격 형", hp = "보통", atk = "보통", def = "높음",
	            pattern = "높은 방어력을 가지고 있으며 몸통 박치기로 공격 한다." },
	throw   = { name = "투척 형", hp = "적음", atk = "높음", def = "낮음",
	            pattern = "장거리에서 원거리 공격을 한다." },
	suicide = { name = "자폭 형", hp = "적음", atk = "높음", def = "보통",
	            pattern = "매우 강한 공격력으로 자폭을 한다." },
}

-- 원안에 없는 공격 방식. **사료와 섞지 않으려고 표를 나눠 둔다.**
-- 1-2에서 적이 묻는 질문을 늘리려고 우리가 만든 것이다
-- (docs/plans/aldebaran-7-tomb.md 5절).
M.EXTRA_ATTACK_TYPES = {
	air    = { name = "공중 형", hp = "적음", atk = "보통", def = "낮음",
	           pattern = "떠다니다가 내려찍는다. 지면에서는 닿지 않는다.",
	           question = "2단 점프의 정점을 써라" },
	shield = { name = "방패 형", hp = "많음", atk = "보통", def = "높음",
	           pattern = "앞을 막는다. 등은 비어 있고 돌아서는 데 시간이 걸린다.",
	           question = "뒤로 돌아가라" },
}

--- 공격 방식 하나 (원안의 것이든 우리 것이든)
function M.attackType(key)
	return M.ATTACK_TYPES[key] or M.EXTRA_ATTACK_TYPES[key]
end

-- ---- 원안 6.2.2절 표 37: 몬스터의 이동 속도 5단계 ----------------------------
-- 원안의 값은 초당 픽셀이 아니라 배율이다. 우리 walkSpeed(픽셀/초)와 짝지어 둔다.

M.SPEED_TIERS = {
	{ key = "veryslow", name = "아주 느림", scale = 0.3 },
	{ key = "slow",     name = "느림",     scale = 0.5 },
	{ key = "normal",   name = "보통",     scale = 0.8 },
	{ key = "fast",     name = "빠름",     scale = 1.0 },
	{ key = "veryfast", name = "아주 빠름", scale = 3.0 },
}

-- ---- 종별 표 ----------------------------------------------------------------

M.species = {
	-- 밀림 전갈거미: 근접형. 움츠렸다가 턱을 내빼는 선딜레이가 공격 신호다.
	spider = {
		name = "밀림 전갈거미",
		hp = 26, atk = 9, def = 2, exp = 5, gold = 10,
		walkSpeed = 25, chaseSpeed = 55,
		alertRange = 96, attackRange = 20,
		windup = 0.35, active = 0.15, recover = 0.5,
		halfW = 12, bodyH = 14,
		special = "sting",           -- 명중의 20%로 데미지 +8 (씬이 굴린다)
		stingChance = 0.2, stingBonus = 8,
		sheet = "./resources/aldebaran/spider.png",
		cols = 4, rows = 2, frameW = 48, frameH = 32,
		anchorX = 22, anchorY = 30,
		frames = { walk = { 0, 1 }, attack = 2, hurt = 3 },

		spec = {
			source = { table = 39, section = "6.3" },
			index = 1,
			name = "밀림 전갈거미",
			gender = nil,                    -- 원안 "없음"
			element = "dark",                -- 암 속성
			attackType = "melee",
			traits = "썩은 시체의 살점이나 죽어가는 동물의 체액을 빨아먹으며 생명을 "
				.. "연장한다. 거미도 전갈도 아닌 절지동물이며, 스피카 숲의 기운을 견디려고 "
				.. "사람 크기로 거대해졌다. 거미줄을 만드는 기능은 일부 퇴화했다.",
			habitat = "시체가 썩고 습기가 많은 지역. 부서진 스피카 사원의 유적지 일대에 "
				.. "다수가 서식한다.",
			preference = "살아 있는 생명체를 거의 죽을 때까지 공격한다. 그 뒤 독이나 마비로 "
				.. "살점이 썩는 속도를 높인다.",
			strength = "다리가 많아 이동이 빠르고 민첩하다. 군락 생활을 하며 동료가 피해를 "
				.. "입으면 즉시 전투에 동참한다.",
			weakness = {
				text = "두터운 세포로 둘러싸여 있으나 빛에 민감해 오래 노출되면 세포질이 "
					.. "약해져 부서진다. 신성 계열 마법에 상당히 약하고, 은으로 도금된 "
					.. "무기에 치명타를 입는다.",
				light = true, holy = true, silver = true,   -- P4의 상성이 여기서 나온다
			},
			weapon = "발달된 턱과 강한 산성의 독침.",
			combatStyle = "민첩하게 접근해 큰 턱으로 타격하고, 일정 확률로 마비와 독침을 "
				.. "쓴다. 마법 공격은 2순위다. 도주하는 적에게 동료와 합세해 달라붙는다.",
			attackPatterns = {
				normal = "몸을 움츠렸다가 턱을 앞으로 내빼며 가격한다.",
				skill = "강한 산성의 독 공격. 플레이어가 10% 확률로 마비에 걸린다.",
				ultimate = "앞다리로 상체를 고정한 뒤 턱으로 가위 자르듯 공격한다.",
				defense = nil,               -- 원안 "없음"
				other = nil,                 -- 원안 "없음"
			},
			appearance = { length = nil, weight = nil, body = nil, face = nil,
			               hair = nil, outfit = nil },   -- 원안이 비워 둔 칸
			behaviorStages = {
				"단계 1 : 평타",
				"단계 2 : 마비, 평타",
				"단계 3 : 독침, 평타",
			},
			chaseBounds = nil,               -- 원안 "-"
			reward = { exp = 5, gold = 10, item = "ITEM 001 끈적거리는 거미줄" },
			stats = {
				moveSpeed = "slow", movePattern = "왕복 이동",
				maxHp = nil, maxMp = nil, atk = nil, def = nil,
				hit = nil, int = nil, agi = nil,
				regenHp = nil, regenMp = nil,
			},
			specials = {
				{ name = "독침", effect = "HP 감소", chance = 0.2, mp = nil,
				  damage = 28, text = "28의 데미지." },
			},
			notes = {
				"원안은 능력치 칸(최대 HP, 힘, 방어, 명중, 지능, 민첩력, 자가 치유량)을 "
					.. "전부 '-'로 비워 두었다. 평평한 칸의 수치는 A2에서 정한 것이다.",
				"독침은 원안이 20% 확률에 28 데미지다. 구현은 20%에 +8이다 (A2). "
					.. "차이는 의도적이며 P2의 계측 뒤에 다시 본다.",
				"마비(일반 스킬 10%)는 아직 구현이 없다. P5의 상태 이상에서 쓴다.",
			},
		},
	},

	-- 늑대 인간: 돌격형. 발견하면 한 번 돌진하고, 그 뒤로는 근접전.
	wolf = {
		name = "늑대 인간",
		hp = 48, atk = 16, def = 4, exp = 8, gold = 10,
		walkSpeed = 30, chaseSpeed = 70,
		alertRange = 128, attackRange = 24,
		windup = 0.3, active = 0.15, recover = 0.55,
		halfW = 9, bodyH = 30,
		special = "charge",          -- 돌격: 데미지 14와 큰 넉백, 1회
		chargeSpeed = 150, chargeTime = 0.9, chargeAtk = 14,
		regen = true,                -- 비전투 시 4초마다 최대 HP의 1/20 회복
		sheet = "./resources/aldebaran/wolf.png",
		cols = 5, rows = 2, frameW = 48, frameH = 48,
		anchorX = 22, anchorY = 46,
		frames = { walk = { 0, 1 }, charge = 2, attack = 3, hurt = 4 },

		spec = {
			source = { table = 40, section = "6.4" },
			index = 2,
			name = "늑대 인간",
			gender = "수컷, 남성",
			element = "dark",                -- 암(暗)
			attackType = "charge",
			traits = "레굴루스 마법 생명학자의 연구실에서 인간 노예를 실험한 프로젝트 "
				.. "'늑대 인간의 모체'가 탈출하며 개체수가 늘었다. 야수 또는 인간으로 "
				.. "변신할 수 있고 살상과 마법 능력이 출중하다.",
			habitat = "습도가 낮은 자연 동굴이나 큰 바위 동굴 밑에 가족 단위로 서식한다.",
			preference = "비문명 늑대인간은 야행성이며 깊은 산림 근처에 모여 사냥한다. "
				.. "문명을 이룩한 늑대인간들과는 습성이 달라 대립 중이다.",
			strength = "인간보다 발달된 근육으로 빠르게 접근하고, 민첩한 몸놀림과 공격 "
				.. "속도로 짧은 시간에 많은 데미지를 준다. 힘과 민첩력과 지능이 높다.",
			weakness = {
				text = "불완전한 실험 생명체라 면역력이 떨어지고 오래 살지 못한다. 독이나 "
					.. "저주 마법에 대한 방어 면역이 생물학적으로 뒤떨어진다. 폴리모프한 "
					.. "상태에서는 모든 능력치가 절반 이하로 떨어진다.",
				poison = true, curse = true,
			},
			weapon = "강철 둔기 같은 근육과 뾰족한 손톱, 발톱.",
			combatStyle = nil,               -- 원안이 서술 지시만 남기고 비워 둔 칸
			attackPatterns = {
				normal = "단단한 팔과 손톱을 검처럼 머리 위로 높이 뻗어 내리찍는다. "
					.. "공격 속도가 매우 빠르다.",
				skill = "충돌 범위 안에 플레이어가 있으면 돌격을 시전한다. 첫 발동이 "
					.. "성공한 뒤로는 다시 발동되지 않는다.",
				ultimate = nil, defense = nil, other = nil,
			},
			appearance = { length = nil, weight = nil, body = nil, face = nil,
			               hair = nil, outfit = nil },
			behaviorStages = {
				"단계 1 : [돌격]은 범위 내에 적군이 들어왔을 경우 발동된다.",
				"단계 2 : [평타]를 가하고 이후에도 단계 2를 반복한다.",
			},
			chaseBounds = nil,               -- 원안: "나중에 적는 것이 옳다"
			reward = { exp = 8, gold = 10, item = "ITEM 002 검은 밀랍 인형" },
			stats = {
				moveSpeed = "slow", movePattern = nil,
				maxHp = 72, maxMp = 40, atk = 24, def = 5,
				hit = nil, int = 41, agi = "민첩력이 높을수록 공격 속도가 빨라진다.",
				regenHp = "전투 중이 아닌 경우 4초마다 최대 HP/20을 회복.",
				regenMp = "전투 중이나 일반 상태에서 4초마다 지능/8을 회복.",
			},
			specials = {
				{ name = "돌격", effect = "스턴", chance = 0.4, mp = 23,
				  damage = 27,
				  text = "보통 속도로 접근하여 27의 데미지를 입히고 스턴을 가한다." },
			},
			notes = {
				"원안의 능력치(HP 72, 공격 24, 방어 5)는 구현에서 검은 늑대가 물려받았다. "
					.. "늑대 인간은 그보다 약한 48/16/4다 — A2가 난이도 곡선을 위해 "
					.. "한 칸 내린 것이다.",
				"돌격은 원안이 40% 확률에 MP 23을 소비하고 27 데미지에 스턴이다. 구현은 "
					.. "확률도 MP도 스턴도 없이 1회 고정에 14 데미지다.",
				"몬스터의 MP와 MP 회복은 구현에 아예 없다. P4의 자원 루프에서 다시 본다.",
			},
		},
	},

	-- 검은 늑대: 마을의 우두머리. 늑대의 1.5배이고 돌격을 다시 쓴다.
	blackwolf = {
		name = "검은 늑대",
		hp = 72, atk = 24, def = 6, exp = 16, gold = 25,
		walkSpeed = 34, chaseSpeed = 82,
		alertRange = 150, attackRange = 26,
		windup = 0.26, active = 0.16, recover = 0.45,
		halfW = 10, bodyH = 32,
		special = "charge",
		chargeSpeed = 170, chargeTime = 0.9, chargeAtk = 20,
		chargeRepeat = true,             -- 한 번 쓰고 끝내지 않는다
		regen = true,
		sheet = "./resources/aldebaran/blackwolf.png",
		cols = 5, rows = 2, frameW = 48, frameH = 48,
		anchorX = 22, anchorY = 46,
		frames = { walk = { 0, 1 }, charge = 2, attack = 3, hurt = 4 },

		spec = {
			source = nil,                    -- 원안에 규격서가 없다. A2에서 만든 종이다
			index = 3,
			name = "검은 늑대",
			element = "dark",
			attackType = "charge",
			traits = "늑대 인간 마을의 우두머리. 원안 4.2.1.1절의 '지능 차이에 따라 "
				.. "지배자와 피지배자로 나뉜다'는 서술을 종으로 옮긴 것이다.",
			habitat = "검은 안개의 숲 4구간, 늑대 마을 안쪽.",
			weakness = { poison = true, curse = true },
			attackPatterns = {
				normal = "늑대 인간과 같은 내리찍기. 더 빠르다.",
				skill = "돌격을 한 번으로 끝내지 않고 되풀이한다.",
			},
			reward = { exp = 16, gold = 25, item = nil },
			stats = { moveSpeed = "normal", maxHp = 72, atk = 24, def = 6 },
			notes = {
				"원안에 규격서가 없는 종이다. 능력치는 원안 표 40(늑대 인간)의 값을 "
					.. "그대로 가져다 썼다.",
				"보상 아이템이 없다. 원안의 'ITEM 002 검은 밀랍 인형'을 상위 등급으로 "
					.. "쓸지는 P8의 아이템 작업에서 정한다.",
			},
		},
	},

	-- 가면 원숭이 짐도둑: 투척형 (보스, 3단계에서 배치된다)
	monkey = {
		name = "가면 원숭이",
		hp = 60, atk = 8, def = 1, exp = 12, gold = 30,
		walkSpeed = 60, chaseSpeed = 110,
		alertRange = 200, attackRange = 160,
		windup = 0.4, active = 0.2, recover = 0.6,
		halfW = 8, bodyH = 28,
		special = "throw",
		fleeRange = 64,              -- 이보다 가까우면 반대로 달아난다
		sheet = "./resources/aldebaran/monkey.png",
		cols = 4, rows = 2, frameW = 48, frameH = 48,
		anchorX = 24, anchorY = 46,
		frames = { walk = { 0, 1 }, attack = 2, hurt = 3 },

		spec = {
			source = nil,                    -- 규격서는 없고 배경 서술만 있다 (4.2.3절)
			index = 4,
			name = "가면 원숭이",
			element = nil,
			attackType = "throw",
			traits = "스피카 문양 가면을 쓴 원숭이. 발이 빠르고 무리를 짓는다. "
				.. "원안 3.2.1절에서 카르토의 배낭과 금괴와 지도를 빼앗는 무리다.",
			habitat = "원숭이 소굴(원안 4.2.3절). 바위산에 벌집처럼 판 동굴 40동 규모이며, "
				.. "1동에 4~5마리가 산다. 동장 열을 우두머리 넷이 거느리고, 그 위에 대장이 "
				.. "있다. 전부 무장하고 있다.",
			attackPatterns = {
				normal = "돌팔매. 거리를 벌리며 던진다.",
				skill = "가까이 붙으면 반대 방향으로 달아난다 (코너로 몰아야 한다).",
			},
			reward = { exp = 12, gold = 30, item = nil },
			stats = { moveSpeed = "veryfast", maxHp = 60, atk = 8, def = 1 },
			notes = {
				"원안에 몬스터 규격서가 없다. 배경(4.2.3절)과 발단 시나리오(3.2.1절)에서 "
					.. "만든 종이다.",
				"P7의 원숭이 소굴은 이 서술의 계급 구조(동장, 우두머리, 대장)를 적 종별로 "
					.. "쓸 수 있다.",
			},
		},
	},
}

-- ---- 1-2 황제의 무덤의 적 셋 (docs/plans/aldebaran-7-tomb.md 5절) ----------
--
-- 셋 다 원안의 서술에 뿌리가 있지만 수치는 우리가 정했다. 텔레그래프 부등식
-- (선딜 >= 회피 성립 17프레임 + 인지 15프레임 = 32프레임 = 0.53초)을 지킨다.
-- 그 검사는 tests/lua/cases/aldebaran_monster_test.lua가 데이터에서 돌린다.

M.species.soul = {
	name = "순장된 영혼",
	hp = 30, atk = 12, def = 1, exp = 7, gold = 8,
	walkSpeed = 24, chaseSpeed = 52,
	alertRange = 128, attackRange = 40, alertRangeY = 96,
	windup = 0.55, active = 0.28, recover = 0.7,  -- 선딜 33프레임
	halfW = 10, bodyH = 22,
	-- 내려찍기는 0.28초에 380px/s = 106px. 떠 있는 높이(약 64px)보다 깊게 내려온다.
	flies = true, flySpeed = 55, diveSpeed = 380, riseSpeed = 190,
	sheet = "./resources/aldebaran/soul.png",
	cols = 4, rows = 2, frameW = 32, frameH = 32,
	anchorX = 15, anchorY = 26,
	frames = { walk = { 0, 1 }, attack = 2, hurt = 3 },

	spec = {
		source = nil,                    -- 규격서는 없다. 표 16과 20의 서술에서 만들었다
		index = 5,
		name = "순장된 영혼",
		element = "dark",
		attackType = "air",
		traits = "왕이 사후에도 함께하길 원해 강제로 순장된 신하와 자식들의 영혼. "
			.. "수호자들이 침입자를 막으려 불러낸다 (원안 표 16, 표 20).",
		habitat = "황제의 무덤. 방을 떠날 수 없다.",
		weakness = { light = true },      -- 별들의 방의 빛기둥 안에서 실체가 된다
		attackPatterns = {
			normal = "떠 있다가 몸을 위로 당겼다 발치까지 내려찍는다.",
		},
		reward = { exp = 7, gold = 8, item = nil },
		stats = { moveSpeed = "slow", maxHp = 30, atk = 12, def = 1 },
		notes = {
			"원안에 몬스터 규격서가 없다. 순장(표 16)과 '희생된 영혼들을 소환'(표 20)에서 "
				.. "만든 종이다.",
			"공중형은 원안 표 6의 넷에 없다. 우리가 더한 공격 방식이다 "
				.. "(M.EXTRA_ATTACK_TYPES).",
		},
	},
}

M.species.sentinel = {
	name = "무덤 번병",
	hp = 60, atk = 18, def = 8, exp = 11, gold = 14,
	walkSpeed = 22, chaseSpeed = 40,
	alertRange = 112, attackRange = 26,
	windup = 0.6, active = 0.18, recover = 0.6,    -- 선딜 36프레임
	halfW = 11, bodyH = 30,
	guardFront = true, turnDelay = 0.55,
	sheet = "./resources/aldebaran/sentinel.png",
	cols = 5, rows = 2, frameW = 48, frameH = 48,
	anchorX = 23, anchorY = 46,
	frames = { walk = { 0, 1 }, attack = 2, hurt = 3, block = 4 },

	spec = {
		source = nil,
		index = 6,
		name = "무덤 번병",
		element = "dark",
		attackType = "shield",
		traits = "수호자들이 '직접 나서지 않고 부하를 통솔'한다는 서술(원안 표 20)의 "
			.. "그 부하다. 석회암 방패를 들고 통로를 막는다.",
		habitat = "황제의 무덤의 복도와 방 입구.",
		weakness = { text = "방패는 앞만 가린다. 등은 비어 있다." },
		attackPatterns = {
			normal = "방패로 밀고 창을 내지른다.",
			defense = "바라보는 쪽에서 오는 것은 막는다. 막은 뒤 잠깐 굳는다.",
		},
		reward = { exp = 11, gold = 14, item = nil },
		stats = { moveSpeed = "veryslow", maxHp = 60, atk = 18, def = 8 },
		notes = {
			"원안에 규격서가 없다. 표 20의 '부하를 통솔하고 지휘하에 침입자를 처치'에서 "
				.. "만든 종이다.",
			"방패형은 원안 표 6의 넷에 없다. 원안 표 39의 '방어 기술' 칸이 '없음'이라 "
				.. "막는 적이 아예 없었다.",
		},
	},
}

M.species.shard = {
	name = "파괴의 조각",
	hp = 14, atk = 26, def = 3, exp = 6, gold = 12,
	walkSpeed = 30, chaseSpeed = 95,
	alertRange = 150, attackRange = 20,
	windup = 0.75, active = 0.15, recover = 0.3,
	halfW = 8, bodyH = 16,
	special = "fuse",
	fuseRange = 26, fuseTime = 0.75, blastTime = 0.15, blastRadius = 30,
	sheet = "./resources/aldebaran/shard.png",
	cols = 4, rows = 2, frameW = 32, frameH = 32,
	anchorX = 15, anchorY = 30,
	frames = { walk = { 0, 1 }, attack = 2, hurt = 3, fuse = 2, boom = 2 },

	spec = {
		source = { table = 6, section = "2.3.1" },   -- 자폭형은 원안의 것이다
		index = 7,
		name = "파괴의 조각",
		element = "dark",
		attackType = "suicide",
		traits = "파괴의 방에서 떨어져 나온 돌조각에 아포피스의 힘이 붙은 것. "
			.. "원안 표 6의 자폭형은 넷 중 하나인데 지금까지 쓰이지 않았다.",
		habitat = "파괴의 방과 그 복도.",
		weakness = { text = "체력이 낮다. 심지가 타는 동안 베면 터지지 않고 스러진다." },
		attackPatterns = {
			normal = "붙으면 멈춰 서서 심지가 탄다. 그리고 터진다.",
		},
		reward = { exp = 6, gold = 12, item = nil },
		stats = { moveSpeed = "fast", maxHp = 14, atk = 26, def = 3 },
		notes = {
			"공격 방식은 원안 표 6의 자폭형이다. 이름과 수치는 우리가 정했다.",
			"멈춰 서는 것이 예고다 (45프레임). 그 사이에 물러나거나 베어 없앤다.",
		},
	},
}

-- ---- 스키마 검사 ------------------------------------------------------------
-- 그릇이 그릇 노릇을 하려면 모양이 지켜져야 한다. P5에서 종이 열로 늘어날 때
-- 칸 하나를 빠뜨리는 것을 여기서 잡는다.

-- 엔진이 반드시 읽는 칸. 하나라도 없으면 game.lua가 nil 산술로 죽는다.
M.REQUIRED = {
	"name", "hp", "atk", "def", "exp", "gold",
	"walkSpeed", "chaseSpeed", "alertRange", "attackRange",
	"windup", "active", "recover", "halfW", "bodyH",
	"sheet", "cols", "rows", "frameW", "frameH", "anchorX", "anchorY",
}

-- 원안 규격서(표 39, 40)의 칸 이름. spec에 이 밖의 이름이 있으면 오타로 본다.
M.SPEC_FIELDS = {
	source = true, index = true, name = true, gender = true, element = true,
	attackType = true, traits = true, habitat = true, preference = true,
	strength = true, weakness = true, weapon = true, combatStyle = true,
	attackPatterns = true, appearance = true, behaviorStages = true,
	chaseBounds = true, reward = true, stats = true, specials = true,
	notes = true,
}

M.STATS_FIELDS = {
	moveSpeed = true, movePattern = true, maxHp = true, maxMp = true,
	atk = true, def = true, hit = true, int = true, agi = true,
	regenHp = true, regenMp = true,
}

--- 종 하나를 검사한다. 문제가 없으면 nil, 있으면 사람이 읽는 이유를 돌려준다.
function M.validateSpecies(key, def)
	if type(def) ~= "table" then
		return key .. ": 종의 정의가 표가 아니다"
	end
	for _, field in ipairs(M.REQUIRED) do
		if def[field] == nil then
			return key .. ": 엔진이 읽는 칸 '" .. field .. "'이 없다"
		end
	end
	if type(def.frames) ~= "table" or type(def.frames.walk) ~= "table" then
		return key .. ": frames.walk 이 없다"
	end
	local spec = def.spec
	if type(spec) ~= "table" then
		return key .. ": spec 이 없다 (원안 규격서의 그릇)"
	end
	for field in pairs(spec) do
		if not M.SPEC_FIELDS[field] then
			return key .. ": spec 에 모르는 칸 '" .. field .. "'이 있다"
		end
	end
	if spec.attackType and not M.attackType(spec.attackType) then
		return key .. ": 모르는 공격 방식 '" .. tostring(spec.attackType) .. "'"
	end
	if type(spec.stats) == "table" then
		for field in pairs(spec.stats) do
			if not M.STATS_FIELDS[field] then
				return key .. ": spec.stats 에 모르는 칸 '" .. field .. "'이 있다"
			end
		end
		local tier = spec.stats.moveSpeed
		if tier ~= nil then
			local found = false
			for _, t in ipairs(M.SPEED_TIERS) do
				if t.key == tier then found = true end
			end
			if not found then
				return key .. ": 모르는 이동 속도 단계 '" .. tostring(tier) .. "'"
			end
		end
	end
	return nil
end

--- 표 전체를 검사한다. 문제가 없으면 빈 목록.
function M.validate()
	local problems = {}
	for key, def in pairs(M.species) do
		local why = M.validateSpecies(key, def)
		if why then problems[#problems + 1] = why end
	end
	table.sort(problems)
	return problems
end

return M
