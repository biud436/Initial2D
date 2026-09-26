-- rpg_mapdata_test.lua : 맵 파일에 실려 온 이벤트(scripts/lua/rpg/mapdata.lua) 검증
-- (9단계 마일스톤 3).
--
-- 포맷 계약 픽스처(tests/fixtures/maps/sample_v2.json)를 진짜로 읽는다. 이 파일은
-- 에디터 저장소와 공유하는 것이라, 포맷이 바뀌면 양쪽 테스트가 함께 깨져야 한다
-- (docs/plans/09-testing.md 3.5절).

local M = {}

function M.run(t)
	local MapData = require("scripts/lua/rpg/mapdata")

	-- ---- [1] v2 픽스처에서 이벤트를 읽는다 ---------------------------------
	local events, version, err = MapData.loadEvents("./fixtures/maps/sample_v2.json")
	t.check_eq(err, nil, "픽스처 로드 오류 없음: " .. tostring(err))
	t.check_eq(version, 2, "포맷 버전 2")
	t.check_eq(#events, 2, "이벤트 두 개")
	t.check_eq(events[1].id, "sign", "첫 이벤트의 id")
	t.check_eq(events[1].x, 1, "좌표 x")
	t.check_eq(events[1].trigger, "action", "트리거")
	t.check_eq(events[1].commands[1].code, "message", "커맨드가 그대로 실린다")
	t.check_eq(events[2].charset.index, 2, "외형 정보도 함께 온다")

	-- JSON으로 온 커맨드도 커맨드 층이 그대로 받아들인다 (중첩 분기까지)
	local Commands = require("scripts/lua/rpg/commands")
	local ok, errors = Commands.validate(events[2].commands)
	t.check(ok, "맵에서 온 커맨드가 검증을 통과한다: " .. table.concat(errors or {}, ", "))

	local Event = require("scripts/lua/rpg/event")
	local built = Event.new(events[1])
	t.check(type(built.script) == "function", "맵에서 온 이벤트도 컴파일된다")

	-- ---- [2] v1 파일에는 이벤트가 없다 (그래도 열린다) ----------------------
	local none, v1 = MapData.loadEvents("./fixtures/maps/sample_v1.json")
	t.check_eq(v1, 1, "v1 파일의 버전")
	t.check_eq(#none, 0, "v1에는 이벤트가 없다")

	-- 없는 파일은 오류를 돌려주되 죽지 않는다
	local missing, _, missErr = MapData.loadEvents("./fixtures/maps/없다.json")
	t.check_eq(#missing, 0, "없는 파일이면 빈 목록")
	t.check(missErr ~= nil, "오류 메시지를 돌려준다")

	-- ---- [3] 합치기: 같은 id면 정의 파일(Lua)이 이긴다 ---------------------
	local fromMap = {
		{ id = "sign", x = 1, y = 1, trigger = "action" },
		{ id = "guard", x = 2, y = 2, trigger = "action" },
	}
	local fromDef = {
		{ id = "guard", x = 9, y = 9, trigger = "action", script = function() end },
		{ id = "extra", x = 3, y = 3, trigger = "auto" },
	}
	local merged = MapData.merge(fromMap, fromDef)
	t.check_eq(#merged, 3, "합치면 셋")
	t.check_eq(merged[1].id, "sign", "맵에만 있는 것은 그대로")
	t.check_eq(merged[2].id, "guard", "덮어써도 자리는 지킨다")
	t.check_eq(merged[2].x, 9, "같은 id면 정의 파일이 이긴다")
	t.check(type(merged[2].script) == "function", "정의 파일의 script가 살아 있다")
	t.check_eq(merged[3].id, "extra", "정의 파일에만 있는 것은 뒤에 붙는다")

	-- 한쪽이 비어도 된다
	t.check_eq(#MapData.merge(nil, fromDef), 2, "맵에 이벤트가 없어도 된다")
	t.check_eq(#MapData.merge(fromMap, nil), 2, "정의 파일에 이벤트가 없어도 된다")
	t.check_eq(#MapData.merge(nil, nil), 0, "둘 다 없으면 빈 목록")

	-- id가 없는 항목은 버린다 (에디터가 잘못 내보낸 경우)
	t.check_eq(#MapData.merge({ { x = 1 } }, nil), 0, "id 없는 이벤트는 무시한다")

	-- ---- [4] eventsFor: 정의 파일 하나로 끝낸다 ----------------------------
	local def = {
		map = "./fixtures/maps/sample_v2.json",
		events = { { id = "sign", x = 5, y = 5, trigger = "touch" } },
	}
	local all = MapData.eventsFor(def)
	t.check_eq(#all, 2, "맵의 둘 중 하나를 정의 파일이 덮어썼다")
	t.check_eq(all[1].trigger, "touch", "덮어쓴 쪽의 값")
	t.check_eq(all[2].id, "guard", "맵에만 있던 이벤트는 그대로")

	-- ---- [5] merge 는 정의 파일이 덮어쓴 id 도 돌려준다 ---------------------
	local _, overridden = MapData.merge(fromMap, fromDef)
	t.check_eq(table.concat(overridden, ","), "guard", "덮인 id 는 guard 하나")
	local _, none2 = MapData.merge(fromMap, { { id = "other", x = 0, y = 0 } })
	t.check_eq(#none2, 0, "겹치지 않으면 덮인 id 가 없다")
	local _, twice = MapData.merge(
		{ { id = "b", x = 0, y = 0 }, { id = "a", x = 0, y = 0 } },
		{ { id = "a", x = 1, y = 1 }, { id = "b", x = 1, y = 1 }, { id = "a", x = 2, y = 2 } })
	t.check_eq(table.concat(twice, ","), "b,a", "덮인 id 는 맵 파일 순서로 한 번씩")
	local _, _, eventsOverridden = MapData.eventsFor(def)
	t.check_eq(table.concat(eventsOverridden, ","), "sign", "eventsFor 도 덮인 id 를 돌려준다")

	-- ---- [6] validateEvents: 계약 표의 줄마다 (m2-rpg-events.md 3절) --------
	local function paths(events, env)
		local ok, problems = MapData.validateEvents(events, env)
		local out = {}
		for _, p in ipairs(problems) do out[#out + 1] = p.path end
		table.sort(out)
		return table.concat(out, " "), ok
	end
	local function base(extra)
		local ev = { id = "e", x = 1, y = 2 }
		for k, v in pairs(extra or {}) do ev[k] = v end
		return ev
	end

	local okPaths, okAll = paths({
		base{ dir = "left", trigger = "touch", charset = { set = "npc", index = 7 },
			through = false, solid = true, speed = 2.5,
			wander = { minWait = 10, maxWait = 10, area = { x = 0, y = 0, w = 1, h = 1 } },
			commands = { { code = "message", text = "a", face = { set = "npc", index = 0 } } } },
		{ id = "f", x = 0, y = 0, charset = { file = "./resources/charsets/placeholder.png" } },
		{ id = "g", x = 3, y = 3, wander = {} },
	})
	t.check(okAll and okPaths == "", "올바른 이벤트는 문제가 없다", okPaths)

	t.check_eq(paths({ "글" }), "events[1]", "이벤트가 객체가 아니다")
	t.check_eq(paths({ { x = 0, y = 0 } }), "events[1].id", "id 가 없다")
	t.check_eq(paths({ base{ id = "" } }), "events[1].id", "id 가 빈 글")
	t.check_eq(paths({ base{ id = 3 } }), "events[1].id", "id 가 글이 아니다")
	t.check_eq(paths({ base{ id = "player" } }), "events[1].id", "id 가 player (예약)")
	t.check_eq(paths({ base{ id = "a" }, base{ id = "b" }, base{ id = "a" } }), "events[3].id",
		"같은 id 는 뒤의 것에 낸다")
	t.check_eq(paths({ { id = "e", x = -1, y = 1.5 } }), "events[1].x events[1].y",
		"x, y 가 0 이상의 정수가 아니다")
	t.check_eq(paths({ { id = "e", x = "1" } }), "events[1].x events[1].y",
		"x 가 글이고 y 가 없다")
	t.check_eq(paths({ { id = "e", x = 2.0, y = 3.0 } }), "",
		"정수 모양의 실수는 정수로 본다 (JSON 쓰기 도구가 2.0 을 2 로 쓴다)")
	t.check_eq(paths({ base{ dir = "north" } }), "events[1].dir", "모르는 방향")
	t.check_eq(paths({ base{ trigger = "click" } }), "events[1].trigger", "모르는 트리거")
	t.check_eq(paths({ base{ charset = "npc" } }), "events[1].charset", "외형이 객체가 아니다")
	t.check_eq(paths({ base{ charset = { set = "npc", file = "./a.png" } } }), "events[1].charset",
		"외형에 set 과 file 이 둘 다")
	t.check_eq(paths({ base{ charset = { index = 1 } } }), "events[1].charset",
		"외형에 set 도 file 도 없다")
	t.check_eq(paths({ base{ charset = { set = "monster" } } }), "events[1].charset.set",
		"외형의 모르는 이름")
	t.check_eq(paths({ base{ charset = { set = "npc", index = 8 } } }), "events[1].charset.index",
		"외형 번호는 0..7")
	t.check_eq(paths({ base{ charset = { file = "", index = 0 } } }), "events[1].charset.file",
		"외형 파일이 빈 글")
	t.check_eq(paths({ base{ through = "yes", solid = 1 } }), "events[1].solid events[1].through",
		"through, solid 가 참거짓이 아니다")
	t.check_eq(paths({ base{ speed = 0 } }), "events[1].speed", "속도 0")
	t.check_eq(paths({ base{ speed = "fast" } }), "events[1].speed", "속도가 수가 아니다")
	t.check_eq(paths({ base{ wander = 5 } }), "events[1].wander", "배회가 객체가 아니다")
	t.check_eq(paths({ base{ wander = { minWait = -1, maxWait = 2.5 } } }),
		"events[1].wander.maxWait events[1].wander.minWait", "대기 프레임이 0 이상의 정수가 아니다")
	t.check_eq(paths({ base{ wander = { minWait = 50, maxWait = 10 } } }),
		"events[1].wander.maxWait", "minWait 가 maxWait 보다 크다")
	t.check_eq(paths({ base{ wander = { minWait = 200 } } }), "events[1].wander.minWait",
		"maxWait 가 없으면 기본값 120 과 비교해 minWait 에 낸다")
	t.check_eq(paths({ base{ wander = { area = { x = -1, y = 0, w = 0, h = 2 } } } }),
		"events[1].wander.area.w events[1].wander.area.x", "구역의 칸마다")
	t.check_eq(paths({ base{ wander = { area = "넓게" } } }), "events[1].wander.area",
		"구역이 객체가 아니다")
	t.check_eq(paths({ base{ commands = "안녕" } }), "events[1].commands", "커맨드가 배열이 아니다")
	t.check_eq(paths({ base{ commands = {
		{ code = "없는커맨드" },
		{ code = "message" },
		{ code = "choice", options = {} },
		{ code = "choice", options = { "가" }, branches = { { { code = "message", name = "a" } } } },
		{ code = "message", text = "a", face = { set = "npc", index = 16 } },
		{ code = "transfer", map = "inn", dir = "north" },
	} } }), table.concat({
		"events[1].commands[1]",
		"events[1].commands[2].text",
		"events[1].commands[3].options",
		"events[1].commands[4].branches[1][1].text",
		"events[1].commands[5].face.index",
		"events[1].commands[6].dir",
	}, " "), "커맨드 검사는 events[i].commands 를 앞에 붙인다")
	t.check_eq(paths({ base{ commands = { { code = "script", name = "greet" } } } },
		{ scripts = { greet = function() end } }), "", "정의 파일의 scripts 로 이름을 확인한다")
	t.check_eq(paths({ base{ commands = { { code = "script", name = "greet" } } } }),
		"events[1].commands[1].name", "등록되지 않은 스크립트 이름")
	t.check_eq(paths("글"), "events", "events 가 배열이 아니다")

	-- JSON 모양: 배열 자리의 객체, 객체 자리의 배열, null 칸 (3.1 의 규칙)
	t.check_eq(paths({ crates = base{} }), "events", "events 자리의 객체")
	t.check_eq(paths({}), "", "빈 표는 빈 events 다")
	t.check_eq(paths({ { 1, 2 } }), "events[1]", "이벤트 자리의 배열")
	t.check_eq(paths({ base{ wander = { 5 } } }), "events[1].wander", "배회 자리의 배열")
	t.check_eq(paths({ base{ wander = { area = { 1, 2, 3, 4 } } } }), "events[1].wander.area",
		"구역 자리의 배열")
	t.check_eq(paths({ base{ wander = {}, commands = {} } }), "", "빈 표는 빈 객체이자 빈 목록이다")
	t.check_eq(paths({ base{ commands = { first = { code = "message", text = "a" } } } }),
		"events[1].commands", "commands 자리의 객체")
	local nullCommands = { { code = "message", text = "first" } }
	nullCommands[3] = { code = "message" }
	nullCommands[4] = { code = "nosuch" }
	t.check_eq(paths({ base{ commands = nullCommands } }),
		"events[1].commands[2] events[1].commands[3].text events[1].commands[4]",
		"null 커맨드는 그 자리에 내고 뒤의 커맨드도 본다")
	local nullBranches = {}
	nullBranches[2] = { { code = "message", text = "t", face = { set = "npc", index = 99 } } }
	local okBranch, branchProblems, branchValid, branchSkipped = MapData.validateEvents({
		base{ id = "sign", commands = { { code = "choice", options = { "a", "b" }, branches = nullBranches } } },
		base{ id = "next" },
	})
	local branchPaths = {}
	for _, p in ipairs(branchProblems) do branchPaths[#branchPaths + 1] = p.path end
	table.sort(branchPaths)
	t.check_eq(table.concat(branchPaths, " "),
		"events[1].commands[1].branches[1] events[1].commands[1].branches[2][1].face.index",
		"null 가지 뒤의 얼굴 번호까지 본다")
	t.check(not okBranch and branchSkipped == 1 and #branchValid == 1 and branchValid[1].id == "next",
		"그 이벤트는 건너뛰고 나머지는 남는다")

	-- 한 이벤트의 문제는 전부 내고, 문제가 있는 이벤트만 뺀다
	local ok, problems, valid, skipped = MapData.validateEvents({
		base{ id = "good" },
		{ id = "player", x = -1, y = 0, dir = "north" },
		base{ id = "also" },
	})
	t.check_eq(ok, false, "문제가 있으면 ok 가 거짓")
	t.check_eq(#problems, 3, "한 이벤트의 문제 셋을 다 낸다")
	t.check_eq(problems[1].index, 2, "문제에 이벤트 번호가 붙는다")
	t.check_eq(skipped, 1, "뺀 이벤트는 하나")
	t.check_eq(#valid, 2, "나머지 둘은 남는다")
	t.check(valid[1].id == "good" and valid[2].id == "also", "남은 이벤트의 순서")

	-- JSON 의 null 은 구멍이 된다. 그 자리도 이벤트로 센다.
	local holes = { base{ id = "a" } }
	holes[3] = base{ id = "c" }
	local _, holeProblems, holeValid = MapData.validateEvents(holes)
	t.check(#holeProblems == 1 and holeProblems[1].path == "events[2]", "null 자리는 객체가 아니다")
	t.check_eq(#holeValid, 2, "구멍 뒤의 이벤트도 남는다")

	-- ---- [7] resolveAssets: 논리 이름을 파일로 ------------------------------
	local Assets = require("scripts/lua/rpg/assets")
	local original = {
		{ id = "npc", x = 1, y = 1, charset = { set = "npc", index = 4, note = "보존" },
		  commands = {
			{ code = "message", text = "a", face = { set = "npc", index = 2 } },
			{ code = "if", cond = { flag = "f" }, thenDo = {
				{ code = "choice", options = { "가" }, branches = {
					{ { code = "message", text = "b", face = { set = "npc", index = 5 } } } } } } },
		  } },
		{ id = "file", x = 2, y = 2, charset = { file = "./resources/charsets/placeholder.png", index = 1 } },
		{ id = "plain", x = 3, y = 3 },
	}
	local resolved = MapData.resolveAssets(original, Assets)
	t.check_eq(#resolved, 3, "이벤트 수는 그대로")
	t.check_eq(resolved[1].charset.file, Assets.npcCharset(), "외형 set 이 NPC CharSet 파일로")
	t.check_eq(resolved[1].charset.set, nil, "풀린 외형에는 set 이 없다")
	t.check_eq(resolved[1].charset.index, 4, "외형 번호는 그대로")
	t.check_eq(resolved[1].charset.note, "보존", "모르는 칸은 보존한다")
	t.check_eq(resolved[1].commands[1].face.file, Assets.faceset(), "대화의 얼굴도 푼다")
	local inner = resolved[1].commands[2].thenDo[1].branches[1][1]
	t.check_eq(inner.face.file, Assets.faceset(), "가지 안의 얼굴도 푼다")
	t.check_eq(inner.face.index, 5, "얼굴 번호는 그대로")
	t.check_eq(original[1].charset.set, "npc", "원본의 외형은 그대로")
	t.check_eq(original[1].commands[1].face.set, "npc", "원본의 얼굴은 그대로")
	t.check_eq(resolved[2].charset.file, "./resources/charsets/placeholder.png", "파일 외형은 그대로")
	t.check_eq(resolved[3].charset, nil, "외형 없는 이벤트")
	t.check(Commands.validate(resolved[1].commands), "풀린 커맨드도 검증을 통과한다")
	local rebuilt = Event.new(resolved[1])
	t.check(type(rebuilt.script) == "function", "풀린 이벤트로 Event.new 가 된다")

	-- null 칸 뒤의 이벤트와 커맨드도 푼다
	local holeCommands = { { code = "message", text = "a" } }
	holeCommands[3] = { code = "message", text = "b", face = { set = "npc", index = 1 } }
	local holeEvents = { { id = "a", x = 1, y = 1 } }
	holeEvents[3] = { id = "c", x = 2, y = 2, charset = { set = "npc", index = 0 }, commands = holeCommands }
	local holeResolved = MapData.resolveAssets(holeEvents, Assets)
	t.check_eq(holeResolved[2], nil, "null 칸은 그대로 비어 있다")
	t.check(holeResolved[3] ~= nil and holeResolved[3].charset.file == Assets.npcCharset(),
		"null 뒤의 이벤트도 푼다")
	t.check(holeResolved[3] ~= nil and holeResolved[3].commands[3].face.file == Assets.faceset(),
		"null 뒤의 커맨드의 얼굴도 푼다")
end

return M
