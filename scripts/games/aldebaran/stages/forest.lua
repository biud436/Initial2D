-- 알데바란 — 스테이지 1-1 「검은 안개의 숲」 (기획서 4.3절)
--
-- 배치와 구간과 이야기 글. 좌표는 전부 손으로 정한 자리다 (픽셀,
-- tools/generate_aldebaran_maps.py의 지형과 짝이 맞아야 한다).
-- 코드가 아니라 표다 — 다른 스테이지는 다른 표를 만든다 (stages/tomb.lua).
--
-- 종별 표는 data/monsters.lua에 있다.

local Monsters = require("scripts/games/aldebaran/data/monsters")

local M = {}

-- ---- 스테이지가 씬에게 알려 주는 것 -----------------------------------------
-- game.lua는 이 칸들만 보고 무대를 차린다. 새 스테이지는 같은 칸을 채우면 된다.

M.id = "forest"
M.number = "1-1"
M.title = "검은 안개의 숲"
M.map = "./resources/maps/aldebaran_forest.json"
M.bgmSlot = "./resources/audio/aldebaran_forest.ogg"
M.bright = "./resources/aldebaran/forest_bright.png"   -- 환각 때 겹치는 옛 숲
M.fog = true                                            -- 안개 입자를 뿌린다
M.boss = { species = "monkey", kind = "thief", drops = "bag" }  -- 짐도둑
M.intro = "thief"                                       -- 도입 컷씬의 종류

-- ---- 구간 (기획서 4.3절) ---------------------------------------------------
-- 걸을수록 무대가 바뀐다. 씬은 카메라 x로 지금 구간을 알아내고, 경계 앞뒤
-- FADE 픽셀에서 두 벌을 겹쳐 서서히 바꾼다.

M.SECTIONS = {
	{ name = "entrance", x1 = 767 },     -- 타일 0~47
	{ name = "road", x1 = 1599 },        -- 48~99
	{ name = "gorge", x1 = 2367 },       -- 100~147
	{ name = "den", x1 = 3263 },         -- 148~203
	{ name = "altar", x1 = 4096 },       -- 204~255
}
M.SECTION_FADE = 96                      -- 경계 앞뒤로 겹치는 폭 (픽셀)

