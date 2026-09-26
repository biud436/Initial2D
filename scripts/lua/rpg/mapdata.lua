-- mapdata.lua : 맵 파일에 실려 온 이벤트 (9단계 마일스톤 3, docs/plans/10-demo-v2.md)
--
-- 맵 포맷 v2는 타일 옆에 `events` 배열을 싣는다. 좌표와 커맨드가 전부 데이터라
-- 맵 에디터가 그 자리에서 만들고 저장할 수 있다 — 이슈 24의 "이벤트 커맨드 배치"가
-- 향하는 곳이다. v1 파일(events 없음)은 그대로 열린다.
--
--   { "version": 2, ..., "events": [
--       { "id": "sign", "x": 1, "y": 0, "trigger": "action",
--         "commands": [ { "code": "message", "text": "..." } ] } ] }
--
-- 한 맵의 이벤트는 두 곳에서 온다.
--   맵 JSON        에디터가 놓은 것 (순수 데이터)
--   맵 정의 Lua    사람이 쓴 것 (커맨드로 적기 어려운 script 함수, 배회 설정 등)
-- 같은 id면 Lua 쪽이 이긴다. 에디터가 놓은 이벤트에 Lua로 살을 붙이는 길을
-- 열어 두기 위해서다 (좌표는 에디터가, 스크립트는 사람이).
--
-- 엔진 바인딩을 늘리지 않는다. 맵 JSON은 1단계의 Json.Load로 읽는다.

local M = {}

--- 맵 JSON에서 이벤트 배열만 읽는다.
-- @param mapPath  맵 파일 경로
-- @param loader   function(path) -> table, err (기본 전역 Json.Load)
-- @return 이벤트 배열 (없으면 빈 배열), 맵 버전, 오류 메시지
function M.loadEvents(mapPath, loader)
	loader = loader or (_G.Json ~= nil and _G.Json.Load) or nil
	if loader == nil or mapPath == nil then
		return {}, nil, "mapdata: Json.Load를 쓸 수 없다"
	end

	local data, err = loader(mapPath)
	if data == nil then
		return {}, nil, tostring(err)
	end
	return data.events or {}, data.version, nil
end

--- 맵에서 온 이벤트와 정의 파일의 이벤트를 합친다. 같은 id면 정의 파일이 이긴다.
-- 순서는 "맵에 있던 것 먼저, 정의 파일에만 있는 것 나중"이며, 정의 파일이
-- 덮어쓴 이벤트는 원래 자리를 지킨다 (auto 이벤트의 실행 순서가 흔들리지 않게).
function M.merge(mapEvents, defEvents)
	local byId, order = {}, {}

	local function put(def)
		if def == nil or def.id == nil then return end
		if byId[def.id] == nil then
			order[#order + 1] = def.id
		end
		byId[def.id] = def
	end

	for _, def in ipairs(mapEvents or {}) do put(def) end
	for _, def in ipairs(defEvents or {}) do put(def) end

	local merged = {}
	for _, id in ipairs(order) do
		merged[#merged + 1] = byId[id]
	end
	return merged
end

--- 맵 정의(Lua)와 맵 파일(JSON)을 합쳐 최종 이벤트 목록을 만든다.
-- @param def     맵 정의 테이블 (map, events, ...)
-- @param loader  Json.Load 대체 (테스트용)
-- @return 이벤트 배열, 오류 메시지
function M.eventsFor(def, loader)
	if def == nil then return {}, "mapdata: 맵 정의가 없다" end
	local fromMap, _, err = M.loadEvents(def.map, loader)
	return M.merge(fromMap, def.events), err
end

return M
