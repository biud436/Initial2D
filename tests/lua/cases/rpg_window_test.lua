-- rpg_window_test.lua : 스킨 창(scripts/rpg/window.lua) 검증.
--
-- 조각 계산은 순수 함수라 그대로 검사하고, 그리기는 가짜 Image 생성자를 넣어
-- "무엇을 어디에 몇 번 찍었는가"를 기록으로 확인한다. 엔진 텍스처가 없어도 돈다.

local M = {}

-- 그리기 기록만 남기는 가짜 스프라이트
local function fakeImageFactory(log)
	return function(path, x, y, w, h, frames, id)
		local img = { path = path, w = w, h = h, id = id, scale = 1,
			rect = { 0, 0, 0, 0 }, pos = { 0, 0 }, opacity = 255 }
		function img.setLoop() end
		function img.setScale(n) img.scale = n end
		function img.setRect(rx, ry, rw, rh) img.rect = { rx, ry, rw, rh } end
		function img.setPosition(px, py) img.pos = { px, py } end
		function img.setOpacity(n) img.opacity = n end
		function img.update() end
		function img.draw()
			log[#log + 1] = { w = img.w, h = img.h, sx = img.rect[1], sy = img.rect[2],
				x = img.pos[1], y = img.pos[2], scale = img.scale }
		end
		function img.dispose() log.disposed = (log.disposed or 0) + 1 end
		return img
	end
end

-- 조각들이 목표 영역을 빈틈없이, 밖으로 넘치지 않게 덮는지 센다
local function coverage(pieces, w, h)
	local grid, outside = {}, 0
	for _, p in ipairs(pieces) do
		for y = p.dy, p.dy + p.sh - 1 do
			for x = p.dx, p.dx + p.sw - 1 do
				if x < 0 or y < 0 or x >= w or y >= h then
					outside = outside + 1
				else
					grid[y * w + x] = (grid[y * w + x] or 0) + 1
				end
			end
		end
	end
	local covered, overlap = 0, 0
	for _, n in pairs(grid) do
		covered = covered + 1
		if n > 1 then overlap = overlap + 1 end
	end
	return covered, outside, overlap
end

