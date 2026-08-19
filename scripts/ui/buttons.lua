-- 화면 위 동작 버튼 (터치 조작) — 범용 UI 모듈 (9단계)
--
-- 가상 D-패드(vpad.lua)가 방향을 맡고, 이쪽이 결정과 취소를 맡는다. 8단계까지는
-- "패드 밖 아무 데나 탭 = 결정"이었는데, 걸으려다 대화가 넘어가고 대화를 넘기려다
-- 걷는 일이 잦았다 (기획서 docs/design/port-town.md 6.3절).
--
-- 엔진의 마우스 API를 그대로 쓴다 (SDL이 첫 손가락을 마우스로 매핑한다). 단일
-- 터치라 한 번에 버튼 하나만 눌린다 — 방향과 결정을 동시에 누를 수는 없다.
--
-- 사용:
--   local Buttons = require("scripts/ui/buttons")
--   local pad = Buttons.new{
--       drawText = DrawText, measure = GetTextWidth,
--       items = {
--           { id = "confirm", label = "결정", x = 300, y = 380, size = 56 },
--           { id = "cancel",  label = "취소", x = 240, y = 396, size = 44 },
--       },
--   }
--   pad.update()                 -- 매 프레임, Input 갱신 뒤
--   if pad.pressed("confirm") then ... end   -- 이번 프레임에 눌렸는가 (엣지)
--   pad.contains(mx, my)         -- 버튼 위 터치인가 (다른 탭 처리에서 제외할 때)
--   pad.draw()
--   pad.dispose()

local Image = require("scripts/image")

local M = {}

local SHEET = "./resources/ui/actionbtn.png"
local FRAME_SIZE = 96          -- tools/generate_ui_assets.py의 make_action_button과 같은 값
local LABEL_LINE = 16          -- 라벨 세로 중앙 보정 (16px 폰트 기준)

--- 점이 원 안에 있는가 (순수 함수 — 단위 테스트가 그대로 부른다)
function M.hit(item, x, y)
	local r = item.size / 2
	local cx, cy = item.x + r, item.y + r
	local dx, dy = x - cx, y - cy
	return dx * dx + dy * dy <= r * r
end

--- @param opts.items    { { id, label, x, y, size }, ... }
-- @param opts.drawText  function(x, y, text) (기본 전역 DrawText)
-- @param opts.measure   function(text) -> 폭 (기본 전역 GetTextWidth)
-- @param opts.input     엔진 Input과 같은 표면 (기본 전역 Input)
-- @param opts.imageFactory  Image 생성자 (테스트가 가짜를 넣는다)
function M.new(opts)
	opts = opts or {}
	assert(type(opts.items) == "table" and #opts.items > 0, "buttons: items가 필요하다")

	local self = {}
	local input = opts.input or _G.Input
	local drawText = opts.drawText or _G.DrawText
	local measure = opts.measure or _G.GetTextWidth
	local factory = opts.imageFactory or Image

	local items = {}
	for i, def in ipairs(opts.items) do
		local size = def.size or 56
		local img = factory(SHEET, def.x, def.y, FRAME_SIZE, FRAME_SIZE, 2,
			"UIButton:" .. tostring(def.id or i))
		img.setLoop(false)
		img.setScale(size / FRAME_SIZE)
		img.setPosition(def.x, def.y)
		items[#items + 1] = {
			id = def.id or ("btn" .. i), label = def.label,
			x = def.x, y = def.y, size = size, img = img,
			held = false, edge = false,
		}
	end

	--- 매 프레임. 눌림 상태와 이번 프레임의 엣지를 갱신한다.
	function self.update()
		local mx, my = input.GetMouseX(), input.GetMouseY()
		local down = input.IsMouseDown(0)      -- 이번 프레임에 눌리기 시작
		local press = input.IsMousePress(0)    -- 계속 눌려 있음

		for _, item in ipairs(items) do
			local inside = M.hit(item, mx, my)
			item.edge = inside and down or false
			item.held = inside and (down or press) or false
			item.img.setFrames(item.held and 1 or 0, item.held and 1 or 0)
			item.img.setPosition(item.x, item.y)
			item.img.update(0)
		end
	end

	--- 이번 프레임에 눌렸는가 (엣지). 대화창과 선택지가 보는 값이다.
	function self.pressed(id)
		for _, item in ipairs(items) do
			if item.id == id then return item.edge end
		end
		return false
	end

	--- 어느 버튼이든 누르고 있는가 (다른 탭 처리에서 제외할 때)
	function self.contains(x, y)
		for _, item in ipairs(items) do
			if M.hit(item, x, y) then return true end
		end
		return false
	end

	function self.draw()
		for _, item in ipairs(items) do
			item.img.draw()
			if item.label ~= nil and drawText ~= nil and measure ~= nil then
				local w = measure(item.label)
				drawText(item.x + (item.size - w) / 2,
					item.y + (item.size - LABEL_LINE) / 2 - 2, item.label)
			end
		end
	end

	function self.dispose()
		for _, item in ipairs(items) do
			item.img.dispose()
		end
		items = {}
	end

	self.items = items
	return self
end

return M
