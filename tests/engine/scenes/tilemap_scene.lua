-- 저자의 Lua 타일맵 모듈 스모크 테스트 (scripts/tilemap.lua를 그대로 사용)
-- tilemap.lua는 전역 Image에 의존하므로 image 모듈을 먼저 로드한다 (원본 main.lua와 동일한 순서)
require("scripts/image")
local Tilemap = require("scripts/tilemap")

function Initialize()
	tilemap = Tilemap(3, 3)
	tilemap.init()
end

function Update(elapsed)
	tilemap.update(0)
end

function Render()
	tilemap.draw()
end

function Destroy()
	tilemap.dispose()
end
