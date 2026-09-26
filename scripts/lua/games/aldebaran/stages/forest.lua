-- 알데바란, 스테이지 1-1 「검은 안개의 숲」 (기획서 4.3절)
--
-- 스테이지의 칸과 이야기 글. 시작 지점, 체크포인트, 몬스터, 흔적, 구간은 맵 파일의
-- objects에서 읽는다 (stages/placement.lua, 스키마는 resources/schema/map-objects.json).
-- 좌표는 픽셀이며 tools/generate_aldebaran_maps.py의 지형과 맞아야 한다.
--
-- 종별 표는 data/monsters.lua에 있다.

local Monsters = require("scripts/lua/games/aldebaran/data/monsters")
local Placement = require("scripts/lua/games/aldebaran/stages/placement")

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

local placed = Placement.build(M.map)

-- ---- 구간 (기획서 4.3절) ---------------------------------------------------
-- 걸을수록 무대가 바뀐다. 씬은 카메라 x로 지금 구간을 알아내고, 경계 앞뒤
-- FADE 픽셀에서 두 벌을 겹쳐 서서히 바꾼다. 구간은 맵의 section 띠다
-- (entrance 타일 0~47, road 48~99, gorge 100~147, den 148~203, altar 204~255).

M.SECTIONS = placed.sections
M.SECTION_FADE = 96                      -- 경계 앞뒤로 겹치는 폭 (픽셀)

--- 카메라 x가 속한 구간과, 다음 구간으로 얼마나 넘어갔는가 (0..1)
function M.sectionAt(x)
	return Placement.sectionAt(M.SECTIONS, M.SECTION_FADE, x)
end

M.START = placed.start               -- 숲 입구 (타일 3.5, 지면 24)
-- 체크포인트 둘 (2구간 끝의 석주, 4구간 초입의 우리). 지나면 부활 지점이 된다.
M.CHECKPOINTS = placed.checkpoints
M.LIVES = 2                          -- 원안 1절의 "2번의 목숨"
M.SEED = 20260823                    -- 전투 굴림의 시드 (테스트 재현용)

-- ---- 종별 표 --------------------------------------------------------------
-- 원안 규격서를 그릇으로 삼은 표는 data/monsters.lua에 있다. 배치(M.spawns)가
-- 이 표의 키를 쓴다.

M.species = Monsters.species

-- ---- 배치 (지형: 입구 24, 턱 22/21/20, 다리, 어깨 20, 내리막 22, 숲 24) ----
-- 맵의 spawn 오브젝트다. 몬스터 id와 난수 소비가 이 순서를 따른다.
-- 배치는 지면 높이를 계산해 정했다 (계획 3.5절의 레벨 디자인 원칙).
-- 적은 구간 경계에서 100px 이상 안쪽에 두어, 넘어오는 순간 맞지 않게 한다.
--   1구간 숲 입구 (지면 384 / 턱 352): 베기를 가르치고, 점프한 뒤 싸우게 한다
--   2구간 옛 길 (계단 352, 336, 320, 304): 턱마다 하나, 마지막에 둘
--   3구간 기암 절벽: 어깨 한가운데 (착지하자마자 맞지 않게)
--   4구간 늑대 마을: 둘씩 두 번, 그리고 안쪽에 검은 늑대
--   5구간 제단 앞: 전초 하나와 짐도둑

M.spawns = placed.spawns

-- ---- 흔적 (기획서 4.3.1절) --------------------------------------------------
-- 구간마다 하나. 밟으면 글이 뜨고 발견 기록에 남는다. 강제가 아니다.
-- 맵의 landmark 띠다.
--   tracks  첫 거미를 잡은 뒤, 턱 앞의 평지 (읽는 동안 맞지 않는 자리)
--   road    포석이 시작되는 자리 (2구간 초입)
--   cart    다리를 건너기 전 어깨 (체크포인트 바로 뒤)
--   cage    마을 초입의 우리. 여기서 안개에 취해 옛 숲이 보인다 (hallucination)
--   altar   제단 앞. 보스와 붙기 전에 읽는다

M.LANDMARKS = placed.landmarks

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
