-- 오두막 안의 이벤트 정의 (6단계)
--
-- 맵에 들어서면 auto 이벤트가 한 번 돌고(그동안 조작이 잠긴다), 아래 출입구를
-- 밟으면 마을로 돌아간다.

local CHARSET = "./resources/charsets/placeholder.png"

return {
	map = "./resources/maps/room.json",
	start = { x = 13, y = 20, dir = "up" },

	-- 자동 시연: 한 칸 아래 출입구를 밟아 마을로 돌아간다 (전환과 페이드 확인)
	-- 자동 시연: 주민에게 말을 걸어 보고 아래 문으로 나간다
	autoRoute = { "left", "left", "up", "up", "up", "up", "talk", "talk",
		"down", "down", "down", "right", "right", "down" },

	events = {
		-- 맵 진입 시 한 번 자동 실행 (조작 잠금 확인용)
		{
			id = "enter_note",
			x = 13, y = 20,
			trigger = "auto",
			script = function(self, ctx)
				if ctx.state.visitedHut then
					return   -- 두 번째부터는 조용히 넘어간다
				end
				ctx.state.visitedHut = true
				ctx.message("오두막 안이다. 아래 문으로 나갈 수 있다.")
			end,
		},

		{
			id = "resident",
			x = 10, y = 16, dir = "down",
			charset = { file = CHARSET, index = 3 },
			trigger = "action",
			script = function(self, ctx)
				ctx.message("여긴 조용해서 좋아요.")
				ctx.moveRoute(self.id, { "turn:left", "wait:300", "turn:down" })
				ctx.message("...가끔 심심하지만요.")
			end,
		},

		-- 아래 출입구: 밟으면 마을로 돌아간다 (문 앞 칸에 세운다)
		{
			id = "exit_to_village",
			x = 13, y = 21,
			trigger = "touch",
			script = function(self, ctx)
				ctx.transfer("village", 13, 15)
			end,
		},
	},
}
