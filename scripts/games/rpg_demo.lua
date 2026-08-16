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
-- 16px 타일을 768x896 화면에 1:1로 그리면 캐릭터가 점처럼 보이므로, 이 씬은
-- 렌더 배율 2를 켠다 (논리 해상도 384x448). 씬을 나갈 때 1로 되돌린다.
--
-- 환경 변수
--   INITIAL2D_MAP      다른 맵 파일 (에디터가 내보낸 맵 확인용)
--   INITIAL2D_CHARSET  다른 CharSet. 지정하지 않으면 변환된 RTP CharSet이 있을 때
--                      그것을, 없으면 커밋된 플레이스홀더를 쓴다
--   INITIAL2D_RPG_SCALE 렌더 배율 (기본 2)

local MapScene = require("scripts/rpg/map_scene")
local Player = require("scripts/rpg/player")
local Rng = require("scripts/rpg/rng")
local VirtualPad = require("scripts/ui/vpad")

RpgDemoScene = {}

local W, H = 768, 896
local scene, sceneError = nil, nil
local player, playerChar = nil, nil
local pad = nil
local scale = 1
local fpsAvg = 0
local hintTimer = 0
local DEBUG_HUD = false
local HINT_SECONDS = 4.0
local autoTimer = 0
local autoIndex = 1

local DEFAULT_MAP = "./resources/maps/sample.json"
local DEFAULT_CHARSET = "./resources/charsets/placeholder.png"
-- 정품 보유자가 tools/rtp_import.py로 변환해 두었다면 그쪽이 훨씬 보기 좋다.
-- 저장소에는 없는 파일이라(라이선스) 있을 때만 쓴다.
local RTP_CHARSET = "./resources/rtp/CharSet/Actor1.png"
local DEFAULT_SCALE = 2
local PAD_DEVICE_SIZE = 160        -- 배율과 무관하게 손가락 크기를 일정하게 유지
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

local function fileExists(path)
	local f = io.open(path, "rb")
	if f == nil then return false end
	f:close()
	return true
end

local function chooseCharset()
	local override = env("INITIAL2D_CHARSET")
	if override ~= nil then return override end
	if fileExists(RTP_CHARSET) then return RTP_CHARSET end
	return DEFAULT_CHARSET
end

function RpgDemoScene.init()
	-- 배율을 먼저 정한다 — WindowWidth/Height가 논리 해상도로 바뀐다
	scale = tonumber(env("INITIAL2D_RPG_SCALE") or "") or DEFAULT_SCALE
	SetRenderScale(scale)

	W = WindowWidth()
	H = WindowHeight()
	fpsAvg = 0
	hintTimer = 0
	autoTimer = 0
	autoIndex = 1
	DEBUG_HUD = env("INITIAL2D_DEBUG") ~= nil

	scene, sceneError = MapScene.new{
		mapPath = env("INITIAL2D_MAP") or DEFAULT_MAP,
		viewW = W, viewH = H,
		groundLayers = 1,
	}
	if scene == nil then return end

	local charset = chooseCharset()

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
		local size = math.floor(PAD_DEVICE_SIZE / scale)
		local margin = math.floor(24 / scale)
		pad = VirtualPad.new{ x = margin, y = H - size - margin, size = size }
	end

	player = Player.new{ character = playerChar, input = Input, pad = pad }
end

function RpgDemoScene.update(elapsed)
	if elapsed > 0 then
		fpsAvg = fpsAvg * 0.95 + (1000.0 / elapsed) * 0.05
	end
	hintTimer = hintTimer + elapsed / 1000.0

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

	-- 비트맵 폰트는 배율만큼 커지므로(배율 2에서 글자 높이가 화면의 9%) 화면에
	-- 글자를 계속 띄우면 게임이 아니라 계기판처럼 보인다. 조작 안내는 잠깐만
	-- 보여 주고, 좌표와 FPS는 INITIAL2D_DEBUG일 때만 그린다.
	if FontReady then
		if hintTimer < HINT_SECONDS then
			local help = pad ~= nil and "뒤로가기: 메뉴" or "방향키 이동  ESC 메뉴"
			DrawText((W - GetTextWidth(help)) / 2, H - 56, help)
		end

		if DEBUG_HUD then
			DrawText(8, 6, string.format("%d,%d  %d fps",
				playerChar.tx, playerChar.ty, math.floor(fpsAvg + 0.5)))
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

	-- 다른 씬(메뉴, 플래피)은 768x896 기준으로 배치되어 있다. 원래대로 되돌린다.
	SetRenderScale(1)
end

return RpgDemoScene
