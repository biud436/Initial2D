-- export_events.lua : 정의 파일(Lua)의 이벤트를 맵 파일의 events 로 쓸 JSON 을 만든다
-- (docs/plans/m2-rpg-events.md 6절)
--
-- tools/export_events.py 가 작업 폴더의 scripts/lua/main.lua 자리에 넣고 엔진 VM 에서 돌린다.
-- 요청은 ./export_request.json ({ "maps": [ { "name", "def", "file" } ] }), 결과는 ./export_result.json.
--
-- 정의 파일은 가짜 자산 모듈을 얹고 읽는다. 진짜 모듈을 __index 로 두고, 논리 이름(Assets.SETS)의
-- 후보를 고르는 함수만 "@charset:npc" 같은 표식을 돌려주게 덮는다. 외형과 얼굴 자리의 표식은
-- { set, index } 가 된다. 이벤트 순서는 MapData.merge 의 병합 순서이고, 키 순서는 2.6절이다.
-- 함수, 스키마에 없는 칸, 검사에 걸리는 이벤트는 옮기지 않고 이유와 함께 알린다.

local MapData = require("scripts/lua/rpg/mapdata")
local Commands = require("scripts/lua/rpg/commands")
local Shape = require("scripts/lua/rpg/jsonshape")
local Assets = require("scripts/lua/rpg/assets")

local REQUEST = "./export_request.json"
local RESULT = "./export_result.json"
local SCHEMA = "./resources/schema/event-commands.json"
local ASSETS_MODULE = "scripts/lua/rpg/assets"

-- 표식을 돌려주게 덮는 함수와 그 논리 이름
local MARKED = {
	{ fn = "playerCharset", kind = "charset", set = "player" },
	{ fn = "npcCharset", kind = "charset", set = "npc" },
	{ fn = "faceset", kind = "face", set = "npc" },
}

-- 스키마에 없는 중첩 객체의 키 순서 (2.6절의 표. 에디터도 같은 표를 갖는다)
local REF_KEYS = { "set", "file", "index" }
local WANDER_KEYS = { "minWait", "maxWait", "area" }
local AREA_KEYS = { "x", "y", "w", "h" }

local function marker(kind, set) return "@" .. kind .. ":" .. set end

local function parseMarker(s)
	if type(s) ~= "string" then return nil end
	return s:match("^@(%a+):(.+)$")
end

local function setOf(list)
	local out = {}
	for _, v in ipairs(list) do out[v] = true end
	return out
end

-- ---- 스키마 -------------------------------------------------------------------

