-- rpgdemo_playenv_test.lua : 데모 맵 씬의 실행 환경 변수 해석 검증 (M2).
--
-- INITIAL2D_RPG_AT, INITIAL2D_RPG_STATE, INITIAL2D_RPG_ROUTE 의 꼴은 에디터의 실행 명령이
-- 만드는 글이다 (docs/plans/m2-rpg-events.md 5.2절). 엔진 없이 도는 순수 함수라 여기서
-- 꼴마다 본다. 게임에 실제로 실리는지는 tests/run_engine_tests.py 의 test_rpg_play_here 가 본다.

local M = {}

function M.run(t)
	local PlayEnv = require("scripts/lua/games/rpgdemo/playenv")
	local Inventory = require("scripts/lua/rpg/inventory")

	-- ---- [1] INITIAL2D_RPG_AT ------------------------------------------------
	local at = PlayEnv.parseAt("15,40,left")
	t.check(at ~= nil and at.x == 15 and at.y == 40 and at.dir == "left", "x,y,dir")
	at = PlayEnv.parseAt(" 3 , 7 ")
	t.check(at ~= nil and at.x == 3 and at.y == 7 and at.dir == nil, "x,y 만 주면 방향은 없다")
	t.check(math.type(at.x) == "integer", "칸은 정수로 읽는다")
	for _, bad in ipairs({ "", "15", "15,40,left,1", "a,40", "-1,40", "1.5,2", "15,40,north" }) do
		local got, why = PlayEnv.parseAt(bad)
		t.check(got == nil and type(why) == "string", "틀린 AT 는 이유와 함께 거절: '" .. bad .. "'")
	end
	t.check(PlayEnv.parseAt(nil) == nil, "값이 없으면 nil")

	-- ---- [2] INITIAL2D_RPG_STATE ---------------------------------------------
	local items = { shell = {}, silver = {}, warehouse_key = {} }
	local state, errors = PlayEnv.parseState(
		"arrived, booked=false,count=3,ratio=2.5,who=captain,item:silver=2,item:shell", items)
	t.check_eq(#errors, 0, "올바른 항목만이면 오류가 없다")
	t.check_eq(state.arrived, true, "이름만 적으면 참")
	t.check_eq(state.booked, false, "=false 는 거짓")
	t.check_eq(state.count, 3, "수는 수로")
	t.check_eq(math.type(state.count), "integer", "정수 모양은 정수로")
	t.check_eq(state.ratio, 2.5, "실수도 수로")
	t.check_eq(state.who, "captain", "그 밖은 글로")
	t.check_eq(Inventory.count(state, "silver"), 2, "item:<id>=<n> 은 소지품")
	t.check_eq(Inventory.count(state, "shell"), 1, "item:<id> 는 하나")

	state, errors = PlayEnv.parseState("x=1,x=2,flag=true", items)
	t.check_eq(state.x, 2, "뒤의 항목이 이긴다")
	t.check_eq(state.flag, true, "=true 는 참")

	state, errors = PlayEnv.parseState(
		"ok,item:lamp_oill=1,item:silver=-1,item:=1,foo:bar=1,=3,empty=,items=1,item:silver=x", items)
	t.check_eq(state.ok, true, "틀린 항목이 있어도 나머지는 적용된다")
	t.check_eq(Inventory.count(state, "silver"), 0, "틀린 개수는 적용되지 않는다")
	t.check_eq(state["foo:bar"], nil, "모르는 접두사는 적용되지 않는다")
	local byEntry = {}
	for _, e in ipairs(errors) do byEntry[e.entry] = e.message end
	t.check(byEntry["item:lamp_oill=1"] ~= nil, "아이템 표에 없는 id 는 틀린 항목")
	t.check(byEntry["item:silver=-1"] ~= nil, "음수 개수는 틀린 항목")
	t.check(byEntry["item:=1"] ~= nil, "빈 아이템 id 는 틀린 항목")
	t.check(byEntry["foo:bar=1"] ~= nil, "item: 이 아닌 접두사는 틀린 항목")
	t.check(byEntry["=3"] ~= nil, "빈 이름은 틀린 항목")
	t.check(byEntry["empty="] ~= nil, "빈 값은 틀린 항목")
	t.check(byEntry["items=1"] ~= nil, "소지품 자리 이름은 쓸 수 없다")
	t.check(byEntry["item:silver=x"] ~= nil, "수가 아닌 개수는 틀린 항목")
	t.check_eq(#errors, 8, "틀린 항목마다 하나씩")

	state, errors = PlayEnv.parseState("item:anything=3")
	t.check_eq(Inventory.count(state, "anything"), 3, "아이템 표가 없으면 id 를 확인하지 않는다")
	state, errors = PlayEnv.parseState(nil, items)
	t.check(next(state) == nil and #errors == 0, "값이 없으면 빈 상태")
	state, errors = PlayEnv.parseState(" , ,", items)
	t.check(next(state) == nil and #errors == 0, "빈 항목은 버린다")

	-- ---- [3] INITIAL2D_RPG_ROUTE ---------------------------------------------
	local steps, bad = PlayEnv.parseRoute("talk, up,up,left")
	t.check_eq(table.concat(steps, ","), "talk,up,up,left", "걸음 순서 그대로")
	t.check_eq(#bad, 0, "올바른 걸음만")
	steps, bad = PlayEnv.parseRoute("")
	t.check(#steps == 0 and #bad == 0, "빈 값은 걸음이 없다 (auto 만 기다린다)")
	steps, bad = PlayEnv.parseRoute("up,jump,down")
	t.check_eq(table.concat(steps, ","), "up,down", "모르는 걸음은 빼고")
	t.check(#bad == 1 and bad[1].entry == "jump", "모르는 걸음을 알린다")

	-- ---- [4] trace 글과 켜짐 값 ----------------------------------------------
	t.check_eq(PlayEnv.escape("첫 줄\n둘째 줄"), "첫 줄\\n둘째 줄", "줄바꿈은 \\n 두 글자")
	t.check_eq(PlayEnv.escape(nil), "", "nil 은 빈 글")
	t.check(PlayEnv.enabled("1") and PlayEnv.enabled("yes"), "켜짐")
	t.check(not PlayEnv.enabled(nil) and not PlayEnv.enabled("") and not PlayEnv.enabled("0"), "꺼짐")
end

return M
