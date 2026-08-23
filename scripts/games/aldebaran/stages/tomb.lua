-- 알데바란 — 스테이지 1-2 「황제의 무덤」 (docs/plans/aldebaran-7-tomb.md)
--
-- 원안 4.2.2절. 석회암 바위산을 스핑크스 모양으로 깎아 만든 무덤이며, 지면에
-- 닿은 가슴부로 들어간다 (표 17). 안에는 방 다섯과 복도 셋이 있고, 파괴의 신
-- 아포피스가 방마다 기후를 좌우한다 (표 19).
--
-- 지형은 tools/generate_aldebaran_tomb_map.py, 자산은 generate_aldebaran_tomb.py.
-- 이 파일은 배치와 이야기 글이다.
--
-- 신령의 방(아크나톤)은 이번 범위 밖이다. 방 다섯 중 넷과 입구를 쓴다.

local Monsters = require("scripts/games/aldebaran/data/monsters")

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

M.species = Monsters.species

-- ---- 구간 다섯 (원안 표 19의 방 이름) ---------------------------------------
-- 경계는 맵 생성기의 ROOMS와 타일 단위로 같아야 한다.

M.SECTIONS = {
	{ name = "chest", x1 = 895 },        -- 타일 0~55    가슴부 입구와 첫 복도
	{ name = "moon", x1 = 1919 },        -- 56~119       달의 방
	{ name = "stars", x1 = 2943 },       -- 120~183      별들의 방
	{ name = "ruin", x1 = 4031 },        -- 184~251      파괴의 방
	{ name = "sun", x1 = 5119 },         -- 252~319      태양의 방
}
M.SECTION_FADE = 96

--- 1-1과 같은 규칙. 구간 경계 앞뒤에서 두 벌을 겹친다.
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
	return "sun", "sun", 0
end

M.START = { x = 56, y = 384 }            -- 가슴부 입구 (타일 3.5, 바닥 24)
M.CHECKPOINTS = {
	{ x = 1984, y = 400 },               -- 별들의 방 앞 목 (타일 124, 바닥 25)
	{ x = 3008, y = 384 },               -- 파괴의 방 초입 (타일 188, 바닥 24)
}
M.LIVES = 2
M.SEED = 20260824

-- ---- 기후 (원안 표 19: 아포피스가 방마다 기후를 좌우한다) --------------------
-- 규칙은 코드(game.lua), 수치는 여기. 방 이름으로 찾는다.

M.CLIMATE = {
	chest = nil,                          -- 입구에는 기후가 없다 (배우는 방)

	-- 달의 방: 눈. 지면 마찰이 준다 — 멈추려면 미리 놓아야 한다
	moon = { kind = "snow", friction = 0.34, flakes = 40 },

	-- 별들의 방: 빛기둥 셋이 켜지고 꺼진다. 빛 안의 영혼만 실체가 되어 베인다
	stars = { kind = "light", period = 4.0, lit = 2.2,
	          pillars = { 2180, 2420, 2660 }, halfW = 44 },

	-- 파괴의 방: 우박. 떨어질 자리에 그림자가 먼저 뜬다 (선딜 30프레임)
	ruin = { kind = "hail", interval = 1.6, warn = 0.5, damage = 9,
	         speed = 320, halfW = 5, count = 2 },

	-- 태양의 방: 홍수. 수위가 오르내린다. 잠기면 느려지고 점프가 낮아진다
	sun = { kind = "flood", period = 9.0, low = 400, high = 336,
	        moveMult = 0.55, jumpMult = 0.72 },
}

-- ---- 배치 -------------------------------------------------------------------
-- 조우 문법: 단독(가르친다) → 조합(시험한다) → 지형과 결합(비튼다).
-- 새 적은 반드시 안전한 자리에서 혼자 처음 나온다.

