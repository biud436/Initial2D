-- rpg_mapdata_test.lua : 맵 파일에 실려 온 이벤트(scripts/rpg/mapdata.lua) 검증
-- (9단계 마일스톤 3).
--
-- 포맷 계약 픽스처(tests/fixtures/maps/sample_v2.json)를 진짜로 읽는다. 이 파일은
-- 에디터 저장소와 공유하는 것이라, 포맷이 바뀌면 양쪽 테스트가 함께 깨져야 한다
-- (docs/plans/09-testing.md 3.5절).

local M = {}

function M.run(t)
	local MapData = require("scripts/rpg/mapdata")

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
	local Commands = require("scripts/rpg/commands")
	local ok, errors = Commands.validate(events[2].commands)
	t.check(ok, "맵에서 온 커맨드가 검증을 통과한다: " .. table.concat(errors or {}, ", "))

	local Event = require("scripts/rpg/event")
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
end

return M
