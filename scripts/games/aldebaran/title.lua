-- 알데바란 — 타이틀 씬 (docs/plans/aldebaran-3-content.md 2절)
--
-- 배경 그림 한 장과 커서 메뉴 하나. 「떠나기 전에」의 타이틀과 같은 구조로,
-- 대화창 부품(창, 선택지, 메시지)을 그대로 재사용한다.
--
--   방향키 위아래: 항목 이동      Z / Enter / Space: 결정
--   터치: 항목을 직접 누른다      ESC / 뒤로가기: 게임 종료
--
-- 배경은 tools/generate_aldebaran_assets.py 로 다시 만든다 (글자가 구워져 있다).

local Image = require("scripts/image")
local Window = require("scripts/rpg/window")
local Choice = require("scripts/rpg/choice")
local Dialogue = require("scripts/rpg/message")
local Assets = require("scripts/rpg/assets")
local Bgm = require("scripts/bgm")

AldebaranTitleScene = {}

local BACKGROUND = "./resources/titles/aldebaran_title.png"
local BASE_FONT = "./resources/fonts/hangul.fnt"
local SE_CURSOR = "./resources/audio/ui_cursor.wav"
local SE_DECISION = "./resources/audio/ui_decision.wav"
local SE_TEXT = "./resources/audio/ui_text.wav"
local TITLE_BGM_SLOT = "./resources/audio/aldebaran_title.ogg"   -- 없으면 bless로
local TITLE_BGM_FALLBACK = "./resources/audio/bless.ogg"
local TITLE_BGM_VOLUME = 72

local SKIN_SCALE = 3
local LINE_HEIGHT = 48
local MENU_WIDTH = 280
-- 메뉴는 왼쪽 아래. 가운데에 놓으면 숲과 별을 가린다.
local MENU_X = 84
local MENU_Y = 600
local AUTOPLAY_START_FRAME = 60

local VK_ESCAPE, VK_RETURN, VK_SPACE, VK_Z = 27, 13, 32, 90
local VK_UP, VK_DOWN, VK_X = 38, 40, 88

local ITEMS = { "시작", "조작 방법", "나가기" }
local START, HELP, LEAVE = 1, 2, 3

local HELP_TEXT = "왼쪽과 오른쪽 방향키로 걷고, 같은 방향을 빠르게 두 번 누르면 "
	.. "대쉬합니다. Z나 스페이스로 뛰고, 공중에서 한 번 더 누르면 2단 점프입니다. "
	.. "X를 이어 누르면 3단 베기, C는 버서커(MP 10)입니다. ESC나 P로 일시 정지. "
	.. "터치 기기에서는 왼쪽 아래 패드로 걷고, 오른쪽 아래의 점프와 공격과 폭주 "
	.. "버튼, 오른쪽 위의 정지 버튼을 씁니다."

local W, H = 768, 896
local bg, skin, choice, help = nil, nil, nil, nil
local frame = 0
local leaving = nil
local leaveTimer = 0
local LEAVE_DELAY = 12

local function playSe(path, id)
	return function() Audio.PlaySound(path, id, 0) end
end

local function openMenu(index)
	choice:show(ITEMS, { x = MENU_X, y = MENU_Y, index = index })
end

--- 씬 바깥(검증)에서 상태를 들여다보는 창구
function AldebaranTitleScene.status()
	return {
		items = #ITEMS,
		index = choice ~= nil and choice.index or nil,
		menuOpen = choice ~= nil and choice:isActive()
			and choice.window ~= nil and choice.window:isOpen() or false,
		helpOpen = help ~= nil and help:isBusy() or false,
		leaving = leaving,
	}
end

function AldebaranTitleScene.init()
	W, H = WindowWidth(), WindowHeight()
	frame, leaving, leaveTimer = 0, nil, 0

	if FontReady then PreparaFont(BASE_FONT) end

	bg = Image(BACKGROUND, 0, 0, W, H, 1, "AldebaranTitle")
	bg.update(0)

	skin = Window.newSkin{ path = Assets.windowskin(), scale = SKIN_SCALE }

	local se = {
		cursor = playSe(SE_CURSOR, "uiCursor"),
		decision = playSe(SE_DECISION, "uiDecision"),
		text = playSe(SE_TEXT, "uiText"),
	}

	choice = Choice.new{
		skin = skin, measure = GetTextWidth, drawText = DrawText,
		lineHeight = LINE_HEIGHT, maxVisible = #ITEMS, minWidth = MENU_WIDTH,
		se = se,
	}
	help = Dialogue.new{
		skin = skin, measure = GetTextWidth, drawText = DrawText,
		screenW = W, screenH = H, lines = 4, lineHeight = LINE_HEIGHT,
		speed = 3, se = se,
	}

	openMenu(1)
	Bgm.play(Assets.exists(TITLE_BGM_SLOT) and TITLE_BGM_SLOT or TITLE_BGM_FALLBACK,
		{ volume = TITLE_BGM_VOLUME })
end

local function pollInput()
	return {
		confirm = Input.IsKeyDown(VK_Z) or Input.IsKeyDown(VK_RETURN)
			or Input.IsKeyDown(VK_SPACE),
		up = Input.IsKeyDown(VK_UP),
		down = Input.IsKeyDown(VK_DOWN),
		cancel = Input.IsKeyDown(VK_X),
	}
end

--- 터치: 항목을 직접 누르면 커서를 옮기고 그대로 결정한다.
local function pollTouch(input)
	if not Input.IsMouseDown(0) then return input end
	local mx, my = Input.GetMouseX(), Input.GetMouseY()

	if help:isBusy() then
		input.confirm = true
		return input
	end

	local index = choice:indexAt(mx, my)
	if index ~= nil then
		choice.index = index
		input.confirm = true
	end
	return input
end

function AldebaranTitleScene.update(elapsed)
	frame = frame + 1

	if leaving ~= nil then
		leaveTimer = leaveTimer + 1
		choice:update(nil)
		help:update({}, false)
		if leaveTimer >= LEAVE_DELAY then
			if leaving == START then
				-- 새 회차다. 첫 스테이지부터, 들고 온 것 없이 시작한다.
				if AldebaranScene ~= nil then
					AldebaranScene.clearCarry()
					AldebaranScene.setStage("forest")
				end
				SwitchScene("aldebaran")
			else
				GameExit()          -- "나가기"
			end
		end
		return
	end

	local input = pollTouch(pollInput())

	if AUTOPLAY and frame == AUTOPLAY_START_FRAME then
		input.confirm = true
	end

	if help:isBusy() then
		help:update(input, false)
		if not help:isBusy() then
			openMenu(HELP)
		end
		choice:update(nil)
	else
		help:update({}, false)
		choice:update(input)

		if not choice:isActive() then
			local picked = choice:result()
			if picked == HELP then
				help:showMessage(HELP_TEXT)
			else
				leaving, leaveTimer = picked or LEAVE, 0
			end
		end
	end

	-- 타이틀이 최상위 씬이다. ESC(안드로이드 뒤로가기)는 게임을 끝낸다.
	if Input.IsKeyDown(VK_ESCAPE) then
		GameExit()
	end
end

function AldebaranTitleScene.render()
	bg.draw()
	choice:draw()
	help:draw()
end

function AldebaranTitleScene.destroy()
	if bg ~= nil then bg.dispose() end
	if help ~= nil then help:dispose() end
	if choice ~= nil then choice:dispose() end
	if skin ~= nil then skin:dispose() end
	bg, help, choice, skin = nil, nil, nil, nil
end

return AldebaranTitleScene
