-- 타일 애니메이션 검증 씬 (tests/run_engine_tests.py 의 test_tile_animation 이 구동)
--
-- 러너가 작업 폴더에 3x1 맵(anim.json)과 여섯 색 타일의 타일셋을 쓴다 (write_anim_fixture).
-- INITIAL2D_TEST_ANIM_MS 만큼 시계를 한 번 진행하고 맵을 화면 왼쪽 위에 8배로 그린다. 틱의 Update 는 부르지 않아 화면이
-- 그 시계에 머문다. broken.json(빈 프레임)과 overlap.json(겹친 범위)은 읽지 못해야 한다.

local map

function Initialize()
	local err
	map, err = Tilemap.Load("./anim.json")
	print("anim:load=" .. tostring(map ~= nil) .. " " .. tostring(err))
	local ms = tonumber(os.getenv("INITIAL2D_TEST_ANIM_MS") or "0")
	Tilemap.Update(map, ms)
	local broken, brokenErr = Tilemap.Load("./broken.json")
	print("anim:broken=" .. tostring(broken == nil) .. " " .. tostring(brokenErr))
	local overlap, overlapErr = Tilemap.Load("./overlap.json")
	print("anim:overlap=" .. tostring(overlap == nil) .. " " .. tostring(overlapErr))
	SetRenderScale(8)
end

function Update(elapsed) end

function Render()
	Tilemap.Draw(map, 1, 1, 0, 0)
end

function Destroy()
	Tilemap.Dispose(map)
end
