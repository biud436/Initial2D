-- 데모 게임 "작은 마을" — 맵 씬 (5~8단계 산출물, docs/plans/08-demo.md)
--
-- 맵 위를 걸어다니고, NPC에게 말을 걸면 얼굴이 있는 대화창이 뜨고, 선택지에 따라
-- 대사가 갈린다. 문을 밟으면 다른 맵으로 이동한다.
--   방향키 또는 가상 D-패드: 이동, 선택지 커서
--     - 정지 중에 다른 방향키를 짧게 누르면 이동 없이 방향만 바뀐다 (R2K3식)
--   Z / Enter / Space (터치는 패드 밖 탭): 말 걸기, 대화 넘기기, 선택지 결정
--   X: 선택지 취소 (취소 항목이 정해진 선택지에서만)
--   ESC 또는 Android 뒤로가기: 타이틀로
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
--                       (대화창 스킨과 얼굴도 같은 규칙으로 고른다)
--   INITIAL2D_RPG_SCALE 렌더 배율 (기본 2)
--   INITIAL2D_DEBUG     좌표와 FPS 표시

local MapScene = require("scripts/rpg/map_scene")
local Player = require("scripts/rpg/player")
local Rng = require("scripts/rpg/rng")
local Event = require("scripts/rpg/event")
local Interpreter = require("scripts/rpg/interpreter")
local Window = require("scripts/rpg/window")
local Dialogue = require("scripts/rpg/message")
local Image = require("scripts/image")
local VirtualPad = require("scripts/ui/vpad")
local Assets = require("scripts/rpg/assets")
local Bgm = require("scripts/bgm")

RpgDemoScene = {}

local MAPS = {
	village = "scripts/maps/village",
	room = "scripts/maps/room",
}

-- 엔진의 텍스트 경로에는 확대와 축소가 없다. 화면이 논리 384x448이라 32px 폰트는
-- 너무 크므로 이 씬만 16px 폰트를 쓰고, 나갈 때 원래 폰트로 되돌린다
-- (tools/generate_bmfont.py 로 다시 구울 수 있다).
local UI_FONT = "./resources/fonts/hangul16.fnt"
local BASE_FONT = "./resources/fonts/hangul.fnt"

-- 그림은 RTP가 있으면 원본을, 없으면 같은 규격으로 그린 플레이스홀더를 쓴다
-- (scripts/rpg/assets.lua).
local SE_CURSOR = "./resources/audio/ui_cursor.wav"
local SE_DECISION = "./resources/audio/ui_decision.wav"
local SE_TEXT = "./resources/audio/ui_text.wav"
local SE_DOOR = "./resources/audio/door.wav"
local DEFAULT_SCALE = 2
local PAD_DEVICE_SIZE = 160
local WANDER_SEED = 20260817
local FADE_FRAMES = 14          -- 전환 페이드 한쪽 길이

local VK_ESCAPE, VK_RETURN, VK_SPACE, VK_Z = 27, 13, 32, 90
local VK_UP, VK_DOWN, VK_X = 38, 40, 88

local W, H = 768, 896
local scale = 1
local scene, sceneError = nil, nil
local player, playerChar = nil, nil
local events, interp = nil, nil
local pad, fadeImg = nil, nil
local charsetPath = nil
local rng = nil
local mapName = nil
local mapScripts = nil    -- 맵 정의가 등록한 script 커맨드용 함수 표 (9단계)

local fade = { alpha = 0, dir = 0, pending = nil, exitTo = nil }
local locationText, locationTimer = nil, 0
local hintTimer, fpsAvg = 0, 0
local DEBUG_HUD = false
local HINT_SECONDS = 4.0
local skin, dialogue = nil, nil   -- 대화창 (7단계)
local padPrev = nil               -- 가상 패드 방향의 직전 값 (엣지 판정용)

-- 자동 시연 경로. 맵 정의 파일의 autoRoute를 쓰고, 없으면 제자리에서 말만 건다.
-- "talk"은 결정키, 나머지는 방향이다.
local DEFAULT_AUTO_ROUTE = { "talk" }
local autoRoute = DEFAULT_AUTO_ROUTE
local autoTimer, autoIndex = 0, 1

local function env(name)
	return (os.getenv ~= nil) and os.getenv(name) or nil
end

-- ---- 대화창 (7단계) -------------------------------------------------------
--
-- 실행기(interpreter.lua)는 messagePort의 네 함수만 안다. 6단계에서는 화면 아래에
-- 글자만 얹는 최소 구현이었고, 지금은 스킨 창(scripts/rpg/message.lua)이 그
-- 자리에 있다. 씬이 하는 일은 창을 만들고, 매 프레임 입력을 넘겨 주는 것뿐이다.

