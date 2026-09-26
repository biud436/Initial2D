-- 씬 로더 플래피 인수 씬 (tests/run_engine_tests.py 가 구동, R1)
--
-- resources/templates/main.lua 와 같은 진입점이다. 러너가 INITIAL2D_SCENE=flappy 와
-- INITIAL2D_AUTOPLAY 를 주면 resources/scenes/flappy.json 이 열리고, director 컴포넌트가
-- 상태 전이와 점수를 stdout 으로 알린 뒤 900틱에 스스로 끝낸다 (mruby_flappy_scene.rb 와 같은 검사).

local SceneLoader = require("scripts/lua/scene_loader")

local scene

function Initialize()
	local game = Json.Load("./game.json") or {}
	local wanted = (os.getenv ~= nil) and os.getenv("INITIAL2D_SCENE") or nil
	scene = SceneLoader.open(wanted or game.startScene or "main")
end

function Update(elapsed)
	scene = scene:tick(elapsed)
end

function Render()
	scene:draw()
end

function Destroy()
	scene:close()
end
