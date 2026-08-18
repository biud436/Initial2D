-- rpg_message_test.lua : 대화창(scripts/rpg/message.lua) 검증.
--
-- 타자 효과, 쪽 나눔, 얼굴, 그리고 실행기(interpreter.lua)와의 연결을 본다.
-- 폭 측정은 가짜(한 글자 10픽셀)라 줄바꿈 위치가 글자 수로 계산된다.

local M = {}

local CHAR_W = 10

local function fakeImageFactory(log)
	return function(path, x, y, w, h, frames, id)
		local img = { path = path, rect = {}, pos = {} }
		function img.setLoop() end
		function img.setScale() end
		function img.setRect(rx, ry, rw, rh) img.rect = { rx, ry, rw, rh } end
		function img.setPosition(px, py) img.pos = { px, py } end
		function img.setOpacity() end
		function img.update() end
		function img.draw()
			if log ~= nil then
				log[#log + 1] = { path = path, sx = img.rect[1], sy = img.rect[2],
					x = img.pos[1], y = img.pos[2] }
			end
		end
		function img.dispose() end
		return img
	end
end

local function fakeMeasure(text)
	local Text = require("scripts/rpg/text")
	return Text.length(text) * CHAR_W
end

--- 창 폭 200 = 글자 18개 (여백 16을 빼면 184 → 18글자), 한 쪽에 두 줄인 대화창
local function newDialogue(opts)
	local Window = require("scripts/rpg/window")
	local Dialogue = require("scripts/rpg/message")
	opts = opts or {}
	local drawLog = opts.drawLog or {}
	local skin = Window.newSkin{ path = "skin.png", scale = 1,
		imageFactory = fakeImageFactory(drawLog) }
	local drawn = {}
	local dlg = Dialogue.new{
		skin = skin, measure = fakeMeasure,
		drawText = function(x, y, text) drawn[#drawn + 1] = { x = x, y = y, text = text } end,
		imageFactory = fakeImageFactory(drawLog),
		x = 0, y = 100, width = opts.width or 200, height = opts.height or 56,
		lines = opts.lines or 2, lineHeight = 20,
		speed = opts.speed or 2, textSeInterval = opts.textSeInterval or 0,
		se = opts.se, openFrames = 0,
	}
	return dlg, drawn
end

-- 창이 다 열릴 때까지 + n 프레임 굴린다
local function pump(dlg, n, input)
	for _ = 1, n do dlg:update(input, true) end
end

function M.run(t)
	local Text = require("scripts/rpg/text")

	-- ---- [1] 쪽 나눔: 폭에 맞춰 줄로, 줄 수에 맞춰 쪽으로 ------------------
	local dlg = newDialogue()
	local pages = dlg:paginate("가나다라마바사아자차카타파하거너더러머버서어저처", 100)
	t.check_eq(#pages[1], 2, "한 쪽은 두 줄 (lines = 2)")
	t.check_eq(Text.length(pages[1][1]), 10, "한 줄은 폭 100 / 글자폭 10 = 10글자")
	t.check(#pages >= 2, "넘치는 줄은 다음 쪽으로", "#pages=" .. #pages)

	-- ---- [2] 타자 효과: 프레임마다 speed 글자씩 -----------------------------
	dlg:showMessage("가나다라마")
	t.check(dlg:isBusy(), "대사를 띄우면 실행기는 기다린다")
	t.check_eq(dlg.revealed, 0, "처음에는 한 글자도 안 나왔다")

	dlg:update({}, true)
	t.check_eq(dlg.revealed, 2, "프레임당 2글자")
	t.check_eq(dlg:visibleLines()[1], "가나", "보이는 글자는 앞에서부터")
	dlg:update({}, true)
	t.check_eq(dlg:visibleLines()[1], "가나다라", "계속 이어진다")
	dlg:update({}, true)
	t.check(dlg:isRevealed(), "다 나오면 멈춘다")
	t.check_eq(dlg.revealed, 5, "글자 수를 넘어가지 않는다")

	-- ---- [3] 결정키: 먼저 전부 표시, 그다음 닫기 ---------------------------
	dlg:showMessage("가나다라마바사")
	dlg:update({ confirm = true }, true)
	t.check(dlg:isRevealed(), "출력 중 결정키는 남은 글자를 즉시 보여 준다")
	t.check(dlg:isBusy(), "그 누름으로 창이 닫히지는 않는다")
	dlg:update({ confirm = true }, true)
	t.check(not dlg:isBusy(), "다 나온 뒤의 결정키가 대사를 끝낸다")

	-- ---- [4] 여러 쪽: 결정키로 넘긴다 --------------------------------------
	local long = string.rep("가", 60)     -- 18글자 x 2줄 = 한 쪽에 36글자
	dlg:showMessage(long)
	t.check(#dlg.pages >= 2, "긴 대사는 여러 쪽", "#pages=" .. #dlg.pages)
	dlg:update({ confirm = true }, true)      -- 전부 표시
	dlg:update({ confirm = true }, true)      -- 다음 쪽
	t.check_eq(dlg.page, 2, "결정키로 다음 쪽")
	t.check_eq(dlg.revealed, 0, "새 쪽은 다시 처음부터 출력한다")
	t.check(dlg:isBusy(), "쪽이 남아 있으면 계속 기다린다")
	dlg:update({ confirm = true }, true)
	dlg:update({ confirm = true }, true)
	t.check(not dlg:isBusy(), "마지막 쪽에서 결정키를 누르면 끝난다")

	-- ---- [5] 얼굴: 글자 영역이 그만큼 밀린다 -------------------------------
	local tx0 = dlg:textRect()
	dlg:showMessage("얼굴 있는 대사", { face = { file = "faces.png", index = 3 } })
	local tx1, _, tw1 = dlg:textRect()
	t.check_eq(tx1 - tx0, 48 + 8, "얼굴(48) + 여백만큼 글자가 오른쪽으로")
	t.check(tw1 < 200 - 16, "글자 영역 폭도 그만큼 줄어든다")

	-- 얼굴 그림은 시트에서 3번 칸(48x48)을 잘라 쓴다
	local faceLog = {}
	local faced = newDialogue{ drawLog = faceLog }
	faced:showMessage("얼굴", { face = { file = "faces.png", index = 3 } })
	faced:update({}, true)
	faced:draw()
	local face = nil
	for _, entry in ipairs(faceLog) do
		if entry.path == "faces.png" then face = entry end
	end
	t.check(face ~= nil, "얼굴 그림을 그렸다")
	if face ~= nil then
		t.check(face.sx == 144 and face.sy == 0, "3번 얼굴은 시트 (144,0)",
			tostring(face.sx) .. "," .. tostring(face.sy))
	end

	-- ---- [6] 이름 창 --------------------------------------------------------
	local named = newDialogue()
	named:showMessage("안녕하신가", { name = "촌장" })
	t.check(named.nameWindow ~= nil, "이름을 주면 작은 창이 생긴다")
	t.check_eq(named.nameWindow.width, 2 * CHAR_W + 16, "이름 창 폭은 이름 길이에서")
	t.check(named.nameWindow.y < named.window.y, "이름 창은 대화창 위에 붙는다")
	named:showMessage("이번엔 이름 없이")
	t.check(named.nameWindow == nil, "이름이 없으면 이름 창도 없다")

	-- ---- [7] 선택지 연동 ----------------------------------------------------
	local dlg2 = newDialogue()
	dlg2:showMessage("고르시오")
	dlg2:update({ confirm = true }, true)
	dlg2:update({ confirm = true }, true)
	t.check(not dlg2:isBusy(), "대사가 끝났다")
	dlg2:showChoice({ "네", "아니요" })
	t.check(dlg2:isBusy(), "선택 중에도 실행기는 기다린다")
	dlg2:update({ down = true }, true)
	dlg2:update({ confirm = true }, true)
	t.check(not dlg2:isBusy(), "고르면 끝난다")
	t.check_eq(dlg2:result(), 2, "고른 번호를 돌려준다")

	-- ---- [8] 창 닫기: 스크립트가 끝나야 닫힌다 ------------------------------
	local closing = newDialogue()
	closing.window.openFrames = 4
	closing:showMessage("가")
	pump(closing, 6)
	t.check(closing.window:isOpen(), "대사 중에는 열려 있다")
	closing:update({ confirm = true }, true)
	t.check(not closing:isBusy(), "대사는 끝났다")
	closing:update({}, true)
	t.check(closing.window.target == 1, "스크립트가 도는 동안에는 열어 둔다 (다음 대사)")
	for _ = 1, 6 do closing:update({}, false) end
	t.check(closing.window:isClosed(), "스크립트까지 끝나면 창이 닫힌다")
	t.check_eq(closing.page, 0, "닫힌 뒤에는 지난 대사를 버린다")

	-- ---- [8.5] 다음을 기다릴 때 스킨의 화살표가 깜빡인다 --------------------
	local Specs = require("scripts/rpg/specs")
	local arrowLog = {}
	local waiting = newDialogue{ drawLog = arrowLog, speed = 0 }
	waiting:showMessage("가나다")
	waiting:update({}, true)
	waiting:draw()
	local function drewArrow(log)
		for _, entry in ipairs(log) do
			if entry.sx == Specs.window.arrowDown.x and entry.sy == Specs.window.arrowDown.y then
				return true
			end
		end
		return false
	end
	t.check(drewArrow(arrowLog), "다 나온 뒤에는 대기 화살표를 그린다")

	-- 깜빡임의 꺼진 구간에서는 그리지 않는다
	local Message = require("scripts/rpg/message")
	for _ = 1, Message.ARROW_BLINK_FRAMES do waiting:update({}, true) end
	local offLog = {}
	waiting.skin.cache = {}                       -- 새 기록으로 갈아 끼운다
	waiting.skin.imageFactory = fakeImageFactory(offLog)
	waiting:draw()
	t.check(not drewArrow(offLog), "깜빡임의 꺼진 구간에서는 화살표를 그리지 않는다")

	-- ---- [9] 효과음 --------------------------------------------------------
	local beeps = { text = 0, decision = 0 }
	local noisy = newDialogue{
		textSeInterval = 2,
		se = {
			text = function() beeps.text = beeps.text + 1 end,
			decision = function() beeps.decision = beeps.decision + 1 end,
		},
	}
	noisy:showMessage("가나다라")
	noisy:update({}, true)
	noisy:update({}, true)
	t.check_eq(beeps.text, 2, "두 글자마다 글자 출력음")
	noisy:update({ confirm = true }, true)
	t.check_eq(beeps.decision, 1, "결정음은 대사를 넘길 때")

	-- ---- [10] 실행기와 실제로 연결한다 --------------------------------------
	local Interpreter = require("scripts/rpg/interpreter")
	local dlg3 = newDialogue{ speed = 0 }     -- speed 0 = 즉시 전부 표시
	local interp = Interpreter.new{ messagePort = dlg3:port() }
	local picked = nil
	interp:start{
		id = "npc", trigger = "action",
		script = function(self, ctx)
			ctx.message("어서 오시게.", { name = "촌장", face = { file = "f.png", index = 1 } })
			picked = ctx.choice({ "네", "아니요" })
			ctx.message("그렇군.")
		end,
	}

	t.check(interp:isBusy(), "스크립트가 돌기 시작했다")
	t.check_eq(dlg3.name, "촌장", "ctx.message의 opts가 대화창까지 전달된다")
	t.check(dlg3.face ~= nil and dlg3.face.file == "f.png", "얼굴 지정도 전달된다")

	dlg3:update({}, interp:isBusy())
	dlg3:update({ confirm = true }, interp:isBusy())   -- 첫 대사 넘기기
	interp:update()
	t.check(dlg3.choice:isActive(), "대사를 넘기면 선택지가 뜬다")

	dlg3:update({ down = true }, interp:isBusy())
	dlg3:update({ confirm = true }, interp:isBusy())
	interp:update()
	t.check_eq(picked, 2, "고른 번호가 스크립트로 돌아간다")
	t.check_eq(dlg3:visibleLines()[1], "그렇군.", "다음 대사가 이어진다")

	dlg3:update({ confirm = true }, interp:isBusy())
	interp:update()
	t.check(not interp:isBusy(), "마지막 대사를 넘기면 스크립트가 끝난다")
end

return M
