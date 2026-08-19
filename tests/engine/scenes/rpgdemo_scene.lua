-- 데모 인수 테스트 씬 (9단계) — tests/run_engine_tests.py가 구동한다.
--
-- 로드맵 전체의 인수 테스트다. 가짜 씬이 아니라 **게임이 실제로 여는 파일**
-- (scripts/games/rpgdemo/title.lua, game.lua, scripts/maps/port_town.lua, inn.lua)을
-- 그대로 얹고, 입력 재생기(tests/lua/input_replay.lua)로 사람이 하듯 키를 눌러
-- 기획서(docs/design/port-town.md)의 흐름을 한 번에 통과시킨다.
--
--   타이틀 → 시작 → 부두 도착 → 생선 장수 → 창고 → 여관(방을 잡는다)
--   → 등대지기(하늘 끝) → 배 → 에필로그 → 타이틀
--
-- 프레임 진행은 여기서 직접 돌린다 (엔진의 Update를 기다리지 않는다). 화면
-- 렌더 프레임과 게임 tick은 헤드리스에서 비율이 다르므로, tick을 손으로 돌려야
-- 결과가 재현된다 — 같은 시나리오는 항상 같은 좌표와 같은 대사를 낸다.
--
-- INITIAL2D_DEMO_STOP 으로 중간에서 멈춰 그 화면을 골든으로 남긴다.
--   title   타이틀 메뉴가 열린 채로      town  마을에 막 들어선 채로
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

--- 지금 어디에 서 있는가 (경로가 어긋났을 때 어디서 어긋났는지 남긴다)
local function where(label)
	local st = status()
	print("at:" .. tostring(label) .. ":" .. tostring(st.tx) .. "," .. tostring(st.ty)
		.. " dir:" .. tostring(st.dir) .. " busy:" .. tostring(st.busy)
		.. " talk:" .. tostring(st.talking))
end

local function tx() return status().tx end
local function ty() return status().ty end

--- 방향키를 붙들고 목표 칸에 닿을 때까지 걷는다.
-- 그리드 이동은 출발하는 순간 목적지 칸을 점유하므로(5단계), 목표 번호가 보이면
-- 바로 키를 뗀다. NPC가 길을 막으면 그 자리에서 기다리다가 비면 다시 걷는다.
local function walk(key, get, target, label)
	replay:press(key)
	local ok = tickUntil(label, function() return get() == target end, 900)
	replay:release(key)
	tickUntil(label .. "Stop", function() return not status().moving end, 120)
	return ok
end

--- 그 자리에서 방향만 돌린다.
-- **앞 칸이 막혀 있을 때만 쓴다.** 열려 있으면 붙든 키로 걸어가 버린다 (한 번
-- 그렇게 한 칸 더 가서 경로가 통째로 어긋났다). 그 밖의 경우에는 걸어온 방향이
-- 곧 바라보는 방향이므로 walk()만으로 충분하다.
local function face(key, dir)
	replay:press(key)
	tick(10)
	replay:release(key)
	tick(2)
	return status().dir == dir
end

--- 결정키를 눌러 대화를 시작하고, 글자가 다 나올 때까지 기다린다.
local function talk(label)
	replay:tap("Z")
	tickUntil(label, function() return status().talking end, 60)
	tick(90)
end

--- 대화를 한 번 넘긴다 (다음 쪽 또는 다음 대사)
local function next(frames)
	replay:tap("Z")
	tick(frames or 90)
