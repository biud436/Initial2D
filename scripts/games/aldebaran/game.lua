-- 알데바란 — 스테이지 씬 (docs/plans/aldebaran-1-core.md 7절, -2-combat.md, -3-content.md)
--
-- 횡스크롤 액션. 기획서는 docs/design/aldebaran.md.
--   ← → : 이동 (같은 방향 빠르게 두 번 = 대쉬)
--   Z 또는 스페이스: 점프 (공중에서 한 번 더 = 2단 점프), 대화 넘기기
--   X: 공격 (연타로 3단 콤보)         C: 버서커 (MP 10, 4초)
--   ESC 또는 P (Android 뒤로가기): 일시 정지 — 계속 하기 / 다시 하기 / 끝내기
--   터치: 좌하단 가상 패드, 우하단 점프와 공격과 폭주 버튼, 우상단 정지 버튼
--
-- 흐름 (기획서 4절): 도입 컷씬(짐도둑이 배낭을 지고 달아난다) → 숲 주파와 전투 →
-- 공터의 짐도둑을 쓰러뜨리고 배낭을 주우면 에필로그와 결과 창 → 타이틀로.
-- 목숨을 다 잃으면 게임 오버 — 다시 하기 / 타이틀로.
--
-- 16px 타일을 768x896 화면에 1:1로 그리면 너무 작아 렌더 배율 2를 켠다
-- (논리 384x448). 씬을 나갈 때 되돌린다 — rpgdemo와 같은 규칙.
--
-- 몬스터 배치와 종별 표와 이야기 글은 stage.lua, 수식은 combat.lua,
-- 상태 기계는 monster.lua.
--
-- 환경 변수
--   INITIAL2D_DEBUG        좌표와 FPS 표시
--   INITIAL2D_VPAD         데스크톱에서도 터치 UI 표시
--   INITIAL2D_SKIP_INTRO   도입 컷씬 생략 (검증용)

local Image = require("scripts/image")
local VirtualPad = require("scripts/ui/vpad")
local Buttons = require("scripts/ui/buttons")
local Assets = require("scripts/rpg/assets")
local Bgm = require("scripts/bgm")
local Rng = require("scripts/rpg/rng")
local Window = require("scripts/rpg/window")
local Choice = require("scripts/rpg/choice")
local Dialogue = require("scripts/rpg/message")
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
local STONE_PATH = "./resources/aldebaran/stone.png"
local BAG_PATH = "./resources/aldebaran/bag.png"
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
	throw = "./resources/audio/aldebaran_throw.wav",
	cursor = "./resources/audio/ui_cursor.wav",
	decision = "./resources/audio/ui_decision.wav",
	text = "./resources/audio/ui_text.wav",
}

local SCALE = 2
local PARALLAX = 0.4
local PAD_DEVICE_SIZE = 160
local SIGN_SECONDS = 4.0
local STONE_SPEED = 140
local STONE_TOSS = -170
local STONE_GRAVITY = 720

local VK_ESCAPE, VK_LEFT, VK_RIGHT, VK_UP, VK_DOWN = 27, 37, 39, 38, 40
local VK_SPACE, VK_RETURN, VK_Z, VK_X, VK_C, VK_P = 32, 13, 90, 88, 67, 80

local W, H = 384, 448
local map, mapError = nil, nil
local mapW, mapH, tileW, tileH, layerCount = 0, 0, 16, 16, 0
local worldW, worldH = 0, 0
local bg1, bg2, karto, aura, fadeImg, stoneImg, bagImg, thiefImg = nil, nil, nil, nil, nil, nil, nil, nil
local player = nil
local camX = 0
local pad, buttons = nil, nil
local padWasLeft, padWasRight = false, false
local fpsAvg = 0
local DEBUG_HUD = false

