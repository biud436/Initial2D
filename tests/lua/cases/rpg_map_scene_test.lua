-- rpg_map_scene_test.lua : 타일맵 + 캐릭터 + 카메라를 묶는 층(scripts/rpg/map_scene.lua) 검증.
--
-- character/camera와 달리 이 모듈은 엔진(Tilemap, Sprite)에 닿는다. Lua 단위
-- 테스트가 엔진 바이너리 안에서 돌기 때문에 여기서도 진짜 타일맵을 쓴다.
-- 값은 전부 포맷 계약 픽스처(4x3, 통행 불가 3칸)로 통제한다.

local M = {}

local FIXTURE = "./fixtures/maps/sample_v1.json"
local CHARSET = "./resources/charsets/placeholder.png"

function M.run(t)
	local MapScene = require("scripts/rpg/map_scene")

	-- ---- [1] 로드 실패 계약 -------------------------------------------------
	local missing, err = MapScene.new{ mapPath = "./no_such_map.json" }
	t.check(missing == nil and type(err) == "string",
		"없는 맵은 nil + 오류 메시지 (Tilemap.Load와 같은 계약)")

	-- ---- [2] 맵 정보와 카메라 세계 크기 -------------------------------------
	local scene = MapScene.new{ mapPath = FIXTURE, viewW = 768, viewH = 896 }
	t.check(scene ~= nil, "픽스처 맵으로 씬 생성")
	if scene == nil then return end

	t.check(scene.width == 4 and scene.height == 3, "맵 크기 4x3")
	t.check(scene.tileW == 16 and scene.tileH == 16, "타일 16x16")
	t.check_eq(scene.layerCount, 2, "레이어 2장")
	t.check_eq(scene.groundLayers, 1, "기본 하층은 1장 (캐릭터가 그 위에 선다)")
	t.check(scene.camera.worldW == 64 and scene.camera.worldH == 48,
		"카메라 세계 크기는 맵 픽셀 크기")

	-- 맵이 화면보다 작으므로 카메라는 가운데 정렬된 고정값이다
	scene.camera:centerOn(32, 24)
	local cx, cy = scene.camera:pos()
	t.check(cx == (64 - 768) / 2 and cy == (48 - 896) / 2,
		"작은 맵은 화면 가운데에 놓인다", cx .. "," .. cy)

	-- ---- [3] 통행 판정: 충돌 레이어 -----------------------------------------
	-- 픽스처의 collision: [0,0,0,1 / 0,1,0,0 / 1,0,0,0]
	t.check_eq(scene:isPassable(0, 0), true, "빈 칸은 통행 가능")
	t.check_eq(scene:isPassable(3, 0), false, "충돌 표시된 칸")
	t.check_eq(scene:isPassable(1, 1), false, "충돌 표시된 칸 (가운데)")
	t.check_eq(scene:isPassable(-1, 0), false, "맵 밖은 통행 불가")
	t.check_eq(scene:isPassable(4, 0), false, "맵 밖은 통행 불가 (x)")

	-- ---- [4] 캐릭터 등록과 점유 ---------------------------------------------
	local a = scene:addCharacter{ tx = 0, ty = 0, dir = "right", speed = 1 }
	local b = scene:addCharacter{ tx = 1, ty = 0, dir = "down", speed = 1 }
	t.check_eq(#scene.characters, 2, "캐릭터 두 명 등록")
	t.check(a.tileW == 16 and a.tileH == 16, "캐릭터가 맵의 타일 크기를 받는다")

	t.check_eq(scene:isPassable(1, 0), false, "캐릭터가 선 칸은 통행 불가")
	t.check_eq(scene:isPassable(1, 0, b), true, "당사자는 자기 칸을 막지 않는다")
	t.check_eq(scene:characterAt(1, 0), b, "characterAt이 그 캐릭터를 찾는다")
	t.check_eq(scene:characterAt(0, 1), nil, "빈 칸은 nil")

	t.check_eq(a:tryMove("right"), false, "다른 캐릭터를 통과하지 못한다")
	t.check_eq(b:tryMove("right"), true, "b는 오른쪽으로 갈 수 있다")
	t.check_eq(scene:isPassable(2, 0), false, "이동 중인 b가 목적지 칸을 점유한다")
	t.check_eq(a:tryMove("right"), true, "b가 떠난 칸으로는 갈 수 있다")

	-- 충돌 레이어도 그대로 막는다 (b는 (2,0)에 있고 (3,0)은 통행 불가)
	for _ = 1, 4 do scene:update(0.25) end
	t.check(not b:isMoving(), "b 이동 완료")
	t.check_eq(b:tryMove("right"), false, "충돌 타일로는 못 간다")

	-- ---- [5] 카메라 추적 -----------------------------------------------------
	scene:setCameraTarget(a)
	scene:update(0.25)
	t.check_eq(scene.cameraTarget, a, "카메라 대상 지정")

	-- ---- [6] 그리기 순서 -----------------------------------------------------
	local lower = scene:addCharacter{ tx = 0, ty = 2 }
	scene:update(0.25)
	local lastIndex, aIndex = 0, 0
	for i, c in ipairs(scene.order) do
		if c == lower then lastIndex = i end
		if c == a then aIndex = i end
	end
	t.check(lastIndex > aIndex, "아래쪽 캐릭터가 나중에 그려진다",
		aIndex .. " < " .. lastIndex)

	-- ---- [7] 화면 밖 판정 ---------------------------------------------------
	t.check_eq(scene:isOnScreen(a), true, "맵 안 캐릭터는 화면 안")
	local outside = scene:addCharacter{ tx = 0, ty = 0 }
	outside:place(-500, -500)
	t.check_eq(scene:isOnScreen(outside), false, "멀리 떨어진 캐릭터는 그리지 않는다")

	-- ---- [8] 그리기 스모크 (레이어 분할 호출 포함) ---------------------------
	scene:draw()
	t.check(true, "draw 호출에 오류 없음")

	scene:dispose()
	t.check_eq(scene.map, nil, "dispose 후 맵 핸들 해제")

	-- ---- [9] 스프라이트 경로: 커밋된 플레이스홀더 CharSet ---------------------
	local scene2 = MapScene.new{ mapPath = FIXTURE, viewW = 768, viewH = 896 }
	t.check(scene2 ~= nil, "두 번째 씬 생성")
	if scene2 == nil then return end

	local drawn = scene2:addCharacter{ tx = 0, ty = 0, charset = CHARSET, charIndex = 0 }
	t.check(scene2.sprites[drawn] ~= nil, "charset을 주면 스프라이트가 붙는다")
	t.check_eq(TextureManager.IsValid("rpg:" .. CHARSET), true,
		"플레이스홀더 CharSet 텍스처 로드 (resources/charsets/placeholder.png)")

	-- 같은 시트를 쓰는 두 캐릭터는 텍스처를 공유한다 (해제도 한 번만)
	local second = scene2:addCharacter{ tx = 2, ty = 0, charset = CHARSET, charIndex = 1 }
	t.check(scene2.sprites[second] ~= scene2.sprites[drawn], "캐릭터마다 스프라이트는 따로")
	local texCount = 0
	for _ in pairs(scene2.textures) do texCount = texCount + 1 end
	t.check_eq(texCount, 1, "같은 시트는 텍스처 하나")

	scene2:update(0.25)
	scene2:draw()
	t.check(true, "스프라이트가 붙은 씬의 갱신·그리기에 오류 없음")

	scene2:dispose()
end

return M
