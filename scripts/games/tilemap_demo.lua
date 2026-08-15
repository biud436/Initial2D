-- 타일맵 데모 — 2단계 산출물 (docs/plans/02-tilemap.md)
--
-- 화면보다 큰 샘플 맵(80x70, 2레이어)을 그리고 방향키로 카메라를 스크롤한다.
--   방향키 또는 화면 왼쪽 아래 가상 D-패드(터치 플랫폼): 카메라 이동
--   마우스/터치 위치: 그 아래 타일의 gid와 통행 가능 여부 표시
--   왼쪽 클릭/탭: 통행 가능한 잔디에 꽃 심기 (Tilemap.SetTileId 시연)
--   ESC 또는 Android 뒤로가기: 메뉴로
-- 레이어를 1층(ground)과 2층(deco)으로 나눠 그리고 그 사이에 새를 끼워
-- 그린다 — 5단계에서 캐릭터를 층 사이에 그릴 때와 같은 방식이다.

local Image = require("scripts/image")
local VirtualPad = require("scripts/ui/vpad")

TilemapDemoScene = {}

local W, H = 768, 896
local map = nil
local mapError = nil
local mapW, mapH, tileW, tileH, layerCount = 0, 0, 16, 16, 0
local camX, camY = 0, 0
local t = 0
local bird = nil
local pad = nil       -- 가상 D-패드 (터치 플랫폼에서만)
local fpsAvg = 0

local SCROLL_SPEED = 480 -- px/s
local FLOWER_GID = 56    -- 흰 꽃 (로컬 55 + firstGid 1)

local VK_LEFT, VK_UP, VK_RIGHT, VK_DOWN, VK_ESCAPE = 37, 38, 39, 40, 27

function TilemapDemoScene.init()
	W = WindowWidth()
	H = WindowHeight()
	t = 0
	fpsAvg = 0

	-- INITIAL2D_MAP 으로 다른 맵 파일을 열 수 있다 (에디터가 내보낸 맵 확인용)
	local mapPath = (os.getenv ~= nil) and os.getenv("INITIAL2D_MAP") or nil
	map, mapError = Tilemap.Load(mapPath or "./resources/maps/sample.json")
	if map ~= nil then
		mapW, mapH, tileW, tileH, layerCount = Tilemap.GetSize(map)
		-- 시작 카메라: 맵 중앙 (마을 구역)
		camX = math.floor((mapW * tileW - W) / 2)
		camY = math.floor((mapH * tileH - H) / 2)
	end

	-- 층 사이에 끼워 그릴 장식용 새 (deco 레이어의 울타리/덤불에 가려진다)
	bird = Image("./resources/bird_276x64.png", 0, 0, 92, 64, 3, "Player")
	bird.setLoop(true)
	bird.setFrames(0, 3)
	bird.setFrameDelay(140.0)
	bird.setAnimComplete(false)

	if VirtualPad.shouldShow() then
		pad = VirtualPad.new{ x = 24, y = H - 184, size = 160 }
	end
end

local function clampCamera()
	local maxX = math.max(0, mapW * tileW - W)
	local maxY = math.max(0, mapH * tileH - H)
	camX = math.max(0, math.min(camX, maxX))
	camY = math.max(0, math.min(camY, maxY))
end

function TilemapDemoScene.update(elapsed)
	t = t + elapsed / 1000.0
	if elapsed > 0 then
		fpsAvg = fpsAvg * 0.95 + (1000.0 / elapsed) * 0.05
	end

	if map == nil then
		if Input.IsKeyDown(VK_ESCAPE) then SwitchScene("menu") end
		return
	end

	if pad ~= nil then
		pad.update()
	end

	local step = SCROLL_SPEED * elapsed / 1000.0
	if AUTOPLAY then
		-- 자동 시연: 카메라가 맵을 크게 돌며 훑는다
		camX = (mapW * tileW - W) / 2 + math.sin(t * 0.7) * (mapW * tileW - W) / 2
		camY = (mapH * tileH - H) / 2 + math.cos(t * 0.5) * (mapH * tileH - H) / 2
	else
		local function held(vk, dir)
			return Input.IsKeyPress(vk) or (pad ~= nil and pad.isPressed(dir))
		end
		if held(VK_LEFT, "left") then camX = camX - step end
		if held(VK_RIGHT, "right") then camX = camX + step end
		if held(VK_UP, "up") then camY = camY - step end
		if held(VK_DOWN, "down") then camY = camY + step end
	end
	clampCamera()

	-- 왼쪽 클릭/탭: 통행 가능한 빈 잔디에 꽃 심기 (SetTileId 시연). 패드 위 탭은 제외
	local onPad = pad ~= nil and pad.contains(Input.GetMouseX(), Input.GetMouseY())
	if Input.IsMouseDown(0) and not onPad then
		local tx = math.floor((camX + Input.GetMouseX()) / tileW)
		local ty = math.floor((camY + Input.GetMouseY()) / tileH)
		if Tilemap.IsPassable(map, tx, ty) and Tilemap.GetTileId(map, tx, ty, 2) == 0 then
			Tilemap.SetTileId(map, tx, ty, 2, FLOWER_GID)
		end
	end

	-- 새는 맵 중앙 근처를 8자로 난다 (월드 좌표)
	local cx = mapW * tileW / 2
	local cy = mapH * tileH / 2
	bird.setPosition(cx + math.sin(t * 1.3) * 160 - camX, cy + math.sin(t * 2.6) * 90 - camY)
	bird.update(elapsed)

	if Input.IsKeyDown(VK_ESCAPE) then
		SwitchScene("menu")
	end
end

function TilemapDemoScene.render()
	if map == nil then
		if FontReady then
			DrawText(40, H / 2 - 40, "맵 로드 실패:")
			DrawText(40, H / 2, tostring(mapError))
		end
		return
	end

	local cx = math.floor(camX)
	local cy = math.floor(camY)

	Tilemap.Draw(map, 1, 1, cx, cy)              -- ground
	bird.draw()                                  -- 층 사이에 끼워 그리기
	Tilemap.Draw(map, 2, layerCount, cx, cy)     -- deco (새를 가린다)

	if FontReady then
		local tx = math.floor((camX + Input.GetMouseX()) / tileW)
		local ty = math.floor((camY + Input.GetMouseY()) / tileH)
		local passable = Tilemap.IsPassable(map, tx, ty)
		local gid = Tilemap.GetTileId(map, tx, ty, 1)
		DrawText(16, 16, string.format("FPS %d  카메라 %d,%d", math.floor(fpsAvg + 0.5), cx, cy))
		DrawText(16, 56, string.format("타일 %d,%d  gid %d  통행 %s", tx, ty, gid, passable and "가능" or "불가"))
		if pad ~= nil then
			DrawText(W / 2 - 200, H - 56, "패드 스크롤, 탭 꽃심기, 뒤로가기 메뉴")
		else
			DrawText(16, H - 56, "방향키 스크롤, 클릭 꽃심기, ESC 메뉴")
		end
	end

	if pad ~= nil then
		pad.draw()
	end
end

function TilemapDemoScene.destroy()
	if map ~= nil then
		Tilemap.Dispose(map)
		map = nil
	end
	if bird ~= nil then
		bird.dispose()
		bird = nil
	end
	if pad ~= nil then
		pad.dispose()
		pad = nil
	end
end

return TilemapDemoScene
