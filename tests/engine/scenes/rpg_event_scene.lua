-- 이벤트 시스템 통합 검증 씬 (6단계) — tests/run_engine_tests.py가 구동한다.
--
-- 단위 테스트는 가짜 맵과 가짜 대화창으로 규칙을 본다. 여기서는 진짜 맵 파일
-- (resources/maps/village.json, room.json)과 진짜 이벤트 정의(scripts/maps/*.lua)를
-- 그대로 얹어, 좌표가 실제로 맞는지와 전환이 도는지를 확인한다.
--
-- 입력 없이 돌려야 하므로 결정키 대신 관리자 API를 직접 부른다. 결과는 stdout으로
-- 남기고 러너가 문자열로 검사한다.

local MapScene = require("scripts/rpg/map_scene")
local Event = require("scripts/rpg/event")
local Interpreter = require("scripts/rpg/interpreter")

local scene, events, interp, playerChar
local transferred = nil

-- 테스트가 직접 여닫는 대화창 (데모의 화면 표시 대신)
local port = { busy = false, value = 1, lines = {}, choices = 0 }
function port.showMessage(text)
	table.insert(port.lines, text)
	port.busy = true
end
function port.showChoice(options)
	port.choices = port.choices + 1
	port.busy = true
end
function port.isBusy() return port.busy end
function port.result() return port.value end

local function loadMap(name, sx, sy)
	if scene ~= nil then scene:dispose() end

	local def = require("scripts/maps/" .. name)
	local err
	scene, err = MapScene.new{ mapPath = def.map, viewW = 480, viewH = 448 }
	if scene == nil then
		print("eventSceneError:" .. tostring(err))
		return false
	end

	playerChar = scene:addCharacter{
		tx = sx or def.start.x, ty = sy or def.start.y, dir = def.start.dir,
		charset = "./resources/charsets/placeholder.png", charIndex = 0, speed = 4,
		name = "player",
	}
	scene:setCameraTarget(playerChar)

	events = Event.newManager{ player = playerChar, interpreter = interp }
	for _, edef in ipairs(def.events or {}) do
		local ev = Event.new{
			id = edef.id, x = edef.x, y = edef.y, dir = edef.dir,
			trigger = edef.trigger, script = edef.script, charset = edef.charset,
			through = edef.through, solid = edef.solid,
		}
		if edef.charset ~= nil then
			ev.character = scene:addCharacter{
				tx = edef.x, ty = edef.y, dir = edef.dir,
				charset = edef.charset.file, charIndex = edef.charset.index,
				speed = 3, name = edef.id,
			}
		end
		events:add(ev)
	end
	scene:setEvents(events)
	interp:clear()
	events:onMapStart()
	return true
end

local function pump(n)
	for _ = 1, (n or 1) do
		scene:update(1 / 60)
		events:update()
		interp:update()
	end
end

function Initialize()
	interp = Interpreter.new{
		messagePort = port,
		host = {
			transfer = function(map, x, y) transferred = { map = map, x = x, y = y } end,
			characterById = function(id)
				if id == "player" then return playerChar end
				local ev = events:get(id)
				return ev ~= nil and ev.character or nil
			end,
		},
	}

	if not loadMap("village") then return end
	print(string.format("village:%dx%d events:%d", scene.width, scene.height, #events.events))
	print("playerStart:" .. playerChar.tx .. "," .. playerChar.ty)

	-- [A] 병렬 순찰이 조작을 잠그지 않고 돈다
	print("busyAfterMapStart:" .. tostring(interp:isBusy()))
	print("parallelCount:" .. #interp.parallels)
	local patrol = events:get("patrol")
	local px, py = patrol:tile()
	pump(120)
	local qx, qy = patrol:tile()
	print("patrolMoved:" .. tostring(px ~= qx or py ~= qy))
	print("busyDuringPatrol:" .. tostring(interp:isBusy()))

	-- [B] 촌장에게 말 걸기: 앞 칸을 보고 결정키
	playerChar:place(32, 21, "up")   -- 촌장(32,20) 바로 아래에서 위를 본다
	print("actionTarget:" .. tostring(events:actionTarget() and events:actionTarget().id))
	print("confirm:" .. tostring(events:confirm()))
	print("busyWhileTalking:" .. tostring(interp:isBusy()))
	print("elderTurned:" .. tostring(events:get("elder").character.dir))
	print("line1:" .. tostring(port.lines[1]))

	-- 대화를 넘기고 선택지에서 1번을 고른다 → 분기 대사
	port.busy = false; pump(1)
	print("choiceShown:" .. port.choices)
	port.value = 1
	port.busy = false; pump(1)
	print("line2:" .. tostring(port.lines[2]))
	port.busy = false; pump(2)
	print("busyAfterTalk:" .. tostring(interp:isBusy()))
	print("stateFlag:" .. tostring(interp.state.toldAboutHut))

	-- [C] 집 문을 밟으면 전환 요청이 나간다
	playerChar:place(13, 15, "up")
	pump(1)
	playerChar:tryMove("up")         -- (13,14) 문 칸으로
	pump(1)
	print("transfer:" .. tostring(transferred and transferred.map)
		.. "," .. tostring(transferred and transferred.x)
		.. "," .. tostring(transferred and transferred.y))
	print("busyAfterTransfer:" .. tostring(interp:isBusy()))

	-- [D] 실제로 맵을 바꾸고 auto 이벤트가 도는지 (자원 해제 포함)
	local ok = loadMap("room", transferred.x, transferred.y)
	print("roomLoaded:" .. tostring(ok))
	print("room:" .. scene.width .. "x" .. scene.height .. " events:" .. #events.events)
	print("autoBusy:" .. tostring(interp:isBusy()))
	print("autoLine:" .. tostring(port.lines[#port.lines]))
	port.busy = false; pump(2)
	print("busyAfterAuto:" .. tostring(interp:isBusy()))

	-- 두 번째 방문에서는 auto가 조용히 넘어간다 (state 유지 확인)
	local before = #port.lines
	loadMap("room")
	pump(2)
	print("secondVisitLines:" .. tostring(#port.lines - before))

	GameExit()
end

function Update(elapsed) end
function Render()
	if scene ~= nil then scene:draw() end
end
function Destroy()
	if scene ~= nil then scene:dispose() end
end
