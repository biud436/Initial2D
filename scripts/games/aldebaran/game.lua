-- 알데바란 — 스테이지 씬 (docs/plans/aldebaran-1-core.md 7절)
--
-- 횡스크롤 액션. 기획서는 docs/design/aldebaran.md.
--   ← → : 이동 (같은 방향 빠르게 두 번 = 대쉬)
--   Z 또는 스페이스: 점프 (공중에서 한 번 더 = 2단 점프)
--   ESC 또는 Android 뒤로가기: 메뉴로
--   터치: 좌하단 가상 패드(좌우), 우하단 점프 버튼
--
-- 16px 타일을 768x896 화면에 1:1로 그리면 너무 작아 렌더 배율 2를 켠다
-- (논리 384x448). 씬을 나갈 때 되돌린다 — rpgdemo와 같은 규칙.
--
-- 전투(몬스터, HUD)는 2단계, 타이틀과 컷씬은 3단계에서 이 씬에 얹는다.
--
-- 환경 변수
--   INITIAL2D_DEBUG    좌표와 FPS 표시
--   INITIAL2D_VPAD     데스크톱에서도 터치 UI 표시

local Image = require("scripts/image")
local VirtualPad = require("scripts/ui/vpad")
local Buttons = require("scripts/ui/buttons")
local Assets = require("scripts/rpg/assets")
local Bgm = require("scripts/bgm")
local Player = require("scripts/games/aldebaran/player")

AldebaranScene = {}

local MAP_PATH = "./resources/maps/aldebaran_forest.json"
local BG_PATH = "./resources/aldebaran/forest_bg.png"
local KARTO_PATH = "./resources/aldebaran/karto.png"
local UI_FONT = "./resources/fonts/hangul16.fnt"
local BASE_FONT = "./resources/fonts/hangul.fnt"
local BGM_SLOT = "./resources/audio/aldebaran_forest.ogg"   -- 없으면 bless로
local BGM_FALLBACK = "./resources/audio/bless.ogg"
local SE_JUMP = "./resources/audio/aldebaran_jump.wav"

local SCALE = 2
local START_X, START_Y = 56, 384        -- 숲 입구 (타일 3.5, 지면 24)
local PARALLAX = 0.4
local PAD_DEVICE_SIZE = 160

local VK_ESCAPE, VK_LEFT, VK_RIGHT, VK_SPACE, VK_Z = 27, 37, 39, 32, 90

local W, H = 384, 448
local map, mapError = nil, nil
local mapW, mapH, tileW, tileH, layerCount = 0, 0, 16, 16, 0
local worldW, worldH = 0, 0
local bg1, bg2, karto = nil, nil, nil
local player = nil
local camX = 0
local pad, buttons = nil, nil
local padWasLeft, padWasRight = false, false
local fpsAvg = 0
local DEBUG_HUD = false
local falls = 0            -- 낭떠러지에 떨어진 횟수 (검증용. 2단계에서 목숨으로)

local function env(name)
	return (os.getenv ~= nil) and os.getenv(name) or nil
end

-- ---- 충돌 조회 -------------------------------------------------------------
-- 픽셀 좌표가 막혀 있는가. 좌우 밖은 벽, 맵 아래는 낭떠러지(뚫려 있다).

local function probe(px, py)
	if px < 0 or px >= worldW then return true end
	if py >= worldH then return false end
	if py < 0 then return false end
	return not Tilemap.IsPassable(map, math.floor(px / tileW), math.floor(py / tileH))
end

-- ---- 입력 ------------------------------------------------------------------

local function pollInput()
	local input = {
		left = Input.IsKeyPress(VK_LEFT) or Input.IsKeyDown(VK_LEFT),
		right = Input.IsKeyPress(VK_RIGHT) or Input.IsKeyDown(VK_RIGHT),
		leftEdge = Input.IsKeyDown(VK_LEFT),
		rightEdge = Input.IsKeyDown(VK_RIGHT),
		jumpEdge = Input.IsKeyDown(VK_Z) or Input.IsKeyDown(VK_SPACE),
	}

	if pad ~= nil then
		pad.update()
		local l, r = pad.isPressed("left"), pad.isPressed("right")
		input.left = input.left or l
		input.right = input.right or r
		-- 패드에는 엣지가 없어 직전 프레임과 비교해 만든다 (더블탭 대쉬용)
		input.leftEdge = input.leftEdge or (l and not padWasLeft)
		input.rightEdge = input.rightEdge or (r and not padWasRight)
		padWasLeft, padWasRight = l, r
	end
	if buttons ~= nil then
		buttons.update()
		input.jumpEdge = input.jumpEdge or buttons.pressed("jump")
	end
	return input
end

-- ---- 씬 --------------------------------------------------------------------

