-- 미니 게임 목록 씬 — 첫 스테이지
--
-- 항목을 터치/클릭하면 해당 미니 게임으로 전환한다 (SwitchScene 전역은 main.lua 제공).

local Image = require("scripts/image")

MenuScene = {}

local W, H = 768, 896
local t = 0
local bg, icon
local entries = {}

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

	-- 미니 게임 목록 (여기에 항목을 추가하면 메뉴에 나타난다)
	entries = {
		{ label = "플래피 버드", scene = "flappy", y = H / 2 - 40 },
	}
end

local function hitEntry(mx, my, e)
	return mx > W / 2 - 220 and mx < W / 2 + 220 and my > e.y - 30 and my < e.y + 60
end

function MenuScene.update(elapsed)
	t = t + elapsed / 1000.0

	icon.setPosition(W / 2 - 46, H / 2 - 200 + math.sin(t * 3.0) * 10.0)
	icon.update(elapsed)
	bg.update(0)

	if Input.IsMouseDown(0) then
		local mx, my = Input.GetMouseX(), Input.GetMouseY()
		for _, e in ipairs(entries) do
			if hitEntry(mx, my, e) then
				SwitchScene(e.scene)
			end
		end
	end

	if AUTOPLAY and t > 1.0 then
		SwitchScene("flappy") -- 자동 시연: 첫 게임으로 진입
	end
end

function MenuScene.render()
	bg.draw()
	icon.draw()

	if FontReady then
		DrawText(W / 2 - 80, H / 2 - 280, "미니 게임")
		for _, e in ipairs(entries) do
			DrawText(W / 2 - 110, e.y, "[ " .. e.label .. " ]")
		end
		DrawText(W / 2 - 190, H - 160, "새로운 미니 게임이 추가될 예정!")
	end
end

function MenuScene.destroy()
	bg.dispose()
	icon.dispose()
end

return MenuScene
