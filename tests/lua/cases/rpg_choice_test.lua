-- rpg_choice_test.lua : 선택지 창(scripts/rpg/choice.lua) 검증.
--
-- 창 크기가 글자 폭에서 나오므로 폭 측정 함수를 가짜로 주입해 값을 통제한다
-- (한 글자 = 10픽셀). 그리기는 가짜 Image로 기록만 남긴다.

local M = {}

local CHAR_W = 10

local function fakeImageFactory()
	return function(path, x, y, w, h, frames, id)
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

-- 한 글자 10픽셀 (UTF-8 글자 수로 센다 — 한글은 3바이트다)
local function fakeMeasure(text)
	local Text = require("scripts/rpg/text")
	return Text.length(text) * CHAR_W
end

local function newChoice(opts)
	local Window = require("scripts/rpg/window")
	local Choice = require("scripts/rpg/choice")
	opts = opts or {}
	local skin = Window.newSkin{ path = "fake.png", scale = 1,
		imageFactory = fakeImageFactory() }
	local drawn = {}
	local choice = Choice.new{
		skin = skin, measure = fakeMeasure,
		drawText = function(x, y, text) drawn[#drawn + 1] = { x = x, y = y, text = text } end,
		lineHeight = opts.lineHeight or 20,
		maxVisible = opts.maxVisible,
		openFrames = 0,
	}
	return choice, drawn
end

function M.run(t)
	-- ---- [1] 창 크기는 가장 긴 항목에서 나온다 -----------------------------
	local choice = newChoice()
	choice:show({ "네", "아니요, 처음입니다" }, { x = 100, y = 50 })
	t.check(choice:isActive(), "항목을 열면 선택 중")
	t.check_eq(choice.window.width, 10 * CHAR_W + 16 + choice.inkMargin,
		"폭 = 가장 긴 항목(10글자) + 여백")
	t.check_eq(choice.window.height, 2 * 20 + 16, "높이 = 항목 수 x 줄 높이 + 여백")
	t.check_eq(choice.index, 1, "커서는 첫 항목에서 시작")
	t.check_eq(choice:result(), nil, "고르기 전에는 결과가 없다")

	-- ---- [2] 위아래 이동은 양끝에서 돈다 ------------------------------------
	choice:update{ down = true }
	t.check_eq(choice.index, 2, "아래로 이동")
	choice:update{ down = true }
	t.check_eq(choice.index, 1, "마지막에서 아래로 가면 처음으로")
	choice:update{ up = true }
	t.check_eq(choice.index, 2, "처음에서 위로 가면 마지막으로")

	-- ---- [3] 결정 -----------------------------------------------------------
	choice:update{ confirm = true }
	t.check(not choice:isActive(), "결정키를 누르면 선택이 끝난다")
	t.check_eq(choice:result(), 2, "고른 항목 번호를 돌려준다")

	-- ---- [4] 취소: cancelIndex가 있을 때만 -----------------------------------
	choice:show({ "산다", "안 산다" }, { x = 0, y = 0 })
	choice:update{ cancel = true }
	t.check(choice:isActive(), "cancelIndex가 없으면 취소키를 무시한다")

	choice:show({ "산다", "안 산다" }, { x = 0, y = 0, cancelIndex = 2 })
	choice:update{ cancel = true }
	t.check(not choice:isActive(), "cancelIndex가 있으면 취소로 빠져나간다")
	t.check_eq(choice:result(), 2, "취소는 지정한 번호를 돌려준다")

	-- ---- [5] 메시지 창 기준 배치 (오른쪽 위에 붙는다) -----------------------
	choice:show({ "예", "아니오" }, { anchor = { x = 8, y = 300, w = 360 } })
	local w, h = choice.window.width, choice.window.height
	t.check_eq(choice.window.x, 8 + 360 - w, "선택지 창은 메시지 창 오른쪽 끝에 맞춘다")
	t.check_eq(choice.window.y, 300 - h, "메시지 창 바로 위에 놓인다")

	-- ---- [6] 항목이 많으면 스크롤한다 ---------------------------------------
	local many = newChoice{ maxVisible = 3 }
	many:show({ "하나", "둘", "셋", "넷", "다섯" }, { x = 0, y = 0 })
	t.check_eq(many.window.height, 3 * 20 + 16, "보이는 항목 수만큼만 창이 커진다")
	local first, last = many:visibleRange()
	t.check(first == 1 and last == 3, "처음에는 1~3번이 보인다", first .. ".." .. last)

	many:update{ down = true }
	many:update{ down = true }
	first, last = many:visibleRange()
	t.check(first == 1 and last == 3 and many.index == 3, "3번까지는 스크롤하지 않는다")
	many:update{ down = true }
	first, last = many:visibleRange()
	t.check(first == 2 and last == 4 and many.index == 4, "4번으로 가면 한 칸 스크롤",
		first .. ".." .. last)
	many:update{ down = true }
	many:update{ down = true }   -- 5 → 1 로 되돌아온다
	first, last = many:visibleRange()
	t.check(many.index == 1 and first == 1, "처음으로 돌아오면 스크롤도 되돌아온다",
		first .. ".." .. last)

	-- ---- [7] 그리기: 보이는 항목만 그린다 ------------------------------------
	local drawable, drawn = newChoice{ maxVisible = 2 }
	drawable:show({ "가", "나", "다" }, { x = 10, y = 10 })
	drawable:update(nil)
	drawable:draw()
	t.check_eq(#drawn, 2, "보이는 두 항목만 글자를 그린다")
	t.check_eq(drawn[1].text, "가", "첫 항목")
	t.check(drawn[2].y - drawn[1].y == 20, "항목 간격은 줄 높이")

	-- ---- [8] 효과음은 있을 때만 부른다 --------------------------------------
	local Window = require("scripts/rpg/window")
	local Choice = require("scripts/rpg/choice")
	local beeps = { cursor = 0, decision = 0 }
	local se = {
		cursor = function() beeps.cursor = beeps.cursor + 1 end,
		decision = function() beeps.decision = beeps.decision + 1 end,
	}
	local noisy = Choice.new{
		skin = Window.newSkin{ path = "fake.png", imageFactory = fakeImageFactory() },
		measure = fakeMeasure, drawText = function() end, se = se, openFrames = 0,
	}
	noisy:show({ "가", "나" }, { x = 0, y = 0 })
	noisy:update{ down = true }
	noisy:update{ confirm = true }
	t.check_eq(beeps.cursor, 1, "커서 이동 효과음")
	t.check_eq(beeps.decision, 1, "결정 효과음")
end

return M
