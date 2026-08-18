-- 대화창 렌더링 검증 씬 (7단계) — tests/run_engine_tests.py가 구동한다.
--
-- 단위 테스트가 쪽 나눔과 입력 규칙을 보고, 여기서는 "실제로 스킨이 조립되어
-- 화면에 그려지는가"를 픽셀로 본다. 그리는 위치는 Lua가 계산하므로 좌표를
-- stdout으로 알려 주고, 러너가 그 사각형 안의 픽셀을 검사한다.
--
-- 화면 상태는 프레임과 무관해야 한다 (09-testing.md 4절). 그래서
--   - 창 여닫기 애니메이션 0프레임, 타자 효과 speed 0 (즉시 전부 표시)
--   - Update에서 dialogue:update를 부르지 않는다 — 커서 깜빡임과 대기 화살표가
--     프레임에 따라 달라지면 골든 스크린샷이 흔들린다.
-- 진행형 동작(타자 효과)은 Initialize에서 손으로 몇 프레임 굴려 stdout으로 남긴다.

local Window = require("scripts/rpg/window")
local Dialogue = require("scripts/rpg/message")

local SKIN = "./resources/ui/window.png"
local FACES = "./resources/faces/placeholder.png"

local skin, dialogue = nil, nil
local W, H = 0, 0

-- INITIAL2D_DLG_MODE=arrow 면 선택지 대신 "다음을 기다리는" 상태로 멈춘다
-- (대기 화살표가 그려지는지 픽셀로 보기 위한 두 번째 상태).
local MODE = (os.getenv ~= nil) and os.getenv("INITIAL2D_DLG_MODE") or nil

-- 한 쪽(세 줄)을 넘겨 쪽 나눔까지 보이는 길이
local LONG = "어서 오시게. 처음 보는 얼굴이군. 이 마을은 조용하지만 지낼 만한 곳이라네. "
	.. "오래 머물 생각인가? 그렇다면 촌장인 내가 마을을 안내해 주지. "
	.. "밭 너머 오두막이 내 집이니 언제든 들르시게."

local function rectLine(name, x, y, w, h)
	print(string.format("%s:%d,%d,%d,%d", name, x, y, w, h))
end

function Initialize()
	print("dlgFont:" .. tostring(PreparaFont("./resources/fonts/hangul.fnt")))
	W, H = WindowWidth(), WindowHeight()

	skin = Window.newSkin{ path = SKIN, scale = 2 }
	print("dlgSkin:" .. skin.path .. " scale:" .. skin.scale)

	-- ---- [A] 타자 효과: 프레임마다 speed 글자씩 ---------------------------
	local typing = Dialogue.new{
		skin = skin, measure = GetTextWidth, drawText = DrawText,
		screenW = W, screenH = H, lines = 3, lineHeight = 36,
		speed = 3, textSeInterval = 0, openFrames = 0,
	}
	typing:showMessage(LONG)
	print("dlgPages:" .. #typing.pages)
	print("dlgReveal0:" .. typing.revealed)
	typing:update({}, true)
	print("dlgReveal1:" .. typing.revealed)
	typing:update({}, true)
	print("dlgReveal2:" .. typing.revealed)
	print("dlgVisible:" .. typing:visibleLines()[1])
	typing:update({ confirm = true }, true)
	print("dlgRevealAll:" .. tostring(typing:isRevealed()))
	print("dlgBusy:" .. tostring(typing:isBusy()))
	typing:dispose()

	-- ---- [B] 화면에 남길 상태: 얼굴 + 이름 + 선택지 ------------------------
	dialogue = Dialogue.new{
		skin = skin, measure = GetTextWidth, drawText = DrawText,
		screenW = W, screenH = H, lines = 3, lineHeight = 36,
		speed = 0, textSeInterval = 0, openFrames = 0,
	}
	dialogue:showMessage(LONG, {
		name = "촌장",
		face = { file = FACES, index = 2 },
	})
	if MODE == "arrow" then
		-- 한 쪽을 다 보여 준 채로 멈춘다 (아직 다음 쪽이 남아 있다)
		dialogue:update({}, true)
		local ax, ay, aw, ah = dialogue:pauseArrowRect()
		rectLine("dlgArrowRect", ax, ay, aw, ah)
		print("dlgArrowPage:" .. dialogue.page .. "/" .. #dialogue.pages)
	else
		dialogue:showChoice({ "네, 처음입니다", "아니요" }, { cancelIndex = 2 })
	end

	local win = dialogue.window
	rectLine("dlgMsgRect", win:rect())
	local cx, cy, cw, ch = win:contentRect()
	rectLine("dlgFaceRect", cx, cy, dialogue.faceSize, dialogue.faceSize)
	local tx, ty, tw = dialogue:textRect()
	rectLine("dlgTextRect", tx, ty, tw, ch)
	rectLine("dlgNameRect", dialogue.nameWindow:rect())

	local choice = dialogue.choice
	if MODE == "arrow" then
		print("dlgChoiceActive:false")
		print("dlgLine1:" .. dialogue:visibleLines()[1])
		return
	end
	rectLine("dlgChoiceRect", choice.window:rect())
	local ccx, ccy, ccw = choice.window:contentRect()
	rectLine("dlgChoiceRow1", ccx, ccy, ccw, choice.lineHeight)
	rectLine("dlgChoiceRow2", ccx, ccy + choice.lineHeight, ccw, choice.lineHeight)
	print("dlgChoiceActive:" .. tostring(choice:isActive()))
	print("dlgLine1:" .. dialogue:visibleLines()[1])
end

function Update(elapsed)
	-- 일부러 아무것도 하지 않는다 (위 주석 참고)
end

function Render()
	if dialogue ~= nil then
		dialogue:draw()
	end
end

function Destroy()
	if dialogue ~= nil then
		dialogue:dispose()
		dialogue = nil
	end
	if skin ~= nil then
		skin:dispose()
		skin = nil
	end
end
