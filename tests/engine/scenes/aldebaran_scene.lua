-- 알데바란 씬 검증 (알데바란 1~2단계) — tests/run_engine_tests.py가 구동한다.
--
-- 진짜 씬(scripts/games/aldebaran/game.lua)과 진짜 맵과 진짜 몬스터 배치를
-- 입력 재생기로 몰아 스테이지를 실제로 주파한다:
--
--   입구에서 더블탭 대쉬 → 바위 턱 셋을 점프로 올라 (첫 전갈거미를 콤보로 잡고)
--   → 낡은 다리의 구멍 둘을 뛰어넘어 → 이정표(체크포인트)에서 일시 정지를
--   열었다 닫고 → 늑대 숲에서 늑대에게 맞고, 버서커를 켜 잡으며 → 공터까지.
--
-- 만나는 몬스터는 "앞쪽 가까이에 살아 있는 몬스터가 있으면 공격 연타"라는
-- 단순한 규칙으로 처리한다. 전투 굴림은 시드 난수(stage.lua의 SEED)라 이
-- 시나리오는 항상 같은 결과를 낸다.
--
-- rpgdemo_scene과 같은 구조다: 시나리오 전체를 Initialize 안에서 고정 스텝으로
-- 돌리고 (INITIAL2D_EXIT_AFTER는 렌더 프레임 단위), stdout을 러너가 검사한다.
--
-- INITIAL2D_ALDEBARAN_STOP=start 면 시나리오 없이 서 있는 첫 화면을 고정한다
-- (골든 스크린샷용).

local replay = require("scripts/luatests/input_replay")

local r = nil
local stopMode = nil

function SwitchScene(name)
	print("aldebaranSwitch:" .. tostring(name))
end

local function tick(n)
	for _ = 1, (n or 1) do
		r:tick()
		AldebaranScene.update(16)
	end
end

local function st()
	return AldebaranScene.status()
end

--- 앞뒤 48px, 위아래 40px 안의 살아 있는 몬스터 (가장 가까운 것)
local function monsterNear(s, range)
	local best, bestDist = nil, range or 48
	for _, m in ipairs(s.monsters) do
		local d = math.abs(m.x - s.x)
		if d < bestDist and math.abs(m.y - s.y) <= 40
				and m.state ~= "dying" then
			best, bestDist = m, d
		end
	end
	return best
end

--- 일시 정지를 열고 "계속 하기"로 닫는다 (기획서 8.3절)
local function pauseAndResume()
	r:release("RIGHT")
	tick(3)
	r:tap("ESCAPE")
	tick(10)
	print("aldebaranPaused:" .. tostring(st().paused))
	r:tap("Z")                      -- 커서는 첫 항목 "계속 하기"
	tick(10)
	print("aldebaranResumed:" .. tostring(not st().paused))
	r:press("RIGHT")
	tick(2)
end