local function playSe(path, id)
	return function() Audio.PlaySound(path, id, 0) end
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
		commands = def.commands, scripts = mapScripts,
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
	mapName = name

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
	mapScripts = def.scripts

	local err
	scene, err = MapScene.new{
		mapPath = def.map, viewW = W, viewH = H, groundLayers = 1,
	}
	if scene == nil then
		sceneError = err
		return
	end
	sceneError = nil

	-- 맵마다 곡이 다를 수 있다. 같은 곡이면 Bgm이 알아서 넘어가므로 맵을
	-- 오갈 때 음악이 끊기지 않는다.
	if def.bgm ~= nil then
		Bgm.play(def.bgm.file, { volume = def.bgm.volume })
	end

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
		-- 커맨드가 틀리면 Event.new가 어느 자리인지와 함께 죽는다. 게임을 통째로
		-- 멈추는 대신 씬 오류로 띄운다 (맵 로드 실패와 같은 경로).
		local built, result = pcall(spawnEvent, edef)
		if not built then
			sceneError = tostring(result)
			return
		end
		events:add(result)
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
local function requestTransfer(target, x, y)
	fade.pending = { name = target, x = x, y = y }
	fade.dir = 1
	Audio.PlaySound(SE_DOOR, "door", 0)
end

-- ---- 커맨드가 위임하는 호스트 기능 (9단계) --------------------------------

--- 화면 위쪽에 장소 이름을 잠깐 띄운다 (맵 진입 auto 이벤트가 부른다)
local function showLocation(text, seconds)
	locationText = text
	locationTimer = tonumber(seconds) or 2.0
end

local function hostPlaySe(file, id)
	Audio.PlaySound(file, id or "se", 0)
end

local function hostPlayBgm(file, opts)
	Bgm.play(file, opts)
end

--- 다른 씬으로 나간다. 페이드를 걸어 두면 어두워진 뒤에 넘어간다.
local function hostScene(name, opts)
	opts = opts or {}
	if opts.text ~= nil then
		showLocation(opts.text, 3.0)
	end
	if opts.fade then
		fade.pending = nil
		fade.dir = 1
		fade.exitTo = name
	else
		SwitchScene(name)
	end
end

local function characterById(id)
	if id == "player" then return playerChar end
	local ev = events ~= nil and events:get(id) or nil
	return ev ~= nil and ev.character or nil
end

