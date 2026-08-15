-- 가상 D-패드 (터치 조작) — 범용 UI 모듈
--
-- 키보드가 없는 플랫폼(Android 등)에서 방향 입력을 화면 위 패드로 받는다.
-- 엔진의 마우스 API(Input.GetMouseX/Y, IsMousePress)를 그대로 쓴다: SDL이 첫 손가락
-- 터치를 마우스로 매핑하므로 단일 터치 D-패드는 별도 터치 API 없이 동작한다.
-- (동시 다중 터치가 필요해지면 그때 Input에 터치 API를 더한다)
--
-- 사용:
--   local VirtualPad = require("scripts/ui/vpad")
--   if VirtualPad.shouldShow() then pad = VirtualPad.new{ x = 24, y = H - 184, size = 160 } end
--   pad.update()                       -- 매 프레임, Input 갱신 뒤
--   if pad.isPressed("left") then ... end
--   pad.contains(mx, my)               -- 패드 위 터치인지 (게임 쪽 탭 처리에서 제외할 때)
--   pad.draw()                         -- HUD 위에 마지막으로 그린다
--   pad.dispose()
--
-- 스프라이트 시트 resources/ui/dpad.png: 가로 5프레임 (기본, 위, 오른쪽, 아래, 왼쪽)

local Image = require("scripts/image")

local VirtualPad = {}

local FRAME_OF = { up = 1, right = 2, down = 3, left = 4 }

-- 표시 여부: 터치 플랫폼이거나 INITIAL2D_VPAD=1 (데스크톱에서 확인용)
function VirtualPad.shouldShow()
	if os.getenv ~= nil and os.getenv("INITIAL2D_VPAD") ~= nil then
		return true
	end
	if GetPlatform == nil then
		return false
	end
	local p = GetPlatform()
	return p == "android" or p == "ios"
end

-- 순수 함수: 패드 중심 기준 상대 좌표(dx, dy)를 방향으로 바꾼다.
-- radius 밖이나 deadzone 안이면 nil. 45도 대각선을 경계로 4방향.
function VirtualPad.direction(dx, dy, radius, deadzone)
	local d2 = dx * dx + dy * dy
	if d2 > radius * radius or d2 < deadzone * deadzone then
		return nil
	end
	if math.abs(dx) > math.abs(dy) then
		return dx > 0 and "right" or "left"
	else
		return dy > 0 and "down" or "up"
	end
end

function VirtualPad.new(opts)
	opts = opts or {}
	local self = {}
	local size = opts.size or 160
	self.x = opts.x or 24
	self.y = opts.y or (WindowHeight() - size - 24)
	self.size = size

	local radius = size * 0.48
	local deadzone = size * 0.10
	local current = nil
	local img = Image("./resources/ui/dpad.png", self.x, self.y, size, size, 5, "UIDpad")
	img.setSheetGrid(5, 1)
	img.setLoop(false)
	img.setFrames(0, 0)
	img.setCurrentFrame(0)
	img.setOpacity(opts.opacity or 220)

	local function center()
		return self.x + size / 2, self.y + size / 2
	end

	function self.contains(px, py)
		local cx, cy = center()
		local dx, dy = px - cx, py - cy
		return dx * dx + dy * dy <= radius * radius
	end

	function self.hitTest(px, py)
		local cx, cy = center()
		return VirtualPad.direction(px - cx, py - cy, radius, deadzone)
	end

	function self.update()
		if Input.IsMousePress(0) then
			current = self.hitTest(Input.GetMouseX(), Input.GetMouseY())
		else
			current = nil
		end
		img.setCurrentFrame(current and FRAME_OF[current] or 0)
		img.update(0)
	end

	function self.isPressed(dir)
		return current == dir
	end

	function self.pressed()
		return current
	end

	function self.setPosition(x, y)
		self.x, self.y = x, y
		img.setPosition(x, y)
	end

	function self.draw()
		img.draw()
	end

	function self.dispose()
		img.dispose()
	end

	return self
end

return VirtualPad
