-- RPG 데모 — 5, 6단계 산출물 (docs/plans/05-rpg-character.md, 06-rpg-events.md)
--
-- 맵 위를 걸어다니고, NPC에게 말을 걸고, 문을 밟아 다른 맵으로 이동한다.
--   방향키 또는 가상 D-패드: 이동
--     - 정지 중에 다른 방향키를 짧게 누르면 이동 없이 방향만 바뀐다 (R2K3식)
--   Z / Enter / Space (터치는 패드 밖 탭): 말 걸기, 대화 넘기기, 선택지 결정
--   ESC 또는 Android 뒤로가기: 메뉴로
--
-- 맵과 이벤트 정의는 scripts/maps/<이름>.lua 가 짝으로 들고 있다. 이 씬은 그
-- 정의를 읽어 씬을 세우고, ctx.transfer 요청이 오면 페이드를 걸고 다시 세운다.
--
-- 16px 타일을 768x896 화면에 1:1로 그리면 캐릭터가 점처럼 보이므로 렌더 배율
-- 2를 켠다 (논리 해상도 384x448). 씬을 나갈 때 1로 되돌린다.
--
-- 환경 변수
--   INITIAL2D_MAP       시작 맵 정의 이름 (village, room)
--   INITIAL2D_CHARSET   다른 CharSet. 없으면 변환된 RTP를, 그것도 없으면 플레이스홀더
--   INITIAL2D_RPG_SCALE 렌더 배율 (기본 2)
--   INITIAL2D_DEBUG     좌표와 FPS 표시

local MapScene = require("scripts/rpg/map_scene")
local Player = require("scripts/rpg/player")
local Rng = require("scripts/rpg/rng")
local Event = require("scripts/rpg/event")
local Interpreter = require("scripts/rpg/interpreter")
local Text = require("scripts/rpg/text")
local Image = require("scripts/image")
local VirtualPad = require("scripts/ui/vpad")

RpgDemoScene = {}

local MAPS = {
	village = "scripts/maps/village",
	room = "scripts/maps/room",
}

-- 엔진의 텍스트 경로에는 확대·축소가 없다. 화면이 논리 384x448이라 32px 폰트는
-- 너무 크므로 이 씬만 16px 폰트를 쓰고, 나갈 때 원래 폰트로 되돌린다
-- (tools/generate_bmfont.py 로 다시 구울 수 있다).
local UI_FONT = "./resources/fonts/hangul16.fnt"
local BASE_FONT = "./resources/fonts/hangul.fnt"

local DEFAULT_CHARSET = "./resources/charsets/placeholder.png"
local RTP_CHARSET = "./resources/rtp/CharSet/Actor1.png"
local DEFAULT_SCALE = 2
local PAD_DEVICE_SIZE = 160
local WANDER_SEED = 20260817
local FADE_FRAMES = 14          -- 전환 페이드 한쪽 길이

local VK_ESCAPE, VK_RETURN, VK_SPACE, VK_Z = 27, 13, 32, 90
local VK_UP, VK_DOWN = 38, 40

local W, H = 768, 896
local scale = 1
local scene, sceneError = nil, nil
local player, playerChar = nil, nil
local events, interp = nil, nil
local pad, fadeImg = nil, nil
local charsetPath = DEFAULT_CHARSET
local rng = nil

local fade = { alpha = 0, dir = 0, pending = nil }
local hintTimer, fpsAvg = 0, 0
local DEBUG_HUD = false
local HINT_SECONDS = 4.0
local message = nil             -- { text = } 또는 { options =, index = }

-- 자동 시연 경로. 맵 정의 파일의 autoRoute를 쓰고, 없으면 제자리에서 말만 건다.
-- "talk"은 결정키, 나머지는 방향이다.
local DEFAULT_AUTO_ROUTE = { "talk" }
local autoRoute = DEFAULT_AUTO_ROUTE
local autoTimer, autoIndex = 0, 1

local function env(name)
	return (os.getenv ~= nil) and os.getenv(name) or nil
