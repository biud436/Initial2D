-- 알데바란 씬 검증 (알데바란 1단계) — tests/run_engine_tests.py가 구동한다.
--
-- 진짜 씬(scripts/games/aldebaran/game.lua)과 진짜 맵을 입력 재생기로 몰아
-- 스테이지 왼쪽 절반을 실제로 주파한다:
--
--   입구에서 더블탭 대쉬 → 바위 턱 셋을 점프로 올라 → 낡은 다리의 구멍 둘을
--   뛰어넘어 → 이정표 구간(x 1024 너머)까지.
--
-- rpgdemo_scene과 같은 구조다: 시나리오 전체를 Initialize 안에서 고정 스텝으로
-- 돌리고 (INITIAL2D_EXIT_AFTER는 렌더 프레임 단위라 Update에 걸 수 없다),
-- 좌표와 낙하 횟수를 stdout으로 남기면 러너가 검사한다. 이후 렌더 프레임은
-- 끝난 화면을 얼려 둔 것이다.
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

local function runScenario()
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

	-- [B] 오른쪽으로 계속 걸으며, 정해 둔 x에 닿으면 점프한다
	--     (턱 셋의 벽 앞 셋, 다리 구멍 앞 둘, 늑대 숲의 낮은 턱 둘)
	local jumps = { 360, 490, 618, 830, 910, 1352, 1512 }
	local jumpIndex = 1
	local cooldown = 0
	local climbed, arrived = false, false
	for _ = 1, 3600 do
		local s = st()
		if not climbed and s.x > 1090 and s.onGround then
			climbed = true
			print("aldebaranClimb:" .. math.floor(s.y))
			print("aldebaranBridge:true")
		end
		if s.x > 1980 and s.onGround then
			arrived = true
			break
		end
		cooldown = math.max(0, cooldown - 1)
		if jumpIndex <= #jumps and s.x >= jumps[jumpIndex]
				and s.onGround and cooldown == 0 then
			r:tap("Z")
			jumpIndex = jumpIndex + 1
			cooldown = 20
		end
		tick(1)
	end
	r:release("RIGHT")
	tick(2)

	local s = st()
	if arrived then
		print("aldebaranEnd:" .. math.floor(s.y))
		print("aldebaranFalls:" .. s.falls)
		print("aldebaranDone:true")
	else
		print(string.format("aldebaranTimeout x:%d y:%d jumpIndex:%d falls:%d",
			math.floor(s.x), math.floor(s.y), jumpIndex, s.falls))
	end
end

function Initialize()
	stopMode = (os.getenv ~= nil) and os.getenv("INITIAL2D_ALDEBARAN_STOP") or nil

	require("scripts/games/aldebaran/game")
	AldebaranScene.init()
	print(string.format("aldebaranView:%dx%d", WindowWidth(), WindowHeight()))
	local s = st()
	print(string.format("aldebaranStart:%d,%d", s.x, s.y))

	if stopMode == nil then
		r = replay.new({})
		r:install()
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
