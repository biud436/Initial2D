-- 알데바란 — 스테이지 목록 (docs/plans/aldebaran-7-tomb.md 7절 1항)
--
-- A6까지 스테이지는 하나였고 game.lua가 그 하나를 직접 require 했다. 1-2가
-- 생기면서 씬은 "어느 스테이지인가"를 인자로 받아야 한다. 이 파일이 그 인자의
-- 값들이다.
--
-- 스테이지 모듈이 채워야 하는 칸은 stages/forest.lua 위쪽에 모아 두었다.
-- 순서(M.order)는 원안 4.2절의 지도 순서다 — 1-1, 1-2, ...
--
-- 부르는 쪽은 경로를 끝까지 적는다:
--   local Stages = require("scripts/games/aldebaran/stages/init")
-- Lua 5.3의 기본 package.path에 ?/init.lua가 있다는 보장이 없어서다.

local M = {}

M.order = { "forest", "tomb" }

local modules = {
	forest = "scripts/games/aldebaran/stages/forest",
	tomb = "scripts/games/aldebaran/stages/tomb",
}

local cache = {}

--- 스테이지 하나. 모르는 id면 nil과 이유를 돌려준다.
function M.get(id)
	if id == nil then return nil, "스테이지 id가 없다" end
	if cache[id] ~= nil then return cache[id] end
	local path = modules[id]
	if path == nil then
		return nil, "모르는 스테이지 '" .. tostring(id) .. "'"
	end
	local stage = require(path)
	cache[id] = stage
	return stage
end

--- 처음 여는 스테이지
function M.first()
	return M.get(M.order[1])
end

--- 이 스테이지 다음. 마지막이면 nil (게임의 끝이다)
function M.after(id)
	for i, key in ipairs(M.order) do
		if key == id and M.order[i + 1] ~= nil then
			return M.get(M.order[i + 1])
		end
	end
	return nil
end

--- 몇 번째인가 (결과 창의 "1 / 2" 표시용)
function M.indexOf(id)
	for i, key in ipairs(M.order) do
		if key == id then return i end
	end
	return nil
end

M.count = #M.order

return M
