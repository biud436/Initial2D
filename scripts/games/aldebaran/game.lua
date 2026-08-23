-- 알데바란 — 스테이지 씬 (docs/plans/aldebaran-1-core.md 7절, aldebaran-2-combat.md)
--
-- 횡스크롤 액션. 기획서는 docs/design/aldebaran.md.
--   ← → : 이동 (같은 방향 빠르게 두 번 = 대쉬)
--   Z 또는 스페이스: 점프 (공중에서 한 번 더 = 2단 점프)
--   X: 공격 (연타로 3단 콤보)         C: 버서커 (MP 10, 4초)
--   ESC 또는 P (Android 뒤로가기): 일시 정지 — 계속 하기 / 다시 하기 / 끝내기
--   터치: 좌하단 가상 패드, 우하단 점프와 공격과 스킬 버튼, 우상단 정지 버튼
--
-- 16px 타일을 768x896 화면에 1:1로 그리면 너무 작아 렌더 배율 2를 켠다
-- (논리 384x448). 씬을 나갈 때 되돌린다 — rpgdemo와 같은 규칙.
--
-- 몬스터 배치와 종별 표는 stage.lua, 수식은 combat.lua, 상태 기계는 monster.lua.
-- 타이틀과 도둑 컷씬과 보스는 3단계에서 이 씬에 얹는다.
--
-- 환경 변수
--   INITIAL2D_DEBUG    좌표와 FPS와 판정 상자 표시
--   INITIAL2D_VPAD     데스크톱에서도 터치 UI 표시

local Image = require("scripts/image")
local VirtualPad = require("scripts/ui/vpad")
local Buttons = require("scripts/ui/buttons")
local Assets = require("scripts/rpg/assets")
local Bgm = require("scripts/bgm")
local Rng = require("scripts/rpg/rng")
local Window = require("scripts/rpg/window")
local Choice = require("scripts/rpg/choice")
local Player = require("scripts/games/aldebaran/player")
local Monster = require("scripts/games/aldebaran/monster")
local Combat = require("scripts/games/aldebaran/combat")
local Stage = require("scripts/games/aldebaran/stage")
local Hud = require("scripts/games/aldebaran/hud")

AldebaranScene = {}

local MAP_PATH = "./resources/maps/aldebaran_forest.json"
local BG_PATH = "./resources/aldebaran/forest_bg.png"
local KARTO_PATH = "./resources/aldebaran/karto.png"
local AURA_PATH = "./resources/aldebaran/aura.png"
local FADE_PATH = "./resources/ui/fade.png"
local UI_FONT = "./resources/fonts/hangul16.fnt"
local BASE_FONT = "./resources/fonts/hangul.fnt"
local BGM_SLOT = "./resources/audio/aldebaran_forest.ogg"   -- 없으면 bless로
local BGM_FALLBACK = "./resources/audio/bless.ogg"

local SE = {
	jump = "./resources/audio/aldebaran_jump.wav",
	swing = "./resources/audio/aldebaran_swing.wav",
	hit = "./resources/audio/hit.wav",
	hurt = "./resources/audio/aldebaran_hurt.wav",
	kill = "./resources/audio/aldebaran_kill.wav",
	level = "./resources/audio/aldebaran_level.wav",
	berserk = "./resources/audio/aldebaran_berserk.wav",
	pick = "./resources/audio/aldebaran_pick.wav",
	cursor = "./resources/audio/ui_cursor.wav",
	decision = "./resources/audio/ui_decision.wav",
}

local SCALE = 2
local PARALLAX = 0.4
local PAD_DEVICE_SIZE = 160

local VK_ESCAPE, VK_LEFT, VK_RIGHT, VK_UP, VK_DOWN = 27, 37, 39, 38, 40
local VK_SPACE, VK_RETURN, VK_Z, VK_X, VK_C, VK_P = 32, 13, 90, 88, 67, 80

local W, H = 384, 448
local map, mapError = nil, nil
local mapW, mapH, tileW, tileH, layerCount = 0, 0, 16, 16, 0
local worldW, worldH = 0, 0
local bg1, bg2, karto, aura, fadeImg = nil, nil, nil, nil, nil
local player = nil
local camX = 0
local pad, buttons = nil, nil
local padWasLeft, padWasRight = false, false
local fpsAvg = 0
local DEBUG_HUD = false

