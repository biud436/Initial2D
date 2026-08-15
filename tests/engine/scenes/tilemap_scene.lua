-- 새 Tilemap API 픽셀 검증 씬 (2단계, docs/plans/02-tilemap.md)
--
-- 커밋된 샘플 맵(80x70, 2레이어)을 그린다. 카메라는 환경 변수로 고정한다:
--   INITIAL2D_TEST_CAM 미설정      : (0,0) — 좌상단 (외곽 울타리, 연못(8,6))
--   INITIAL2D_TEST_CAM=bottomright : 우하단 끝 — 컬링과 카메라 오프셋 검증
-- (Update는 렌더 프레임당 여러 번 불릴 수 있어 프레임 카운터 기반 전환은
--  스크린샷 프레임과 어긋난다. 러너가 씬을 두 번 실행한다.)
-- 크기·통행 판정은 stdout으로 찍어 러너가 문자열로 확인한다.

local map, err
local camX, camY = 0, 0

function Initialize()
	map, err = Tilemap.Load("./resources/maps/sample.json")
	if map == nil then
		print("tilemapError:" .. tostring(err))
		return
	end

	local w, h, tw, th, layers = Tilemap.GetSize(map)
	print(string.format("tilemapSize:%dx%d tile:%dx%d layers:%d", w, h, tw, th, layers))
	print("passableGrass:" .. tostring(Tilemap.IsPassable(map, 5, 5)))
	print("passableFence:" .. tostring(Tilemap.IsPassable(map, 2, 2)))
	print("passableOut:" .. tostring(Tilemap.IsPassable(map, -1, 5)))
	print("fenceGid:" .. Tilemap.GetTileId(map, 2, 2, 2))

	local mode = (os.getenv ~= nil) and os.getenv("INITIAL2D_TEST_CAM") or nil
	if mode == "bottomright" then
		camX = w * tw - WindowWidth()
		camY = h * th - WindowHeight()
	else
		camX, camY = 0, 0
	end
end

function Update(elapsed)
end

function Render()
	if map == nil then
		return
	end
	Tilemap.Draw(map, 1, 2, camX, camY)
end

function Destroy()
	if map ~= nil then
		Tilemap.Dispose(map)
	end
end