end

local function fileExists(path)
	local f = io.open(path, "rb")
	if f == nil then return false end
	f:close()
	return true
end

-- ---- 대화 표시 (7단계에서 대화창으로 교체할 자리) -------------------------
--
-- interpreter는 messagePort.isBusy()가 false가 될 때까지 스크립트를 재개하지
-- 않는다. 여기서는 화면 아래에 글자를 얹고 결정키를 기다리는 최소 구현만 둔다.
-- 7단계가 오면 이 테이블만 진짜 창으로 갈아 끼우면 된다.
local messagePort = {}

function messagePort.showMessage(text)
	message = { text = text }
end

function messagePort.showChoice(options)
	message = { options = options, index = 1 }
end

function messagePort.isBusy()
	return message ~= nil
end

function messagePort.result()
	return messagePort.picked or 1
end

-- ---- 맵 적재 -------------------------------------------------------------

local function disposeMap()
	if scene ~= nil then
		scene:dispose()
		scene = nil
	end
	events, player, playerChar = nil, nil, nil
end

--- 이벤트 정의 하나를 씬에 세운다. 외형이 있으면 캐릭터를 붙인다.
local function spawnEvent(def)
	local ev = Event.new{
		id = def.id, x = def.x, y = def.y, dir = def.dir,
		trigger = def.trigger, script = def.script,
		charset = def.charset, through = def.through, solid = def.solid,
		data = def.data,
	}

	if def.charset ~= nil then
		ev.character = scene:addCharacter{
			tx = def.x, ty = def.y, dir = def.dir,
			charset = def.charset.file or charsetPath,
			charIndex = def.charset.index or 0,
			speed = def.speed or 3,
			name = def.id,
		}
		if def.wander ~= nil then
			ev.character:setWander{
				rng = rng,
				minWait = def.wander.minWait, maxWait = def.wander.maxWait,
				area = def.wander.area,
			}
		end
	end

	return ev
end

local function loadMap(name, startX, startY, startDir)
	disposeMap()

	local modulePath = MAPS[name]
	if modulePath == nil then
		sceneError = "알 수 없는 맵: " .. tostring(name)
		return
	end

	local ok, def = pcall(require, modulePath)
	if not ok then
		sceneError = "이벤트 정의 로드 실패: " .. tostring(def)
		return
	end

	local err
	scene, err = MapScene.new{
		mapPath = def.map, viewW = W, viewH = H, groundLayers = 1,
	}
	if scene == nil then
		sceneError = err
		return
	end
	sceneError = nil

	local sx = startX or (def.start and def.start.x) or 0
	local sy = startY or (def.start and def.start.y) or 0
	local sdir = startDir or (def.start and def.start.dir) or "down"

	playerChar = scene:addCharacter{
		tx = sx, ty = sy, dir = sdir,
		charset = charsetPath, charIndex = 0, speed = 4, name = "player",
	}
	scene:setCameraTarget(playerChar)

	rng = Rng.new(WANDER_SEED)   -- 맵마다 같은 시드에서 시작 (재현 가능한 데모)

	events = Event.newManager{ player = playerChar, interpreter = interp }
	for _, edef in ipairs(def.events or {}) do
		events:add(spawnEvent(edef))
	end
	scene:setEvents(events)

	interp:clear()
	events:onMapStart()

	autoRoute = def.autoRoute or DEFAULT_AUTO_ROUTE
	autoIndex = 1

	player = Player.new{ character = playerChar, input = Input, pad = pad }

	-- 스프라이트 위치를 한 번 맞춰 둔다. 전환 직후에는 페이드가 도느라 update가
	-- 돌지 않아서, 이게 없으면 캐릭터들이 잠시 화면 좌상단에 그려진다.
	scene:update(0)
end

--- ctx.transfer 요청. 페이드가 끝난 뒤에 실제 교체가 일어난다.
local function requestTransfer(mapName, x, y)
	fade.pending = { name = mapName, x = x, y = y }
	fade.dir = 1
