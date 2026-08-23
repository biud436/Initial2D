-- rpg_menu_test.lua : 소지품 창(scripts/rpg/menu.lua) 검증 (10단계).
--
-- 선택지 창 테스트와 같은 방식이다 — 폭 측정과 Image를 가짜로 주입해 창의
-- 크기와 그린 글자를 값으로 확인한다 (한 글자 = 10픽셀).

local M = {}

local CHAR_W = 10

local function fakeImageFactory()
	return function()
		local img = {}
		function img.setLoop() end
		function img.setScale() end
		function img.setRect() end
		function img.setPosition() end
		function img.setOpacity() end
		function img.update() end
		function img.draw() end
		function img.dispose() end
		return img
	end
end

local function fakeMeasure(text)
	local Text = require("scripts/rpg/text")
	return Text.length(text) * CHAR_W
end

local function newMenu(opts)
	local Window = require("scripts/rpg/window")
	local Menu = require("scripts/rpg/menu")
	opts = opts or {}
	local skin = Window.newSkin{ path = "fake.png", scale = 1,
		imageFactory = fakeImageFactory() }
	local drawn = {}
	local menu = Menu.new{
		skin = skin, measure = fakeMeasure,
		drawText = function(x, y, text) drawn[#drawn + 1] = { x = x, y = y, text = text } end,
		screenW = 384, screenH = 448,
		lineHeight = opts.lineHeight or 20,
		maxVisible = opts.maxVisible or 6,
		openFrames = 0,
	}
	return menu, drawn
end

--- drawn에 그 글자가 있는가
local function drewText(drawn, text)
	for _, d in ipairs(drawn) do
		if d.text == text then return true end
	end
	return false
end

function M.run(t)
	local Inventory = require("scripts/rpg/inventory")

	local DB = {
		key = { name = "창고 열쇠", desc = "여관 주인이 맡아 둔 열쇠.", order = 10 },
		oil = { name = "등유 한 통", desc = "아직 맑다.", order = 20 },
		coin = { name = "은화", desc = "하루치가 두 닢이다.", order = 30 },
	}

	-- ---- [1] 열고 닫기 ------------------------------------------------------
	local menu, drawn = newMenu()
	t.check(not menu:isOpen(), "만든 직후에는 닫혀 있다")

	local bag = {}
	Inventory.give(bag, "key")
	Inventory.give(bag, "coin", 2)
	menu:open(Inventory.list(bag, DB))
	t.check(menu:isOpen(), "열면 열린다")
	t.check_eq(menu.index, 1, "커서는 첫 항목")
	t.check_eq(menu.listWin.width, 384 - 8 * 2, "목록 창은 화면 폭에서 여백만큼 뺀다")
	t.check_eq(menu.listWin.height, 2 * 20 + 16, "높이는 항목 수에서 나온다")
	t.check(menu.descWin.y == menu.listWin.y + menu.listWin.height,
		"설명 창은 목록 창 바로 아래에 붙는다")

	-- ---- [2] 그린 것: 이름, 개수, 설명 -------------------------------------
	menu:update{}
	menu:draw()
	t.check(drewText(drawn, "창고 열쇠"), "이름을 그린다")
	t.check(drewText(drawn, "은화"), "두 번째 이름도 그린다")
	t.check(drewText(drawn, "x2"), "개수가 둘 이상이면 오른쪽에 적는다")
	t.check(drewText(drawn, "여관 주인이 맡아 둔 열쇠."), "고른 항목의 설명이 아래 칸에")

	-- 개수 1은 적지 않는다
	t.check(not drewText(drawn, "x1"), "한 개짜리에는 개수를 적지 않는다")

	-- ---- [3] 커서 이동과 설명 갱신 ------------------------------------------
	local menu2, drawn2 = newMenu()
	menu2:open(Inventory.list(bag, DB))
	menu2:update{ down = true }
	t.check_eq(menu2.index, 2, "아래로 내려간다")
	menu2:draw()
	t.check(drewText(drawn2, "하루치가 두 닢이다."), "설명이 고른 항목의 것으로 바뀐다")
	menu2:update{ down = true }
	t.check_eq(menu2.index, 1, "끝에서 다시 처음으로 돈다")
	menu2:update{ up = true }
	t.check_eq(menu2.index, 2, "위로도 돈다")

	-- ---- [4] 취소키와 결정키 둘 다 닫는다 ----------------------------------
	menu2:update{ cancel = true }
	t.check(not menu2:isOpen(), "취소키로 닫힌다")

	local menu3 = newMenu()
	menu3:open(Inventory.list(bag, DB))
	menu3:update{ confirm = true }
	t.check(not menu3:isOpen(), "쓸 수 있는 물건이 없으므로 결정키도 닫기다")

	-- ---- [5] 빈 소지품 ------------------------------------------------------
	local empty, emptyDrawn = newMenu()
	empty:open({})
	t.check(empty:isOpen(), "가진 것이 없어도 창은 열린다")
	t.check_eq(empty:selected(), nil, "고를 항목이 없다")
	empty:update{ down = true }
	t.check_eq(empty.index, 1, "빈 목록에서 커서를 움직여도 죽지 않는다")
	empty:draw()
	local Menu = require("scripts/rpg/menu")
	t.check(drewText(emptyDrawn, Menu.EMPTY_TEXT), "가진 것이 없다고 알린다")

	-- ---- [6] 스크롤: 보이는 만큼만 그린다 ----------------------------------
	local many = {}
	for i = 1, 9 do
		many[i] = { id = "i" .. i, name = "물건" .. i, count = 1, desc = "설명" }
	end
	local scroll, scrollDrawn = newMenu{ maxVisible = 4 }
	scroll:open(many)
	local first, last = scroll:visibleRange()
	t.check_eq(first .. "," .. last, "1,4", "처음에는 1~4번이 보인다")
	for _ = 1, 5 do scroll:update{ down = true } end
	first, last = scroll:visibleRange()
	t.check_eq(scroll.index, 6, "커서가 6번으로")
	t.check_eq(first .. "," .. last, "3,6", "커서를 따라 목록이 밀린다")
	scroll:draw()
	t.check(drewText(scrollDrawn, "물건6"), "보이는 항목은 그린다")
	t.check(not drewText(scrollDrawn, "물건1"), "밀려난 항목은 그리지 않는다")
end

return M
