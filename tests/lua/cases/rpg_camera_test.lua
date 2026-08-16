-- rpg_camera_test.lua : 카메라 추적과 경계 클램프(scripts/rpg/camera.lua) 검증.
-- 엔진 없이 도는 순수 계산이다.

local M = {}

function M.run(t)
	local Camera = require("scripts/rpg/camera")

	-- [1] clampAxis: 맵이 화면보다 클 때
	local VIEW, WORLD = 100, 500
	t.check_eq(Camera.clampAxis(250, VIEW, WORLD), 200, "가운데는 대상 - 화면 절반")
	t.check_eq(Camera.clampAxis(0, VIEW, WORLD), 0, "왼쪽 끝에서 0으로 멈춘다")
	t.check_eq(Camera.clampAxis(20, VIEW, WORLD), 0, "왼쪽 경계 안쪽도 0")
	t.check_eq(Camera.clampAxis(50, VIEW, WORLD), 0, "정확히 화면 절반이면 0")
	t.check_eq(Camera.clampAxis(51, VIEW, WORLD), 1, "경계를 벗어나면 따라가기 시작")
	t.check_eq(Camera.clampAxis(WORLD, VIEW, WORLD), 400, "오른쪽 끝은 worldW - viewW")
	t.check_eq(Camera.clampAxis(9999, VIEW, WORLD), 400, "끝을 넘어도 더 가지 않는다")

	-- [2] 맵이 화면보다 작거나 같을 때: 가운데 정렬 (오프셋이 음수)
	t.check_eq(Camera.clampAxis(0, 100, 60), -20, "작은 맵은 가운데 정렬")
	t.check_eq(Camera.clampAxis(999, 100, 60), -20, "작은 맵은 대상과 무관하게 고정")
	t.check_eq(Camera.clampAxis(50, 100, 100), 0, "크기가 같으면 0")

	-- [3] Camera 객체: 두 축 동시 클램프
	local cam = Camera.new{ viewW = 768, viewH = 896, worldW = 1280, worldH = 1120 }
	cam:centerOn(640, 560)
	local x, y = cam:pos()
	t.check_eq(x, 256, "맵 중앙 추적 x")
	t.check_eq(y, 112, "맵 중앙 추적 y")

	cam:centerOn(0, 0)
	x, y = cam:pos()
	t.check(x == 0 and y == 0, "좌상단에서 (0,0)")

	cam:centerOn(99999, 99999)
	x, y = cam:pos()
	t.check_eq(x, 1280 - 768, "우하단 x는 맵 폭 - 화면 폭")
	t.check_eq(y, 1120 - 896, "우하단 y는 맵 높이 - 화면 높이")

	-- [4] pos()는 정수를 준다 (소수를 넘기면 타일 경계가 떨린다)
	cam:centerOn(640.7, 560.9)
	x, y = cam:pos()
	t.check(math.type(x) == "integer" and math.type(y) == "integer",
		"pos()는 정수", tostring(x) .. "," .. tostring(y))
	t.check_eq(x, 256, "소수 좌표는 내림")

	-- [5] follow: centerPos()를 가진 대상을 따라간다
	local target = { centerPos = function() return 700, 600 end }
	cam:follow(target)
	x, y = cam:pos()
	t.check(x == 700 - 384 and y == 600 - 448, "follow가 대상 중심을 화면 가운데로",
		x .. "," .. y)

	-- [6] toScreen: 월드 → 화면
	cam:centerOn(640, 560)
	local sx, sy = cam:toScreen(640, 560)
	t.check(sx == 384 and sy == 448, "화면 중앙으로 변환", sx .. "," .. sy)

	-- [7] setWorld / setView로 나중에 바꿀 수 있다 (맵 전환)
	cam:setWorld(200, 200):setView(100, 100):centerOn(150, 150)
	x, y = cam:pos()
	t.check(x == 100 and y == 100, "맵을 바꾸면 새 경계로 클램프", x .. "," .. y)
end

return M