local rng = nil
local monsters = {}            -- { model = Monster, img = Image }
local stats = nil              -- hp, mp, atk, def, luck (레벨 반영)
local exp, gold, lives = 0, 0, 2
local level = 1
local berserkTimer = 0
local checkpoint = nil         -- { x, y } (이정표를 지나면 선다)
local checkpointHit = false
local falls = 0                -- 낭떠러지 낙하 횟수 (검증용)
local deaths = 0
local hud = nil
local skin, pauseChoice = nil, nil
local paused = false
local gameOvers = 0            -- 스테이지 재시작 횟수 (검증용, 3단계에서 창으로)

local function env(name)
	return (os.getenv ~= nil) and os.getenv(name) or nil
end

local function playSe(name)
	Audio.PlaySound(SE[name], "aldebaran:" .. name, 0)
end

-- ---- 충돌 조회 -------------------------------------------------------------
-- 픽셀 좌표가 막혀 있는가. 좌우 밖은 벽, 맵 아래는 낭떠러지(뚫려 있다).

local function probe(px, py)
	if px < 0 or px >= worldW then return true end
	if py >= worldH then return false end
	if py < 0 then return false end
	return not Tilemap.IsPassable(map, math.floor(px / tileW), math.floor(py / tileH))
end

local function overlap(l1, t1, r1, b1, l2, t2, r2, b2)
	return l1 < r2 and r1 > l2 and t1 < b2 and b1 > t2
end

-- ---- 입력 ------------------------------------------------------------------