local function runScenario()
	local maxHp0 = st().maxHp

	-- [A] 더블탭 대쉬: 오른쪽을 짧게 두 번 (판정 창 0.25초 안), 두 번째는 계속
	r:press("RIGHT")
	tick(2)
	r:release("RIGHT")
	tick(2)
	r:press("RIGHT")
	tick(2)                                   -- 여기서 대쉬가 발동한다
	local x0 = st().x
	tick(1)
	local dashStep = st().x - x0              -- 걷기 1.5px, 대쉬 3.2px
	print("aldebaranDash:" .. tostring(dashStep > 2.5))

	-- [B] 주파. 정해 둔 x에서 점프하고, 몬스터가 가까우면 공격을 연타한다.
	local jumps = { 360, 490, 618, 830, 910, 1352, 1512 }
	local jumpIndex = 1
	local jumpCd, attackCd = 0, 0
	local climbed, checked, paused = false, false, false
	local firstKill, hurtSeen, berserkOn, levelSeen = false, false, false, false
	local arrived = false

	for _ = 1, 9000 do
		local s = st()

		-- 이정표 (마일스톤 보고는 한 번씩)
		if not climbed and s.x > 640 and s.y == 320 and s.onGround then
			climbed = true
			print("aldebaranClimb:320")
		end
		if not checked and s.checkpoint then
			checked = true
			print("aldebaranCheckpoint:true")
			print("aldebaranBridge:true")     -- 이정표는 다리 건너에 있다
		end
		-- 체크포인트 직후의 조용한 자리에서 일시 정지를 확인하고,
		-- 일부러 다리 구멍으로 되돌아가 떨어져 본다 (목숨과 부활 확인)
		if checked and not paused then
			paused = true
			pauseAndResume()

			r:release("RIGHT")
			r:press("LEFT")
			for _ = 1, 600 do
				tick(1)
				if st().deaths >= 1 then break end
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

		-- 첫 처치 (전갈거미): 경험치와 골드가 들어온다
		if not firstKill and s.exp >= 5 then
			firstKill = true
			print(string.format("aldebaranFirstKill:exp=%d,gold=%d", s.exp, s.gold))
		end
		-- 처음 맞았을 때: HP가 줄고 무적 시간이 선다
		if not hurtSeen and s.hp < s.maxHp then
			hurtSeen = true
			print("aldebaranHurt:" .. s.hp)
			print("aldebaranHurtInvuln:" .. tostring(s.invuln))
		end
		-- 레벨 업: 전량 회복이 함께 온다
		if not levelSeen and s.level >= 2 then
			levelSeen = true
			print("aldebaranLevelUp:" .. s.level)
			print("aldebaranLevelHeal:" .. tostring(s.hp == s.maxHp))
		end

		if s.x > 1980 and s.onGround then
			arrived = true
			break
		end

		jumpCd = math.max(0, jumpCd - 1)
		attackCd = math.max(0, attackCd - 1)

		local near = monsterNear(s)
		if near ~= nil and s.onGround then
			-- 늑대 앞에서는 버서커를 켠다 (MP 10)
			if not berserkOn and near.species == "늑대 인간" and s.mp >= 10 then
				local mpBefore = s.mp
				r:tap("C")
				tick(3)
				local b = st()
				berserkOn = true
				print("aldebaranBerserk:" .. tostring(b.berserk))
				print("aldebaranBerserkMp:" .. tostring(b.mp == mpBefore - 10))
			end
			if attackCd == 0 and math.abs(near.x - s.x) < 34 then
				r:tap("X")
				attackCd = 8
			end
		elseif jumpIndex <= #jumps and s.x >= jumps[jumpIndex]
				and s.onGround and jumpCd == 0 then
			r:tap("Z")
			jumpIndex = jumpIndex + 1
			jumpCd = 20
		end

		tick(1)
	end
	r:release("RIGHT")
	tick(2)

	local s = st()
	if arrived then
		print("aldebaranEnd:" .. math.floor(s.y))
		print("aldebaranFalls:" .. s.falls)
		print("aldebaranDeaths:" .. s.deaths)
		print(string.format("aldebaranCleared:%d/7 level=%d gold=%d",
			7 - #s.monsters, s.level, s.gold))
		print("aldebaranDone:true")
	else
		print(string.format("aldebaranTimeout x:%d y:%d hp:%s jumpIndex:%d 몬스터:%d",
			math.floor(s.x), math.floor(s.y), tostring(s.hp), jumpIndex, #s.monsters))
	end
end

function Initialize()
	stopMode = (os.getenv ~= nil) and os.getenv("INITIAL2D_ALDEBARAN_STOP") or nil

	require("scripts/games/aldebaran/game")

	if stopMode == nil then
		r = replay.new({})
		r:install()
	end

	AldebaranScene.init()
	print(string.format("aldebaranView:%dx%d", WindowWidth(), WindowHeight()))
	local s = st()
	print(string.format("aldebaranStart:%d,%d", s.x, s.y))
	print("aldebaranMonsters:" .. #s.monsters)

	if stopMode == nil then
		runScenario()
		r:restore()
	end
end

function Update(elapsed)
	if stopMode ~= nil then
		AldebaranScene.update(0)   -- 화면 고정 (골든)
	end
	-- 시나리오는 Initialize에서 끝났다 — 끝난 화면을 얼려 둔다
end

function Render()
	AldebaranScene.render()
end

function Destroy()
	AldebaranScene.destroy()
end
