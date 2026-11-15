-- 스프라이트 시트 클립 검증 씬 (엔진 2). tests/run_engine_tests.py 의 test_sheet_clips 가 구동한다.
-- tests/fixtures/scenes/sheet_v1.json 을 씬 로더로 열고 20ms 틱을 26 번 직접 돌리며 클립의 프레임을 찍는다.
-- 틱을 Initialize 안에서 끝내므로 그 뒤의 화면은 늘 같다 (러너가 픽셀과 골든으로 본다).
-- mruby_sheet_clips_scene.rb 가 같은 줄을 찍고 같은 그림을 그린다.

local SceneLoader = require("scripts/lua/scene_loader")

local TICK = 20
local scene

local function state(obj)
	local a = obj.animator
	return obj.id .. "=" .. tostring(a:clip()) .. ":" .. a:frame() .. (a:isDone() and ",done" or "")
end

local function report(label)
	local parts = {}
	for _, id in ipairs({ "walker", "waver", "hitter" }) do parts[#parts + 1] = state(scene:find(id)) end
	print("sheet:" .. label .. ":" .. table.concat(parts, " "))
end

local function rectOf(id)
	local r = Sprite.GetRect(scene:find(id).sprite)
	return string.format("%s=%d,%d", id, math.floor(r.x), math.floor(r.y))
end

function Initialize()
	scene = SceneLoader.open("fixtures/scenes/sheet_v1.json")
	local sheet = scene:find("walker").sheet
	print(string.format("sheet:grid:%dx%d frames=%d frame=%dx%d", sheet.columns, sheet.rows, sheet.frameCount,
		sheet.frameWidth, sheet.frameHeight))
	report("open")
	for tick = 1, 26 do
		scene = scene:tick(TICK)
		if tick == 5 or tick == 8 or tick == 10 or tick == 13 or tick == 20 or tick == 21 or tick == 26 then
			report("t" .. tick)
		end
		if tick == 20 then
			scene:find("walker").props.clip = "hit"   -- 다음 틱에 처음부터 (그 틱에는 시간을 보내지 않는다)
			scene:find("waver").animate = false       -- 멈춘다
		elseif tick == 23 then
			scene:find("hitter").animator:restart()   -- 끝난 once 를 다시
		end
	end
	print("sheet:rect:" .. rectOf("walker") .. " " .. rectOf("waver") .. " " .. rectOf("hitter"))
end

function Update(elapsed)
end

function Render()
	scene:draw()
end

function Destroy()
	scene:close()
end
