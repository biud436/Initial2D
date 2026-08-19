-- 데모 인수 테스트 씬 (8단계) — tests/run_engine_tests.py가 구동한다.
--
-- 로드맵 전체의 인수 테스트다. 가짜 씬이 아니라 **게임이 실제로 여는 파일**
-- (scripts/games/rpgdemo/title.lua, game.lua, scripts/maps/*.lua)을 그대로 얹고,
-- 입력 재생기(tests/lua/input_replay.lua)로 사람이 하듯 키를 눌러
--   타이틀 → 시작 → 마을 → 촌장과 대화 → 선택지 2번 → 집 출입
-- 을 한 번에 통과시킨다.
--
-- 프레임 진행은 여기서 직접 돌린다 (엔진의 Update를 기다리지 않는다). 화면
-- 렌더 프레임과 게임 tick은 헤드리스에서 비율이 다르므로, tick을 손으로 돌려야
-- 결과가 재현된다 — 같은 시나리오는 항상 같은 좌표와 같은 대사를 낸다.
--
-- INITIAL2D_DEMO_STOP 으로 중간에서 멈춰 그 화면을 골든으로 남긴다.
--   title   타이틀 메뉴가 열린 채로      village 마을에 막 들어선 채로
--   (없음)  시나리오 전체를 끝까지

local Replay = require("scripts/luatests/input_replay")

require("scripts/games/rpgdemo/title")
require("scripts/games/rpgdemo/game")

local STOP = (os.getenv ~= nil) and os.getenv("INITIAL2D_DEMO_STOP") or nil

local scenes = { title = RpgDemoTitleScene, rpg = RpgDemoScene }
local current, pending, currentName = nil, nil, nil
local replay = nil
local frozen = false

-- 허브(scripts/main.lua)와 같은 씬 전환 계약
function SwitchScene(name)
	if scenes[name] ~= nil then pending = name end
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
		replay:tick()
		current.update(16)
	end
end

--- 조건이 참이 될 때까지 돌린다. 못 만나면 timeout을 남긴다 (무한 루프 방지).
local function tickUntil(label, cond, limit)
	limit = limit or 600
	for i = 1, limit do
		if cond() then
			print(label .. ":" .. i)
			return true
		end
		tick(1)
	end
	print(label .. ":timeout")
	return false
end

local function status()
	return RpgDemoScene.status()
end

--- 지금 대화창에 보이는 글자 (쪽의 줄을 이어 붙인다)
local function dialogueText()
	return table.concat(status().lines or {}, " ")
end

--- 방향키를 붙들고 목표 칸에 닿을 때까지 걷는다.
-- 그리드 이동은 출발하는 순간 목적지 칸을 점유하므로(5단계), 목표 번호가 보이면
-- 바로 키를 뗀다 — 한 tick만 늦어도 다음 칸으로 출발해 버린다. NPC가 길을
-- 막으면 그 자리에 서서 기다리다가 비면 다시 걷는다 (키를 계속 붙들고 있으므로).
local function walk(key, get, target, label)
	replay:press(key)
	local ok = tickUntil(label, function() return get() == target end, 900)
	replay:release(key)
	tickUntil(label .. "Stop", function() return not status().moving end, 120)
	return ok
end

local function tx() return status().tx end
local function ty() return status().ty end

function Initialize()
	AUTOPLAY = false           -- 입력은 시나리오가 준다
	FontReady = PreparaFont("./resources/fonts/hangul.fnt")

	replay = Replay.new({})
	replay:install()

	current, currentName = scenes.title, "title"
	current.init()

	-- ---- [A] 타이틀 --------------------------------------------------------
	tick(8)                     -- 창이 다 열릴 때까지 (openFrames 기본 4)
	local ts = RpgDemoTitleScene.status()
	print("titleScene:" .. currentName)
	print("titleMenuOpen:" .. tostring(ts.menuOpen))
	print("titleItems:" .. tostring(ts.items) .. " index:" .. tostring(ts.index))

	if STOP == "title" then
		frozen = true
		return
	end

	-- 커서를 "조작 방법"으로 내려 도움말을 열어 본다
	replay:tap("DOWN"); tick(2)
	replay:tap("Z"); tick(3)
	print("helpCursor:" .. tostring(RpgDemoTitleScene.status().index))
	print("helpShown:" .. tostring(RpgDemoTitleScene.status().helpOpen))
	-- 도움말을 끝까지 넘긴다
	for _ = 1, 8 do
		replay:tap("Z")
		tick(6)
	end
	print("helpClosed:" .. tostring(not RpgDemoTitleScene.status().helpOpen))
	print("menuBack:" .. tostring(RpgDemoTitleScene.status().menuOpen))

	-- 커서를 "시작"으로 올려 결정
	replay:tap("UP"); tick(2)
	replay:tap("Z"); tick(2)
	tickUntil("startSwitch", function() return currentName == "rpg" end, 60)
	print("sceneAfterStart:" .. tostring(currentName))

	-- ---- [B] 마을 ----------------------------------------------------------
	tickUntil("fadeIn", function() return not status().fading end, 60)
	local st = status()
	print("mapLoaded:" .. tostring(st.map) .. " error:" .. tostring(st.error))
	print("playerAt:" .. tostring(st.tx) .. "," .. tostring(st.ty))

	if STOP == "village" then
		frozen = true
		return
	end

	-- ---- [C] 촌장에게 말 걸기 ----------------------------------------------
	-- 시작 칸(34,21)에서 왼쪽으로 두 칸, 위를 보면 촌장(32,20)이 앞에 선다
	walk("LEFT", tx, 32, "walkLeft")
	print("beforeTalkAt:" .. tostring(tx()) .. "," .. tostring(ty()))

	replay:press("UP")          -- 붙들면 방향만 돌고 벽(촌장)에 막힌다
	tick(10)
	replay:release("UP")
	tick(2)
	print("facing:" .. tostring(status().dir))

	replay:tap("Z")
	tickUntil("talkStart", function() return status().talking end, 60)
	tick(80)                     -- 타자 효과가 다 나올 때까지
	print("elderLine:" .. dialogueText())

	-- 대사를 넘기면 선택지가 뜬다. 아래로 내려 2번을 고른다.
	replay:tap("Z"); tick(4)
	print("choiceOpen:" .. tostring(status().talking))
	replay:tap("DOWN"); tick(3)
	replay:tap("Z"); tick(4)
	tick(80)
	print("branchLine:" .. dialogueText())
	replay:tap("Z"); tick(4)
	tickUntil("talkEnd", function() return not status().busy end, 120)

	-- ---- [D] 집에 들어갔다 나오기 ------------------------------------------
	-- 문(13,14) 앞까지 걸어가 밟는다. 길은 y=21 가로줄을 따라간다.
	walk("LEFT", tx, 13, "walkToDoorX")
	walk("UP", ty, 15, "walkToDoorY")
	replay:press("UP")
	tickUntil("enterRoom", function() return status().map == "room" end, 300)
	replay:release("UP")
	tickUntil("roomFade", function() return not status().fading end, 60)
	local rs = status()
	print("roomAt:" .. tostring(rs.tx) .. "," .. tostring(rs.ty))
	print("autoBusy:" .. tostring(rs.busy or rs.talking))
	tick(80)
	print("autoLine:" .. dialogueText())
	replay:tap("Z"); tick(4)
	tickUntil("autoEnd", function() return not status().busy end, 120)

	-- 아래 출입구(10,13)를 밟아 마을로 돌아간다
	replay:press("DOWN")
	tickUntil("backToVillage", function() return status().map == "village" end, 300)
	replay:release("DOWN")
	tickUntil("villageFade", function() return not status().fading end, 60)
	local vs = status()
	print("backAt:" .. tostring(vs.tx) .. "," .. tostring(vs.ty))
	print("finalScene:" .. tostring(currentName))
	print("demoDone:true")
	frozen = true
end

function Update(elapsed)
	-- 시나리오가 끝난 뒤에는 화면을 얼려 둔다 (골든이 캡처 프레임에 흔들리지 않게)
	if frozen then return end
end

function Render()
	if current ~= nil then current.render() end
end

function Destroy()
	if current ~= nil then current.destroy() end
	if replay ~= nil then replay:restore() end
end
