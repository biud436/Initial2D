-- 오두막 안의 이벤트 정의 (6단계, 8단계에서 확장)
--
-- 맵에 들어서면 auto 이벤트가 한 번 돌고(그동안 조작이 잠긴다), 아래 출입구를
-- 밟으면 마을로 돌아간다. 그림 고르기는 scripts/rpg/assets.lua 에 맡긴다.

local Assets = require("scripts/rpg/assets")

local CHARSET = Assets.npcCharset()
local FACESET = Assets.faceset()

local RESIDENT_FACE = { file = FACESET, index = 3 }
-- 플레이스홀더 FaceSet은 8..15가 웃는 얼굴이다
local RESIDENT_SMILE = { file = FACESET, index = 11 }

return {
	map = Assets.mapPath("room", "Interior"),
	start = { x = 10, y = 12, dir = "up" },

	-- 실내는 같은 곡을 조금 작게 (곡마다 음압이 달라 볼륨을 곡과 함께 준다)
	bgm = { file = "./resources/audio/bless.ogg", volume = 72 },

	-- 자동 시연: 주민에게 말을 걸어 보고 아래 문을 밟아 마을로 돌아간다
	-- (맵 전환과 페이드까지 한 바퀴 확인한다)
	autoRoute = { "left", "left", "up", "up", "up", "up", "talk", "talk",
		"down", "down", "down", "right", "right", "down" },

	events = {
		-- 맵 진입 시 한 번 자동 실행 (조작 잠금 확인용)
		{
			id = "enter_note",
			x = 10, y = 12,
			trigger = "auto",
			-- 두 번째 방문부터는 조용히 넘어간다 (thenDo가 없으면 아무것도 하지 않는다)
			commands = {
				{ code = "if", cond = { flag = "visitedHut" }, elseDo = {
					{ code = "setFlag", key = "visitedHut" },
					{ code = "message", text = "오두막 안이다. 아래 문으로 나갈 수 있다." },
				} },
			},
		},

		{
			id = "resident",
			x = 7, y = 8, dir = "down",
			charset = { file = CHARSET, index = 3 },
			trigger = "action",
			commands = {
				{ code = "if", cond = { flag = "gotHerb" },
				  thenDo = {
					{ code = "message", name = "주민", face = RESIDENT_FACE,
					  text = "상인 아저씨한테 약초를 받으셨군요. 인심이 좋은 분이에요." },
				  },
				  elseDo = {
					{ code = "message", name = "주민", face = RESIDENT_FACE,
					  text = "여긴 조용해서 좋아요." },
				  } },
				{ code = "moveRoute", target = "resident",
				  route = { "turn:left", "wait:300", "turn:down" } },
				{ code = "message", name = "주민", face = RESIDENT_SMILE,
				  text = "...가끔 심심하지만요." },
			},
		},

		-- 아래 출입구: 밟으면 마을로 돌아간다 (문 앞 칸에 세운다)
		{
			id = "exit_to_village",
			x = 10, y = 13,
			trigger = "touch",
			commands = { { code = "transfer", map = "village", x = 13, y = 15 } },
		},
	},
}