end

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
	-- 닫힐 때까지만 누른다. 정해진 횟수만큼 누르면, 다 넘긴 뒤의 누름이 메뉴로
	-- 새어 들어가 "조작 방법"을 다시 열어 버린다.
	for _ = 1, 16 do
		if not RpgDemoTitleScene.status().helpOpen then break end
		replay:tap("Z")
		tick(8)
	end
	print("helpClosed:" .. tostring(not RpgDemoTitleScene.status().helpOpen))
	print("menuBack:" .. tostring(RpgDemoTitleScene.status().menuOpen))

	-- 커서를 "시작"으로 올려 결정
	replay:tap("UP"); tick(2)
	replay:tap("Z"); tick(2)
	tickUntil("startSwitch", function() return currentName == "rpg" end, 60)
	print("sceneAfterStart:" .. tostring(currentName))

	-- ---- [B] 부두 도착 -----------------------------------------------------
	tickUntil("fadeIn", function() return not status().fading end, 60)
	local st = status()
	print("mapLoaded:" .. tostring(st.map) .. " error:" .. tostring(st.error))
	print("playerAt:" .. tostring(st.tx) .. "," .. tostring(st.ty))
	print("location:" .. tostring(st.location))

	-- 맵에 들어서면 선장이 먼저 말을 건다 (auto 이벤트, 첫 방문만)
	tickUntil("arrivalTalk", function() return status().talking end, 60)
	tick(120)
	print("captainLine:" .. dialogueText())
	next(120)
	print("captainLine2:" .. dialogueText())
	next(20)
	tickUntil("arrivalEnd", function() return not status().busy end, 200)

	if STOP == "town" then
		frozen = true
		return
	end

	-- ---- [C] 광장: 생선 장수와 창고 ----------------------------------------
	walk("UP", ty, 35, "walkToPlaza")
	walk("LEFT", tx, 14, "walkToStall")
	print("facingStall:" .. tostring(face("LEFT", "left")))
	talk("fishTalk")
	print("fishLine:" .. dialogueText())
	next(6)
	print("fishChoice:" .. tostring(status().talking))
	replay:tap("Z"); tick(6)      -- 1번 "창고가 잠겨 있던데요"
	tick(120)
	print("warehouseStory:" .. dialogueText())
	next(20)
	tickUntil("fishEnd", function() return not status().busy end, 120)

	-- 사연을 들은 뒤에는 창고 문의 설명이 달라진다
	-- 광장의 우물(18,35)이 가로줄을 막으므로 한 줄 위로 돌아간다
	walk("UP", ty, 31, "walkAroundWell")
	walk("RIGHT", tx, 19, "walkToWarehouse")
	walk("UP", ty, 30, "walkUpToWarehouse")
	-- 창고 문(19,29)은 막힌 칸이라 붙들어도 걸어가지 않는다
	print("facingWarehouse:" .. tostring(face("UP", "up")))
	talk("warehouseTalk")
	print("warehouseLine:" .. dialogueText())
	next(20)
	tickUntil("warehouseEnd", function() return not status().busy end, 120)

	-- ---- [D] 여관: 방을 잡는다 ---------------------------------------------
	walk("LEFT", tx, 13, "walkToInnDoor")
	replay:press("UP")
	tickUntil("enterInn", function() return status().map == "inn" end, 300)
	replay:release("UP")
	tickUntil("innFade", function() return not status().fading end, 60)
	print("innAt:" .. tostring(tx()) .. "," .. tostring(ty()))
	print("innLocation:" .. tostring(status().location))
	tickUntil("innAuto", function() return not status().busy end, 120)

	-- 카운터와 주인이 막고 있어 (10,4)에서 멈추고, 걸어온 방향 그대로 위를 본다
	walk("UP", ty, 4, "walkToCounter")
	print("facingHost:" .. tostring(status().dir == "up"))
	talk("hostTalk")
	print("hostLine:" .. dialogueText())
	next(120)
	print("hostPrice:" .. dialogueText())
	next(6)
	print("hostChoice:" .. tostring(status().talking))
	replay:tap("Z"); tick(6)      -- 1번 "묵는다"
	tick(120)
	print("bookedLine:" .. dialogueText())
	next(20)
	tickUntil("hostEnd", function() return not status().busy end, 120)

	-- 아래 문으로 마을로 돌아간다
	walk("DOWN", ty, 12, "walkToInnExit")
	replay:press("DOWN")
	tickUntil("backToTown", function() return status().map == "port_town" end, 300)
	replay:release("DOWN")
	tickUntil("townFade", function() return not status().fading end, 60)
	print("backAt:" .. tostring(tx()) .. "," .. tostring(ty()))

	-- ---- [E] 언덕: 등대지기 ------------------------------------------------
	walk("RIGHT", tx, 16, "walkToRoad")
	walk("UP", ty, 13, "walkToHill")
	walk("RIGHT", tx, 17, "walkToKeeper")
	print("facingKeeper:" .. tostring(status().dir == "right"))
	talk("keeperTalk")
	print("keeperLine:" .. dialogueText())
	next(120)
	print("keeperLine2:" .. dialogueText())
	next(6)
	print("keeperChoice:" .. tostring(status().talking))
	replay:tap("Z"); tick(6)      -- 1번 "하늘 끝에 가 보셨습니까"
	tick(120)
	print("altarLine:" .. dialogueText())
	next(20)
	tickUntil("keeperEnd", function() return not status().busy end, 120)

	-- 그 이야기를 들은 뒤에는 북쪽 문의 설명도 달라진다
	walk("LEFT", tx, 16, "walkBackToRoad")
	walk("UP", ty, 7, "walkToGate")
	print("facingGate:" .. tostring(status().dir == "up"))
	talk("gateTalk")
	print("gateLine:" .. dialogueText())
	next(20)
	tickUntil("gateEnd", function() return not status().busy end, 120)

	-- ---- [F] 배: 떠난다 ----------------------------------------------------
	walk("DOWN", ty, 43, "walkToPier")
	walk("RIGHT", tx, 17, "walkToPierEdge")
	walk("DOWN", ty, 44, "walkToShip")
	print("facingShip:" .. tostring(face("RIGHT", "right")))
	where("atShip")
	talk("shipTalk")
	print("shipLine:" .. dialogueText())
	next(6)
	print("shipChoice:" .. tostring(status().talking))
	replay:tap("Z"); tick(6)      -- 1번 "지금 떠난다"
	tick(120)
	print("farewellLine:" .. dialogueText())
	next(120)
	print("epilogue:" .. dialogueText())
	next(20)

	-- 에필로그가 끝나면 페이드와 함께 타이틀로 돌아간다
	tickUntil("backToTitle", function() return currentName == "title" end, 300)
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