local function pollInput()
	local input = {
		left = Input.IsKeyPress(VK_LEFT) or Input.IsKeyDown(VK_LEFT),
		right = Input.IsKeyPress(VK_RIGHT) or Input.IsKeyDown(VK_RIGHT),
		leftEdge = Input.IsKeyDown(VK_LEFT),
		rightEdge = Input.IsKeyDown(VK_RIGHT),
		jumpEdge = Input.IsKeyDown(VK_Z) or Input.IsKeyDown(VK_SPACE),
		attackEdge = Input.IsKeyDown(VK_X),
		skillEdge = Input.IsKeyDown(VK_C),
		pauseEdge = Input.IsKeyDown(VK_ESCAPE) or Input.IsKeyDown(VK_P),
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
		input.attackEdge = input.attackEdge or buttons.pressed("attack")
		input.skillEdge = input.skillEdge or buttons.pressed("skill")
		input.pauseEdge = input.pauseEdge or buttons.pressed("pause")
	end
	return input
end

-- ---- 스테이지 세우기 --------------------------------------------------------

local function spawnMonsters()
	for _, e in ipairs(monsters) do
		if e.img ~= nil then e.img.dispose() end
	end
	monsters = {}
	for i, s in ipairs(Stage.spawns) do
		local def = Stage.species[s.species]
		local model = Monster.new(def, s)
		local img = Image(def.sheet, 0, 0, def.frameW, def.frameH,
			def.cols * def.rows, "Aldebaran:" .. s.species)
		img.setSheetGrid(def.cols, def.rows)
		img.setLoop(false)
		monsters[#monsters + 1] = { model = model, img = img }
	end
end

--- 레벨 반영. 레벨이 오르면 전량 회복이 규칙이다 (기획서 7.2절)
local function applyLevel(newLevel)
	level = newLevel
	local s = Combat.statsAt(level)
	stats = { hp = s.hp, mp = s.mp, atk = s.atk, def = s.def, luck = s.luck,
		maxHp = s.hp, maxMp = s.mp }
end

--- 스테이지를 처음부터 (첫 진입, 그리고 다시 하기)
local function resetStage()
	rng = Rng.new(Stage.SEED)
	player = Player.new(Stage.START.x, Stage.START.y)
	exp, gold = 0, 0
	lives = Stage.LIVES
	applyLevel(1)
	berserkTimer = 0
	checkpoint = nil
	checkpointHit = false
	spawnMonsters()
	camX = 0
end

--- 목숨 하나를 잃었다 (HP 0 또는 낭떠러지)
local function loseLife()
	deaths = deaths + 1
	lives = lives - 1
	if lives <= 0 then
		gameOvers = gameOvers + 1
		resetStage()             -- 3단계에서 게임 오버 창으로 바뀐다
		return
	end
	local at = checkpoint or Stage.START
	player = Player.new(at.x, at.y)
	player.invulnTimer = 1.5     -- 부활 직후의 짧은 무적
	stats.hp = stats.maxHp
	berserkTimer = 0
end

-- ---- 전투 -------------------------------------------------------------------

local function berserkActive()
	return berserkTimer > 0
end

local function gainReward(def)
	exp = exp + def.exp
	gold = gold + def.gold
	playSe("kill")
	local newLevel = Combat.levelFor(exp)
	if newLevel > level then
		applyLevel(newLevel)     -- 전량 회복 포함
		playSe("level")
	end
end

--- 플레이어의 베기가 몬스터를 때린다
local function resolvePlayerAttack()
	if not Player.attackActive(player) then return end
	local ax0, ay0, ax1, ay1 = Player.attackBox(player)
	for _, e in ipairs(monsters) do
		local m = e.model
		if not m.dead and m.state ~= "dying" and not player.attackHit[m] then
			local bx0, by0, bx1, by1 = Monster.body(m)
			if overlap(ax0, ay0, ax1, ay1, bx0, by0, bx1, by1) then
				player.attackHit[m] = true
				local atk = stats.atk * Player.attackMult(player)
				if berserkActive() then atk = atk * Combat.BERSERK.atkMult end
				local r = Combat.resolve(atk, m.def.def, rng, stats.luck)
				if r.dmg > 0 then
					playSe("hit")
					if Monster.hurt(m, r.dmg, player.facing) then
						gainReward(m.def)
					end
				end
			end
		end
	end
end

--- 몬스터의 공격(내리찍기, 돌격)이 플레이어를 때린다
local function resolveMonsterAttacks()
	if player.invulnTimer > 0 then return end
	local px0, py0 = player.x - Player.HALF_W, player.y - Player.BODY_H
	local px1, py1 = player.x + Player.HALF_W, player.y
	for _, e in ipairs(monsters) do
		local m = e.model
		if not m.dead and m.state ~= "dying" and not m.strikeHit then
			local bx0, by0, bx1, by1 = Monster.attackBox(m)
			if bx0 ~= nil and overlap(px0, py0, px1, py1, bx0, by0, bx1, by1) then
				local charging = (m.state == "charge")
				local base = charging and (m.def.chargeAtk or m.def.atk) or m.def.atk
				local r = Combat.resolve(base, stats.def, rng, 0)
				if r.kind ~= "miss" then
					local dmg = r.dmg
					-- 전갈거미의 독침: 명중의 20%로 데미지 +8 (기획서 6절)
					if m.def.special == "sting" and rng:chance(m.def.stingChance) then
						dmg = dmg + m.def.stingBonus
					end
					if berserkActive() then
						dmg = math.floor(dmg * Combat.BERSERK.takenMult)
					end
					if Player.applyHit(player, m.x) then
						stats.hp = stats.hp - dmg
						playSe("hurt")
						m.strikeHit = true
						if charging then
							m.chargeUsed = true
							m.timer = 0          -- 명중한 돌격은 거기서 끝난다
						end
						if stats.hp <= 0 then
							loseLife()
							return
						end
					end
				else
					m.strikeHit = true           -- 회피당한 공격도 한 번뿐이다
				end
			end
		end
	end
end

-- ---- 씬 --------------------------------------------------------------------

--- 씬 바깥(검증)에서 상태를 들여다보는 창구
function AldebaranScene.status()
	local ms = {}
	for _, e in ipairs(monsters) do
		local m = e.model
		if not m.dead then
			ms[#ms + 1] = { species = m.def.name, x = math.floor(m.x),
				y = math.floor(m.y), hp = m.hp, state = m.state }
		end
	end
	return {
		x = player ~= nil and player.x or nil,
		y = player ~= nil and player.y or nil,
		onGround = player ~= nil and player.onGround or false,
		invuln = player ~= nil and player.invulnTimer > 0 or false,
		hp = stats ~= nil and stats.hp or nil,
		mp = stats ~= nil and stats.mp or nil,
		maxHp = stats ~= nil and stats.maxHp or nil,
		exp = exp, gold = gold, level = level, lives = lives,
		berserk = berserkActive(),
		paused = paused,
		checkpoint = checkpointHit,
		falls = falls, deaths = deaths, gameOvers = gameOvers,
		camX = camX,
		monsters = ms,
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

	aura = Image(AURA_PATH, 0, 0, 48, 48, 2, "AldebaranAura")
	aura.setSheetGrid(2, 1)
	aura.setLoop(false)

	fadeImg = Image(FADE_PATH, 0, 0, 16, 16, 1, "AldebaranFade")
	fadeImg.setScale(math.max(W, H) / 16)

	hud = Hud.new()
	falls, deaths, gameOvers = 0, 0, 0
	paused = false
	padWasLeft, padWasRight = false, false

	-- 일시 정지 창 (대화창 부품을 그대로 쓴다 — 공용품이다)
	skin = Window.newSkin{ path = Assets.windowskin(), scale = 1 }
	pauseChoice = Choice.new{
		skin = skin, measure = GetTextWidth, drawText = DrawText,
		lineHeight = 22, maxVisible = 3, minWidth = 140,
		se = {
			cursor = function() playSe("cursor") end,
			decision = function() playSe("decision") end,
		},
	}

	resetStage()

	if VirtualPad.shouldShow() then
		local size = PAD_DEVICE_SIZE / SCALE
		pad = VirtualPad.new{ x = 12, y = H - size - 12, size = size }
		buttons = Buttons.new{
			items = {
				{ id = "attack", label = "공격", x = W - 60, y = H - 64, size = 52 },
				{ id = "jump", label = "점프", x = W - 116, y = H - 52, size = 44 },
				{ id = "skill", label = "폭주", x = W - 56, y = H - 122, size = 40 },
				{ id = "pause", label = "II", x = W - 34, y = 8, size = 26 },
			},
		}
	end

	Bgm.play(Assets.exists(BGM_SLOT) and BGM_SLOT or BGM_FALLBACK, { volume = 64 })
end

-- ---- 일시 정지 (기획서 8.3절) ----------------------------------------------

local PAUSE_ITEMS = { "계속 하기", "다시 하기", "끝내기" }

local function openPause()
	paused = true
	playSe("decision")
	pauseChoice:show(PAUSE_ITEMS, {
		x = math.floor(W / 2 - 80), y = math.floor(H / 2 - 40), index = 1,
	})
end

local function updatePause()
	local input = {
		confirm = Input.IsKeyDown(VK_Z) or Input.IsKeyDown(VK_RETURN)
			or Input.IsKeyDown(VK_SPACE),
		up = Input.IsKeyDown(VK_UP),
		down = Input.IsKeyDown(VK_DOWN),
		cancel = Input.IsKeyDown(VK_X) or Input.IsKeyDown(VK_ESCAPE)
			or Input.IsKeyDown(VK_P),
	}
	-- 터치: 항목을 직접 누른다
	if Input.IsMouseDown(0) then
		local index = pauseChoice:indexAt(Input.GetMouseX(), Input.GetMouseY())
		if index ~= nil then
			pauseChoice.index = index
			input.confirm = true
		end
	end
	if buttons ~= nil then
		buttons.update()
		if buttons.pressed("pause") then input.cancel = true end
	end

	pauseChoice:update(input)
	if not pauseChoice:isActive() then
		local picked = pauseChoice:result()
		paused = false
		if picked == 2 then
			resetStage()             -- 다시 하기
		elseif picked == 3 then
			SwitchScene("menu")      -- 끝내기 (3단계에서 타이틀로 바뀐다)
		end
	end
end

function AldebaranScene.update(elapsed)
	if elapsed > 0 then
		fpsAvg = fpsAvg * 0.95 + (1000.0 / elapsed) * 0.05
	end
	if map == nil then
		if Input.IsKeyDown(VK_ESCAPE) then SwitchScene("menu") end
		return
	end

	if paused then
		updatePause()
		return                       -- 게임 시간이 멈춘다
	end

	local dt = math.min(elapsed, 50) / 1000.0
	local input = pollInput()

	if input.pauseEdge then
		openPause()
		return
	end

	-- 버서커 (기획서 7.3절)
	berserkTimer = math.max(0, berserkTimer - dt)
	if input.skillEdge and Combat.canBerserk(stats.mp, berserkActive()) then
		stats.mp = stats.mp - Combat.BERSERK.cost
		berserkTimer = Combat.BERSERK.time
		playSe("berserk")
	end

	Player.update(player, input, dt, probe)
	if player.jumped then playSe("jump") end
	if player.swung then playSe("swing") end

	-- 낭떠러지: 목숨 하나를 잃고 체크포인트에서 다시 선다
	if player.y > worldH + 60 then
		falls = falls + 1
		loseLife()
	end

	-- 체크포인트 (이정표)
	if not checkpointHit and player.x >= Stage.CHECKPOINT_X then
		checkpointHit = true
		checkpoint = { x = Stage.CHECKPOINT_X, y = Stage.CHECKPOINT_Y }
		playSe("pick")
	end

	for _, e in ipairs(monsters) do
		if not e.model.dead then
			Monster.update(e.model, dt, probe, player.x, player.y)
		end
	end

	resolvePlayerAttack()
	resolveMonsterAttacks()

	-- 카메라: 가로만 따라간다 (세로는 맵과 화면이 같다)
	camX = math.max(0, math.min(player.x - W / 2, worldW - W))

	bg1.update(0)
	bg2.update(0)
	karto.update(0)
end

-- ---- 그리기 ----------------------------------------------------------------

local function drawMonsters(cx)
	for _, e in ipairs(monsters) do
		local m = e.model
		if not m.dead then
			local sx = math.floor(m.x) - m.def.anchorX - cx
			if sx > -m.def.frameW and sx < W then
				local f = Monster.frame(m)
				e.img.setFrames(f, f)
				e.img.setCurrentFrame(f)
				e.img.setPosition(sx, math.floor(m.y) - m.def.anchorY)
				if m.state == "dying" then
					e.img.setOpacity(math.floor(255 * (1 - m.fade / Monster.DYING_TIME)))
				else
					e.img.setOpacity(255)
				end
				e.img.update(0)
				e.img.draw()
			end
		end
	end
end

local function drawHud()
	hud.bar(6, 6, "hp", stats.hp / stats.maxHp)
	hud.bar(6, 14, "mp", stats.mp / stats.maxMp)
	hud.bar(6, 22, "exp", Combat.expRatio(exp))
	for i = 1, Stage.LIVES do
		hud.icon(76 + (i - 1) * 12, 5, i <= lives and "star" or "starEmpty")
	end
	hud.icon(76, 18, "coin")
	if FontReady then
		DrawText(88, 16, tostring(gold))
		DrawText(76, 30, "Lv " .. level)
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

	drawMonsters(cx)

	-- 버서커의 붉은 기운은 카르토 뒤에
	if berserkActive() then
		local af = math.floor(player.animTime * 8) % 2
		aura.setFrames(af, af)
		aura.setCurrentFrame(af)
		aura.setPosition(math.floor(player.x) - 24 - cx, math.floor(player.y) - 46)
		aura.update(0)
		aura.draw()
	end

	local f = Player.frame(player)
	karto.setFrames(f, f)
	karto.setCurrentFrame(f)
	karto.setPosition(math.floor(player.x) - 24 - cx, math.floor(player.y) - 46)
	-- 무적 시간에는 깜박인다
	if player.invulnTimer > 0 and math.floor(player.invulnTimer * 10) % 2 == 0 then
		karto.setOpacity(110)
	else
		karto.setOpacity(255)
	end
	karto.draw()

	drawHud()

	if DEBUG_HUD and FontReady then
		DrawText(4, 40, string.format("FPS %d  x %d y %d  %s", math.floor(fpsAvg + 0.5),
			math.floor(player.x), math.floor(player.y),
			player.onGround and "지상" or "공중"))
	end

	if pad ~= nil then pad.draw() end
	if buttons ~= nil then buttons.draw() end

	-- 일시 정지: 화면을 어둡게 깔고 창을 띄운다
	if paused then
		fadeImg.setPosition(0, 0)
		fadeImg.setOpacity(150)
		fadeImg.update(0)
		fadeImg.draw()
		pauseChoice:draw()
		if FontReady then
			DrawText(math.floor(W / 2 - 40), math.floor(H / 2 - 64), "일시 정지")
		end
	end
end

function AldebaranScene.destroy()
	if map ~= nil then
		Tilemap.Dispose(map)
		map = nil
	end
	for _, e in ipairs(monsters) do
		if e.img ~= nil then e.img.dispose() end
	end
	monsters = {}
	if bg1 ~= nil then bg1.dispose() end
	if bg2 ~= nil then bg2.dispose() end
	if karto ~= nil then karto.dispose() end
	if aura ~= nil then aura.dispose() end
	if fadeImg ~= nil then fadeImg.dispose() end
	bg1, bg2, karto, aura, fadeImg = nil, nil, nil, nil, nil
	if hud ~= nil then
		hud.dispose()
		hud = nil
	end
	if pauseChoice ~= nil then
		pauseChoice:dispose()
		pauseChoice = nil
	end
	if skin ~= nil then
		skin:dispose()
		skin = nil
	end
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