local function loadSchema()
	local s, err = Json.Load(SCHEMA)
	if type(s) ~= "table" then error("스키마를 읽지 못했다: " .. tostring(err)) end
	local schema = { fields = {}, fieldType = {}, commands = {}, conditions = {} }
	for _, f in ipairs(s.event.fields) do
		schema.fields[#schema.fields + 1] = f.name
		schema.fieldType[f.name] = f.type
	end
	for _, c in ipairs(s.commands) do
		local spec = { order = { "code" }, argType = {}, list = {} }
		for _, a in ipairs(c.args) do
			spec.order[#spec.order + 1] = a.name
			spec.argType[a.name] = a.type
		end
		for _, l in ipairs(c.lists or {}) do
			spec.order[#spec.order + 1] = l.name
			spec.list[l.name] = l.perOption ~= nil and "perOption" or "list"
		end
		schema.commands[c.code] = spec
	end
	for _, c in ipairs(s.conditions) do
		local spec = { kind = c.kind, order = {}, argType = {} }
		for _, a in ipairs(c.args) do
			spec.order[#spec.order + 1] = a.name
			spec.argType[a.name] = a.type
		end
		schema.conditions[#schema.conditions + 1] = spec
	end
	return schema
end

-- ---- 옮길 수 있는가 보고, 표식을 논리 이름으로 바꾼 사본을 만든다 --------------------

local Walker = {}
Walker.__index = Walker

local function newWalker(schema)
	return setmetatable({ schema = schema, problems = {} }, Walker)
end

function Walker:add(path, message)
	self.problems[#self.problems + 1] = path .. ": " .. message
end

-- 스키마가 모양을 정하지 않는 값 (글, 수, 참거짓, 배열, 객체)
function Walker:plain(value, path)
	local tv = type(value)
	if tv == "function" then
		self:add(path, "함수는 맵 파일에 쓸 수 없다")
	elseif tv == "string" then
		if parseMarker(value) ~= nil then
			self:add(path, "자산 표식 " .. value .. " 이 외형이나 얼굴의 file 자리 밖에 있다")
		elseif utf8.len(value) == nil then
			self:add(path, "UTF-8 이 아닌 글")
		end
	elseif tv == "number" then
		if value ~= value or value == math.huge or value == -math.huge then
			self:add(path, "유한한 수가 아니다")
		end
	elseif tv == "table" then
		if Shape.isArray(value) then
			for i = 1, Shape.length(value) do self:plain(value[i], path .. "[" .. i .. "]") end
		elseif Shape.isObject(value) then
			for k, v in pairs(value) do self:plain(v, path .. "." .. k) end
		else
			self:add(path, "배열과 객체가 섞인 표")
		end
		local out = {}
		for k, v in pairs(value) do out[k] = v end
		return out
	elseif tv ~= "boolean" and tv ~= "nil" then
		self:add(path, "맵 파일에 쓸 수 없는 값 (" .. tv .. ")")
	end
	return value
end

-- 모르는 키. 함수면 그렇게 알린다
function Walker:unknown(key, value, path, what)
	if type(value) == "function" then
		self:add(path .. "." .. tostring(key), "함수는 맵 파일에 쓸 수 없다")
	else
		self:add(path .. "." .. tostring(key), "스키마에 없는 " .. what)
	end
end

-- 키가 전부 known 안에 있는 객체의 사본. 값은 each(key, value, path) 가 바꾼다
function Walker:object(value, path, known, what, each)
	if not Shape.isObject(value) then return self:plain(value, path) end
	local out = {}
	for k, v in pairs(value) do
		if known[k] then
			out[k] = each(k, v, path .. "." .. k)
		else
			self:unknown(k, v, path, what)
		end
	end
	return out
end

-- 외형이나 얼굴. file 자리의 표식은 set 이 된다
function Walker:ref(kind, value, path)
	local out = self:object(value, path, setOf(REF_KEYS), "칸", function(k, v, here)
		if k == "file" and parseMarker(v) ~= nil then return v end
		return self:plain(v, here)
	end)
	if not Shape.isObject(value) then return out end
	local mk, ms = parseMarker(value.file)
	if mk ~= nil then
		if mk ~= kind then
			self:add(path .. ".file", kind .. " 자리에 " .. value.file .. " 표식")
		elseif value.set ~= nil then
			self:add(path, "set 과 표식 file 이 함께 있다")
		end
		out.file = nil
		out.set = ms
	end
	return out
end

function Walker:wander(value, path)
	return self:object(value, path, setOf(WANDER_KEYS), "칸", function(k, v, here)
		if k == "area" then
			return self:object(v, here, setOf(AREA_KEYS), "칸", function(_, av, ahere)
				return self:plain(av, ahere)
			end)
		end
		return self:plain(v, here)
	end)
end

function Walker:condition(value, path)
	if not Shape.isObject(value) then return self:plain(value, path) end
	local spec
	for _, c in ipairs(self.schema.conditions) do
		if value[c.kind] ~= nil then spec = c break end
	end
	local known = spec and setOf(spec.order) or {}
	return self:object(value, path, known, "조건 칸", function(_, v, here)
		return self:plain(v, here)
	end)
end

function Walker:list(value, path)
	if not Shape.isArray(value) then return self:plain(value, path) end
	local out = {}
	for i = 1, Shape.length(value) do
		out[i] = self:command(value[i], path .. "[" .. i .. "]")
	end
	return out
end

function Walker:command(cmd, path)
	if not Shape.isObject(cmd) then return self:plain(cmd, path) end
	local spec = self.schema.commands[cmd.code]
	if spec == nil then
		self:add(path, "스키마에 없는 커맨드 " .. tostring(cmd.code))
		return self:plain(cmd, path)
	end
	local known = setOf(spec.order)
	return self:object(cmd, path, known, "인자", function(k, v, here)
		local listKind = spec.list[k]
		if listKind == "list" then return self:list(v, here) end
		if listKind == "perOption" then
			if not Shape.isArray(v) then return self:plain(v, here) end
			local out = {}
			for i = 1, Shape.length(v) do out[i] = self:list(v[i], here .. "[" .. i .. "]") end
			return out
		end
		local t = spec.argType[k]
		if t == "face" then return self:ref("face", v, here) end
		if t == "condition" then return self:condition(v, here) end
		return self:plain(v, here)
	end)
end

function Walker:event(ev, path)
	if not Shape.isObject(ev) then return self:plain(ev, path) end
	local known = setOf(self.schema.fields)
	return self:object(ev, path, known, "칸", function(k, v, here)
		local t = self.schema.fieldType[k]
		if t == "charset" then return self:ref("charset", v, here) end
		if t == "wander" then return self:wander(v, here) end
		if t == "list" then return self:list(v, here) end
		return self:plain(v, here)
	end)
end

-- ---- JSON 쓰기 (2.6절의 키 순서) --------------------------------------------------

local ESCAPES = { ['"'] = '\\"', ["\\"] = "\\\\", ["\b"] = "\\b", ["\f"] = "\\f",
	["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t" }

local function encString(s)
	return '"' .. s:gsub('[%c"\\]', function(c)
		return ESCAPES[c] or string.format("\\u%04x", c:byte())
	end) .. '"'
end

-- 정수는 정수로, 실수는 되읽으면 같은 값이 되는 가장 짧은 표기로
local function encNumber(n)
	if math.type(n) == "integer" then return string.format("%d", n) end
	for p = 1, 17 do
		local s = string.format("%." .. p .. "g", n)
		if tonumber(s) == n then
			if not s:find("[%.eE]") then s = s .. ".0" end
			return s
		end
	end
	return string.format("%.17g", n)
end

local encode

local function encArray(value, each)
	local parts = {}
	for i = 1, Shape.length(value) do parts[i] = each(value[i]) end
	return "[" .. table.concat(parts, ",") .. "]"
end

-- order 의 키를 그 순서로. order 에 없는 키는 이름 순서로 (json 값에서만 생긴다)
local function encObject(value, order, each)
	local parts, seen = {}, {}
	for _, k in ipairs(order) do
		if value[k] ~= nil then
			parts[#parts + 1] = encString(k) .. ":" .. each(k, value[k])
			seen[k] = true
		end
	end
	local rest = {}
	for k in pairs(value) do
		if not seen[k] then rest[#rest + 1] = k end
	end
	table.sort(rest)
	for _, k in ipairs(rest) do
		parts[#parts + 1] = encString(k) .. ":" .. each(k, value[k])
	end
	return "{" .. table.concat(parts, ",") .. "}"
end

-- 스키마가 모양을 정하지 않는 값. 빈 표는 hint 로 가린다 ("array" 면 [], 아니면 {})
local function encPlain(value, hint)
	local tv = type(value)
	if tv == "nil" then return "null" end
	if tv == "boolean" then return tostring(value) end
	if tv == "number" then return encNumber(value) end
	if tv == "string" then return encString(value) end
	if next(value) == nil then return hint == "array" and "[]" or "{}" end
	if Shape.isArray(value) then
		return encArray(value, function(v) return encPlain(v) end)
	end
	return encObject(value, {}, function(_, v) return encPlain(v) end)
end

local function encCommandList(schema, list)
	if type(list) ~= "table" then return encPlain(list) end
	return encArray(list, function(cmd) return encode(schema, "command", cmd) end)
end

encode = function(schema, kind, value)
	if type(value) ~= "table" then return encPlain(value) end
	if kind == "event" then
		return encObject(value, schema.fields, function(k, v)
			return encode(schema, schema.fieldType[k], v)
		end)
	elseif kind == "charset" or kind == "face" then
		return encObject(value, REF_KEYS, function(_, v) return encPlain(v) end)
	elseif kind == "wander" then
		return encObject(value, WANDER_KEYS, function(k, v)
			if k == "area" and type(v) == "table" then
				return encObject(v, AREA_KEYS, function(_, av) return encPlain(av) end)
			end
			return encPlain(v)
		end)
	elseif kind == "list" then
		return encCommandList(schema, value)
	elseif kind == "command" then
		local spec = schema.commands[value.code]
		return encObject(value, spec.order, function(k, v)
			local listKind = spec.list[k]
			if listKind == "list" then return encCommandList(schema, v) end
			if listKind == "perOption" then
				return encArray(v, function(branch) return encCommandList(schema, branch) end)
			end
			return encode(schema, spec.argType[k], v)
		end)
	elseif kind == "condition" then
		local order = {}
		for _, c in ipairs(schema.conditions) do
			if value[c.kind] ~= nil then order = c.order break end
		end
		return encObject(value, order, function(_, v) return encPlain(v) end)
	elseif kind == "options" or kind == "route" then
		return encPlain(value, "array")
	end
	return encPlain(value)
end

-- ---- 맵 하나 ------------------------------------------------------------------

local function requireDef(module)
	local fake = setmetatable({}, { __index = Assets })
	for _, m in ipairs(MARKED) do
		local token = marker(m.kind, m.set)
		fake[m.fn] = function() return token end
	end
	package.loaded[ASSETS_MODULE] = fake
	package.loaded[module] = nil
	local ok, def = pcall(require, module)
	package.loaded[ASSETS_MODULE] = Assets
	package.loaded[module] = nil
	return ok, def
end

-- @return 결과 JSON 글
--- 메타테이블이 있는 표의 경로 (없으면 nil). 이벤트 안의 표까지 본다
local function metatablePath(value, path, seen)
	if type(value) ~= "table" then return nil end
	seen = seen or {}
	if seen[value] then return nil end
	seen[value] = true
	if getmetatable(value) ~= nil then return path end
	for k, v in pairs(value) do
		local key = (type(k) == "number") and ("[" .. k .. "]") or ("." .. tostring(k))
		local found = metatablePath(v, path .. key, seen)
		if found ~= nil then return found end
	end
	return nil
end

local function exportMap(schema, req)
	local module = req.def:gsub("%.lua$", "")
	local ok, def = requireDef(module)
	if not ok then error(req.def .. ": 정의 파일을 읽지 못했다: " .. tostring(def)) end
	if type(def) ~= "table" then error(req.def .. ": 정의 파일이 표를 돌려주지 않는다") end

	local fromMap, _, err = MapData.loadEvents("./" .. req.file)
	if err ~= nil then error(req.file .. ": " .. tostring(err)) end
	if fromMap ~= nil and not Shape.isArray(fromMap) then
		error(req.file .. ": events 가 배열이 아니다")
	end

	-- 맵 파일의 이벤트는 자리 표시만 합친다. 파이썬이 원래 바이트대로 옮겨 적는다
	local stubs, isStub = {}, {}
	for i = 1, Shape.length(fromMap) do
		if not Shape.isObject(fromMap[i]) or type(fromMap[i].id) ~= "string" then
			error(req.file .. ": events[" .. i .. "] 에 id 가 없다")
		end
		local stub = { id = fromMap[i].id, mapIndex = i }
		stubs[i] = stub
		isStub[stub] = true
	end

	local defEvents = def.events or {}
	if not Shape.isArray(defEvents) then error(req.def .. ": events 가 배열이 아니다") end

	local movable, left = {}, {}
	local env = { scripts = def.scripts }
	-- 정의 파일 안에서 id 가 몇 번 나오는가 (둘 이상이면 게임은 뒤의 것만 쓴다)
	local idCount = {}
	for j = 1, Shape.length(defEvents) do
		local ev = defEvents[j]
		if type(ev) == "table" and type(ev.id) == "string" then idCount[ev.id] = (idCount[ev.id] or 0) + 1 end
	end
	local mapIds = {}
	for i = 1, Shape.length(fromMap) do mapIds[fromMap[i].id] = true end
	for j = 1, Shape.length(defEvents) do
		local ev = defEvents[j]
		local label = (type(ev) == "table" and type(ev.id) == "string") and ev.id or ("events[" .. j .. "]")
		local walker = newWalker(schema)
		local converted = walker:event(ev, "events[" .. j .. "]")
		local problems = walker.problems
		-- pairs 는 메타테이블(__index)로 오는 칸을 보지 못한다. 그런 칸을 잃지 않게 옮기지 않는다
		local metaPath = metatablePath(ev, "events[" .. j .. "]")
		if metaPath ~= nil then
			problems[#problems + 1] = metaPath .. ": 메타테이블이 있는 표는 옮길 수 없다 (메타테이블로 오는 칸을 잃는다)"
		end
		if type(ev) == "table" and type(ev.id) == "string" and idCount[ev.id] > 1 then
			problems[#problems + 1] = "events[" .. j .. "].id: 같은 id 의 이벤트가 정의 파일에 둘 이상이다 (게임은 뒤의 것만 쓴다)"
		end
		table.sort(problems)
		if #problems == 0 then
			local _, found = MapData.validateEvents({ converted }, env)
			for _, p in ipairs(found) do
				problems[#problems + 1] = "events[" .. j .. "]" .. p.path:sub(#"events[1]" + 1)
					.. ": " .. p.message
			end
		end
		if #problems == 0 then
			movable[#movable + 1] = converted
		else
			left[#left + 1] = { id = label, problems = problems, overrides = mapIds[label] == true }
		end
	end

	local merged = MapData.merge(stubs, movable)
	local parts = {}
	for _, item in ipairs(merged) do
		if isStub[item] then
			parts[#parts + 1] = '{"map":' .. item.mapIndex .. "}"
		else
			parts[#parts + 1] = '{"event":' .. encode(schema, "event", item) .. "}"
		end
	end
	local leftParts = {}
	for _, l in ipairs(left) do
		local ps = {}
		for i, p in ipairs(l.problems) do ps[i] = encString(p) end
		leftParts[#leftParts + 1] = '{"id":' .. encString(l.id) .. ',"overrides":' .. tostring(l.overrides)
			.. ',"problems":[' .. table.concat(ps, ",") .. "]}"
	end
	return '{"name":' .. encString(req.name)
		.. ',"mapCount":' .. Shape.length(fromMap)
		.. ',"order":[' .. table.concat(parts, ",") .. "]"
		.. ',"left":[' .. table.concat(leftParts, ",") .. "]}"
end

local function writeResult(text)
	local f = assert(io.open(RESULT, "w"))
	f:write(text)
	f:close()
end

function Initialize()
	local ok, result = pcall(function()
		local req, err = Json.Load(REQUEST)
		if type(req) ~= "table" then error("요청을 읽지 못했다: " .. tostring(err)) end
		local schema = loadSchema()
		for _, m in ipairs(MARKED) do
			local sets = Assets.SETS[m.kind]
			if sets == nil or sets[m.set] == nil then
				error("Assets.SETS 에 " .. m.kind .. "." .. m.set .. " 가 없다")
			end
			if Assets[m.fn]() ~= Assets.pick(sets[m.set]) then
				error("Assets." .. m.fn .. " 이 " .. m.kind .. "." .. m.set .. " 의 후보를 고르지 않는다")
			end
		end
		local maps = {}
		for _, r in ipairs(req.maps) do maps[#maps + 1] = exportMap(schema, r) end
		return '{"maps":[' .. table.concat(maps, ",") .. "]}"
	end)
	if ok then
		writeResult(result)
	else
		writeResult('{"error":' .. encString(tostring(result)) .. "}")
	end
	print("export_events:" .. (ok and "done" or "error"))
	GameExit()
end

function Update() end
function Render() end
function Destroy() end
