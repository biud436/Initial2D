-- 미니 게임 목록 씬 — 첫 스테이지
--
-- 버튼을 터치/클릭하면 해당 미니 게임으로 전환한다 (SwitchScene 전역은 main.lua 제공).
-- 버튼은 resources/ui/button.png 패널 + 흰색 비트맵 폰트 라벨로 구성되며,
-- 누르는 동안 살짝 가라앉고 어두워지는 피드백을 준다.

local Image = require("scripts/image")

MenuScene = {}

local W, H = 768, 896
local t = 0
local bg, icon
local buttons = {}

local BTN_W, BTN_H = 440, 96
local PRESS_SINK = 5 -- 눌림 피드백: 아래로 가라앉는 픽셀 수

-- labelHalf: 라벨 중앙 정렬용 절반 폭 (비트맵 폰트는 폭 측정 API가 없어 수동 지정)
local function makeButton(label, scene, cy, labelHalf)
	local x = W / 2 - BTN_W / 2
	local y = cy - BTN_H / 2
	return {
		label = label,
		scene = scene,
		x = x,
		y = y,
		labelHalf = labelHalf,
		held = false,
		img = Image("./resources/ui/button.png", x, y, BTN_W, BTN_H, 1, "UIButton"),
	}
end

function MenuScene.init()
	W = WindowWidth()
	H = WindowHeight()
	t = 0

	bg = Image("./resources/background_768x896.png", 0, 0, W, H, 1, "Background")

	-- 장식용 새 (플래피 버드 아이콘 겸)
	icon = Image("./resources/bird_276x64.png", 0, 0, 92, 64, 3, "Player")
	icon.setLoop(true)
	icon.setFrames(0, 3)
	icon.setFrameDelay(140.0)
	icon.setAnimComplete(false)

	-- 미니 게임 목록 (여기에 버튼을 추가하면 메뉴에 나타난다)
	buttons = {
		makeButton("플래피 버드", "flappy", H / 2 - 10, 90),
	}
end

function MenuScene.update(elapsed)
	t = t + elapsed / 1000.0

	icon.setPosition(W / 2 - 46, H / 2 - 220 + math.sin(t * 3.0) * 10.0)
	icon.update(elapsed)
	bg.update(0)

	local mx, my = Input.GetMouseX(), Input.GetMouseY()

	for _, b in ipairs(buttons) do
		local inside = mx > b.x and mx < b.x + BTN_W and my > b.y and my < b.y + BTN_H

		b.held = inside and Input.IsMousePress(0)
		b.img.setPosition(b.x, b.y + (b.held and PRESS_SINK or 0))
		b.img.setOpacity(b.held and 210 or 255)
		b.img.update(0)

		if inside and Input.IsMouseDown(0) then
			Audio.PlaySound("./resources/audio/point.wav", "uiSelect", 1)
			SwitchScene(b.scene)
		end
	end

	if AUTOPLAY and t > 1.0 then
		SwitchScene("flappy") -- 자동 시연: 첫 게임으로 진입
	end
end

function MenuScene.render()
	bg.draw()
	icon.draw()

	for _, b in ipairs(buttons) do
		b.img.draw()
	end

	if FontReady then
		DrawText(W / 2 - 80, H / 2 - 320, "미니 게임")

		for _, b in ipairs(buttons) do
			local sink = b.held and PRESS_SINK or 0
			DrawText(W / 2 - b.labelHalf, b.y + BTN_H / 2 - 20 + sink, b.label)
		end

		DrawText(W / 2 - 190, H - 160, "새로운 미니 게임이 추가될 예정!")
	end
end

function MenuScene.destroy()
	bg.dispose()
	icon.dispose()
	for _, b in ipairs(buttons) do
		b.img.dispose()
	end
end

return MenuScene
