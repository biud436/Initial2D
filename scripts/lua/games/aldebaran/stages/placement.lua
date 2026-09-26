-- 알데바란, 맵 파일의 오브젝트에서 스테이지 배치를 만든다 (docs/plans/m1-map-objects.md)
--
-- 맵 포맷 v2의 objects(픽셀 좌표, 타입, props)를 읽어 스테이지 모듈이 쓰는 표로
-- 바꾼다. 타입과 칸은 resources/schema/map-objects.json이 정하고, 에디터는 같은
-- 스키마로 오브젝트를 맵 위에 그리고 고친다.
--
--   start       점, 하나      → START { x, y }
--   checkpoint  점            → CHECKPOINTS { x, y } 목록 (x 오름차순)
--   spawn       점            → spawns { species, x, y, minX, maxX, boss } 목록 (파일 순서)
--   landmark    띠             → LANDMARKS { id, x0, x1, title, text, skill, hallucination }
--   section     띠             → SECTIONS { name, x1 } 목록 (x 오름차순). x1은 띠의 오른끝
--   light       점            → 빛기둥 x. 기후 표가 방 이름으로 골라 쓴다 (lightsIn)
--
-- 띠의 오른끝은 x + width이고 양 끝을 포함한다. 띠 모양 오브젝트의 y는 쓰지 않는다.
--
--   local Placement = require("scripts/lua/games/aldebaran/stages/placement")
--   local placed = Placement.build("./resources/maps/aldebaran_forest.json")

local M = {}

local maps = {}                 -- 경로 → 읽은 맵 (한 번만 읽는다)

--- 맵 파일을 읽는다. 못 읽으면 오류를 던진다.
function M.load(path)
	if maps[path] == nil then
		local data, err = Json.Load(path)
		if data == nil then
			error("알데바란: 맵 파일을 읽지 못했다: " .. tostring(err), 2)
		end
		maps[path] = data
	end
	return maps[path]
end

--- x 오름차순으로 줄 세운다. x가 같으면 파일 순서를 지킨다.
local function sortByX(list)
	for i, e in ipairs(list) do e.order = i end
	table.sort(list, function(a, b)
		if a.x ~= b.x then return a.x < b.x end
		return a.order < b.order
	end)
end

--- 맵의 objects에서 스테이지 표를 만든다. 없으면 안 되는 것이 빠졌으면 오류를 던진다.
function M.build(path)
	local objects = M.load(path).objects or {}
	local out = { start = nil, checkpoints = {}, spawns = {}, landmarks = {},
		sections = {}, lights = {} }
	local checkpoints, sections = {}, {}

	for _, o in ipairs(objects) do
		local p = o.props or {}
		if o.type == "start" then
			out.start = { x = o.x, y = o.y }
		elseif o.type == "checkpoint" then
			checkpoints[#checkpoints + 1] = { x = o.x, y = o.y }
		elseif o.type == "spawn" then
			out.spawns[#out.spawns + 1] = {
				species = p.species, x = o.x, y = o.y, minX = p.minX, maxX = p.maxX,
				boss = (p.boss == true) or nil,
			}
		elseif o.type == "landmark" then
			out.landmarks[#out.landmarks + 1] = {
				id = o.id, x0 = o.x, x1 = o.x + o.width, title = p.title, text = p.text,
				skill = p.skill,
				-- JSON의 3은 정수로 읽히므로 실수로 바꾼다
				hallucination = (p.hallucination ~= nil) and p.hallucination * 1.0 or nil,
			}
		elseif o.type == "section" then
			sections[#sections + 1] = { name = p.name, x = o.x, x1 = o.x + o.width }
		elseif o.type == "light" then
			out.lights[#out.lights + 1] = o.x
		end
	end

	-- 한 프레임에 체크포인트 둘을 지나면 먼 쪽이 부활 지점이 되도록 x 순서로 둔다
	sortByX(checkpoints)
	for _, cp in ipairs(checkpoints) do
		out.checkpoints[#out.checkpoints + 1] = { x = cp.x, y = cp.y }
	end
	-- sectionAt은 오른끝이 오름차순이라고 보고 앞에서부터 찾는다
	sortByX(sections)
	for _, s in ipairs(sections) do
		out.sections[#out.sections + 1] = { name = s.name, x1 = s.x1 }
	end

	if out.start == nil then
		error("알데바란: " .. path .. "에 시작 지점(start)이 없다", 2)
	end
	if #out.sections == 0 then
		error("알데바란: " .. path .. "에 구간(section)이 없다", 2)
	end
	return out
end

--- 이름이 name인 구간 안의 빛기둥 x 목록 (파일 순서)
function M.lightsIn(placed, name)
	local xs = {}
	local left = nil
	for _, s in ipairs(placed.sections) do
		if s.name == name then
			for _, x in ipairs(placed.lights) do
				if (left == nil or x > left) and x <= s.x1 then xs[#xs + 1] = x end
			end
			return xs
		end
		left = s.x1
	end
	return xs
end

--- x가 속한 구간과 다음 구간, 그리고 다음 구간으로 넘어간 정도 (0..1).
-- 경계 앞뒤 fade 픽셀에서 두 구간을 섞는다. 마지막 구간 너머는 마지막 구간이다.
function M.sectionAt(sections, fade, x)
	for i, s in ipairs(sections) do
		if x <= s.x1 then
			local blend = 0
			if i < #sections then
				local d = s.x1 - x
				if d < fade then
					blend = (fade - d) / (fade * 2)
				end
			end
			if i > 1 then
				local prev = sections[i - 1]
				local d = x - prev.x1
				if d < fade then
					return prev.name, sections[i].name, 0.5 + d / (fade * 2)
				end
			end
			local nextName = (i < #sections) and sections[i + 1].name or s.name
			return s.name, nextName, blend
		end
	end
	local last = sections[#sections].name
	return last, last, 0
end

--- x에서 발이 y인 자리가 지면 속이면 한 칸(step)씩 올려 지면 위의 y를 돌려준다.
-- solid(px, py)는 그 픽셀이 막혔는가. 위가 끝까지 막혔으면 y를 그대로 돌려준다.
function M.standY(x, y, solid, step)
	local sy = y
	while sy > 0 and solid(x, sy - 1) do sy = sy - step end
	if sy <= 0 then return y end
	return sy
end

-- ---- 스테이지 이름 -------------------------------------------------------------

--- 경로의 구분자를 /로 맞추고 앞의 ./를 뗀다
local function normalize(path)
	local p = path:gsub("\\", "/")
	while p:sub(1, 2) == "./" do p = p:sub(3) end
	return p
end

--- 경로에서 폴더와 .json을 뗀 이름
local function baseName(path)
	local name = normalize(path):match("([^/]*)$")
	return (name:gsub("%.json$", ""))
end

--- name이 path의 맵을 가리키는가. 맵 이름(파일 이름이나 맵의 name), 파일 이름,
-- 프로젝트 기준 경로, 그 경로로 끝나는 절대 경로를 받는다.
function M.refersTo(path, name)
	if type(name) ~= "string" or name == "" then return false end
	local want = normalize(name)
	if want:find("/", 1, true) then
		local target = normalize(path)
		return want == target or want:sub(-(#target + 1)) == "/" .. target
	end
	local base = want:gsub("%.json$", "")
	return base == baseName(path) or base == M.load(path).name
end

return M
