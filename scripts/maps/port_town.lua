-- 항구 마을의 이벤트 정의 (9단계, 기획서 docs/design/port-town.md)
--
-- 배를 기다리는 반나절. 여행자가 부두에 내려 마을을 둘러보고, 떠날지 하루 더
-- 머물지 스스로 정한다. 대사의 기준은 기획서 5절에 있다 — 세계를 넓히거나,
-- 선택에 필요한 정보를 주거나, 인물을 드러내거나. 셋 중 아니면 지운다.
--
-- 10단계에서 인물들이 **하나의 심부름 사슬**로 이어졌다 (docs/plans/11-game-systems.md).
--
--   생선 장수(창고 사연) → 여관 주인(창고 열쇠) → 창고(등유)
--     → 등대지기(불을 켠다, 은화 두 닢) → 여관(방을 잡는다) → 배(끝)
--
-- 사슬은 강제가 아니다. 어느 자리에서든 부두로 내려가 배를 타면 게임이 끝나며,
-- 심부름은 "더 볼 것"이다. 다음에 갈 곳은 언제나 그 자리의 대사가 말한다.
--
-- 본문은 전부 커맨드 목록(데이터)이라 맵 에디터가 만들고 읽을 수 있다.
-- 좌표는 tools/generate_port_maps.py 가 찍은 타일과 짝이 맞는다.

local Assets = require("scripts/rpg/assets")

local CHARSET = Assets.npcCharset()
local FACESET = Assets.faceset()

-- CharSet과 FaceSet은 같은 팔레트라 같은 번호면 같은 인물이다.
-- 웃는 얼굴은 번호 + 8 (플레이스홀더 규격).
local CAPTAIN = { file = FACESET, index = 6 }
local CAPTAIN_SMILE = { file = FACESET, index = 14 }
local FISHER = { file = FACESET, index = 4 }
local KID = { file = FACESET, index = 3 }
local KID_SMILE = { file = FACESET, index = 11 }
local KEEPER = { file = FACESET, index = 5 }

local SE_DOOR = "./resources/audio/door.wav"
local SE_ITEM = "./resources/audio/ui_decision.wav"

--- 배를 타고 떠나는 마무리.
--
-- 에필로그는 갈래가 아니라 **줄의 쌓임**이다. 본 것마다 한 줄씩 붙어, 전부 본
-- 플레이어는 네 줄을 읽는다. 분기를 늘리는 것보다 "내가 한 만큼 남았다"가
-- 또렷하고, 조건이 늘어도 조합이 터지지 않는다.
--
-- 두 선택지 가지에서 같은 흐름을 쓰므로 여기서 한 번만 적는다 (에디터로
-- 내보내면 두 자리에 똑같이 펼쳐진다).
local function departure()
	return {
		{ code = "message", name = "선장", face = CAPTAIN_SMILE,
		  text = "밧줄 푸네. 뭍에 두고 가는 게 없나 보시게." },
		{ code = "message", text = "배는 저녁 물때에 항구를 떠났다." },
		{ code = "if", cond = { flag = "lampReady" }, thenDo = {
			{ code = "message", text = "등 뒤에서 등대에 불이 켜졌다. "
				.. "노인이 오늘 밤 몫의 기름을 다 붓는 모양이었다." },
		} },
		{ code = "if", cond = { flag = "booked" }, thenDo = {
			{ code = "message", text = "여관의 방 하나가 하룻밤 비어 있었다." },
		} },
		{ code = "if", cond = { item = "shell" }, thenDo = {
			{ code = "message", text = "주머니 속에서 조개 목걸이가 달그락거렸다. "
				.. "숲의 노래를 들었다는 아이는, 아직 그 마을에 있다." },
		} },
		{ code = "scene", name = "title", fade = true },
	}
end

