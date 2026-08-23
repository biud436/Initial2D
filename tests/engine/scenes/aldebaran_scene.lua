-- 알데바란 인수 시나리오 (알데바란 1~3단계) — tests/run_engine_tests.py가 구동한다.
--
-- 게임이 실제로 여는 파일(scripts/games/aldebaran/*.lua)을 얹고 입력 재생기로
-- 처음부터 끝까지 통과한다:
--
--   타이틀 (조작 방법을 열었다 닫고 시작) → 도입 컷씬 (짐도둑과 나레이션)
--   → 일부러 다리에서 두 번 떨어져 게임 오버 → 다시 하기
--   → 대쉬, 바위 턱, 첫 거미 처치, 다리, 표지, 체크포인트, 일시 정지,
--     한 번 더 일부러 떨어져 체크포인트 부활 → 늑대에게 맞고 버서커로 잡으며
--   → 공터의 짐도둑 (돌팔매를 뚫고 몰아붙여 처치) → 배낭 → 에필로그
--   → 결과 창 → 타이틀로.
--
-- 만나는 몬스터는 "앞쪽 가까이에 살아 있으면 공격 연타"라는 규칙으로 처리한다.
-- 전투 굴림은 시드 난수(stage.lua의 SEED)라 이 시나리오는 항상 같은 결과를 낸다.
--
-- rpgdemo_scene과 같은 구조다: 씬 전환 계약을 갖춘 드라이버 위에서 시나리오
-- 전체를 Initialize 안의 고정 스텝으로 돌리고, stdout을 러너가 검사한다.
--
-- INITIAL2D_ALDEBARAN_STOP=start | title 이면 그 씬의 첫 화면을 고정한다
-- (골든 스크린샷용. start는 INITIAL2D_SKIP_INTRO와 함께 쓴다).

local replay = require("scripts/luatests/input_replay")

local r = nil
local stopMode = nil
local scenes, current, currentName, pending = nil, nil, nil, nil
local frozen = false

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

-- ---- 이동과 전투의 자동 조종 ------------------------------------------------

local jumpCd, attackCd = 0, 0

--- s.x가 구간에 들어왔고 지상에 있으면 점프 (구간마다 쿨다운이 겹침을 막는다)
local function autoJump(s, zones)
	if jumpCd > 0 then return end
	for _, z in ipairs(zones) do
		if s.x >= z and s.x <= z + 22 and s.onGround then
			r:tap("Z")
			jumpCd = 20
			return
		end
	end
end

--- 가까이(수평 range, 수직 40) 살아 있는 몬스터
local function monsterNear(s, range)
	local best, bestDist = nil, range or 48
	for _, m in ipairs(s.monsters) do
		local d = math.abs(m.x - s.x)
		if d < bestDist and math.abs(m.y - s.y) <= 40 and m.state ~= "dying" then
			best, bestDist = m, d
		end
	end
	return best
end

local CLIMB_ZONES = { 360, 490, 618 }
local ALL_ZONES = { 360, 490, 618, 830, 910, 1352, 1512 }
-- 왼쪽으로 되돌아갈 때의 점프 자리: 몸이 벽에 붙어 멈추는 x가 구간에 들게 잡는다
-- (늑대 숲 턱 오른벽 1616과 1456, 내리막 턱 오른벽 1280, 절벽 어깨 오른벽 1152)
local BACK_ZONES = { 1612, 1452, 1278, 1150 }

--- 오른쪽으로 걷다가 죽는다 (게임 오버 확인용 — 다리 구멍을 안 뛰어넘는다)
local function walkToDeath(maxTicks)
	local before = st().deaths
	r:press("RIGHT")
	for _ = 1, maxTicks do
		local s = st()
		if s.deaths > before or s.gameOver ~= nil then break end
		jumpCd = math.max(0, jumpCd - 1)
		autoJump(s, CLIMB_ZONES)
		tick(1)
	end
	r:release("RIGHT")
	tick(3)
end

--- 일시 정지를 열고 "계속 하기"로 닫는다
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

--- 나레이션(대화창)을 결정키로 끝까지 넘긴다. cond가 참이 되면 멈춘다.
local function readThrough(cond, maxTaps)
	for _ = 1, (maxTaps or 40) do
		if cond() then return true end
		r:tap("Z")
		tick(8)
	end
	return cond()
end

-- ---- 시나리오 ----------------------------------------------------------------

local function runTitle()
	print("titleScene:" .. currentName)
	tick(6)
	local ts = titleSt()
	print("titleMenuOpen:" .. tostring(ts.menuOpen))
	print("titleItems:" .. ts.items .. " index:" .. tostring(ts.index))

	-- 조작 방법을 열었다 끝까지 읽고 닫는다
	r:tap("DOWN")
	tick(4)
	r:tap("Z")
	tick(8)
	print("titleHelpOpen:" .. tostring(titleSt().helpOpen))
	readThrough(function() return not titleSt().helpOpen end)
	print("titleHelpClosed:" .. tostring(not titleSt().helpOpen))

	-- 커서를 시작으로 되돌려 결정
	r:tap("UP")
	tick(4)
	r:tap("Z")
	tick(20)                            -- 결정 여운(12) + 전환
	print("sceneAfterStart:" .. currentName)
end

local function runIntro()
	print("introActive:" .. tostring(st().intro))
	tick(110)                           -- 짐도둑이 달아난다 (1.6초)
	readThrough(function() return not st().intro end)
	print("introDone:" .. tostring(not st().intro))
end

local function runGameOver()
	-- 다리 구멍에 두 번 떨어진다: 목숨 2 → 1 → 게임 오버
	walkToDeath(1500)
	local s = st()
	print("firstDeathLives:" .. s.lives)
	walkToDeath(1500)
	readThrough(function() return st().gameOver == "choice" end)
	s = st()
	print("gameOverChoice:" .. tostring(s.gameOver == "choice"))
	print("gameOvers:" .. s.gameOvers)
	r:tap("Z")                          -- 첫 항목 "다시 하기"
	tick(8)
	s = st()
	print("retryLives:" .. s.lives)
	print("retryAtStart:" .. tostring(s.x < 100))
end

local function runStage()
	-- [A] 더블탭 대쉬
	r:press("RIGHT")
	tick(2)
	r:release("RIGHT")
	tick(2)
	r:press("RIGHT")
	tick(2)
	local x0 = st().x
	tick(1)
	print("aldebaranDash:" .. tostring(st().x - x0 > 2.5))

	-- [B] 주파: 정해 둔 구간에서 점프, 몬스터가 가까우면 공격, 늑대 앞에서 버서커
	local climbed, checked, pausedOnce, fellOnce = false, false, false, false
	local firstKill, hurtSeen, berserkOn, levelSeen = false, false, false, false
	local signSeen, stoneSeen, bossDown, endReached = false, false, false, false

	for _ = 1, 12000 do
		local s = st()

		if s.ending ~= nil then break end

		if not climbed and s.x > 640 and s.y == 320 and s.onGround then
			climbed = true
			print("aldebaranClimb:320")
		end
		if not signSeen and s.sign ~= nil then
			signSeen = true
			print("aldebaranSign:" .. s.sign)
		end
		if not checked and s.checkpoint then
			checked = true
			print("aldebaranCheckpoint:true")
			print("aldebaranBridge:true")
		end
		if checked and not pausedOnce then
			pausedOnce = true
			pauseAndResume()
		end
		-- 늑대 숲을 지나면 일부러 다리까지 되돌아가 떨어진다 (부활 확인).
		-- 목숨이 둘 다 있는 채로 전투를 끝내 두고 시험하는 순서다.
		if s.x > 1690 and not fellOnce then
			fellOnce = true
			r:release("RIGHT")
			r:press("LEFT")
			local before = st().deaths
			for _ = 1, 1500 do
				local bs = st()
				if bs.deaths > before then break end
				jumpCd = math.max(0, jumpCd - 1)
				autoJump(bs, BACK_ZONES)
				tick(1)
			end
			r:release("LEFT")
			tick(3)
			local rs = st()
			print("aldebaranRespawnX:" .. math.floor(rs.x))
			print("aldebaranRespawnLives:" .. rs.lives)
			print("aldebaranRespawnHp:" .. tostring(rs.hp == rs.maxHp))
			r:press("RIGHT")
			tick(2)
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
		if not levelSeen and s.level >= 2 then
			levelSeen = true
			print("aldebaranLevelUp:" .. s.level)
			print("aldebaranLevelHeal:" .. tostring(s.hp == s.maxHp))
		end
		if not stoneSeen and s.stones > 0 then
			stoneSeen = true
			print("aldebaranStone:true")
		end
		if not bossDown and s.bag then
			bossDown = true
			print("aldebaranBossDown:true")
		end
		if not endReached and s.x > 1980 and s.onGround then
			endReached = true
			print("aldebaranEnd:" .. math.floor(s.y))
		end

		jumpCd = math.max(0, jumpCd - 1)
		attackCd = math.max(0, attackCd - 1)

		local near = monsterNear(s)
		if near ~= nil and s.onGround then
			-- 늑대 앞에서는 매번 버서커를 켠다 (MP가 있는 한)
			if near.species == "늑대 인간" and not s.berserk and s.mp >= 10 then
				local mpBefore = s.mp
				r:tap("C")
				tick(3)
				local b = st()
				if not berserkOn then
					berserkOn = true
					print("aldebaranBerserk:" .. tostring(b.berserk))
					print("aldebaranBerserkMp:" .. tostring(b.mp == mpBefore - 10))
				end
			end
			if attackCd == 0 and math.abs(near.x - s.x) < 34 then
				r:tap("X")
				attackCd = 8
			end
		else
			autoJump(s, ALL_ZONES)
		end

		tick(1)
	end
	r:release("RIGHT")
	tick(2)

	local s = st()
	if s.ending ~= nil then
		print("aldebaranFalls:" .. s.falls)
		print("aldebaranDeaths:" .. s.deaths)
		print("aldebaranEpilogue:" .. tostring(s.ending))
	else
		print(string.format("aldebaranTimeout x:%d y:%d hp:%s 몬스터:%d",
			math.floor(s.x), math.floor(s.y), tostring(s.hp), #s.monsters))
	end
end

local function runEnding()
	readThrough(function() return st().ending == "result" end)
	local s = st()
	print("aldebaranResult:" .. tostring(s.ending == "result"))
	print(string.format("aldebaranResultStats:level=%d gold=%d", s.level, s.gold))
	tick(15)                            -- 결과 창의 잠금 여유
	r:tap("Z")
	tick(6)
	print("finalScene:" .. tostring(currentName))
	print("aldebaranAcceptDone:true")
end

--- 터치 조작의 끝-끝 검증 (stop=touch): 가상 패드로 걷고, 버튼으로 뛰고 베고,
-- 정지 버튼과 항목 누름으로 일시 정지를 여닫는다. 재생기의 마우스 이벤트가
-- SDL의 "첫 손가락 = 마우스" 매핑과 같은 표면이다.
local function runTouch()
	local function press(x, y, holdTicks)
		r:schedule({ mouse = { x = x, y = y } }, 1)
		r:schedule({ click = 0 }, 2)
		if holdTicks == nil then
			r:schedule({ unclick = 0 }, 4)
		end
	end

	-- 패드 오른쪽을 누르고 있으면 걷는다 (패드 중심 52,396의 오른쪽)
	local x0 = st().x
	r:schedule({ mouse = { x = 82, y = 396 } }, 1)
	r:schedule({ click = 0 }, 2)
	tick(30)
	print("touchWalk:" .. tostring(st().x > x0 + 10))
	r:schedule({ unclick = 0 }, 1)
	tick(6)

	press(290, 418)                     -- 점프 버튼
	tick(6)
	print("touchJump:" .. tostring(not st().onGround))
	tick(60)                            -- 착지를 기다린다

	press(350, 410)                     -- 공격 버튼
	tick(4)
	print("touchAttack:" .. tostring(st().attacking))
	tick(30)

	press(363, 21)                      -- 정지 버튼
	tick(8)
	print("touchPause:" .. tostring(st().paused))
	press(160, 208)                     -- "계속 하기" 항목을 직접 누른다
	tick(8)
	print("touchResume:" .. tostring(not st().paused))
end

function Initialize()
	stopMode = (os.getenv ~= nil) and os.getenv("INITIAL2D_ALDEBARAN_STOP") or nil

	require("scripts/games/aldebaran/title")
	require("scripts/games/aldebaran/game")
	scenes = { aldebaran_title = AldebaranTitleScene, aldebaran = AldebaranScene }

	-- 허브(main.lua)와 같은 폰트 준비 — 골든에 메뉴와 HUD의 글자가 나오게
	FontReady = PreparaFont("./resources/fonts/hangul.fnt")

	if stopMode == "touch" then
		currentName = "aldebaran"
		current = AldebaranScene
		r = replay.new({})
		r:install()
		current.init()
		runTouch()
		r:restore()
		stopMode = "start"               -- 이후에는 얼린 화면
		return
	end

	if stopMode == "title" then
		currentName = "aldebaran_title"
		current = AldebaranTitleScene
		current.init()
		for _ = 1, 30 do current.update(16) end   -- 메뉴 창이 다 열린 뒤에 얼린다
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
	frozen = true
end

function Update(elapsed)
	if stopMode ~= nil then
		current.update(0)               -- 화면 고정 (골든)
		return
	end
	-- 시나리오는 Initialize에서 끝났다 — 끝난 화면을 얼려 둔다
end

function Render()
	if current ~= nil then current.render() end
end

function Destroy()
	if current ~= nil then current.destroy() end
	if r ~= nil then r:restore() end
end
