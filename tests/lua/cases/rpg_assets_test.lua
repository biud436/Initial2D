-- rpg_assets_test.lua : 리소스 고르기(scripts/lua/rpg/assets.lua) 검증 (8단계).
-- RTP는 재배포할 수 없어 CI에도 개발자 기계에도 없을 수 있다. 그래서 "있으면
-- RTP, 없으면 플레이스홀더"가 두 경우 모두에서 옳아야 한다.

local M = {}

function M.run(t)
	local Assets = require("scripts/lua/rpg/assets")

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

	-- [6] 논리 이름 (맵 파일의 { set, index }). 목록 자체는 rpg_event_schema_test 가 스키마와 대조한다
	t.check_eq(Assets.SETS.charset.npc, Assets.NPC_CHARSET, "charset.npc 는 NPC 후보 목록")
	t.check_eq(Assets.SETS.charset.player, Assets.PLAYER_CHARSET, "charset.player 는 플레이어 후보 목록")
	t.check_eq(Assets.SETS.face.npc, Assets.FACESET, "face.npc 는 FaceSet 후보 목록")
	t.check_eq(Assets.resolveRef("charset", { set = "npc", index = 3 }), Assets.npcCharset(),
		"set 은 후보 중 있는 파일로 푼다")
	t.check_eq(Assets.resolveRef("charset", { set = "player" }), Assets.playerCharset(),
		"플레이어 외형도 이름으로 고른다")
	t.check_eq(Assets.resolveRef("face", { set = "npc", index = 6 }), Assets.faceset(), "얼굴 이름")
	t.check_eq(Assets.resolveRef("face", { file = "./x.png", index = 1 }), "./x.png",
		"file 은 그대로 돌려준다")
	local missing, why = Assets.resolveRef("face", { set = "player" })
	t.check(missing == nil and type(why) == "string", "없는 이름은 nil 과 이유", why)
	t.check_eq(Assets.resolveRef("sprite", { set = "npc" }), nil, "모르는 종류는 nil")
	t.check_eq(Assets.resolveRef("charset", "npc"), nil, "객체가 아니면 nil")

	-- [7] checkRef: 모양 검사 (경로 끝부분과 이유)
	local function tails(kind, ref)
		local out = {}
		for _, p in ipairs(Assets.checkRef(kind, ref)) do
			out[#out + 1] = p.path == "" and "@" or p.path    -- @ 는 참조 자체
		end
		return table.concat(out, ",")
	end
	t.check_eq(tails("charset", { set = "npc", index = 7 }), "", "올바른 외형")
	t.check_eq(tails("charset", { set = "npc", index = 8 }), ".index", "외형 번호는 0..7")
	t.check_eq(tails("face", { set = "npc", index = 15 }), "", "얼굴 번호 15 는 된다")
	t.check_eq(tails("face", { set = "npc", index = 16 }), ".index", "얼굴 번호는 0..15")
	t.check_eq(tails("face", { set = "npc", index = -1 }), ".index", "음수 번호")
	t.check_eq(tails("face", { set = "player" }), ".set", "얼굴에는 player 이름이 없다")
	t.check_eq(tails("charset", { set = "npc", file = "./a.png" }), "@", "둘 다 있으면 참조 자체")
	t.check_eq(tails("charset", {}), "@", "둘 다 없어도 참조 자체")
	t.check_eq(tails("charset", 3), "@", "객체가 아니면 참조 자체 하나")
	t.check_eq(tails("charset", { file = 5 }), ".file", "파일이 글이 아니다")
	t.check_eq(tails("face", { file = "", index = 0 }), ".file", "얼굴 파일이 빈 글")
	t.check_eq(tails("charset", { "npc", 1 }), "@", "배열은 객체가 아니다 (참조 자체 하나)")
end

return M
