-- RPG 캐릭터 렌더링 검증 씬 (5단계) — tests/run_engine_tests.py가 구동한다.
--
-- 화면 상태를 프레임과 무관하게 고정한다: 캐릭터 셋을 Initialize에서 원하는
-- 자세로 세워 두고, Update는 dt=0으로 스프라이트 동기화만 한다. 고정 스텝
-- 루프에서 Update 호출 횟수는 스크린샷 프레임과 어긋나므로, 시간에 따라
-- 변하는 상태를 골든으로 찍으면 안 된다 (docs/plans/09-testing.md 4절).
--
-- 세워 두는 것 세 가지:
--   ref  (12,12) 가림 없는 잔디 — 머리색 픽셀의 기준값
--   hid  (5,3)   위 칸이 울타리(상층 타일) — 같은 캐릭터의 머리가 가려져야 한다
--   walk (16,12) 반 칸 이동 중 — 보간 좌표와 걷기 자세
-- ref와 hid는 같은 캐릭터를 같은 방향으로 세운 것이라, 머리색 픽셀 수의 차이가
-- 곧 레이어 분할 그리기(캐릭터를 1층과 2층 사이에 그림)의 효과다.

local MapScene = require("scripts/rpg/map_scene")

local scene = nil
local CHARSET = "./resources/charsets/placeholder.png"

-- 가림 비교용 캐릭터 (3번: 보라 머리, 흰옷 — 맵의 어떤 색과도 겹치지 않는다)
local HAIR_INDEX = 3

function Initialize()
	local err
	scene, err = MapScene.new{
		mapPath = "./resources/maps/sample.json",
		viewW = WindowWidth(), viewH = WindowHeight(),
		groundLayers = 1,
	}
	if scene == nil then
		print("rpgError:" .. tostring(err))
		return
	end

	print(string.format("rpgMap:%dx%d layers:%d", scene.width, scene.height, scene.layerCount))

	local ref = scene:addCharacter{
		tx = 12, ty = 12, dir = "down", charset = CHARSET, charIndex = HAIR_INDEX,
		name = "ref",
	}
	local hid = scene:addCharacter{
		tx = 5, ty = 3, dir = "down", charset = CHARSET, charIndex = HAIR_INDEX,
		name = "hid",
	}
	local walk = scene:addCharacter{
		tx = 16, ty = 12, dir = "right", charset = CHARSET, charIndex = 0,
		speed = 4, name = "walk",
	}

	-- 카메라는 좌상단 고정 (씬을 세 캐릭터가 한 화면에 들어오게 배치했다)
	scene:setCameraTarget(nil)
	scene.camera:centerOn(0, 0)

	-- 반 칸 이동 중인 자세를 만든다 (speed 4 → 0.125초가 정확히 반 칸)
	walk:tryMove("right")
	walk:update(0.5 / walk.speed)
	scene:update(0)   -- 스프라이트 위치·프레임 동기화

	local rx, ry = ref:pixelPos()
	local hx, hy = hid:pixelPos()
	local wx, wy = walk:pixelPos()
	print(string.format("rpgRef:%d,%d frame:%d", rx, ry, ref:frameIndex()))
	print(string.format("rpgHid:%d,%d frame:%d", hx, hy, hid:frameIndex()))
	print(string.format("rpgWalk:%d,%d frame:%d moving:%s",
		wx, wy, walk:frameIndex(), tostring(walk:isMoving())))
	print("rpgWalkOffset:" .. tostring(walk.offsetX))

	local names = {}
	for _, c in ipairs(scene.order) do names[#names + 1] = c.name end
	print("rpgOrder:" .. table.concat(names, ","))
	print("rpgCamera:" .. table.concat({ scene.camera:pos() }, ","))
end

function Update(elapsed)
	if scene ~= nil then
		scene:update(0)   -- 시간을 흘려보내지 않는다 — 화면은 항상 같은 상태
	end
end

function Render()
	if scene ~= nil then
		scene:draw()
	end
end

function Destroy()
	if scene ~= nil then
		scene:dispose()
		scene = nil
	end
end
