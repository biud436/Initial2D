-- rpg_inventory_test.lua : 소지품(scripts/rpg/inventory.lua) 검증 (10단계).
--
-- 소지품은 상태 테이블 위의 순수 함수라 엔진 없이 전부 검사된다.

local M = {}

function M.run(t)
	local Inventory = require("scripts/rpg/inventory")

	-- ---- [1] 세기와 더하기 --------------------------------------------------
	local state = {}
	t.check_eq(Inventory.count(state, "silver"), 0, "없으면 0")
	t.check(not Inventory.has(state, "silver"), "없으면 has는 거짓")
	t.check_eq(Inventory.give(state, "silver"), 1, "기본 개수는 1")
	t.check_eq(Inventory.give(state, "silver", 2), 3, "더하면 쌓인다")
	t.check(Inventory.has(state, "silver", 3), "3개 가졌다")
	t.check(not Inventory.has(state, "silver", 4), "4개는 아니다")
	t.check_eq(Inventory.give(state, "silver", 0), 3, "0개를 더해도 그대로")

	-- 소지품은 state 안에 산다 (저장이 생기면 state와 함께 저장된다)
	t.check_eq(type(state[Inventory.KEY]), "table", "state 안의 표에 들어간다")
	t.check_eq(state[Inventory.KEY].silver, 3, "표에 개수가 있다")

	-- ---- [2] 빼기: 모자라면 아무 일도 없다 ---------------------------------
	t.check(not Inventory.take(state, "silver", 4), "모자라면 false")
	t.check_eq(Inventory.count(state, "silver"), 3, "실패했을 때 개수가 줄지 않는다")
	t.check(Inventory.take(state, "silver", 2), "충분하면 true")
	t.check_eq(Inventory.count(state, "silver"), 1, "뺀 만큼 줄었다")
	t.check(Inventory.take(state, "silver", 1), "마지막 하나도 뺀다")
	t.check_eq(state[Inventory.KEY].silver, nil, "0개는 표에서 지운다")
	t.check(not Inventory.take(state, "없는것"), "없는 물건은 뺄 수 없다")

	-- ---- [3] 목록: 표의 order로 정렬한다 ------------------------------------
	local db = {
		key = { name = "창고 열쇠", desc = "손잡이가 반들반들하다.", order = 10 },
		oil = { name = "등유 한 통", order = 20 },
		coin = { name = "은화", order = 30 },
	}
	local bag = {}
	Inventory.give(bag, "coin", 2)
	Inventory.give(bag, "key")
	Inventory.give(bag, "oil")

	local list = Inventory.list(bag, db)
	t.check_eq(#list, 3, "가진 종류만큼 나온다")
	t.check_eq(list[1].name, "창고 열쇠", "order가 작은 것이 위")
	t.check_eq(list[2].name, "등유 한 통", "그 다음")
	t.check_eq(list[3].name, "은화", "마지막")
	t.check_eq(list[3].count, 2, "개수가 실려 나온다")
	t.check_eq(list[1].desc, "손잡이가 반들반들하다.", "설명도 실려 나온다")
	t.check_eq(list[1].id, "key", "id도 남는다")

	-- 순서가 실행마다 흔들리지 않는다 (pairs 순회를 정렬로 덮는다)
	local again = Inventory.list(bag, db)
	t.check_eq(again[1].id .. again[2].id .. again[3].id, "keyoilcoin",
		"같은 소지품이면 같은 순서")

	-- ---- [4] 표에 없는 물건도 빠뜨리지 않는다 -------------------------------
	Inventory.give(bag, "수수께끼")
	local withUnknown = Inventory.list(bag, db)
	t.check_eq(#withUnknown, 4, "표에 없어도 목록에 나온다")
	t.check_eq(withUnknown[4].name, "수수께끼", "이름 자리에 id를 그대로 쓴다")

	t.check_eq(#Inventory.list({}, db), 0, "빈 소지품은 빈 목록")
	t.check_eq(#Inventory.list(nil, db), 0, "state가 없어도 죽지 않는다")
end

return M
