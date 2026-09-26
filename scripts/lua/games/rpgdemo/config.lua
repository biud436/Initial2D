-- config.lua : 데모의 게임 설정 파일 resources/data/rpg-game.json 을 읽는다
-- (docs/plans/m2-rpg-events.md)
--
-- 맵 등록(이름, 맵 파일, 정의 파일)과 아이템 표의 경로가 이 파일에 있다. 에디터도 같은
-- 파일을 읽는다. 경로는 프로젝트 기준이고 "./" 을 붙이지 않고 적는다.

local M = {}

M.PATH = "./resources/data/rpg-game.json"

--- 프로젝트 기준 경로를 엔진이 여는 꼴("./resources/...")로 바꾼다.
function M.projectPath(path)
	if type(path) ~= "string" then return nil end
	if path:sub(1, 2) == "./" then return path end
	return "./" .. path
end

--- "./" 을 뗀 경로 (두 꼴을 비교할 때 쓴다)
function M.bare(path)
	if type(path) ~= "string" then return nil end
	if path:sub(1, 2) == "./" then return path:sub(3) end
	return path
end

--- 설정 파일을 읽는다.
-- @param loader  function(path) -> table, err (기본 전역 Json.Load)
-- @return 설정 표, 또는 nil 과 이유
function M.load(loader)
	loader = loader or (_G.Json ~= nil and _G.Json.Load) or nil
	if loader == nil then return nil, "Json.Load를 쓸 수 없다" end
	local data, err = loader(M.PATH)
	if type(data) ~= "table" then return nil, tostring(err or "읽을 수 없다") end
	if data.version ~= 1 then
		return nil, "모르는 버전 " .. tostring(data.version)
	end
	if type(data.maps) ~= "table" then return nil, "maps 가 배열이 아니다" end
	return data
end

--- 맵 이름 → 정의 모듈 경로 ("scripts/lua/maps/port_town") 표.
function M.mapModules(config)
	local out = {}
	for _, entry in ipairs(config and config.maps or {}) do
		if type(entry) == "table" and type(entry.name) == "string" and type(entry.def) == "string" then
			out[entry.name] = (entry.def:gsub("%.lua$", ""))
		end
	end
	return out
end

--- 맵 이름으로 등록 항목을 찾는다.
function M.mapEntry(config, name)
	for _, entry in ipairs(config and config.maps or {}) do
		if type(entry) == "table" and entry.name == name then return entry end
	end
	return nil
end

--- 아이템 표를 읽어 id → { name, desc, order } 표로 만든다.
-- @return 표, 또는 빈 표와 이유와 읽으려던 경로
function M.loadItems(config, loader)
	loader = loader or (_G.Json ~= nil and _G.Json.Load) or nil
	local path = config and config.items or nil
	if type(path) ~= "string" then return {}, "items 경로가 없다", path end
	if loader == nil then return {}, "Json.Load를 쓸 수 없다", path end
	local data, err = loader(M.projectPath(path))
	if type(data) ~= "table" then return {}, tostring(err or "읽을 수 없다"), path end
	if type(data.items) ~= "table" then return {}, "items 가 배열이 아니다", path end
	local out = {}
	for i, item in ipairs(data.items) do
		if type(item) ~= "table" or type(item.id) ~= "string" or item.id == "" then
			return {}, "items[" .. i .. "] 에 id 가 없다", path
		end
		out[item.id] = { name = item.name, desc = item.desc, order = item.order }
	end
	return out, nil, path
end

return M
