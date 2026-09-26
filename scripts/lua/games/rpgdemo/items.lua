-- 「떠나기 전에」의 아이템 표 (10단계, docs/plans/11-game-systems.md)
--
-- 표는 resources/data/items.json 에 있고 (rpg-game.json 의 items 가 가리킨다), 이 모듈은
-- 그것을 읽어 id → { name, desc, order } 표로 돌려준다. 소지품 프레임워크
-- (scripts/lua/rpg/inventory.lua)는 이 표를 주입받을 뿐 내용을 모른다.
--
--   name   소지품 창에 뜨는 이름
--   desc   창 아래 칸의 설명 (두 줄까지 보인다)
--   order  목록에서의 순서. 작은 것이 위
--
-- 아이템 표를 읽지 못하면 빈 표를 돌려주고 rpg:error 줄을 찍는다. rpg-game.json 을 읽지
-- 못한 것은 맵 씬(game.lua)이 알리므로 여기서는 빈 표만 돌려준다.

local Config = require("scripts/lua/games/rpgdemo/config")
local PlayEnv = require("scripts/lua/games/rpgdemo/playenv")

local config = Config.load()
if config == nil then
	return {}
end

local items, itemsErr, path = Config.loadItems(config)
if itemsErr ~= nil then
	print(PlayEnv.errorLine(path, itemsErr))
end
return items