function M.run(t)
	local Window = require("scripts/rpg/window")
	local Specs = require("scripts/rpg/specs")
	local spec = Specs.window

	-- ---- [1] 반복 채우기: 자투리까지 정확히 --------------------------------
	local pieces = Window.tileFill({}, 0, 0, 70, 20, 0, 0, 32, 32)
	local covered, outside, overlap = coverage(pieces, 70, 20)
	t.check_eq(covered, 70 * 20, "반복 채우기가 영역을 빈틈없이 덮는다")
	t.check_eq(outside, 0, "영역 밖으로 넘치지 않는다 (자투리는 소스를 자른다)")
	t.check_eq(overlap, 0, "겹쳐 그리지 않는다")
	t.check_eq(#pieces, 3, "70x20은 32+32+6 세 조각")
	t.check(pieces[3].sw == 6 and pieces[3].sh == 20, "마지막 조각은 잘린 크기",
		pieces[3].sw .. "x" .. pieces[3].sh)

	t.check_eq(#Window.tileFill({}, 0, 0, 0, 10, 0, 0, 8, 8), 0, "빈 영역은 조각 없음")

	-- ---- [2] 나인 슬라이스 --------------------------------------------------
	local frame = Window.ninePatch({}, spec.frame, spec.frameCorner, 100, 40, false)
	covered, outside, overlap = coverage(frame, 100, 40)
	t.check_eq(outside, 0, "테두리가 창 밖으로 나가지 않는다")
	t.check_eq(overlap, 0, "테두리 조각끼리 겹치지 않는다")
	-- 테두리만 그리므로 가운데(8..92, 8..32)는 비어 있어야 한다
	t.check_eq(covered, 100 * 40 - (100 - 16) * (40 - 16), "가운데는 비운다 (테두리만)")

	local corner = frame[1]
	t.check(corner.dx == 0 and corner.dy == 0 and corner.sw == 8 and corner.sh == 8,
		"첫 조각은 좌상단 모서리 8x8")
	t.check(corner.sx == spec.frame.x and corner.sy == spec.frame.y,
		"모서리는 테두리 블록의 좌상단에서 잘라 온다")

	local filled = Window.ninePatch({}, spec.cursor, spec.cursorCorner, 64, 24, true)
	covered = coverage(filled, 64, 24)
	t.check_eq(covered, 64 * 24, "가운데까지 채우면 사각형 전체를 덮는다 (커서)")

	t.check_eq(#Window.ninePatch({}, spec.frame, 8, 12, 40, false), 0,
		"모서리가 겹칠 만큼 좁으면 그리지 않는다")

	-- ---- [3] 창 전체: 바탕 + 테두리 -----------------------------------------
	local all = Window.slices(64, 48, spec)
	covered, outside = coverage(all, 64, 48)
	t.check_eq(covered, 64 * 48, "바탕이 창 전체를 덮는다")
	t.check_eq(outside, 0, "창 밖으로 넘치지 않는다")

	-- 바탕 띠: 원본의 위쪽부터 순서대로 쓴다 (그라데이션 방향 유지)
	local bands = {}
	for _, p in ipairs(Window.backgroundFill({}, 64, 48, spec)) do
		bands[p.sy] = true
	end
	local count = 0
	for _ in pairs(bands) do count = count + 1 end
	t.check_eq(count, Window.BG_BANDS, "바탕은 원본을 세로 4등분해 쓴다")

	-- ---- [4] 커서 조각: 깜빡임은 다른 그림에서 잘라 온다 --------------------
	local c1 = Window.cursorSlices(32, 16, spec, false)
	local c2 = Window.cursorSlices(32, 16, spec, true)
	t.check_eq(c1[1].sx, spec.cursor.x, "기본 커서")
	t.check_eq(c2[1].sx, spec.cursor2.x, "깜빡임용 두 번째 커서")

	-- ---- [5] 창 객체: 열기·닫기 애니메이션 ----------------------------------
	local log = {}
	local skin = Window.newSkin{ path = "fake.png", scale = 1,
		imageFactory = fakeImageFactory(log) }
	local win = Window.new{ skin = skin, x = 10, y = 20, width = 64, height = 48,
		openFrames = 4 }

	t.check(win:isClosed(), "창은 닫힌 채로 시작한다")
	win:draw()
	t.check_eq(#log, 0, "닫힌 창은 아무것도 그리지 않는다")

	win:open()
	win:update()
	local x, y, w, h = win:rect()
	t.check(h == 12 and y == 20 + 18, "열리는 중에는 가운데에서 자란다",
		string.format("y=%d h=%d", y, h))
	t.check(x == 10 and w == 64, "가로는 처음부터 제 크기")
	t.check(not win:isOpen(), "열리는 중에는 내용을 그리지 않는다")

	for _ = 1, 4 do win:update() end
	t.check(win:isOpen(), "4프레임이면 다 열린다")
	local _, oy, _, oh = win:rect()
	t.check(oy == 20 and oh == 48, "다 열리면 원래 크기")

	win:draw()
	t.check(#log > 0, "열린 창은 조각을 그린다")
	local first = log[1]
	t.check(first.x >= 10 and first.y >= 20, "창 위치에서부터 그린다")

	win:close()
	for _ = 1, 4 do win:update() end
	t.check(win:isClosed(), "닫기도 4프레임")

	-- ---- [6] 안쪽 여백과 배율 ------------------------------------------------
	local cx, cy, cw, ch = win:contentRect()
	t.check(cx == 10 + 8 and cy == 20 + 8, "내용 영역은 모서리(8)만큼 안쪽")
	t.check(cw == 64 - 16 and ch == 48 - 16, "내용 크기도 그만큼 줄어든다")

	local log2 = {}
	local skin2 = Window.newSkin{ path = "fake.png", scale = 2,
		imageFactory = fakeImageFactory(log2) }
	local win2 = Window.new{ skin = skin2, x = 0, y = 0, width = 65, height = 48,
		openFrames = 0 }
	t.check_eq(win2.width, 64, "배율 2에서는 창 폭을 배율의 배수로 내린다")
	t.check_eq(win2.padding, 16, "여백도 배율만큼 커진다")
	win2:open()
	win2:update()
	win2:draw()
	t.check(#log2 > 0, "배율 2 창도 그려진다")
	local scaled = log2[1]
	t.check_eq(scaled.scale, 2, "조각은 배율만큼 확대해 찍는다")

	-- 조각 좌표에도 배율이 곱해진다 (32 스킨픽셀 = 64 화면픽셀)
	local far = nil
	for _, entry in ipairs(log2) do
		if far == nil or entry.x > far.x then far = entry end
	end
	t.check(far.x % 2 == 0, "화면 좌표는 배율의 배수", tostring(far.x))

	-- ---- [7] 텍스처 해제는 한 번만 ------------------------------------------
	skin:image(8, 8)
	skin:image(16, 8)
	skin:dispose()
	t.check_eq(log.disposed, 1, "크기별 스프라이트가 여럿이어도 텍스처 해제는 한 번")
end

return M
