-- 알데바란 — 스테이지 1-1 「검은 안개의 숲」의 데이터 (기획서 6절)
--
-- 몬스터의 종별 표와 배치. 좌표는 전부 손으로 정한 자리다 (픽셀,
-- tools/generate_aldebaran_maps.py의 지형과 짝이 맞아야 한다).
-- 코드가 아니라 표다 — 다른 스테이지는 다른 표를 만든다.

local M = {}

M.START = { x = 56, y = 384 }        -- 숲 입구 (타일 3.5, 지면 24)
M.CHECKPOINT_X = 1056                -- 이정표 (타일 66). 지나면 부활 지점이 된다
M.CHECKPOINT_Y = 320
M.LIVES = 2                          -- 원안 1절의 "2번의 목숨"
M.SEED = 20260823                    -- 전투 굴림의 시드 (테스트 재현용)

-- ---- 종별 표 (기획서 6절의 능력치, 시트는 generate_aldebaran_assets.py) ----

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
	},
}

-- ---- 배치 (지형: 입구 24, 턱 22/21/20, 다리, 어깨 20, 내리막 22, 숲 24) ----

M.spawns = {
	-- 전갈거미 넷
	{ species = "spider", x = 456, y = 352, minX = 396, maxX = 496 },     -- 턱 1
	{ species = "spider", x = 712, y = 320, minX = 652, maxX = 756 },     -- 왼쪽 어깨
	{ species = "spider", x = 1224, y = 352, minX = 1164, maxX = 1268 },  -- 내리막 턱
	{ species = "spider", x = 1736, y = 384, minX = 1680, maxX = 1790 },  -- 공터 앞

	-- 늑대 인간 셋 (늑대 숲의 지면, 낮은 바위 턱 사이사이)
	{ species = "wolf", x = 1330, y = 384, minX = 1296, maxX = 1360 },
	{ species = "wolf", x = 1496, y = 384, minX = 1464, maxX = 1528 },
	{ species = "wolf", x = 1650, y = 384, minX = 1620, maxX = 1670 },

	-- 짐도둑 (보스): 부서진 석상 앞. 배낭을 지고 있고, 쓰러지면 떨군다.
	-- 공터(minX~maxX)를 벗어나지 않는다 — 오른쪽 끝에 몰리면 던지기만 한다.
	{ species = "monkey", x = 1860, y = 384, minX = 1720, maxX = 2020, boss = true },
}

-- ---- 이야기 글 (기획서 4절) -------------------------------------------------

-- 도입 컷씬의 나레이션. 대화창이 쪽을 나눈다.
M.INTRO = "알데바란에 발을 디딘 순간이었다. 발 빠른 가면 원숭이들이 배낭과 금괴, "
	.. "지도까지 전부 채 갔다. 남은 것은 단검 한 자루와, 본능적으로 지켜 낸 몇 장의 "
	.. "단서뿐. 깜깜한 하늘, 우거진 숲, 마른 넝쿨과 부서진 대나무 — 잔상 같은 세계 "
	.. "속에서, 카르토는 달아난 원숭이의 발자국을 뒤따랐다."

-- 에필로그 (배낭을 되찾으면). 넷으로 나눠 한 쪽씩 보여 준다.
M.EPILOGUE = {
	"배낭은 반쯤 비어 있었다. 금괴는 사라졌지만, 지도는 무사했다.",
	"지도 위, 협회의 문양과 일치하던 그 지형에 누군가 새로 표시를 남겨 두었다.",
	"스핑크스를 닮은 왕릉 — 사람들이 황제의 무덤이라 부르는 곳이었다.",
	"카르토는 배낭을 고쳐 메고, 더 깊은 숲을 향해 걸음을 옮겼다.",
}

-- 게임 오버 (목숨을 다 잃으면)
M.GAMEOVER = "검은 안개가 시야를 덮었다. ...멀리서 늑대 울음이 들린다."

-- 표지 글: 그 x 구간에 처음 닿으면 화면 위에 잠깐 뜬다 (컷씬이 아니다)
M.SIGNS = {
	{ x0 = 726, x1 = 762, text = "낡은 다리다. 널이 몇 장 빠져 있다." },
	{ x0 = 1040, x1 = 1076, text = "이정표다. 원숭이 발자국이 오른쪽으로 이어진다." },
}

return M