local rng = nil
local monsters = {}            -- { model = Monster, img = Image, boss = bool }
local stones = {}              -- 짐도둑의 돌팔매 { x, y, vx, vy }
local bag = nil                -- 떨어진 배낭 { x, y }
local stats = nil
local exp, gold, lives = 0, 0, 2
local level = 1
local berserkTimer = 0
local checkpoint = nil
local checkpointHit = false
local falls = 0
local deaths = 0
local hud = nil
local skin, pauseChoice, dialogue = nil, nil, nil
local paused = false
local gameOvers = 0

local intro = nil              -- { phase = "thief" | "text", timer } 도입 컷씬
local ending = nil             -- { phase = "epilogue" | "result" } 에필로그와 결과
local gameOver = nil           -- { phase = "text" | "choice" }
local stageTime = 0
local signSeen = {}
local signText, signTimer = nil, 0

local function env(name)
	return (os.getenv ~= nil) and os.getenv(name) or nil
end

local function playSe(name)
	Audio.PlaySound(SE[name], "aldebaran:" .. name, 0)
end

-- ---- 충돌 조회 -------------------------------------------------------------

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

--- 대화창(나레이션)이 보는 결정키. 화면 탭도 결정으로 친다.
local function pollConfirm()
	local confirm = Input.IsKeyDown(VK_Z) or Input.IsKeyDown(VK_RETURN)
		or Input.IsKeyDown(VK_SPACE) or Input.IsMouseDown(0)
	return { confirm = confirm }
end

-- ---- 스테이지 세우기 --------------------------------------------------------

