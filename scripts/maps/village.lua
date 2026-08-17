-- 마을 맵의 이벤트 정의 (6단계, docs/plans/06-rpg-events.md)
--
-- 맵 파일(JSON)에는 타일만 들어 있고, 무엇이 어디서 무슨 일을 하는지는 이 파일에
-- 있다. 데이터와 로직의 경계를 여기서 긋는다 (2단계 결정).
--
-- 스크립트는 코루틴으로 돌기 때문에 ctx.message처럼 "끝날 때까지 기다리는" 호출을
-- 그냥 순서대로 쓰면 된다. 조건과 반복은 Lua 문법 그대로다.

local CHARSET = "./resources/charsets/placeholder.png"

return {
	map = "./resources/maps/village.json",
	start = { x = 34, y = 21, dir = "down" },

	-- 자동 시연(INITIAL2D_AUTOPLAY)에서 따라 걷는 경로. "talk"은 결정키.
	autoRoute = { "left", "left", "up", "talk", "talk", "talk", "down", "right", "right" },

	events = {
		-- 말을 걸면 대화하고, 선택지에 따라 다른 대사를 한다
		{
			id = "elder",
			x = 32, y = 20, dir = "down",
			charset = { file = CHARSET, index = 2 },
			trigger = "action",
			script = function(self, ctx)
				ctx.message("어서 오시게. 처음 보는 얼굴이군.")
				local pick = ctx.choice({ "네, 처음입니다", "아니요, 와 본 적 있습니다" })
				if pick == 1 then
					ctx.message("왼쪽 마당의 문으로 들어가면 오두막이라네.")
					ctx.state.toldAboutHut = true
				else
					ctx.message("그럼 길은 잘 알겠군.")
				end
			end,
		},

		-- 배회하다가도 말을 걸면 멈추고 대답한다 (배회는 5단계 기능 재사용)
		{
			id = "kid",
			x = 36, y = 22, dir = "left",
			charset = { file = CHARSET, index = 5 },
			trigger = "action",
			wander = { minWait = 30, maxWait = 120, area = { x = 30, y = 18, w = 12, h = 8 } },
			script = function(self, ctx)
				if ctx.state.toldAboutHut then
					ctx.message("촌장님한테 들었죠? 저 문 맞아요.")
				else
					ctx.message("여기저기 돌아다니는 게 제 일이에요.")
				end
			end,
		},

		-- 마당 출입구를 밟으면 오두막으로 (전송 + 페이드)
		{
			id = "gate_to_hut",
			x = 15, y = 15,
			trigger = "touch",
			script = function(self, ctx)
				ctx.transfer("room", 10, 11)
			end,
		},

		-- 병렬 이벤트: 조작을 잠그지 않고 계속 도는 순찰 (이동 루트 반복)
		{
			id = "patrol",
			x = 30, y = 25, dir = "right",
			charset = { file = CHARSET, index = 6 },
			trigger = "parallel",
			script = function(self, ctx)
				ctx.moveRoute(self.id, {
					"right", "right", "right", "wait:400",
					"down", "down", "wait:400",
					"left", "left", "left", "wait:400",
					"up", "up", "wait:800",
				})
			end,
		},
	},
}