end

local function characterById(id)
	if id == "player" then return playerChar end
	local ev = events ~= nil and events:get(id) or nil
	return ev ~= nil and ev.character or nil
end

-- ---- 씬 계약 --------------------------------------------------------------

function RpgDemoScene.init()
	scale = tonumber(env("INITIAL2D_RPG_SCALE") or "") or DEFAULT_SCALE
	SetRenderScale(scale)

	if FontReady then PreparaFont(UI_FONT) end

	W, H = WindowWidth(), WindowHeight()
	fpsAvg, hintTimer = 0, 0
	autoTimer, autoIndex = 0, 1
	DEBUG_HUD = env("INITIAL2D_DEBUG") ~= nil
	message = nil
	messagePort.picked = nil
	fade = { alpha = 0, dir = 0, pending = nil }

	charsetPath = env("INITIAL2D_CHARSET")
		or (fileExists(RTP_CHARSET) and RTP_CHARSET)
		or DEFAULT_CHARSET

	if VirtualPad.shouldShow() then
		local size = math.floor(PAD_DEVICE_SIZE / scale)
		local margin = math.floor(24 / scale)
		pad = VirtualPad.new{ x = margin, y = H - size - margin, size = size }
	end

	-- 페이드와 대화 배경에 쓰는 단색 판 (엔진에 사각형 채우기가 없어 스프라이트로 대신)
	fadeImg = Image("./resources/ui/fade.png", 0, 0, 16, 16, 1, "UIFade")
	fadeImg.setScale(math.max(W, H) / 16 + 1)
	fadeImg.setOpacity(0)
	fadeImg.update(0)   -- 위치·스케일은 update가 트랜스폼에 반영한다

	interp = Interpreter.new{
		messagePort = messagePort,
		host = { transfer = requestTransfer, characterById = characterById },
	}

	loadMap(env("INITIAL2D_MAP") or "village")
end

-- 결정키: 대화를 넘기거나, 선택지를 고르거나, 말을 건다
local function confirmPressed()
	if Input.IsKeyDown(VK_Z) or Input.IsKeyDown(VK_RETURN) or Input.IsKeyDown(VK_SPACE) then
		return true
	end
	-- 터치: 패드 밖을 탭하면 결정 (단일 터치라 이동과 겹치지 않는다)
	if pad ~= nil and Input.IsMouseDown(0)
		and not pad.contains(Input.GetMouseX(), Input.GetMouseY()) then
		return true
	end
	return false
end

local function updateMessage()
	if message.options ~= nil then
		local n = #message.options
		if Input.IsKeyDown(VK_UP) or (pad ~= nil and pad.pressed() == "up") then
			message.index = (message.index - 2) % n + 1
		elseif Input.IsKeyDown(VK_DOWN) or (pad ~= nil and pad.pressed() == "down") then
			message.index = message.index % n + 1
		end
		if confirmPressed() then
			messagePort.picked = message.index
			message = nil
		end
		return
	end

	if confirmPressed() then
		message = nil
	end
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

	-- 페이드 중에는 게임을 멈춘다 (전환이 또렷하게 보인다)
	if fade.dir ~= 0 then
		fade.alpha = fade.alpha + fade.dir * (255 / FADE_FRAMES)
		if fade.dir > 0 and fade.alpha >= 255 then
			fade.alpha = 255
			local t = fade.pending
			fade.pending = nil
			if t ~= nil then
				loadMap(t.name, t.x, t.y)
			end
			fade.dir = -1
		elseif fade.dir < 0 and fade.alpha <= 0 then
			fade.alpha = 0
			fade.dir = 0
		end
		return
	end

	if AUTOPLAY then
		-- 자동 시연: 촌장 쪽으로 걸어가 말을 걸고, 대화는 알아서 넘긴다
		autoTimer = autoTimer + elapsed
		if message ~= nil then
			if autoTimer > 900 then
				autoTimer = 0
				if message.options ~= nil then messagePort.picked = message.index end
				message = nil
			end
		elseif interp:isBusy() then
			-- 스크립트가 도는 중이면 기다린다
		elseif autoTimer > 200 and not playerChar:isMoving() then
			autoTimer = 0
			local step = autoRoute[autoIndex]
			autoIndex = autoIndex % #autoRoute + 1
			if step == "talk" then
				events:confirm()
			else
				playerChar:request(step)
			end
		end
	elseif message ~= nil then
		updateMessage()
	elseif not interp:isBusy() and confirmPressed() then
		events:confirm()
	end

	if player ~= nil and not AUTOPLAY then
		-- 이벤트가 도는 동안 플레이어만 멈춘다. 맵과 병렬 이벤트는 계속 돈다.
		player.enabled = not interp:isBusy() and message == nil
		player:update()
	end

	scene:update(elapsed / 1000.0)
	events:update()
	interp:update()

	if Input.IsKeyDown(VK_ESCAPE) then
		SwitchScene("menu")
	end
