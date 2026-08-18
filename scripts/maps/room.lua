-- 오두막 안의 이벤트 정의 (6단계)
--
-- 맵에 들어서면 auto 이벤트가 한 번 돌고(그동안 조작이 잠긴다), 아래 출입구를
-- 밟으면 마을로 돌아간다.


-- RTP 칩셋이 로컬에 있으면 그 판을 쓴다. RTP 그림은 재배포할 수 없어 저장소에
-- 없으므로, 없으면 직접 그린 타일셋 판으로 돌아간다. 두 판은 지오메트리가 같아
-- 아래 이벤트 좌표를 그대로 쓴다 (tools/generate_demo_maps.py).
local function exists(path)
	local f = io.open(path, "rb")
	if f == nil then return false end
	f:close()
	return true
end

-- NPC 그림도 마찬가지로 로컬에 RTP가 있으면 그쪽을 쓴다.
local CHARSET = "./resources/charsets/placeholder.png"
for _, candidate in ipairs({ "./resources/rtp/CharSet/People1.png" }) do
	if exists(candidate) then CHARSET = candidate end
end

-- 대화창 얼굴 그림 (7단계, tools/generate_faceset.py)
local FACESET = "./resources/faces/placeholder.png"
for _, candidate in ipairs({ "./resources/rtp/FaceSet/People1.png" }) do
	if exists(candidate) then FACESET = candidate end
end

local function pickMap(base)
	if exists("./resources/rtp/ChipSet/Interior.png") then
		return "./resources/maps/" .. base .. "_rtp.json"
	end
	return "./resources/maps/" .. base .. ".json"
end

return {
	map = pickMap("room"),
	start = { x = 10, y = 12, dir = "up" },

	-- 자동 시연: 한 칸 아래 출입구를 밟아 마을로 돌아간다 (전환과 페이드 확인)
	-- 자동 시연: 주민에게 말을 걸어 보고 아래 문으로 나간다
	autoRoute = { "left", "left", "up", "up", "up", "up", "talk", "talk",
		"down", "down", "down", "right", "right", "down" },

	events = {
		-- 맵 진입 시 한 번 자동 실행 (조작 잠금 확인용)
		{
			id = "enter_note",
			x = 10, y = 12,
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
			x = 7, y = 8, dir = "down",
			charset = { file = CHARSET, index = 3 },
			trigger = "action",
			script = function(self, ctx)
				local resident = { name = "주민", face = { file = FACESET, index = 3 } }
				ctx.message("여긴 조용해서 좋아요.", resident)
				ctx.moveRoute(self.id, { "turn:left", "wait:300", "turn:down" })
				-- 웃는 표정으로 바꿔 본다 (플레이스홀더 FaceSet은 8..15가 웃는 얼굴)
				ctx.message("...가끔 심심하지만요.",
					{ name = "주민", face = { file = FACESET, index = 11 } })
			end,
		},

		-- 아래 출입구: 밟으면 마을로 돌아간다 (문 앞 칸에 세운다)
		{
			id = "exit_to_village",
			x = 10, y = 13,
			trigger = "touch",
			script = function(self, ctx)
				ctx.transfer("village", 13, 15)
			end,
		},
	},
}
