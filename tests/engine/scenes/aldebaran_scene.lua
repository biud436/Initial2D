-- 알데바란 인수 시나리오 — tests/run_engine_tests.py가 구동한다.
--
-- 게임이 실제로 여는 파일(scripts/games/aldebaran/*.lua)을 얹고 입력 재생기로
-- 처음부터 끝까지 통과한다:
--
--   타이틀 → 도입 컷씬 → (일부러 맞아 죽어) 게임 오버와 다시 하기
--   → 다섯 구간을 지나며 흔적 다섯을 줍고 힘을 익힌다
--   → 검은 늑대와 짐도둑(두 판) → 배낭 → 에필로그 → 결과 창 → 타이틀
--
-- **맵 좌표를 박아 넣지 않는다** (docs/plans/aldebaran-5-stage.md 6.3절).
-- 앞이 막히면 뛰고, 발을 헛디디면 공중에서 한 번 더 뛰고, 벨 수 있는 적이 있으면
-- 벤다. 그래서 지형이 바뀌어도 시나리오가 산다.
--
-- 전투 굴림은 시드 난수(stage.lua의 SEED)라 이 시나리오는 항상 같은 결과를 낸다.
--
-- INITIAL2D_ALDEBARAN_STOP=start | title | touch 면 그 화면을 고정한다 (골든용).

local replay = require("scripts/luatests/input_replay")

local r = nil
local stopMode = nil
local scenes, current, currentName, pending = nil, nil, nil, nil

function SwitchScene(name)
	pending = name
end

local function tick(n)
	for _ = 1, (n or 1) do
		if pending ~= nil then
			current.destroy()
			currentName = pending
			current = scenes[pending]
			pending = nil
			current.init()
		end
		r:tick()
		current.update(16)
	end
end

local function st()
	return AldebaranScene.status()
end

local function titleSt()
	return AldebaranTitleScene.status()
end

--- 벨 수 있는 거리(수평 34, 수직 24) 안의 살아 있는 몬스터
local function monsterNear(s, range)
	local best, bestDist = nil, range or 34
	for _, m in ipairs(s.monsters) do
		local d = math.abs(m.x - s.x)
		if d < bestDist and math.abs(m.y - s.y) < 24 and m.state ~= "dying" then
			best, bestDist = m, d
		end
	end
	return best
end

local function pauseAndResume()
	r:release("RIGHT")
	tick(3)
	r:tap("ESCAPE")
	tick(10)
	print("aldebaranPaused:" .. tostring(st().paused))
	r:tap("Z")
	tick(10)
	print("aldebaranResumed:" .. tostring(not st().paused))
	r:press("RIGHT")
	tick(2)
end

local function readThrough(cond, maxTaps)
	for _ = 1, (maxTaps or 40) do
		if cond() then return true end
		r:tap("Z")
		tick(8)
	end
	return cond()
end

-- ---- 자동 조종 ---------------------------------------------------------------

local drive = { last = -1, stuck = 0, hop = 0, atk = 0,
	wasGround = true, saved = false, tick = 0 }

local function autoStep()
	local s = st()
	drive.tick = drive.tick + 1
	drive.hop = math.max(0, drive.hop - 1)
	drive.atk = math.max(0, drive.atk - 1)

	-- 발을 헛디뎠으면 (뛰지 않았는데 공중이면) 공중 점프로 건넌다
	if drive.wasGround and not s.onGround and drive.hop == 0 and not drive.saved then
		r:tap("Z")
		drive.saved = true
	end
	if s.onGround then drive.saved = false end
	drive.wasGround = s.onGround

	local near = monsterNear(s)
	if near ~= nil and s.onGround then
		-- 늑대가 붙으면 폭주를 쓴다 (익히지 않았거나 쿨타임이면 먹지 않는다)
		if near.species ~= "밀림 전갈거미" and not s.berserk then
			r:tap("C")
		end
		if drive.atk == 0 then
			r:tap("X")
			drive.atk = 8
		end
	elseif s.onGround and drive.hop == 0 then
		if math.abs(s.x - drive.last) < 0.2 then
			drive.stuck = drive.stuck + 1
		else
			drive.stuck = 0
		end
		if drive.stuck > 3 or drive.tick % 22 == 0 then
			r:tap("Z")
			r:schedule({ press = "Z" }, 9)      -- 2단 점프로 구멍을 넘는다
			r:schedule({ release = "Z" }, 10)
			drive.hop = 16
			drive.stuck = 0
		end
	end
	drive.last = s.x
	tick(1)
end

-- ---- 터치 조작의 끝-끝 검증 (stop=touch) ------------------------------------

local function runTouch()
	local function press(x, y)
		r:schedule({ mouse = { x = x, y = y } }, 1)
		r:schedule({ click = 0 }, 2)
		r:schedule({ unclick = 0 }, 4)
	end

	-- 공격을 먼저 본다. 걷다 보면 첫 거미가 붙어 피격 경직에 걸리기 때문이다.
	press(350, 410)
	local swung = false
	for _ = 1, 12 do
		tick(1)
		if st().attacking then swung = true end
	end
	print("touchAttack:" .. tostring(swung))
	tick(24)

	local x0 = st().x
	r:schedule({ mouse = { x = 82, y = 396 } }, 1)
	r:schedule({ click = 0 }, 2)
	tick(30)
	print("touchWalk:" .. tostring(st().x > x0 + 10))
	r:schedule({ unclick = 0 }, 1)
	tick(6)

	press(290, 418)
	tick(6)
	print("touchJump:" .. tostring(not st().onGround))
	tick(60)

	press(363, 21)
	tick(8)
	print("touchPause:" .. tostring(st().paused))
	press(160, 208)
	tick(8)
	print("touchResume:" .. tostring(not st().paused))
end

-- ---- 시나리오 ----------------------------------------------------------------

local function runTitle()
	print("titleScene:" .. currentName)
	tick(6)
	local ts = titleSt()
	print("titleMenuOpen:" .. tostring(ts.menuOpen))
	print("titleItems:" .. ts.items .. " index:" .. tostring(ts.index))

	r:tap("DOWN")
	tick(4)
	r:tap("Z")
	tick(8)
	print("titleHelpOpen:" .. tostring(titleSt().helpOpen))
	readThrough(function() return not titleSt().helpOpen end)
	print("titleHelpClosed:" .. tostring(not titleSt().helpOpen))

	r:tap("UP")
	tick(4)
	r:tap("Z")
	tick(20)
	print("sceneAfterStart:" .. currentName)
end

local function runIntro()
	print("introActive:" .. tostring(st().intro))
	tick(110)
	print("introWindow:" .. tostring(st().dialogueShown))
	readThrough(function() return not st().intro end)
	print("introDone:" .. tostring(not st().intro))
	tick(30)
	print("introWindowClosed:" .. tostring(not st().dialogueShown))
end

--- 첫 거미 앞에 서서 맞기만 한다. 목숨 둘이 다하면 게임 오버.
local function runGameOver()
	r:press("RIGHT")
	for _ = 1, 400 do
		if monsterNear(st(), 40) ~= nil then break end
		tick(1)
	end
	r:release("RIGHT")
	local firstLoss = false
	for _ = 1, 3000 do
		local s = st()
		if not firstLoss and s.lives < 2 then
			firstLoss = true
			print("firstDeathLives:" .. s.lives)
		end
		if s.gameOver ~= nil then break end
		tick(1)
	end
	readThrough(function() return st().gameOver == "choice" end)
	local s = st()
	print("gameOverChoice:" .. tostring(s.gameOver == "choice"))
	print("gameOvers:" .. s.gameOvers)
	r:tap("Z")
	tick(8)
	s = st()
	print("retryLives:" .. s.lives)
	print("retryAtStart:" .. tostring(s.x < 100))
end

local function runStage()
	-- 더블탭 대쉬
	r:press("RIGHT")
	tick(2)
	r:release("RIGHT")
	tick(2)
	r:press("RIGHT")
	tick(2)
	local x0 = st().x
	tick(1)
	print("aldebaranDash:" .. tostring(st().x - x0 > 2.5))

	local seen = {}
	local paused = false
	local firstKill, hurtSeen, berserkOn, levelSeen = false, false, false, false
	local stoneSeen, bossDown, blackDown, phase2 = false, false, false, false

	for _ = 1, 30000 do
		local s = st()
		if s.ending ~= nil then break end

		if #s.found > #seen then
			for i = #seen + 1, #s.found do
				seen[i] = s.found[i]
				print("aldebaranFound" .. i .. ":" .. s.found[i])
			end
		end
		if not levelSeen and s.level >= 2 then
			levelSeen = true
			print("aldebaranLevelUp:" .. s.level)
			print("aldebaranLevelHeal:" .. tostring(s.hp == s.maxHp))
		end
		if not firstKill and s.exp >= 5 then
			firstKill = true
			print(string.format("aldebaranFirstKill:exp=%d,gold=%d", s.exp, s.gold))
		end
		if not hurtSeen and s.hp < s.maxHp then
			hurtSeen = true
			print("aldebaranHurt:" .. s.hp)
			print("aldebaranHurtInvuln:" .. tostring(s.invuln))
		end
		if not berserkOn and s.berserk then
			berserkOn = true
			print("aldebaranBerserk:true")
		end
		if not stoneSeen and s.stones > 0 then
			stoneSeen = true
			print("aldebaranStone:true")
		end
		if not paused and s.checkpoint then
			paused = true
			pauseAndResume()
		end

		local black, boss = nil, nil
		for _, m in ipairs(s.monsters) do
			if m.species == "검은 늑대" then black = m end
			if m.boss then boss = m end
		end
		if not blackDown and black == nil and s.x > 3260 then
			blackDown = true
			print("aldebaranBlackWolfDown:true")
		end
		if not phase2 and boss ~= nil and boss.phase2 then
			phase2 = true
			print("aldebaranBossPhase2:true")
		end
		if not bossDown and s.bag then
			bossDown = true
			print("aldebaranBossDown:true")
		end
		autoStep()
	end
	r:release("RIGHT")
	tick(2)

	local s = st()
	print("aldebaranFoundCount:" .. #s.found)
	if s.ending ~= nil then
		print("aldebaranDeaths:" .. s.deaths)
		print("aldebaranEpilogue:" .. tostring(s.ending))
	else
		print(string.format("aldebaranTimeout x:%d y:%d hp:%s 몬스터:%d 흔적:%d",
			math.floor(s.x), math.floor(s.y), tostring(s.hp), #s.monsters, #s.found))
	end
end

local function runEnding()
	readThrough(function() return st().ending == "result" end, 60)
	local s = st()
	print("aldebaranResult:" .. tostring(s.ending == "result"))
	print(string.format("aldebaranResultStats:level=%d gold=%d", s.level, s.gold))
	tick(15)
	r:tap("Z")
	tick(6)
	print("finalScene:" .. tostring(currentName))
	print("aldebaranAcceptDone:true")
end

function Initialize()
	stopMode = (os.getenv ~= nil) and os.getenv("INITIAL2D_ALDEBARAN_STOP") or nil

	require("scripts/games/aldebaran/title")
	require("scripts/games/aldebaran/game")
	scenes = { aldebaran_title = AldebaranTitleScene, aldebaran = AldebaranScene }
	FontReady = PreparaFont("./resources/fonts/hangul.fnt")

	if stopMode == "touch" then
		currentName = "aldebaran"
		current = AldebaranScene
		r = replay.new({})
		r:install()
		current.init()
		runTouch()
		r:restore()
		stopMode = "start"
		return
	end

	if stopMode == "title" then
		currentName = "aldebaran_title"
		current = AldebaranTitleScene
		current.init()
		for _ = 1, 30 do current.update(16) end
		return
	elseif stopMode ~= nil then
		currentName = "aldebaran"
		current = AldebaranScene
		current.init()
		local s = st()
		print(string.format("aldebaranStart:%d,%d", s.x, s.y))
		return
	end

	r = replay.new({})
	r:install()

	currentName = "aldebaran_title"
	current = AldebaranTitleScene
	current.init()
	print(string.format("aldebaranView:%dx%d", WindowWidth(), WindowHeight()))

	runTitle()
	print("aldebaranMonsters:" .. #st().monsters)
	runIntro()
	runGameOver()
	runStage()
	runEnding()

	r:restore()
end

function Update(elapsed)
	if stopMode ~= nil then
		current.update(0)
	end
end

function Render()
	if current ~= nil then current.render() end
end

function Destroy()
	if current ~= nil then current.destroy() end
	if r ~= nil then r:restore() end
end