M.spawns = {
	-- 1구간 가슴부 입구: 무덤 번병 하나. 앞을 막는다는 것을 여기서 배운다
	-- (뒤가 트인 넓은 자리라 돌아 들어가는 연습이 된다)
	{ species = "sentinel", x = 640, y = 384, minX = 600, maxX = 700 },

	-- 2구간 달의 방 (눈): 순장된 영혼이 처음 나온다. 미끄러운 바닥 위에서
	-- 2단 점프의 정점을 맞추는 것이 이 방의 과제다
	{ species = "soul", x = 1040, y = 336, minX = 990, maxX = 1120 },
	{ species = "soul", x = 1300, y = 300, minX = 1250, maxX = 1380 },
	{ species = "sentinel", x = 1500, y = 400, minX = 1450, maxX = 1560 },
	{ species = "soul", x = 1700, y = 288, minX = 1640, maxX = 1780 },

	-- 3구간 별들의 방 (빛기둥): 영혼 셋이 발판 사이를 떠다닌다.
	-- 그늘에서는 베이지 않으므로 빛이 켜질 때를 기다려야 한다
	{ species = "soul", x = 2200, y = 300, minX = 2140, maxX = 2280 },
	{ species = "soul", x = 2440, y = 268, minX = 2380, maxX = 2520 },
	{ species = "soul", x = 2680, y = 300, minX = 2620, maxX = 2760 },
	{ species = "sentinel", x = 2860, y = 384, minX = 2800, maxX = 2920 },

	-- 4구간 파괴의 방 (우박): 파괴의 조각이 처음 나온다. 구덩이 앞 평지에서
	-- 혼자 (터지는 것을 안전하게 배운다)
	{ species = "shard", x = 3120, y = 384, minX = 3060, maxX = 3180 },
	-- 그다음은 조합이다: 번병이 길을 막고 조각이 뒤에서 붙는다
	{ species = "sentinel", x = 3440, y = 368, minX = 3400, maxX = 3500 },
	{ species = "shard", x = 3560, y = 368, minX = 3500, maxX = 3640 },
	-- 구덩이 위의 영혼 (떨어질 자리를 재면서 싸운다)
	{ species = "soul", x = 3700, y = 300, minX = 3650, maxX = 3800 },
	{ species = "shard", x = 3900, y = 384, minX = 3840, maxX = 3980 },

	-- 5구간 태양의 방 (홍수): 삼각 조합 하나와 아포피스
	{ species = "sentinel", x = 4180, y = 400, minX = 4130, maxX = 4240 },
	{ species = "soul", x = 4320, y = 300, minX = 4260, maxX = 4400 },
	{ species = "shard", x = 4420, y = 400, minX = 4360, maxX = 4480 },
	{ species = "apophis", x = 4720, y = 400, minX = 4300, maxX = 5040, boss = true },
}

-- ---- 흔적 (1-1과 같은 장치. 여기서는 무덤의 내력을 알려 준다) ----------------
-- 원안의 서술을 그대로 옮긴 것이며, 지어낸 것은 문장의 호흡뿐이다.

M.LANDMARKS = {
	{ id = "chest", x0 = 300, x1 = 348, title = "열려 있는 가슴",
	  text = "사자의 가슴이 문이다. 닫힌 적이 없다. 언제든 나올 수 있게 지었다." },
	{ id = "moon", x0 = 1440, x1 = 1488, title = "달의 방",
	  text = "달의 기운으로 태양의 방을 고른다고 했다. 눈이 내리는 이유다." },
	{ id = "stars", x0 = 2360, x1 = 2408, title = "별들의 노래",
	  text = "별들은 황제의 탄생을 칭송하며 노래를 부르고 빛의 축제를 여느니라." },
	{ id = "ruin", x0 = 3260, x1 = 3308, title = "파괴의 방",
	  text = "여기 수호자가 있다. 기후를 쥔 자다. 방마다 다른 하늘은 그의 것이다." },
	{ id = "sarc", x0 = 4020, x1 = 4068, title = "닫히지 않은 석관",
	  text = "신하와 자식들을 함께 묻었다. 그들이 아직 이 방을 지킨다." },
}

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