return {
	map = "./resources/maps/port_town.json",
	start = { x = 16, y = 43, dir = "up" },   -- 배에서 막 내린 자리

	-- ground와 deco는 캐릭터보다 아래, over(빨래줄)만 위에 그린다.
	-- 집 벽과 울타리는 "앞에 서는" 것이라 아래여야 한다 — 위에 두면 벽 앞에
	-- 섰을 때 캐릭터의 머리가 벽에 가려진다.
	groundLayers = 2,

	-- 마을의 곡. 저자의 자작곡이다 (docs/music/bless-analysis.md).
	bgm = { file = "./resources/audio/bless.ogg", volume = 96 },

	-- 자동 시연(INITIAL2D_AUTOPLAY)에서 따라 걷는 길. "talk"은 결정키.
	-- 부두에서 광장까지 올라가 생선 장수에게 말을 건다.
	autoRoute = {
		"talk", "up", "up", "up", "up", "up", "up", "up", "up",
		"left", "left", "talk", "talk", "talk",
		"up", "up", "up", "up", "up", "up",
	},

	events = {
		-- 도착: 장소 이름은 올 때마다, 선장의 첫 인사는 한 번만
		{
			id = "arrival",
			x = 16, y = 43,
			trigger = "auto",
			commands = {
				{ code = "showLocation", text = "항구 마을", seconds = 2.5 },
				{ code = "if", cond = { flag = "arrived" }, elseDo = {
					{ code = "setFlag", key = "arrived" },
					{ code = "message", name = "선장", face = CAPTAIN,
					  text = "짐은 다 내렸네. 저녁 물때에 배가 다시 뜨니, "
						.. "그때까지는 자네 시간이야." },
					{ code = "message", name = "선장", face = CAPTAIN,
					  text = "급할 것 없으면 마을을 좀 둘러보게. 여긴 떠나는 사람을 "
						.. "붙잡지 않는 대신, 남는 사람도 서운하게 하지 않거든." },
				} },
			},
		},

		-- 선장: 남쪽 항로 이야기. 등대지기의 이야기를 들었으면 그 사연을 받는다.
		{
			id = "captain",
			x = 16, y = 44, dir = "up",
			charset = { file = CHARSET, index = 6 },
			trigger = "action",
			commands = {
				{ code = "if", cond = { flag = "heardAltar" },
				  thenDo = {
					{ code = "message", name = "선장", face = CAPTAIN,
					  text = "노인이 하늘 끝 이야기를 하던가? ...그 양반은 젊을 때 "
						.. "그쪽 배를 탔었네. 돌아온 사람은 그 양반 하나였고." },
				  },
				  elseDo = {
					{ code = "message", name = "선장", face = CAPTAIN,
					  text = "남쪽 항로는 사막을 낀 길이라 물을 넉넉히 실어야 하네. "
						.. "신기루를 오래 보면 사람이 이상해진다고들 하지만, "
						.. "나야 뭐 스무 번은 지나다녔지." },
				  } },
			},
		},

		-- 저녁 배: 이 데모의 마무리
		{
			id = "ship",
			x = 18, y = 44,
			trigger = "action",
			commands = {
				{ code = "if", cond = { flag = "lampReady" },
				  thenDo = {
					{ code = "message",
					  text = "저녁 배가 밧줄을 풀 준비를 하고 있다. "
						.. "언덕의 등대에는 기름이 채워져 있다." },
					{ code = "choice",
					  options = { "지금 떠난다", "불이 켜지는 것을 보고 간다" },
					  cancel = 2, branches = {
						departure(),
						{ { code = "message", name = "선장", face = CAPTAIN,
						    text = "해가 아직 남았네. 천천히 보고 오시게." } },
					  } },
				  },
				  elseDo = {
					{ code = "message", text = "저녁 배가 밧줄을 풀 준비를 하고 있다." },
					{ code = "choice", options = { "지금 떠난다", "조금 더 둘러본다" },
					  cancel = 2, branches = {
						departure(),
						{ { code = "message", name = "선장", face = CAPTAIN,
						    text = "그러시게. 해가 지기 전에는 오시게." } },
					  } },
				  } },
			},
		},

		-- 부두의 살림
		{
			id = "bollard", x = 17, y = 42, trigger = "action",
			commands = { { code = "message", text = "굵은 밧줄이 말뚝에 단단히 매여 있다." } },
		},
		-- 짐 상자(crates, 14,40)는 이 파일이 아니라 **맵 파일**에 실려 있다
		-- (resources/maps/port_town.json의 events). 맵 에디터가 놓는 이벤트가
		-- 어떻게 도는지 보이는 자리이며, 둘은 id로 합쳐진다 (scripts/rpg/mapdata.lua).

		-- 광장
		{
			id = "notice", x = 13, y = 37, trigger = "action",
			commands = {
				{ code = "message", text = "마을 게시판이다.\n"
					.. "하나. 저녁 배는 물때에 맞춰 뜬다. 늦으면 기다리지 않는다." },
				{ code = "message", text = "둘. 북쪽 숲에는 들어가지 말 것. "
					.. "아이들은 특히." },
				{ code = "message", text = "셋. 창고 물건은 주인이 돌아올 때까지 "
					.. "손대지 말 것. 열쇠는 여관에 맡겨 두었다." },
			},
		},
		{
			id = "well", x = 18, y = 36, trigger = "action",
			commands = { { code = "message", text = "물이 차다. 두레박은 비어 있다." } },
		},
		{
			id = "bench", x = 19, y = 34, trigger = "action",
			commands = { { code = "message", text = "볕이 드는 자리다. 앉아 쉴 수 있을 것 같다." } },
		},

		-- 생선 장수: 창고의 사연과 등대 안내. 사슬의 첫 칸이다.
		{
			id = "fishmonger",
			x = 13, y = 35, dir = "left",
			charset = { file = CHARSET, index = 4 },
			trigger = "action",
			commands = {
				{ code = "message", name = "생선 장수", face = FISHER,
				  text = "오늘 물건은 아침에 다 나갔어요. 배가 들어오는 날은 늘 이렇죠." },
				{ code = "choice",
				  options = { "창고가 잠겨 있던데요", "마을에 볼 것이 있나요" },
				  branches = {
					{ { code = "setFlag", key = "heardWarehouse" },
					  { code = "message", name = "생선 장수", face = FISHER,
					    text = "저 창고요? 주인이 남쪽으로 떠난 지 삼 년째예요. "
						.. "계약은 아직 살아 있어서 아무도 손을 못 대고요. "
						.. "돌아오겠다고는 했다는데." },
					  { code = "message", name = "생선 장수", face = FISHER,
					    text = "열쇠는 여관 주인이 맡아 뒀어요. 안에 등유가 남아 있을 "
						.. "텐데, 등대 노인이 늘 아쉬워하시죠." } },
					{ { code = "message", name = "생선 장수", face = FISHER,
					    text = "언덕에 등대가 있어요. 등대지기 노인이 계신데, "
						.. "말은 별로 없어도 물어보면 대답은 해 주세요." } },
				  } },
			},
		},

		-- 여관: 문을 밟으면 안으로, 간판은 읽을 수 있다
		{
			id = "inn_door", x = 13, y = 29, trigger = "touch",
			commands = {
				{ code = "playSe", file = SE_DOOR, id = "door" },
				{ code = "transfer", map = "inn", x = 10, y = 12, dir = "up" },
			},
		},
		{
			id = "inn_sign", x = 14, y = 29, trigger = "action",
			commands = { { code = "message", text = "항구 여관. 오늘도 방이 남아 있다." } },
		},

		-- 창고: 사슬의 가운데. 열쇠가 있으면 열리고, 안에는 등유가 있다.
		{
			id = "warehouse", x = 19, y = 29, trigger = "action",
			commands = {
				{ code = "if", cond = { flag = "openedWarehouse" },
				  thenDo = {
					{ code = "message",
					  text = "다시 잠가 두었다. 안에 남은 것은 밧줄과 빈 궤짝뿐이었다." },
				  },
				  elseDo = {
					{ code = "if", cond = { item = "warehouse_key" },
					  thenDo = {
						{ code = "playSe", file = SE_DOOR, id = "door" },
						{ code = "message",
						  text = "열쇠가 맞는다. 삼 년 만에 열린 문 안에서 "
							.. "마른 밧줄 냄새가 났다." },
						{ code = "setFlag", key = "openedWarehouse" },
						{ code = "giveItem", item = "lamp_oil" },
						{ code = "playSe", file = SE_ITEM, id = "item" },
						{ code = "message", text = "선반에 등유 한 통이 남아 있다. "
							.. "등유 한 통을 얻었다." },
						{ code = "message",
						  text = "등대 노인에게 가져다 주면 오늘 밤은 불을 켜겠다." },
					  },
					  elseDo = {
						{ code = "if", cond = { flag = "heardWarehouse" },
						  thenDo = {
							{ code = "message",
							  text = "삼 년째 잠긴 문이다. 자물쇠에는 녹이 슬지 않았다. "
								.. "여관 주인이 열쇠를 맡아 두었다고 했다." },
						  },
						  elseDo = {
							{ code = "message",
							  text = "창고 문은 잠겨 있다. 사람 손을 탄 지 오래다." },
						  } },
					  } },
				  } },
			},
		},

		-- 주택가
		{
			id = "laundry", x = 12, y = 21, trigger = "action",
			commands = { { code = "message", text = "빨래가 바닷바람에 흔들린다. 소금기가 밴다." } },
		},
		{
			id = "kid",
			x = 14, y = 20, dir = "down",
			charset = { file = CHARSET, index = 3 },
			trigger = "action",
			wander = { minWait = 40, maxWait = 140, area = { x = 13, y = 19, w = 6, h = 6 } },
			commands = {
				{ code = "if", cond = { item = "shell" },
				  thenDo = {
					{ code = "message", name = "아이", face = KID_SMILE,
					  text = "그거 잃어버리면 안 돼요. 숲에서 주운 거니까." },
				  },
				  elseDo = {
					{ code = "if", cond = { flag = "heardAltar" },
					  thenDo = {
						{ code = "message", name = "아이", face = KID_SMILE,
						  text = "등대 할아버지도 노래 얘기를 했죠? 할아버지는 저를 안 놀려요." },
						{ code = "giveItem", item = "shell" },
						{ code = "playSe", file = SE_ITEM, id = "item" },
						{ code = "message", text = "조개 목걸이를 받았다." },
						{ code = "message", name = "아이", face = KID_SMILE,
						  text = "이거 드릴게요. 숲에서 주운 거예요. 배 타고 가다가 "
							.. "이거 보면, 여기 생각나실 거예요." },
					  },
					  elseDo = {
						{ code = "message", name = "아이", face = KID,
						  text = "북쪽 문은 어른들이 막아 놨어요. 숲에서 노래가 들린다고요." },
						{ code = "message", name = "아이", face = KID,
						  text = "근데 저는 들었어요. 생일 노래 같은 거였는데, 아무도 안 믿어요." },
						{ code = "message", name = "아이", face = KID,
						  text = "등대 할아버지한테 물어봐 주세요. 그 할아버지는 뭐든 아니까." },
					  } },
				  } },
			},
		},

		-- 언덕과 등대
		{
			id = "lighthouse_door", x = 17, y = 12, trigger = "action",
			commands = {
				{ code = "if", cond = { flag = "lampReady" },
				  thenDo = {
					{ code = "message", text = "등대 문이 조금 열려 있다. "
						.. "안에서 기름 붓는 소리가 난다." },
				  },
				  elseDo = {
					{ code = "message", text = "등대 문은 잠겨 있다. 열쇠는 등대지기가 갖고 있다." },
				  } },
			},
		},
		{
			id = "keeper",
			x = 18, y = 13, dir = "left",
			charset = { file = CHARSET, index = 5 },
			trigger = "action",
			commands = {
				-- 등유를 들고 왔으면 그 이야기가 먼저다. 노인이 먼저 알아본다.
				{ code = "if", cond = { item = "lamp_oil" },
				  thenDo = {
					{ code = "message", name = "등대지기", face = KEEPER,
					  text = "...그건 창고 것이군. 여관에서 열쇠를 받았나." },
					{ code = "takeItem", item = "lamp_oil" },
					{ code = "setFlag", key = "lampReady" },
					{ code = "message", name = "등대지기", face = KEEPER,
					  text = "고맙네. 오늘 밤은 아끼지 않고 켜겠네. "
						.. "자네 배가 항구를 나갈 때까지는 밝을 걸세." },
					{ code = "giveItem", item = "silver", count = 2 },
					{ code = "playSe", file = SE_ITEM, id = "item" },
					{ code = "message", text = "은화 두 닢을 받았다." },
					{ code = "message", name = "등대지기", face = KEEPER,
					  text = "받아 두게. 여관 하루치일세. 쓸 일이 없으면 그냥 가지고 가고." },
				  },
				  elseDo = {
					{ code = "message", name = "등대지기", face = KEEPER,
					  text = "...배를 기다리나." },
					{ code = "message", name = "등대지기", face = KEEPER,
					  text = "저 불은 사람을 부르는 게 아니라, 돌아오는 길을 잊지 말라고 "
						.. "켜 두는 걸세." },
					{ code = "choice",
					  options = { "하늘 끝에 가 보셨습니까", "등대를 지키신 지 오래되셨나요" },
					  branches = {
						{ { code = "setFlag", key = "heardAltar" },
						  { code = "message", name = "등대지기", face = KEEPER,
						    text = "제단이 있었네. 소리가 오래 남는 곳이었지. "
							.. "그 뒤로는 배를 타지 않았네." },
						  { code = "message", name = "등대지기", face = KEEPER,
						    text = "숲에서 노래를 들었다는 아이가 있다지. "
							.. "그 아이한테 거짓말쟁이라 하지 말게." } },
						{ { code = "message", name = "등대지기", face = KEEPER,
						    text = "불을 켜는 일에는 오래고 짧고가 없네. 오늘 켜면 오늘의 일이지." },
						  { code = "if", cond = { flag = "lampReady" }, elseDo = {
							{ code = "message", name = "등대지기", face = KEEPER,
							  text = "다만 기름이 얼마 없네. 창고에 한 통 남아 있을 텐데, "
								.. "그 문이 삼 년째 잠겨 있어서." },
						  } } },
					  } },
				  } },
			},
		},

		-- 북쪽 문: 숲은 이번 범위 밖이다. 그 경계를 대사로 표시한다.
		{
			id = "north_gate", x = 16, y = 6, trigger = "action",
			commands = {
				{ code = "if", cond = { flag = "heardAltar" },
				  thenDo = {
					{ code = "message",
					  text = "숲으로 가는 길은 막혀 있다. 바람이 나뭇가지를 훑고 지나간다. "
						.. "노래처럼 들리기도 한다." },
				  },
				  elseDo = {
					{ code = "message", text = "숲으로 가는 길은 널빤지로 막혀 있다." },
				  } },
			},
		},
	},
}
