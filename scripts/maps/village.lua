-- 마을 맵의 이벤트 정의 (6단계 docs/plans/06-rpg-events.md, 8단계에서 확장)
--
-- 맵 파일(JSON)에는 타일만 들어 있고, 무엇이 어디서 무슨 일을 하는지는 이 파일에
-- 있다. 데이터와 로직의 경계를 여기서 긋는다 (2단계 결정).
--
-- 이벤트 본문은 커맨드 목록(commands)이다 (9단계). 순수 데이터라 맵 에디터가
-- 만들고 읽을 수 있고, 실행은 scripts/rpg/commands.lua가 6단계 실행기가 아는
-- 함수 하나로 바꿔 준다. 커맨드로 적기 어려운 이벤트는 script 함수로 적는다.
--
-- 그림은 RTP가 로컬에 있으면 그쪽을, 없으면 저장소에 커밋된 플레이스홀더를
-- 쓴다 (scripts/rpg/assets.lua). 두 판은 지오메트리가 같아 좌표는 그대로다.

local Assets = require("scripts/rpg/assets")

local CHARSET = Assets.npcCharset()
local FACESET = Assets.faceset()

-- 얼굴은 커맨드 안에 그대로 실리는 데이터다 (FaceSet 한 장의 몇 번 칸인가)
local ELDER_FACE = { file = FACESET, index = 2 }
local KID_FACE = { file = FACESET, index = 13 }
local MERCHANT_FACE = { file = FACESET, index = 4 }

return {
	map = Assets.mapPath("village", "Exterior"),
	start = { x = 34, y = 21, dir = "down" },

	-- 마을의 BGM. 저자의 자작곡이다 (docs/music/bless-analysis.md).
	bgm = { file = "./resources/audio/bless.ogg", volume = 96 },

	-- 자동 시연(INITIAL2D_AUTOPLAY)에서 따라 걷는 경로. "talk"은 결정키.
	autoRoute = {
		"left", "left", "up", "talk", "talk", "talk", "left", "left",
		"left", "left", "left", "left", "left", "left", "left", "left",
		"left", "left", "left", "left", "left", "left", "left", "left",
		"left", "up", "up", "up", "up", "up", "up", "up",
	},

	events = {
		-- 말을 걸면 대화하고, 선택지에 따라 다른 대사를 한다
		{
			id = "elder",
			x = 32, y = 20, dir = "down",
			charset = { file = CHARSET, index = 2 },
			trigger = "action",
			commands = {
				{ code = "message", name = "촌장", face = ELDER_FACE,
				  text = "어서 오시게. 처음 보는 얼굴이군. 이 마을은 조용하지만 "
					.. "지낼 만한 곳이라네. 오래 머물 생각인가?" },
				-- cancel은 취소키(X)가 빠져나갈 항목 번호다
				{ code = "choice", options = { "네, 처음입니다", "아니요, 와 본 적 있습니다" },
				  cancel = 2, branches = {
					{ { code = "message", name = "촌장", face = ELDER_FACE,
					    text = "왼쪽 집 문으로 들어가면 우리 오두막이라네." },
					  { code = "setFlag", key = "toldAboutHut" } },
					{ { code = "message", name = "촌장", face = ELDER_FACE,
					    text = "그럼 길은 잘 알겠군." } },
				  } },
			},
		},

		-- 배회하다가도 말을 걸면 멈추고 대답한다 (배회는 5단계 기능 재사용)
		{
			id = "kid",
			x = 36, y = 22, dir = "left",
			charset = { file = CHARSET, index = 5 },
			trigger = "action",
			wander = { minWait = 30, maxWait = 120, area = { x = 30, y = 18, w = 12, h = 8 } },
			commands = {
				{ code = "if", cond = { flag = "gotHerb" },
				  thenDo = {
					{ code = "message", name = "아이", face = KID_FACE,
					  text = "그 약초, 아저씨가 아무한테나 안 주는 건데!" },
				  },
				  elseDo = {
					{ code = "if", cond = { flag = "toldAboutHut" },
					  thenDo = {
						{ code = "message", name = "아이", face = KID_FACE,
						  text = "촌장님한테 들었죠? 저 빨간 지붕 집이에요." },
					  },
					  elseDo = {
						{ code = "message", name = "아이", face = KID_FACE,
						  text = "여기저기 돌아다니는 게 제 일이에요." },
					  } },
				  } },
			},
		},

		-- 길목에 선 채로 장사하는 상인. 선택지로 물건을 건네고, 그 사실이
		-- ctx.state에 남아 다른 맵의 대사까지 바꾼다 (맵을 넘는 상태 공유).
		{
			id = "merchant",
			x = 37, y = 20, dir = "left",
			charset = { file = CHARSET, index = 4 },
			trigger = "action",
			commands = {
				{ code = "if", cond = { flag = "gotHerb" },
				  thenDo = {
					{ code = "message", name = "상인", face = MERCHANT_FACE,
					  text = "약초는 잘 챙겨 두시게. 급할 때 요긴하다네." },
				  },
				  elseDo = {
					{ code = "message", name = "상인", face = MERCHANT_FACE,
					  text = "길이 험하지 않은 마을이지만, 그래도 빈손보다야 낫겠지. "
						.. "약초 한 뿌리 어떤가? 값은 됐네." },
					{ code = "choice", options = { "고맙게 받겠습니다", "괜찮습니다" },
					  cancel = 2, branches = {
						{ { code = "setFlag", key = "gotHerb" },
						  { code = "message", name = "상인", face = MERCHANT_FACE,
						    text = "자, 받게. 이 마을을 좀 더 둘러보고 가시게나." } },
						{ { code = "message", name = "상인", face = MERCHANT_FACE,
						    text = "마음이 바뀌면 언제든 들르게." } },
					  } },
				  } },
			},
		},

		-- 집 문을 밟으면 안으로 (전송 + 페이드)
		{
			id = "door_to_hut",
			x = 13, y = 14,
			trigger = "touch",
			commands = { { code = "transfer", map = "room", x = 10, y = 12 } },
		},

		-- 오른쪽 집은 잠겨 있다 — 밟는 게 아니라 문 앞에서 말을 걸면 반응한다
		{
			id = "locked_door",
			x = 51, y = 14,
			trigger = "action",
			commands = { { code = "message", text = "문이 잠겨 있다." } },
		},

		-- 병렬 이벤트: 조작을 잠그지 않고 계속 도는 순찰 (이동 루트 반복)
		{
			id = "patrol",
			x = 30, y = 25, dir = "right",
			charset = { file = CHARSET, index = 6 },
			trigger = "parallel",
			commands = {
				{ code = "moveRoute", target = "patrol", route = {
					"right", "right", "right", "wait:400",
					"down", "down", "wait:400",
					"left", "left", "left", "wait:400",
					"up", "up", "wait:800",
				} },
			},
		},
	},
}