end

local MSG_MARGIN = 12

local function drawMessage()
	if message == nil or not FontReady then return end

	-- 폭에 맞춰 줄을 나눈다. 비트맵 폰트는 글자마다 폭이 달라서 글자 수가 아니라
	-- 픽셀로 재야 한다 (scripts/rpg/text.lua, 7단계의 대화창도 같은 것을 쓴다).
	local maxWidth = W - MSG_MARGIN * 2
	local lines = {}
	if message.text ~= nil then
		lines = Text.wrap(message.text, maxWidth, GetTextWidth)
	else
		for i, option in ipairs(message.options) do
			local prefix = (i == message.index and "> " or "  ")
			for _, line in ipairs(Text.wrap(prefix .. option, maxWidth, GetTextWidth)) do
				lines[#lines + 1] = line
			end
		end
	end

	local lineH = 24
	local boxH = lineH * #lines + 16
	fadeImg.setOpacity(190)
	fadeImg.setPosition(0, H - boxH)
	fadeImg.update(0)
	fadeImg.draw()

	for i, line in ipairs(lines) do
		DrawText(12, H - boxH + 8 + (i - 1) * lineH, line)
	end
end

function RpgDemoScene.render()
	if scene == nil then
		if FontReady then
			DrawText(20, H / 2 - 40, "맵 로드 실패:")
			DrawText(20, H / 2, tostring(sceneError))
		end
		return
	end

	-- 맵이 화면보다 작으면 바깥이 배경색으로 남는다. 뒤에 검은 판을 깔아 둔다.
	fadeImg.setOpacity(255)
	fadeImg.setPosition(0, 0)
	fadeImg.update(0)
	fadeImg.draw()

	scene:draw()

	if FontReady then
		if hintTimer < HINT_SECONDS then
			local help = pad ~= nil and "패드 이동, 화면 탭 결정" or "방향키 이동  Z 결정  ESC 메뉴"
			DrawText((W - GetTextWidth(help)) / 2, 8, help)
		end
		if DEBUG_HUD then
			DrawText(8, H - 24, string.format("%d,%d  %d fps  busy %s",
				playerChar.tx, playerChar.ty, math.floor(fpsAvg + 0.5),
				tostring(interp:isBusy())))
		end
	end

	drawMessage()

	if pad ~= nil then
		pad.draw()
	end

	if fade.alpha > 0 then
		fadeImg.setOpacity(math.floor(fade.alpha))
		fadeImg.setPosition(0, 0)
		fadeImg.update(0)
		fadeImg.draw()
	end
end

function RpgDemoScene.destroy()
	disposeMap()
	if pad ~= nil then
		pad.dispose()
		pad = nil
	end
	if fadeImg ~= nil then
		fadeImg.dispose()
		fadeImg = nil
	end
	interp = nil
	message = nil
	if FontReady then PreparaFont(BASE_FONT) end
	SetRenderScale(1)
end

return RpgDemoScene
