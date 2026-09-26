-- 알데바란, 스테이지 1-2 「황제의 무덤」 (docs/plans/aldebaran-7-tomb.md)
--
-- 원안 4.2.2절. 석회암 바위산을 스핑크스 모양으로 깎아 만든 무덤이며, 지면에
-- 닿은 가슴부로 들어간다 (표 17). 안에는 방 다섯과 복도 셋이 있고, 파괴의 신
-- 아포피스가 방마다 기후를 좌우한다 (표 19).
--
-- 지형은 tools/generate_aldebaran_tomb_map.py, 자산은 generate_aldebaran_tomb.py.
-- 이 파일은 스테이지의 칸, 기후 수치, 이야기 글이다. 시작 지점, 체크포인트, 몬스터,
-- 흔적, 구간, 빛기둥은 맵 파일의 objects에서 읽는다 (stages/placement.lua).
--
-- 신령의 방(아크나톤)은 이번 범위 밖이다. 방 다섯 중 넷과 입구를 쓴다.

local Monsters = require("scripts/lua/games/aldebaran/data/monsters")
local Placement = require("scripts/lua/games/aldebaran/stages/placement")

local M = {}

M.id = "tomb"
M.number = "1-2"
M.title = "황제의 무덤"
M.map = "./resources/maps/aldebaran_tomb.json"
M.bgmSlot = "./resources/audio/aldebaran_tomb.ogg"
M.bright = nil                          -- 환각은 검은 안개의 것이다. 여기엔 없다
M.fog = false                           -- 원안 표 19: 안개 없음
M.boss = { species = "apophis", kind = "guardian" }   -- 떨구는 것이 없다
M.intro = "text"                        -- 컷씬 없이 나레이션만

local placed = Placement.build(M.map)

M.species = Monsters.species

-- ---- 구간 다섯 (원안 표 19의 방 이름) ---------------------------------------
-- 맵의 section 띠다. 경계는 맵 생성기의 ROOMS와 타일 단위로 같아야 한다
-- (chest 타일 0~55, moon 56~119, stars 120~183, ruin 184~251, sun 252~319).

M.SECTIONS = placed.sections
M.SECTION_FADE = 96

--- 1-1과 같은 규칙. 구간 경계 앞뒤에서 두 벌을 겹친다.
function M.sectionAt(x)
	return Placement.sectionAt(M.SECTIONS, M.SECTION_FADE, x)
end

M.START = placed.start                   -- 가슴부 입구 (타일 3.5, 바닥 24)
-- 별들의 방 앞 목 (타일 124, 바닥 25), 파괴의 방 초입 (타일 188, 바닥 24)
M.CHECKPOINTS = placed.checkpoints
M.LIVES = 2
M.SEED = 20260824

-- ---- 기후 (원안 표 19: 아포피스가 방마다 기후를 좌우한다) --------------------
-- 규칙은 코드(game.lua), 수치는 여기. 방 이름으로 찾는다. 빛기둥의 x는 맵의 light
-- 오브젝트 중 그 방 안의 것이다. 나머지는 방 전체에 걸리는 수치라 여기에 둔다.

M.CLIMATE = {
	chest = nil,                          -- 입구에는 기후가 없다 (배우는 방)

	-- 달의 방: 눈. 지면 마찰이 준다 — 멈추려면 미리 놓아야 한다
	moon = { kind = "snow", friction = 0.34, flakes = 40 },

	-- 별들의 방: 빛기둥 셋이 켜지고 꺼진다. 빛 안의 영혼만 실체가 되어 베인다
	stars = { kind = "light", period = 4.0, lit = 2.2,
	          pillars = Placement.lightsIn(placed, "stars"), halfW = 44 },

	-- 파괴의 방: 우박. 떨어질 자리에 그림자가 먼저 뜬다 (선딜 30프레임)
	ruin = { kind = "hail", interval = 1.6, warn = 0.5, damage = 9,
	         speed = 320, halfW = 5, count = 2 },

	-- 태양의 방: 홍수. 수위가 오르내린다. 잠기면 느려지고 점프가 낮아진다
	sun = { kind = "flood", period = 9.0, low = 400, high = 336,
	        moveMult = 0.55, jumpMult = 0.72 },
}

-- ---- 배치 -------------------------------------------------------------------
-- 맵의 spawn 오브젝트다. 몬스터 id와 난수 소비가 이 순서를 따른다.
-- 조우 문법: 단독(가르친다), 조합(시험한다), 지형과 결합(비튼다).
-- 새 적은 반드시 안전한 자리에서 혼자 처음 나온다.
--   1구간 가슴부 입구: 무덤 번병 하나. 앞을 막는다는 것을 여기서 배운다
--     (뒤가 트인 넓은 자리라 돌아 들어가는 연습이 된다)
--   2구간 달의 방 (눈): 순장된 영혼이 처음 나온다. 미끄러운 바닥 위에서
--     2단 점프의 정점을 맞추는 것이 이 방의 과제다
--   3구간 별들의 방 (빛기둥): 영혼 셋이 발판 사이를 떠다닌다. 그늘에서는
--     베이지 않으므로 빛이 켜질 때를 기다려야 한다
--   4구간 파괴의 방 (우박): 파괴의 조각이 구덩이 앞 평지에서 혼자 처음 나온다.
--     그다음은 번병이 길을 막고 조각이 뒤에서 붙는 조합, 구덩이 위의 영혼
--   5구간 태양의 방 (홍수): 삼각 조합 하나와 아포피스

M.spawns = placed.spawns

-- ---- 흔적 (1-1과 같은 장치. 여기서는 무덤의 내력을 알려 준다) ----------------
-- 맵의 landmark 띠다. 원안의 서술을 그대로 옮긴 것이며, 지어낸 것은 문장의 호흡뿐이다.

M.LANDMARKS = placed.landmarks

M.EPILOGUE_FULL = "지도의 표시는 여기까지였다. 다음 표시는 카르토가 직접 그려야 한다."

-- ---- 이야기 글 --------------------------------------------------------------

M.INTRO = "스핑크스를 닮은 바위산이 지평을 가로막았다. 벽돌을 쌓은 것이 아니라 "
	.. "산을 깎아 만든 것이었다. 지면에 닿은 가슴께에 문이 있었고, 그 문은 "
	.. "열려 있었다. 닫힌 적이 없다는 듯이. 카르토는 지도를 접어 넣고 안으로 "
	.. "들어섰다."

M.EPILOGUE = {
	"수호자가 무너지자 방마다 다르던 하늘이 한꺼번에 멎었다.",
	"태양의 방 한가운데, 물이 빠진 자리에 석판 하나가 드러났다.",
	"협회의 문양과 같은 것이 새겨져 있었다. 이번에는 지도가 아니라 돌에.",
	"카르토는 그것을 옮겨 그렸다. 다음으로 가야 할 곳이 거기 있었다.",
}

M.GAMEOVER = "빛이 꺼졌다. ...멀리서 물이 차오르는 소리가 들린다."

M.SIGNS = {}

return M