local function spawnMonsters()
	for _, e in ipairs(monsters) do
		if e.img ~= nil then e.img.dispose() end
	end
	monsters = {}
	for _, s in ipairs(Stage.spawns) do
		local def = Stage.species[s.species]
		local model = Monster.new(def, s)
		local img = Image(def.sheet, 0, 0, def.frameW, def.frameH,
			def.cols * def.rows, "Aldebaran:" .. s.species)
		img.setSheetGrid(def.cols, def.rows)
		img.setLoop(false)
		monsters[#monsters + 1] = { model = model, img = img, boss = s.boss }
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
	stones = {}
	bag = nil
	ending = nil
	gameOver = nil
	stageTime = 0
	signSeen = {}
	signText, signTimer = nil, 0
	camX = 0
end

--- 목숨 하나를 잃었다 (HP 0 또는 낭떠러지)
local function loseLife()
	deaths = deaths + 1
	lives = lives - 1
	if lives <= 0 then
		gameOvers = gameOvers + 1
		gameOver = { phase = "text" }
		dialogue:showMessage(Stage.GAMEOVER)
		return
	end
	local at = checkpoint or Stage.START
	player = Player.new(at.x, at.y)
	player.invulnTimer = 1.5
	stats.hp = stats.maxHp
	berserkTimer = 0
	stones = {}
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
		applyLevel(newLevel)
		playSe("level")
	end
end

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
						if e.boss then
							-- 짐도둑이 쓰러지면 배낭이 떨어진다 (기획서 4.3절)
							bag = { x = m.x, y = m.y }
						end
					end
				end
			end
		end
	end
end

--- 플레이어가 데미지를 받는다 (내리찍기, 돌격, 돌팔매 공통)
local function damagePlayer(base, fromX, sting)
	local r = Combat.resolve(base, stats.def, rng, 0)
	if r.kind == "miss" then return false end
	local dmg = r.dmg
	if sting ~= nil and rng:chance(sting.chance) then
		dmg = dmg + sting.bonus
	end
	if berserkActive() then
		dmg = math.floor(dmg * Combat.BERSERK.takenMult)
	end
	if not Player.applyHit(player, fromX) then return false end
	stats.hp = math.max(0, stats.hp - dmg)
	playSe("hurt")
	if stats.hp <= 0 then loseLife() end
	return true
end

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
				local sting = nil
				if m.def.special == "sting" then
					sting = { chance = m.def.stingChance, bonus = m.def.stingBonus }
				end
				m.strikeHit = true               -- 회피당해도 그 공격은 끝났다
				if damagePlayer(base, m.x, sting) and charging then
					m.chargeUsed = true
					m.timer = 0
				end
				if gameOver ~= nil then return end
			end
		end
	end
end

-- ---- 돌팔매 (짐도둑의 투사체) ------------------------------------------------

local function updateStones(dt)
	-- 짐도둑의 strike가 돌을 만든다 (monster.lua는 thrown 깃발만 세운다)
	for _, e in ipairs(monsters) do
		local m = e.model
		if m.def.special == "throw" and m.state == "strike" and not m.thrown then
			m.thrown = true
			stones[#stones + 1] = {
				x = m.x + m.dir * 12, y = m.y - 24,
				vx = m.dir * STONE_SPEED, vy = STONE_TOSS,
			}
			playSe("throw")
		end
	end

	local px0, py0 = player.x - Player.HALF_W, player.y - Player.BODY_H
	local px1, py1 = player.x + Player.HALF_W, player.y
	for i = #stones, 1, -1 do
		local s = stones[i]
		s.vy = s.vy + STONE_GRAVITY * dt
		s.x = s.x + s.vx * dt
		s.y = s.y + s.vy * dt
		local gone = false
		if probe(s.x, s.y) or s.y > worldH + 40 then
			gone = true
		elseif player.invulnTimer <= 0
				and overlap(s.x - 4, s.y - 4, s.x + 4, s.y + 4, px0, py0, px1, py1) then
			damagePlayer(Stage.species.monkey.atk, s.x, nil)
			gone = true
		end
		if gone then table.remove(stones, i) end
		if gameOver ~= nil then return end
	end
end

-- ---- 씬 --------------------------------------------------------------------

function AldebaranScene.status()
	local ms = {}
	for _, e in ipairs(monsters) do
		local m = e.model
		if not m.dead then
			ms[#ms + 1] = { species = m.def.name, x = math.floor(m.x),
				y = math.floor(m.y), hp = m.hp, state = m.state,
				boss = e.boss or false }
		end
	end
	return {
		x = player ~= nil and player.x or nil,
		y = player ~= nil and player.y or nil,
		onGround = player ~= nil and player.onGround or false,
		invuln = player ~= nil and player.invulnTimer > 0 or false,
		attacking = player ~= nil and player.attackTimer > 0 or false,
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
		stones = #stones,
		intro = intro ~= nil,
		-- 창이 화면에 남아 있는가 (닫히는 중도 포함). 컷씬이 끝난 뒤 이것이
		-- 참으로 남으면 "대화창이 안 꺼진다" 버그다 (2026-08-23 사용자 보고)
		dialogueShown = dialogue ~= nil and dialogue.window ~= nil
			and not dialogue.window:isClosed() or false,
		bag = bag ~= nil,
		ending = ending ~= nil and ending.phase or nil,
		gameOver = gameOver ~= nil and gameOver.phase or nil,
		sign = signText,
		time = stageTime,
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

	stoneImg = Image(STONE_PATH, 0, 0, 8, 8, 1, "AldebaranStone")
	bagImg = Image(BAG_PATH, 0, 0, 16, 16, 1, "AldebaranBag")

	-- 도입 컷씬의 짐도둑 (몬스터와 같은 시트, 다른 스프라이트)
	local mk = Stage.species.monkey
	thiefImg = Image(mk.sheet, 0, 0, mk.frameW, mk.frameH,
		mk.cols * mk.rows, "Aldebaran:monkey")
	thiefImg.setSheetGrid(mk.cols, mk.rows)
	thiefImg.setLoop(false)

	fadeImg = Image(FADE_PATH, 0, 0, 16, 16, 1, "AldebaranFade")
	fadeImg.setScale(math.max(W, H) / 16)

	hud = Hud.new()
	falls, deaths, gameOvers = 0, 0, 0
	paused = false
	padWasLeft, padWasRight = false, false

	-- 창 부품 (일시 정지, 게임 오버, 나레이션 — 전부 공용품이다)
	skin = Window.newSkin{ path = Assets.windowskin(), scale = 1 }
	local se = {
		cursor = function() playSe("cursor") end,
		decision = function() playSe("decision") end,
		text = function() playSe("text") end,
	}
	pauseChoice = Choice.new{
		skin = skin, measure = GetTextWidth, drawText = DrawText,
		lineHeight = 22, maxVisible = 3, minWidth = 140, se = se,
	}
	dialogue = Dialogue.new{
		skin = skin, measure = GetTextWidth, drawText = DrawText,
		screenW = W, screenH = H, lines = 3, lineHeight = 20,
		speed = 3, se = se,
	}

	resetStage()

	-- 도입 컷씬 (기획서 4.2절): 짐도둑이 배낭을 지고 달아난다 → 나레이션
	if env("INITIAL2D_SKIP_INTRO") == nil then
		intro = { phase = "thief", timer = 0, x = Stage.START.x + 40 }
	else
		intro = nil
	end

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
local GAMEOVER_ITEMS = { "다시 하기", "타이틀로" }

local function openPause()
	paused = true
	playSe("decision")
	pauseChoice:show(PAUSE_ITEMS, {
		x = math.floor(W / 2 - 80), y = math.floor(H / 2 - 40), index = 1,
	})
end

local function pollMenuInput()
	local input = {
		confirm = Input.IsKeyDown(VK_Z) or Input.IsKeyDown(VK_RETURN)
			or Input.IsKeyDown(VK_SPACE),
		up = Input.IsKeyDown(VK_UP),
		down = Input.IsKeyDown(VK_DOWN),
		cancel = Input.IsKeyDown(VK_X) or Input.IsKeyDown(VK_ESCAPE)
			or Input.IsKeyDown(VK_P),
	}
	if Input.IsMouseDown(0) then
		local index = pauseChoice:indexAt(Input.GetMouseX(), Input.GetMouseY())
		if index ~= nil then
			pauseChoice.index = index
			input.confirm = true
		end
	end
	return input
end

local function updatePause()
	local input = pollMenuInput()
	if buttons ~= nil then
		buttons.update()
		if buttons.pressed("pause") then input.cancel = true end
	end

	pauseChoice:update(input)
	if not pauseChoice:isActive() then
		local picked = pauseChoice:result()
		paused = false
		if picked == 2 then
			resetStage()
		elseif picked == 3 then
			SwitchScene("aldebaran_title")
		end
	end
end

-- ---- 컷씬과 끝 --------------------------------------------------------------

local function updateIntro(dt)
	if intro.phase == "thief" then
		intro.timer = intro.timer + dt
		intro.x = intro.x + 150 * dt        -- 화면 밖으로 달아난다
		if intro.timer >= 1.6 then
			intro.phase = "text"
			dialogue:showMessage(Stage.INTRO)
		end
	else
		dialogue:update(pollConfirm(), false)
		if not dialogue:isBusy() then
			intro = nil                      -- 조작이 풀린다
		end
	end
end

local function startEnding()
	playSe("pick")
	bag = nil
	ending = { phase = "epilogue", page = 1 }
	Bgm.stop()
	dialogue:showMessage(Stage.EPILOGUE[1])
end

local function updateEnding()
	if ending.phase == "epilogue" then
		dialogue:update(pollConfirm(), false)
		if not dialogue:isBusy() then
			ending.page = ending.page + 1
			if Stage.EPILOGUE[ending.page] ~= nil then
				dialogue:showMessage(Stage.EPILOGUE[ending.page])
			else
				ending.phase = "result"
				ending.wait = 0
				playSe("decision")
			end
		end
	else
		-- 결과 창 (기획서 4.4절): 결정키로 닫으면 타이틀로
		dialogue:update({}, false)      -- 에필로그 창이 닫히는 것을 마저 본다
		ending.wait = ending.wait + 1
		if ending.wait > 10 and pollConfirm().confirm then
			SwitchScene("aldebaran_title")
		end
	end
end

local function updateGameOver()
	if gameOver.phase == "text" then
		dialogue:update(pollConfirm(), false)
		if not dialogue:isBusy() then
			gameOver.phase = "choice"
			pauseChoice:show(GAMEOVER_ITEMS, {
				x = math.floor(W / 2 - 70), y = math.floor(H / 2 - 20), index = 1,
			})
		end
	else
		dialogue:update({}, false)      -- 게임 오버 글의 창이 닫히는 것을 마저 본다
		pauseChoice:update(pollMenuInput())
		if not pauseChoice:isActive() then
			local picked = pauseChoice:result()
			if picked == 2 then
				SwitchScene("aldebaran_title")
			else
				resetStage()                 -- 취소를 포함해 기본은 다시 하기
			end
		end
	end
end

-- ---- 갱신 -------------------------------------------------------------------

function AldebaranScene.update(elapsed)
	if elapsed > 0 then
		fpsAvg = fpsAvg * 0.95 + (1000.0 / elapsed) * 0.05
	end
	if map == nil then
		if Input.IsKeyDown(VK_ESCAPE) then SwitchScene("menu") end
		return
	end

	local dt = math.min(elapsed, 50) / 1000.0

	if paused then
		updatePause()
		return
	end
	if gameOver ~= nil then
		updateGameOver()
		return
	end
	if ending ~= nil then
		updateEnding()
		return
	end
	if intro ~= nil then
		updateIntro(dt)
		return
	end

	-- 대화창은 한가할 때도 매 프레임 돌린다. isBusy()는 마지막 쪽을 넘긴 즉시
	-- 거짓이 되고 창이 닫히는 것은 그 뒤의 update()가 하는 일이라, 컷씬이
	-- 끝났다고 갱신을 멈추면 창이 열린 채로 화면에 남는다.
	dialogue:update({}, false)

	stageTime = stageTime + dt
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

	if player.y > worldH + 60 then
		falls = falls + 1
		loseLife()
		if gameOver ~= nil then return end
	end

	if not checkpointHit and player.x >= Stage.CHECKPOINT_X then
		checkpointHit = true
		checkpoint = { x = Stage.CHECKPOINT_X, y = Stage.CHECKPOINT_Y }
		playSe("pick")
	end

	-- 표지 글 (기획서 4.3절): 닿으면 화면 위에 잠깐 뜬다
	signTimer = math.max(0, signTimer - dt)
	if signTimer <= 0 then signText = nil end
	for i, sign in ipairs(Stage.SIGNS) do
		if not signSeen[i] and player.x >= sign.x0 and player.x <= sign.x1 then
			signSeen[i] = true
			signText = sign.text
			signTimer = SIGN_SECONDS
		end
	end

	for _, e in ipairs(monsters) do
		if not e.model.dead then
			Monster.update(e.model, dt, probe, player.x, player.y)
		end
	end

	resolvePlayerAttack()
	resolveMonsterAttacks()
	if gameOver ~= nil then return end
	updateStones(dt)
	if gameOver ~= nil then return end

	-- 배낭 줍기 → 에필로그 (기획서 4.4절)
	if bag ~= nil and math.abs(player.x - bag.x) < 14
			and math.abs(player.y - bag.y) < 24 then
		startEnding()
		return
	end

	camX = math.max(0, math.min(player.x - W / 2, worldW - W))
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

local function drawCenteredText(y, text)
	local w = (GetTextWidth ~= nil) and GetTextWidth(text) or (#text * 8)
	DrawText(math.floor((W - w) / 2), y, text)
end

--- 결과 창 (기획서 4.4절)
local function drawResult()
	local bw, bh = 200, 110
	local bx = math.floor((W - bw) / 2)
	local by = math.floor((H - bh) / 2)
	skin:drawPieces(Window.slices(bw, bh), bx, by)
	if FontReady then
		drawCenteredText(by + 12, "— 1-1 검은 안개의 숲 끝 —")
		DrawText(bx + 20, by + 38, "레벨 " .. level .. "   경험치 " .. exp)
		DrawText(bx + 20, by + 58, "골드 " .. gold)
		DrawText(bx + 20, by + 78, string.format("걸린 시간 %d초", math.floor(stageTime)))
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

	-- 스프라이트의 트랜스폼은 update()에서 커밋된다. 위치를 render에서 정하므로
	-- 그리기 직전에 update(0)을 불러야 한다 — 그러지 않으면 한 프레임 늦고,
	-- 컷씬처럼 update가 일찍 반환하는 동안에는 아예 반영되지 않는다.
	local bx = -math.floor(camX * PARALLAX) % W
	bg1.setPosition(bx - W, 0)
	bg2.setPosition(bx, 0)
	bg1.update(0)
	bg2.update(0)
	bg1.draw()
	bg2.draw()

	Tilemap.Draw(map, 1, layerCount, cx, 0)

	drawMonsters(cx)

	-- 떨어진 배낭
	if bag ~= nil then
		bagImg.setPosition(math.floor(bag.x) - 8 - cx, math.floor(bag.y) - 16)
		bagImg.update(0)
		bagImg.draw()
	end

	-- 돌팔매
	for _, s in ipairs(stones) do
		stoneImg.setPosition(math.floor(s.x) - 4 - cx, math.floor(s.y) - 4)
		stoneImg.update(0)
		stoneImg.draw()
	end

	-- 도입 컷씬의 짐도둑
	if intro ~= nil and intro.phase == "thief" then
		local mk = Stage.species.monkey
		local f = math.floor(intro.timer * 8) % 2
		thiefImg.setFrames(f, f)
		thiefImg.setCurrentFrame(f)
		thiefImg.setPosition(math.floor(intro.x) - mk.anchorX - cx,
			Stage.START.y - mk.anchorY)
		thiefImg.update(0)
		thiefImg.draw()
	end

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
	if player.invulnTimer > 0 and math.floor(player.invulnTimer * 10) % 2 == 0 then
		karto.setOpacity(110)
	else
		karto.setOpacity(255)
	end
	karto.update(0)
	karto.draw()

	drawHud()

	-- 표지 글 (상단 가운데)
	if signText ~= nil and FontReady then
		drawCenteredText(44, signText)
	end

	if DEBUG_HUD and FontReady then
		DrawText(4, 40, string.format("FPS %d  x %d y %d  %s", math.floor(fpsAvg + 0.5),
			math.floor(player.x), math.floor(player.y),
			player.onGround and "지상" or "공중"))
	end

	if pad ~= nil then pad.draw() end
	if buttons ~= nil then buttons.draw() end

	-- 나레이션 (도입, 에필로그, 게임 오버의 글)
	if gameOver ~= nil then
		fadeImg.setPosition(0, 0)
		fadeImg.setOpacity(170)
		fadeImg.update(0)
		fadeImg.draw()
		if FontReady and gameOver.phase == "choice" then
			drawCenteredText(math.floor(H / 2 - 56), "게임 오버")
		end
	end
	dialogue:draw()
	if gameOver ~= nil and gameOver.phase == "choice" then
		pauseChoice:draw()
	end

	if ending ~= nil and ending.phase == "result" then
		drawResult()
	end

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
	for _, img in ipairs({ bg1, bg2, karto, aura, fadeImg, stoneImg, bagImg, thiefImg }) do
		if img ~= nil then img.dispose() end
	end
	bg1, bg2, karto, aura, fadeImg, stoneImg, bagImg, thiefImg =
		nil, nil, nil, nil, nil, nil, nil, nil
	if hud ~= nil then
		hud.dispose()
		hud = nil
	end
	if dialogue ~= nil then
		dialogue:dispose()
		dialogue = nil
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