--- 지금 씬의 상태. 디버그 HUD가 쓰고, 8단계 시나리오 테스트가 같은 값을 읽어
-- "정말로 그 칸에 서 있고 그 대사가 떠 있는가"를 확인한다. 씬 바깥에서 상태를
-- 들여다볼 창구가 이것 하나뿐이라 테스트가 내부 지역 변수에 손대지 않는다.
function RpgDemoScene.status()
	return {
		map = mapName,
		tx = playerChar ~= nil and playerChar.tx or nil,
		ty = playerChar ~= nil and playerChar.ty or nil,
		dir = playerChar ~= nil and playerChar.dir or nil,
		moving = playerChar ~= nil and playerChar:isMoving() or false,
		busy = interp ~= nil and interp:isBusy() or false,
		talking = dialogue ~= nil and dialogue:isBusy() or false,
		lines = dialogue ~= nil and dialogue:visibleLines() or {},
		fading = fade.dir ~= 0,
		location = locationTimer > 0 and locationText or nil,
		error = sceneError,
	}
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
	padPrev = nil
	-- 검은 화면에서 밝아지며 시작한다 (타이틀에서 넘어오는 장면이 이어진다)
	fade = { alpha = 255, dir = -1, pending = nil, exitTo = nil }
	locationText, locationTimer = nil, 0

	charsetPath = env("INITIAL2D_CHARSET") or Assets.playerCharset()

	if VirtualPad.shouldShow() then
		local size = math.floor(PAD_DEVICE_SIZE / scale)
		local margin = math.floor(24 / scale)
		pad = VirtualPad.new{ x = margin, y = H - size - margin, size = size }
	end

	-- 페이드와 대화 배경에 쓰는 단색 판 (엔진에 사각형 채우기가 없어 스프라이트로 대신)
	fadeImg = Image("./resources/ui/fade.png", 0, 0, 16, 16, 1, "UIFade")
	fadeImg.setScale(math.max(W, H) / 16 + 1)
	fadeImg.setOpacity(0)
	fadeImg.update(0)   -- 위치와 스케일은 update가 트랜스폼에 반영한다

	skin = Window.newSkin{
		path = Assets.windowskin(),
		scale = 1,
	}
	dialogue = Dialogue.new{
		skin = skin, measure = GetTextWidth, drawText = DrawText,
		screenW = W, screenH = H, lines = 3, lineHeight = 20,
		se = {
			cursor = playSe(SE_CURSOR, "uiCursor"),
			decision = playSe(SE_DECISION, "uiDecision"),
			text = playSe(SE_TEXT, "uiText"),
		},
	}

	interp = Interpreter.new{
		messagePort = dialogue:port(),
		host = {
			transfer = requestTransfer, characterById = characterById,
			playSe = hostPlaySe, playBgm = hostPlayBgm,
			showLocation = showLocation, scene = hostScene,
		},
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

--- 이번 프레임에 눌린 키들. 대화창은 "누르고 있다"가 아니라 "방금 눌렀다"를 본다.
-- 가상 패드는 누르고 있는 방향만 알려 주므로 여기서 직전 값과 비교해 엣지로 바꾼다.
local function pollInput()
	local padDir = pad ~= nil and pad.pressed() or nil
	local padEdge = (padDir ~= nil and padDir ~= padPrev) and padDir or nil
	padPrev = padDir

	return {
		confirm = confirmPressed(),
		up = Input.IsKeyDown(VK_UP) or padEdge == "up",
		down = Input.IsKeyDown(VK_DOWN) or padEdge == "down",
		cancel = Input.IsKeyDown(VK_X),
	}
end

function RpgDemoScene.update(elapsed)
	if elapsed > 0 then
		fpsAvg = fpsAvg * 0.95 + (1000.0 / elapsed) * 0.05
	end
	hintTimer = hintTimer + elapsed / 1000.0
	if locationTimer > 0 then
		locationTimer = math.max(0, locationTimer - elapsed / 1000.0)
	end

	if scene == nil then
		if Input.IsKeyDown(VK_ESCAPE) then SwitchScene("title") end
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
			if fade.exitTo ~= nil then
				SwitchScene(fade.exitTo)   -- 검게 덮인 채로 다음 씬에 넘긴다
				return
			end
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

	local input = pollInput()

	if AUTOPLAY then
		-- 자동 시연: 촌장 쪽으로 걸어가 말을 걸고, 대화는 알아서 넘긴다
		autoTimer = autoTimer + elapsed
		if dialogue:isBusy() then
			if autoTimer > 700 then
				autoTimer = 0
				input.confirm = true
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
	end

	-- 대화창이 결정키를 먼저 가져간다. 대화를 닫은 그 누름으로 같은 NPC에게 다시
	-- 말을 걸지 않도록, 말 걸기는 "이번 프레임을 한가하게 시작했는가"로 판단한다.
	local wasIdle = not dialogue:isBusy() and not interp:isBusy()
	dialogue:update(input, interp:isBusy())

	if not AUTOPLAY and wasIdle and input.confirm then
		events:confirm()
	end

	if player ~= nil and not AUTOPLAY then
		-- 이벤트가 도는 동안 플레이어만 멈춘다. 맵과 병렬 이벤트는 계속 돈다.
		player.enabled = not interp:isBusy() and not dialogue:isBusy()
		player:update()
	end

	scene:update(elapsed / 1000.0)
	events:update()
	interp:update()

	if Input.IsKeyDown(VK_ESCAPE) then
		SwitchScene("title")
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
		if locationTimer > 0 and locationText ~= nil then
			DrawText((W - GetTextWidth(locationText)) / 2, 28, locationText)
		end
		if hintTimer < HINT_SECONDS then
			local help = pad ~= nil and "패드 이동, 화면 탭 결정" or "방향키 이동  Z 결정  ESC 타이틀"
			DrawText((W - GetTextWidth(help)) / 2, 8, help)
		end
		if DEBUG_HUD then
			local st = RpgDemoScene.status()
			DrawText(8, H - 24, string.format("%s %d,%d  %d fps  busy %s",
				tostring(st.map), st.tx, st.ty, math.floor(fpsAvg + 0.5),
				tostring(st.busy)))
		end
	end

	dialogue:draw()

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
	if dialogue ~= nil then
		dialogue:dispose()
		dialogue = nil
	end
	if skin ~= nil then
		skin:dispose()
		skin = nil
	end
	interp = nil
	if FontReady then PreparaFont(BASE_FONT) end
	SetRenderScale(1)
end

return RpgDemoScene
