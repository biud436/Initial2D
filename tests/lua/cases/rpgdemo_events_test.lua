-- rpgdemo_events_test.lua : 항구 마을과 여관의 이벤트를 맵 파일로 옮겨도 게임이 받는 목록이 같다
-- (docs/plans/m2-rpg-events.md 6절)
--
-- tests/fixtures/events/rpgdemo_events_before.json 은 이벤트를 맵 파일로 옮기기 전의 트리에서
-- 게임과 같은 순서(맵 파일 검사, 자산 풀기, 정의 파일과 병합)로 만든 목록이다. 자산은 표식
-- (@charset:npc, @face:npc)으로 적혀 있다. 두 번 대조한다.
--   표식: 정의 파일을 표식을 돌려주는 자산 모듈로 읽고, 맵 파일의 set 도 표식으로 푼다.
--         플레이스홀더에서는 player 와 npc 가 같은 파일이라 경로로는 둘을 가를 수 없다
--   경로: 표식을 지금의 Assets 가 고르는 경로로 바꾼 목록 == 게임이 실제로 받는 목록

local MapData = require("scripts/lua/rpg/mapdata")
local Assets = require("scripts/lua/rpg/assets")
local Config = require("scripts/lua/games/rpgdemo/config")

local M = {}

local SNAPSHOT_PATH = "./fixtures/events/rpgdemo_events_before.json"
local ASSETS_MODULE = "scripts/lua/rpg/assets"
local MAPS = { "port_town", "inn" }

-- 표식과 그 표식 자리에서 정의 파일이 부르던 Assets 함수
local TOKENS = {
	["@charset:player"] = "playerCharset",
	["@charset:npc"] = "npcCharset",
	["@face:npc"] = "faceset",
}

local tokenAssets = setmetatable({
	resolveRef = function(kind, ref) return "@" .. kind .. ":" .. tostring(ref.set) end,
}, { __index = Assets })
for token, fn in pairs(TOKENS) do
	tokenAssets[fn] = function() return token end
end

-- 정의 파일을 assets 모듈로 새로 읽는다. 끝나면 진짜 모듈과 빈 자리로 되돌린다
local function requireWith(module, assets)
	package.loaded[ASSETS_MODULE] = assets
	package.loaded[module] = nil
	local ok, def = pcall(require, module)
	package.loaded[ASSETS_MODULE] = Assets
	package.loaded[module] = nil
	return ok, def
end

-- 첫 차이의 자리와 두 값. 수는 정수와 실수까지 같아야 한다
local function diff(a, b, path)
	if type(a) ~= type(b) then
		return path .. ": " .. type(a) .. " / " .. type(b)
	end
	if type(a) == "number" then
		if math.type(a) ~= math.type(b) or a ~= b then
			return path .. ": " .. tostring(a) .. " / " .. tostring(b)
		end
		return nil
	end
	if type(a) ~= "table" then
		if a ~= b then return path .. ": " .. tostring(a) .. " / " .. tostring(b) end
		return nil
	end
	local keys = {}
	for k in pairs(a) do keys[#keys + 1] = k end
	for k in pairs(b) do
		if a[k] == nil then keys[#keys + 1] = k end
	end
	table.sort(keys, function(x, y) return tostring(x) < tostring(y) end)
	for _, k in ipairs(keys) do
		local d = diff(a[k], b[k], path .. "." .. tostring(k))
		if d ~= nil then return d end
	end
	return nil
end

-- 표식을 지금 고르는 경로로 바꾼 사본
local function materialize(value)
	if type(value) == "string" and TOKENS[value] ~= nil then
		return Assets[TOKENS[value]]()
	end
	if type(value) ~= "table" then return value end
	local out = {}
	for k, v in pairs(value) do out[k] = materialize(v) end
	return out
end

local function ids(events)
	local out = {}
	for i, ev in ipairs(events) do out[i] = tostring(ev.id) end
	return table.concat(out, ",")
end

-- 게임의 loadMap 과 같은 순서로 이벤트 목록을 만든다
local function build(t, name, module, assets, resolver)
	local ok, def = requireWith(module, assets)
	t.check(ok, name .. ": 정의 파일을 읽는다", def)
	if not ok then return nil end
	local fromMap, _, err = MapData.loadEvents(def.map)
	t.check(err == nil, name .. ": 맵 파일을 읽는다", err)
	local valid, problems, list, skipped = MapData.validateEvents(fromMap, { scripts = def.scripts })
	local lines = {}
	for _, p in ipairs(problems) do lines[#lines + 1] = p.path .. ": " .. p.message end
	t.check(valid and #problems == 0 and skipped == 0,
		name .. ": 맵 파일의 이벤트가 문제 없이 검사를 통과한다", table.concat(lines, "; "))
	return (MapData.merge(MapData.resolveAssets(list, resolver), def.events))
end

function M.run(t)
	local snapshot, serr = Json.Load(SNAPSHOT_PATH)
	t.check(type(snapshot) == "table" and type(snapshot.maps) == "table",
		"옮기기 전의 목록을 읽는다", serr)
	if type(snapshot) ~= "table" or type(snapshot.maps) ~= "table" then return end
	local config = Config.load()
	t.check(config ~= nil, "rpg-game.json 을 읽는다")
	if config == nil then return end

	for _, name in ipairs(MAPS) do
		local before = snapshot.maps[name]
		local entry = Config.mapEntry(config, name)
		t.check(type(before) == "table" and entry ~= nil, name .. ": 목록과 맵 등록이 있다")
		if type(before) == "table" and entry ~= nil then
			local module = (entry.def:gsub("%.lua$", ""))

			local tokens = build(t, name, module, tokenAssets, tokenAssets)
			if tokens ~= nil then
				t.check_eq(ids(tokens), ids(before), name .. ": id 와 순서가 같다")
				local d = diff(tokens, before, name)
				t.check(d == nil, name .. ": 자산 표식까지 같은 목록 (" .. #before .. "개)", d)
			end

			local real = build(t, name, module, Assets, Assets)
			if real ~= nil then
				local d = diff(real, materialize(before), name)
				t.check(d == nil, name .. ": 지금 고르는 경로로 풀어도 같은 목록", d)
			end

			-- 이벤트는 맵 파일에만 있다. 정의 파일에 남으면 같은 id 의 Lua 가 이겨 에디터의 편집이 안 보인다
			local ok, def = requireWith(module, Assets)
			t.check(ok and def.events == nil, name .. ": 정의 파일에 이벤트가 없다")
			local fromMap = MapData.loadEvents(Config.projectPath(entry.file))
			t.check_eq(#fromMap, #before, name .. ": 맵 파일의 이벤트 수")
		end
	end
end

return M