--- 카메라 x가 속한 구간과, 다음 구간으로 얼마나 넘어갔는가 (0..1)
function M.sectionAt(x)
	for i, s in ipairs(M.SECTIONS) do
		if x <= s.x1 then
			local blend = 0
			if i < #M.SECTIONS then
				local d = s.x1 - x
				if d < M.SECTION_FADE then
					blend = (M.SECTION_FADE - d) / (M.SECTION_FADE * 2)
				end
			end
			if i > 1 then
				local prev = M.SECTIONS[i - 1]
				local d = x - prev.x1
				if d < M.SECTION_FADE then
					return prev.name, M.SECTIONS[i].name, 0.5 + d / (M.SECTION_FADE * 2)
				end
			end
			local nextName = (i < #M.SECTIONS) and M.SECTIONS[i + 1].name or s.name
			return s.name, nextName, blend
		end
	end
	return "altar", "altar", 0
end

M.START = { x = 56, y = 384 }        -- 숲 입구 (타일 3.5, 지면 24)
-- 체크포인트 둘 (2구간 끝의 석주, 4구간 초입의 우리). 지나면 부활 지점이 된다.
M.CHECKPOINTS = {
	{ x = 1552, y = 304 },
	{ x = 2400, y = 352 },
}
M.LIVES = 2                          -- 원안 1절의 "2번의 목숨"
M.SEED = 20260823                    -- 전투 굴림의 시드 (테스트 재현용)

-- ---- 종별 표 --------------------------------------------------------------
-- 원안 규격서를 그릇으로 삼은 표는 data/monsters.lua로 옮겼다 (A6). 여기서는
-- 이름만 다시 내보낸다 — 배치(M.spawns)가 이 키를 쓰기 때문이다.

M.species = Monsters.species

-- ---- 배치 (지형: 입구 24, 턱 22/21/20, 다리, 어깨 20, 내리막 22, 숲 24) ----

-- 배치는 지면 높이를 계산해 정했다 (계획 3.5절의 레벨 디자인 원칙).
-- 적은 구간 경계에서 100px 이상 안쪽에 두어, 넘어오는 순간 맞지 않게 한다.
M.spawns = {
	-- 1구간 숲 입구 (지면 384 / 턱 352): 베기를 가르치고, 점프한 뒤 싸우게 한다
	{ species = "spider", x = 224, y = 384, minX = 180, maxX = 280 },
	{ species = "spider", x = 672, y = 352, minX = 630, maxX = 730 },

	-- 2구간 옛 길 (계단 352 → 336 → 320 → 304): 턱마다 하나, 마지막에 둘
	{ species = "spider", x = 900, y = 352, minX = 860, maxX = 960 },
	{ species = "spider", x = 1056, y = 336, minX = 1010, maxX = 1120 },
	{ species = "spider", x = 1400, y = 304, minX = 1370, maxX = 1450 },
	{ species = "spider", x = 1470, y = 304, minX = 1440, maxX = 1520 },

	-- 3구간 기암 절벽: 어깨 한가운데 (착지하자마자 맞지 않게)
	{ species = "spider", x = 1700, y = 304, minX = 1660, maxX = 1760 },
	{ species = "wolf", x = 1990, y = 304, minX = 1950, maxX = 2030 },
	{ species = "spider", x = 2290, y = 320, minX = 2260, maxX = 2340 },

	-- 4구간 늑대 마을: 둘씩 두 번, 그리고 안쪽에 검은 늑대
	{ species = "wolf", x = 2760, y = 368, minX = 2700, maxX = 2820 },
	{ species = "wolf", x = 2830, y = 368, minX = 2770, maxX = 2890 },
	{ species = "wolf", x = 3060, y = 368, minX = 3010, maxX = 3120 },
	{ species = "wolf", x = 3120, y = 368, minX = 3060, maxX = 3180 },
	{ species = "blackwolf", x = 3220, y = 368, minX = 3160, maxX = 3250 },

	-- 5구간 제단 앞: 전초 하나와 짐도둑
	{ species = "wolf", x = 3450, y = 384, minX = 3400, maxX = 3520 },
	{ species = "monkey", x = 3860, y = 384, minX = 3640, maxX = 4040, boss = true },
}

-- ---- 흔적 (기획서 4.3.1절) --------------------------------------------------
-- 구간마다 하나. 밟으면 글이 뜨고 발견 기록에 남는다. 강제가 아니다.

M.LANDMARKS = {
	-- 첫 거미를 잡은 뒤, 턱 앞의 평지 (읽는 동안 맞지 않는 자리)
	{ id = "tracks", x0 = 300, x1 = 348, title = "여러 갈래의 발자국",
	  text = "발자국이 여럿이다. 그놈은 혼자가 아니었다.", skill = "edge" },
	-- 포석이 시작되는 자리 (2구간 초입)
	{ id = "road", x0 = 790, x1 = 838, title = "다져진 포석",
	  text = "밟혀 다져진 돌길이다. 숲이 나중에 덮은 것이다.", skill = "read" },
	-- 다리를 건너기 전 어깨 (체크포인트 바로 뒤)
	{ id = "cart", x0 = 1640, x1 = 1688, title = "버려진 짐수레",
	  text = "짐이 그대로 실려 있다. 사람들은 급히 떠났다.", skill = "leap" },
	-- 마을 초입의 우리. 여기서 안개에 취해 옛 숲이 보인다
	{ id = "cage", x0 = 2440, x1 = 2488, title = "부서진 우리",
	  text = "실험실의 우리다. 안개는 저들이 열매를 태워 만든다.",
	  hallucination = 3.0, skill = "berserk" },
	-- 제단 앞. 보스와 붙기 전에 읽는다
	{ id = "altar", x0 = 3700, x1 = 3748, title = "네 개의 화두",
	  text = "고대 문자와 굳은 피. 지도에 그려진 것이 이곳이었다.", skill = "bolt" },
}

-- 다섯을 다 모은 플레이어만 읽는 마지막 한 줄
M.EPILOGUE_FULL = "도둑이 노린 것은 금괴가 아니었다. 이 숲의 지형을 그린 그 지도였다."

-- ---- 이야기 글 (기획서 4절) -------------------------------------------------

-- 도입 컷씬의 나레이션. 대화창이 쪽을 나눈다.
M.INTRO = "알데바란에 발을 디딘 순간이었다. 발 빠른 가면 원숭이들이 배낭과 금괴, "
	.. "지도까지 전부 채 갔다. 남은 것은 단검 한 자루와, 본능적으로 지켜 낸 몇 장의 "
	.. "단서뿐. 깜깜한 하늘, 우거진 숲, 마른 넝쿨과 부서진 대나무. 잔상 같은 세계 "
	.. "속에서, 카르토는 달아난 원숭이의 발자국을 뒤따랐다."

-- 에필로그 (배낭을 되찾으면). 넷으로 나눠 한 쪽씩 보여 준다.
M.EPILOGUE = {
	"배낭은 반쯤 비어 있었다. 금괴는 사라졌지만, 지도는 무사했다.",
	"지도 위, 협회의 문양과 일치하던 그 지형에 누군가 새로 표시를 남겨 두었다.",
	"스핑크스를 닮은 왕릉, 사람들이 황제의 무덤이라 부르는 곳이었다.",
	"카르토는 배낭을 고쳐 메고, 더 깊은 숲을 향해 걸음을 옮겼다.",
}

-- 게임 오버 (목숨을 다 잃으면)
M.GAMEOVER = "검은 안개가 시야를 덮었다. ...멀리서 늑대 울음이 들린다."

-- 표지 글: 그 x 구간에 처음 닿으면 화면 위에 잠깐 뜬다 (컷씬이 아니다)
M.SIGNS = {}     -- 표지 글은 흔적(M.LANDMARKS)으로 바뀌었다

return M
