-- RPG 캐릭터 데모 — 5단계 산출물 (docs/plans/05-rpg-character.md)
--
-- 맵 위를 걸어다니는 캐릭터. 조작은 다음과 같다.
--   방향키 또는 화면 왼쪽 아래 가상 D-패드(터치 플랫폼): 이동
--     - 정지 중에 다른 방향키를 짧게 누르면 이동 없이 방향만 바뀐다 (R2K3식)
--   ESC 또는 Android 뒤로가기: 메뉴로
--
-- NPC 둘이 시드 고정 난수로 배회하며, 캐릭터끼리는 서로를 통과하지 못한다.
-- 캐릭터는 타일맵의 1층과 2층 사이에 그려지므로 울타리나 나무 뒤로 지나간다.
--
-- 환경 변수
--   INITIAL2D_MAP      다른 맵 파일 (에디터가 내보낸 맵 확인용)
--   INITIAL2D_CHARSET  다른 CharSet (예: 정품 보유자의 resources/rtp/CharSet/Actor1.png)

local MapScene = require("scripts/rpg/map_scene")
local Player = require("scripts/rpg/player")
local Rng = require("scripts/rpg/rng")
local VirtualPad = require("scripts/ui/vpad")

RpgDemoScene = {}

local W, H = 768, 896
local scene, sceneError = nil, nil
local player, playerChar = nil, nil
local pad = nil
local fpsAvg = 0
local autoTimer = 0
local autoIndex = 1

local DEFAULT_MAP = "./resources/maps/sample.json"
local DEFAULT_CHARSET = "./resources/charsets/placeholder.png"
local WANDER_SEED = 20260816       -- 시드를 고정해 데모가 매번 같게 움직인다

-- 맵 중앙의 열린 잔디 (resources/maps/sample.json 기준)
local START = { tx = 40, ty = 35 }
local NPCS = {
	{ tx = 38, ty = 34, charIndex = 2, dir = "down" },
	{ tx = 42, ty = 33, charIndex = 5, dir = "left" },
}
local WANDER_AREA = { x = 34, y = 29, w = 14, h = 12 }
local AUTO_ROUTE = { "right", "right", "down", "down", "left", "left", "up", "up" }

local VK_ESCAPE = 27

local function env(name)
	return (os.getenv ~= nil) and os.getenv(name) or nil
end

function RpgDemoScene.init()
	W = WindowWidth()
	H = WindowHeight()
	fpsAvg = 0
	autoTimer = 0
	autoIndex = 1

	scene, sceneError = MapScene.new{
		mapPath = env("INITIAL2D_MAP") or DEFAULT_MAP,
		viewW = W, viewH = H,
		groundLayers = 1,
	}
	if scene == nil then return end

	local charset = env("INITIAL2D_CHARSET") or DEFAULT_CHARSET

	playerChar = scene:addCharacter{
		tx = START.tx, ty = START.ty, dir = "down",
		charset = charset, charIndex = 0, speed = 4, name = "player",
	}
	scene:setCameraTarget(playerChar)

	local rng = Rng.new(WANDER_SEED)
	for _, npc in ipairs(NPCS) do
		local c = scene:addCharacter{
			tx = npc.tx, ty = npc.ty, dir = npc.dir,
			charset = charset, charIndex = npc.charIndex, speed = 3,
		}
		c:setWander{ rng = rng, minWait = 24, maxWait = 90, area = WANDER_AREA }
	end

	if VirtualPad.shouldShow() then
		pad = VirtualPad.new{ x = 24, y = H - 184, size = 160 }
	end

	player = Player.new{ character = playerChar, input = Input, pad = pad }
end

function RpgDemoScene.update(elapsed)
	if elapsed > 0 then
		fpsAvg = fpsAvg * 0.95 + (1000.0 / elapsed) * 0.05
	end

	if scene == nil then
		if Input.IsKeyDown(VK_ESCAPE) then SwitchScene("menu") end
		return
	end

	if pad ~= nil then
		pad.update()
	end

	if AUTOPLAY then
		-- 자동 시연: 정해진 순서로 네 방향을 돈다 (입력 없이도 걷는 모습이 보인다)
		autoTimer = autoTimer + elapsed
		if not playerChar:isMoving() and autoTimer > 120 then
			autoTimer = 0
			playerChar:request(AUTO_ROUTE[autoIndex])
			autoIndex = autoIndex % #AUTO_ROUTE + 1
		end
	else
		player:update()
	end

	scene:update(elapsed / 1000.0)

	if Input.IsKeyDown(VK_ESCAPE) then
		SwitchScene("menu")
	end
end

function RpgDemoScene.render()
	if scene == nil then
		if FontReady then
			DrawText(40, H / 2 - 40, "맵 로드 실패:")
			DrawText(40, H / 2, tostring(sceneError))
		end
		return
	end

	scene:draw()

	if FontReady then
		local camX, camY = scene.camera:pos()
		DrawText(16, 16, string.format("FPS %d  카메라 %d,%d",
			math.floor(fpsAvg + 0.5), camX, camY))
		DrawText(16, 56, string.format("타일 %d,%d  방향 %s%s",
			playerChar.tx, playerChar.ty, playerChar.dir,
			playerChar:isMoving() and "  이동 중" or ""))
		if pad ~= nil then
			DrawText(W / 2 - 190, H - 56, "패드로 이동, 뒤로가기로 메뉴")
		else
			DrawText(16, H - 56, "방향키 이동, ESC 메뉴")
		end
	end

	if pad ~= nil then
		pad.draw()
	end
end

function RpgDemoScene.destroy()
	if scene ~= nil then
		scene:dispose()
		scene = nil
	end
	if pad ~= nil then
		pad.dispose()
		pad = nil
	end
	player, playerChar = nil, nil
end

return RpgDemoScene
