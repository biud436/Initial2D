-- 항구 여관 1층의 이벤트 정의 (9단계, 기획서 docs/design/port-town.md)
--
-- 마을에서 유일하게 들어갈 수 있는 건물이다. 방을 잡으면 그 사실이 ctx.state에
-- 남아 마지막 선택과 에필로그가 달라진다.
--
-- 10단계에서 여관 주인이 심부름 사슬의 두 번째 칸이 되었다. 창고 이야기를 듣고
-- 오면 열쇠를 내주고, 방값 은화 두 닢은 실제로 세어 받는다 — 가진 것이 모자라면
-- 방을 잡을 수 없다 (docs/plans/11-game-systems.md).
--
-- 실내의 곡은 저자의 《Port》 1번 트랙 "Inn"이다 (docs/music/inn-analysis.md).
-- 원본은 개인 소장이라 저장소에 없으므로, 파일이 있으면 그 곡을 걸고 없으면
-- 마을 곡을 조금 낮춰 쓴다 — 그림을 고르는 규칙(assets.lua)과 같은 방식이다.

local Assets = require("scripts/rpg/assets")

local CHARSET = Assets.npcCharset()
local FACESET = Assets.faceset()

local HOST = { file = FACESET, index = 1 }
local HOST_SMILE = { file = FACESET, index = 9 }

local SE_ITEM = "./resources/audio/ui_decision.wav"

local INN_BGM = Assets.pick({
	"./resources/audio/inn.ogg",
	"./resources/audio/bless.ogg",
})

--- 창고 열쇠를 내주는 대목. 생선 장수에게 사연을 들은 뒤 한 번만 돈다.
-- `if`의 조건은 하나뿐이라 "들었는가"와 "아직 안 줬는가"를 겹쳐 적는다.
local function handKey()
	return { code = "if", cond = { flag = "heardWarehouse" }, thenDo = {
		{ code = "if", cond = { flag = "gaveKey" }, elseDo = {
			{ code = "setFlag", key = "gaveKey" },
			{ code = "message", name = "여관 주인", face = HOST,
			  text = "창고 얘기를 들으셨군요. 그 열쇠라면 여기 있어요. "
				.. "주인이 떠나면서 맡기고 갔거든요." },
			{ code = "giveItem", item = "warehouse_key" },
			{ code = "playSe", file = SE_ITEM, id = "item" },
			{ code = "message", text = "창고 열쇠를 받았다." },
			{ code = "message", name = "여관 주인", face = HOST,
			  text = "등유가 남아 있을 거예요. 등대 노인께 가져다 드리세요. "
				.. "주인도 그걸 아까워할 사람은 아니었어요." },
		} },
	} }
end

return {
	map = "./resources/maps/inn.json",
	start = { x = 10, y = 12, dir = "up" },

	-- 실내는 머리 위로 지나갈 것이 없다. 벽과 탁자는 전부 캐릭터보다 아래다.
	groundLayers = 2,

	bgm = { file = INN_BGM, volume = 80 },   -- 실내는 낮게

	events = {
		{
			id = "arrival",
			x = 10, y = 12,
			trigger = "auto",
			commands = { { code = "showLocation", text = "항구 여관", seconds = 2.5 } },
		},

		-- 여관 주인: 열쇠를 내주고, 방값을 세어 받는다.
		{
			id = "innkeeper",
			x = 10, y = 3, dir = "down",
			charset = { file = CHARSET, index = 1 },
			trigger = "action",
			commands = {
				{ code = "if", cond = { flag = "booked" },
				  thenDo = {
					{ code = "message", name = "여관 주인", face = HOST_SMILE,
					  text = "방은 그대로 두었어요. 저녁 배를 타시더라도 짐은 챙겨 가세요." },
					handKey(),
				  },
				  elseDo = {
					{ code = "if", cond = { flag = "greeted" },
					  elseDo = {
						{ code = "setFlag", key = "greeted" },
						{ code = "message", name = "여관 주인", face = HOST,
						  text = "어서 오세요. 저녁 배를 기다리는 분이시군요. "
							.. "얼굴에 그렇게 쓰여 있어요." },
					  } },
					handKey(),
					{ code = "message", name = "여관 주인", face = HOST,
					  text = "방을 잡으실 건가요? 하루치는 은화 두 닢이에요." },
					{ code = "choice", options = { "묵는다", "배를 탄다", "그냥 둘러본다" },
					  cancel = 3, branches = {
						{ { code = "if", cond = { item = "silver", op = ">=", value = 2 },
						    thenDo = {
							{ code = "takeItem", item = "silver", count = 2 },
							{ code = "setFlag", key = "booked" },
							{ code = "message", name = "여관 주인", face = HOST_SMILE,
							  text = "그럼 짐을 올려 두세요. 저녁 배는 놓치셔도 "
								.. "아침 배가 또 옵니다." },
						    },
						    elseDo = {
							{ code = "message", name = "여관 주인", face = HOST,
							  text = "...두 닢이 모자라시네요. 괜찮아요, 이 마을에서 "
								.. "돈 없다고 쫓겨난 사람은 없어요." },
							{ code = "message", name = "여관 주인", face = HOST,
							  text = "일거리라면 언덕에 하나 있을 거예요. "
								.. "노인이 늘 손이 모자라시거든요." },
						    } } },
						{ { code = "message", name = "여관 주인", face = HOST,
						    text = "그러실 것 같았어요. 다들 처음엔 그렇게 말하죠." } },
						{ { code = "message", name = "여관 주인", face = HOST_SMILE,
						    text = "천천히 보세요. 난로 옆이 제일 따뜻합니다." } },
					  } },
				  } },
			},
		},

		-- 방명록: 갈 수 없는 곳들이 여기에 적혀 있다
		{
			id = "guestbook", x = 14, y = 3, trigger = "action",
			commands = {
				{ code = "message", text = "여관 방명록이다. 여러 사람의 필체가 섞여 있다." },
				{ code = "message", text = "\"숲에는 들어가지 말 것. 길이 하나뿐인 줄 알았는데 "
					.. "나올 때는 세 갈래였다.\"" },
				{ code = "message", text = "\"사막 항로, 물 두 통으로는 모자람.\"\n"
					.. "마지막 장에는 이름 대신 날짜만 적혀 있다." },
			},
		},

		{
			id = "hearth", x = 2, y = 3, trigger = "action",
			commands = { { code = "message", text = "난로가 낮게 타고 있다. 바닷바람이 가시는 자리다." } },
		},

		-- 2층은 이번 범위 밖이다
		{
			id = "stairs", x = 17, y = 4, trigger = "action",
			commands = {
				{ code = "if", cond = { flag = "booked" },
				  thenDo = {
					{ code = "message", text = "잡아 둔 방은 위층이다. 아직 올라가 볼 일은 없다." },
				  },
				  elseDo = {
					{ code = "message", text = "위층으로 오르는 계단이다. 아직 방을 잡지 않았다." },
				  } },
			},
		},

		-- 아래 출입구: 밟으면 마을로 (여관 문 앞)
		{
			id = "exit", x = 10, y = 13, trigger = "touch",
			commands = {
				{ code = "playSe", file = "./resources/audio/door.wav", id = "door" },
				{ code = "transfer", map = "port_town", x = 13, y = 30, dir = "down" },
			},
		},
	},
}