function AldebaranScene.status()
	return {
		x = player ~= nil and player.x or nil,
		y = player ~= nil and player.y or nil,
		onGround = player ~= nil and player.onGround or false,
		falls = falls,
		camX = camX,
	}
end

function AldebaranScene.init()
	SetRenderScale(SCALE)
	W, H = WindowWidth(), WindowHeight()
	DEBUG_HUD = env("INITIAL2D_DEBUG") ~= nil
	if FontReady then PreparaFont(UI_FONT) end

	map, mapError = Tilemap.Load(MAP_PATH)
	if map ~= nil then
		mapW, mapH, tileW, tileH, layerCount = Tilemap.GetSize(map)
		worldW, worldH = mapW * tileW, mapH * tileH
	end

	bg1 = Image(BG_PATH, 0, 0, W, H, 1, "AldebaranBg")
	bg2 = Image(BG_PATH, 0, 0, W, H, 1, "AldebaranBg")

	karto = Image(KARTO_PATH, 0, 0, 48, 48, 24, "AldebaranKarto")
	karto.setSheetGrid(12, 2)
	karto.setLoop(false)

	player = Player.new(START_X, START_Y)
	camX = 0
	falls = 0
	padWasLeft, padWasRight = false, false

	if VirtualPad.shouldShow() then
		local size = PAD_DEVICE_SIZE / SCALE
		pad = VirtualPad.new{ x = 12, y = H - size - 12, size = size }
		buttons = Buttons.new{
			items = {
				{ id = "jump", label = "점프", x = W - 64, y = H - 70, size = 52 },
			},
		}
	end

	Bgm.play(Assets.exists(BGM_SLOT) and BGM_SLOT or BGM_FALLBACK, { volume = 64 })
end

local function respawn()
	player = Player.new(START_X, START_Y)
	falls = falls + 1
end

function AldebaranScene.update(elapsed)
	if elapsed > 0 then
		fpsAvg = fpsAvg * 0.95 + (1000.0 / elapsed) * 0.05
	end
	if map == nil then
		if Input.IsKeyDown(VK_ESCAPE) then SwitchScene("menu") end
		return
	end

	local dt = math.min(elapsed, 50) / 1000.0
	local input = pollInput()

	Player.update(player, input, dt, probe)
	if player.jumped then
		Audio.PlaySound(SE_JUMP, "aldebaranJump", 0)
	end

	-- 낭떠러지: 맵 아래로 떨어지면 시작 지점으로 (2단계에서 목숨 하나로 바뀐다)
	if player.y > worldH + 60 then
		respawn()
	end

	-- 카메라: 가로만 따라간다 (세로는 맵과 화면이 같다)
	camX = math.max(0, math.min(player.x - W / 2, worldW - W))

	bg1.update(0)
	bg2.update(0)
	karto.update(0)

	if Input.IsKeyDown(VK_ESCAPE) then
		SwitchScene("menu")
	end
end

function AldebaranScene.render()
	if map == nil then
		if FontReady then
			DrawText(20, H / 2 - 20, "맵 로드 실패:")
			DrawText(20, H / 2 + 4, tostring(mapError))
		end
		return
	end

	local cx = math.floor(camX)

	-- 원경 (시차 스크롤, 두 장 이어붙임)
	local bx = -math.floor(camX * PARALLAX) % W
	bg1.setPosition(bx - W, 0)
	bg2.setPosition(bx, 0)
	bg1.draw()
	bg2.draw()

	Tilemap.Draw(map, 1, layerCount, cx, 0)

	local f = Player.frame(player)
	karto.setFrames(f, f)
	karto.setCurrentFrame(f)
	karto.setPosition(math.floor(player.x) - 24 - cx, math.floor(player.y) - 46)
	karto.draw()

	if DEBUG_HUD and FontReady then
		DrawText(4, 4, string.format("FPS %d  x %d y %d  %s", math.floor(fpsAvg + 0.5),
			math.floor(player.x), math.floor(player.y),
			player.onGround and "지상" or "공중"))
	end

	if pad ~= nil then pad.draw() end
	if buttons ~= nil then buttons.draw() end
end

function AldebaranScene.destroy()
	if map ~= nil then
		Tilemap.Dispose(map)
		map = nil
	end
	if bg1 ~= nil then bg1.dispose() end
	if bg2 ~= nil then bg2.dispose() end
	if karto ~= nil then karto.dispose() end
	bg1, bg2, karto = nil, nil, nil
	if pad ~= nil then
		pad.dispose()
		pad = nil
	end
	if buttons ~= nil then
		buttons.dispose()
		buttons = nil
	end
	if FontReady then PreparaFont(BASE_FONT) end
	SetRenderScale(1)
end

return AldebaranScene
