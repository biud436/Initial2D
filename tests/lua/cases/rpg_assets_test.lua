-- rpg_assets_test.lua : 리소스 고르기(scripts/rpg/assets.lua) 검증 (8단계).
-- RTP는 재배포할 수 없어 CI에도 개발자 기계에도 없을 수 있다. 그래서 "있으면
-- RTP, 없으면 플레이스홀더"가 두 경우 모두에서 옳아야 한다.

local M = {}

function M.run(t)
	local Assets = require("scripts/rpg/assets")

	-- [1] exists: 커밋된 파일과 없는 파일
	t.check(Assets.exists("./resources/charsets/placeholder.png"),
		"커밋된 플레이스홀더 CharSet은 있다")
	t.check(not Assets.exists("./resources/charsets/이런_파일은_없다.png"),
		"없는 파일은 없다고 한다")
	t.check(not Assets.exists(nil), "nil은 없는 것으로 친다")
	t.check(not Assets.exists(42), "문자열이 아니면 없는 것으로 친다")

	-- [2] pick: 앞에서부터 처음 있는 것
	t.check_eq(Assets.pick({ "./없다.png", "./resources/ui/window.png" }),
		"./resources/ui/window.png", "없는 후보를 건너뛴다")
	t.check_eq(Assets.pick({ "./resources/ui/window.png", "./resources/ui/fade.png" }),
		"./resources/ui/window.png", "앞의 후보가 있으면 그것을 쓴다")
	t.check_eq(Assets.pick({ "./없다1.png", "./없다2.png" }), "./없다2.png",
		"전부 없으면 마지막 후보를 돌려준다 (nil이 아니라)")

	-- [3] 이름 붙은 접근자는 언제나 실재하는 파일을 준다 (RTP 유무와 무관)
	for name, path in pairs({
		playerCharset = Assets.playerCharset(),
		npcCharset = Assets.npcCharset(),
		faceset = Assets.faceset(),
		windowskin = Assets.windowskin(),
	}) do
		t.check(Assets.exists(path), name .. " 는 실재하는 파일: " .. tostring(path))
	end

	-- [4] 후보 목록의 순서: RTP가 먼저, 커밋된 플레이스홀더가 나중
	for _, list in ipairs({ Assets.PLAYER_CHARSET, Assets.NPC_CHARSET,
		Assets.FACESET, Assets.WINDOWSKIN }) do
		t.check(list[1]:find("/rtp/", 1, true) ~= nil, "첫 후보는 RTP: " .. list[1])
		t.check(list[#list]:find("/rtp/", 1, true) == nil,
			"마지막 후보는 저장소 자산: " .. list[#list])
	end

	-- [5] 맵 경로: 칩셋이 없으면 기본 판
	local hasExterior = Assets.exists("./resources/rtp/ChipSet/Exterior.png")
		and Assets.rtpEnabled()
	local village = Assets.mapPath("village", "Exterior")
	if hasExterior then
		t.check_eq(village, "./resources/maps/village_rtp.json", "칩셋이 있으면 RTP 판")
	else
		t.check_eq(village, "./resources/maps/village.json", "칩셋이 없으면 기본 판")
	end
	t.check(Assets.exists(village), "고른 맵 파일은 실재한다: " .. village)

	-- [5b] INITIAL2D_NO_RTP 가 걸린 실행에서는 RTP를 아예 보지 않는다
	if not Assets.rtpEnabled() then
		t.check_eq(village, "./resources/maps/village.json",
			"RTP를 끄면 칩셋이 있어도 기본 판")
		for _, path in ipairs({ Assets.playerCharset(), Assets.npcCharset(),
			Assets.faceset(), Assets.windowskin() }) do
			t.check(path:find("/rtp/", 1, true) == nil, "RTP를 끄면 저장소 자산만: " .. path)
		end
	end

	t.check_eq(Assets.mapPath("room", nil), "./resources/maps/room.json",
		"칩셋 이름이 없으면 기본 판")
	t.check(Assets.exists(Assets.mapPath("room", "Interior")), "오두막 맵도 실재한다")
end

return M
