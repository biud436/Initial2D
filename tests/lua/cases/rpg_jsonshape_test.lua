-- rpg_jsonshape_test.lua : Json.Load 가 만든 표의 JSON 모양 판정 (scripts/lua/rpg/jsonshape.lua)
--
-- 판정 규칙(docs/plans/m2-rpg-events.md 3.1절)이 진짜 Json.Load 의 결과에 맞는지 본다.
-- 테스트 데이터는 워크 디렉터리에 직접 만든다.

local M = {}

local SAMPLE = [[{
  "holes": [ { "a": 1 }, null, { "c": 3 } ],
  "trailing": [ { "a": 1 }, null ],
  "allNull": [ null ],
  "emptyArray": [],
  "emptyObject": {},
  "object": { "k": [ 1 ] },
  "numberKeys": { "1": [], "2": [] },
  "array": [ 1, 2 ]
}]]

function M.run(t)
	local Shape = require("scripts/lua/rpg/jsonshape")

	local f = assert(io.open("./jsonshape_test_data.json", "w"))
	f:write(SAMPLE)
	f:close()
	local data, err = Json.Load("./jsonshape_test_data.json")
	os.remove("./jsonshape_test_data.json")
	t.check(type(data) == "table", "샘플을 읽는다", err)
	if type(data) ~= "table" then return end

	-- 칸 수: 가운데의 null 은 한 칸, 끝의 null 은 보이지 않는다
	t.check_eq(Shape.length(data.holes), 3, "가운데의 null 도 한 칸으로 센다")
	t.check_eq(data.holes[2], nil, "null 칸은 nil")
	t.check_eq(Shape.length(data.trailing), 1, "끝의 null 은 Json.Load 가 남기지 않는다")
	t.check_eq(Shape.length(data.allNull), 0, "null 만 있는 배열은 빈 표")
	t.check_eq(Shape.length("글"), 0, "표가 아니면 0")

	-- 배열 자리
	t.check(Shape.isArray(data.holes), "구멍이 있어도 배열이다")
	t.check(Shape.isArray(data.array), "정수 키만 있으면 배열")
	t.check(Shape.isArray(data.emptyArray), "빈 배열")
	t.check(Shape.isArray(data.emptyObject), "빈 객체 {} 도 빈 배열로 본다 (가릴 수 없다)")
	t.check(not Shape.isArray(data.object), "글 키가 있으면 배열이 아니다")
	t.check(not Shape.isArray(data.numberKeys), "\"1\" 같은 수 모양의 키도 글 키다")
	t.check(not Shape.isArray("글"), "글은 배열이 아니다")
	t.check(not Shape.isArray(nil), "nil 은 배열이 아니다")

	-- 객체 자리
	t.check(Shape.isObject(data.object), "글 키만 있으면 객체")
	t.check(Shape.isObject(data.numberKeys), "수 모양의 글 키도 객체")
	t.check(Shape.isObject(data.emptyObject), "빈 객체")
	t.check(Shape.isObject(data.emptyArray), "빈 배열 [] 도 빈 객체로 본다 (가릴 수 없다)")
	t.check(not Shape.isObject(data.array), "정수 키가 있으면 객체가 아니다")
	t.check(not Shape.isObject(5), "수는 객체가 아니다")
	t.check(not Shape.isObject(nil), "nil 은 객체가 아니다")
end

return M
