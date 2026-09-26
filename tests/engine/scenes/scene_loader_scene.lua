-- 씬 로더 픽스처 씬 (tests/run_engine_tests.py 가 구동, R1)
--
-- tests/fixtures/scenes/sample_v1.json (러너가 ./fixtures/ 로 복사)을 열어 타입 넷(tilemap,
-- sprite 둘, node 와 컴포넌트, text)이 실제로 만들어지고 그려지는지 본다. 오브젝트 순서와
-- 위치, 모르는 키의 보존을 stdout 으로 알리고, 러너는 화면을 골든 scene_loader 에 견준다
-- (mruby_scene_loader_scene.rb 가 같은 골든을 쓴다).

local SceneLoader = require("scripts/lua/scene_loader")

local scene
local ticks = 0

function Initialize()
	scene = SceneLoader.open("fixtures/scenes/sample_v1.json")
	print("scene:name:" .. scene.name)
	local ids = {}
	for _, obj in ipairs(scene:objects()) do ids[#ids + 1] = obj.id end
	print("scene:order:" .. table.concat(ids, ","))
	print("scene:editorOnly:" .. tostring(scene.source.editorOnly and scene.source.editorOnly.note))
	print("scene:tileEditorOnly:" .. tostring(scene:find("tile").spec.editorOnly.locked))
	local tile = scene:find("tile")
	print("scene:tile:" .. tile.x .. "," .. tile.y .. " frame " .. tile.frameWidth .. "x" .. tile.frameHeight)
	print("scene:map:layers " .. scene:find("map").layerCount)
	print("scene:anim:frame " .. Sprite.GetCurrentFrame(scene:find("anim").sprite))
end

function Update(elapsed)
	scene = scene:tick(elapsed)
	ticks = ticks + 1
	if ticks <= 3 then
		print("scene:tick" .. ticks .. ":tile.x=" .. scene:find("tile").x)
	end
end

function Render()
	scene:draw()
end

function Destroy()
	print("scene:final:tile.x=" .. scene:find("tile").x)
	scene:close()
	print("scene:closed:" .. tostring(scene:isClosed()))
end
