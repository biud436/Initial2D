-- rpg_event_schema_test.lua : 이벤트 스키마와 RPG 프레임워크의 대조 (docs/plans/m2-rpg-events.md)
--
-- resources/schema/event-commands.json 은 손으로 유지하고, 여기서 commands.lua 와 양방향으로
-- 대조한다. 커맨드를 더하고 스키마를 안 고치면(또는 그 반대면) 이 테스트가 깨진다.
--   [A] 스키마 형식 (에디터의 해석기가 거절하는 것이 없다)
--   [B] 커맨드 목록 == Commands.codes()
--   [C] 커맨드마다 인자 명세(이름, 순서, 타입, 필수, min, max, values, ref) == describe()[code].args,
--       스키마의 인자마다 틀린 타입의 값을 validate 가 그 경로에서 거절한다
--   [D] 하위 목록 == describe()[code].lists
--   [E] 조건의 꼴과 순서 == Commands.CONDITIONS, 꼴마다 인자 명세 == describeConditions(),
--       비교 연산이 Commands.test 에서 참과 거짓을 가른다
--   [F] 이벤트 칸: 트리거, 방향, 예약 id, 이동 루트의 걸음과 접두사
--   [G] 자산 이름 == Assets.SETS, 시트 규격 == Specs
--   [H] 모든 맵 파일의 이벤트가 validateEvents 를 통과하고, 정의 파일의 커맨드도 검증을 통과한다
--   [I] 경로 픽스처: validateEvents(invalid_events) 의 경로 집합 == invalid_events.paths.json
--   [J] 게임 설정 resources/data/rpg-game.json 과 아이템 표

local Commands = require("scripts/lua/rpg/commands")
local Event = require("scripts/lua/rpg/event")
local Character = require("scripts/lua/rpg/character")
local Specs = require("scripts/lua/rpg/specs")
local Assets = require("scripts/lua/rpg/assets")
local MapData = require("scripts/lua/rpg/mapdata")
local Shape = require("scripts/lua/rpg/jsonshape")
local Config = require("scripts/lua/games/rpgdemo/config")

local M = {}

local SCHEMA_PATH = "./resources/schema/event-commands.json"
local MAP_OBJECTS_PATH = "./resources/schema/map-objects.json"
local FIXTURE_PATH = "./fixtures/events/invalid_events.json"
local FIXTURE_PATHS_PATH = "./fixtures/events/invalid_events.paths.json"
local GAME_LUA = "./scripts/lua/games/rpgdemo/game.lua"

-- resources/maps/ 의 맵 파일 전부. Lua 에는 폴더 목록이 없어 이름을 적는다.
-- 파일을 더하면 여기에도 더한다 ([J] 가 rpg-game.json 의 파일이 여기 다 있는지 본다).
local MAP_FILES = {
	"resources/maps/aldebaran_forest.json",
	"resources/maps/aldebaran_tomb.json",
	"resources/maps/inn.json",
	"resources/maps/port_town.json",
	"resources/maps/room.json",
	"resources/maps/room_rtp.json",
	"resources/maps/sample.json",
	"resources/maps/village.json",
	"resources/maps/village_rtp.json",
}

-- 스키마의 인자 타입 (m2-rpg-events.md 2.3절 표)
local ARG_TYPES = {
	string = true, text = true, integer = true, number = true, boolean = true, enum = true,
	scalar = true, ref = true, file = true, face = true, charset = true, options = true,
	route = true, condition = true, wander = true, json = true, list = true,
}
-- 이벤트 칸에만 쓰는 타입 (커맨드 인자로는 쓰지 않는다)
local EVENT_ONLY = { charset = true, wander = true, list = true }
local REF_KINDS = { map = true, item = true, flag = true, var = true, character = true }
local ARG_KEYS = {
	name = true, type = true, ref = true, values = true, required = true, min = true,
	max = true, default = true, accept = true, dir = true, suggest = true, label = true,
}

-- 스키마는 필수인데 엔진의 인자 명세는 선택이고 validate 의 따로 규칙이 보는 인자
local SPECIAL_REQUIRED = { ["script.name"] = true }
-- 인자 명세에서 대조하는 칸 (label, default, accept, dir, suggest 는 에디터의 것)
local COMPARED_KEYS = { "type", "required", "min", "max", "ref" }

-- ---- 도움 함수 ---------------------------------------------------------------

local function keysOf(t)
	local out = {}
	for k in pairs(t or {}) do out[#out + 1] = tostring(k) end
	table.sort(out)
	return out
end

local function sortedCopy(list)
	local out = {}
	for i, v in ipairs(list or {}) do out[i] = tostring(v) end
	table.sort(out)
	return out
end

local function join(list) return table.concat(list, ",") end

local function isInteger(v)
	return type(v) == "number" and v == math.floor(v)
end

local function readFile(path)
	local f = io.open(path, "rb")
	if f == nil then return nil end
	local text = f:read("a")
	f:close()
	return text
end

local function findCommand(schema, code)
	for _, c in ipairs(schema.commands or {}) do
		if c.code == code then return c end
	end
	return nil
end

local function findArg(args, name)
	for _, a in ipairs(args or {}) do
		if a.name == name then return a end
	end
	return nil
end

-- 인자 명세 하나의 형식 문제
local function argProblems(arg, where, bad)
	if type(arg) ~= "table" then
		bad[#bad + 1] = where .. ": 객체가 아니다"
		return
	end
	for k in pairs(arg) do
		if not ARG_KEYS[k] then bad[#bad + 1] = where .. ": 모르는 키 " .. tostring(k) end
	end
	if type(arg.name) ~= "string" or arg.name == "" then bad[#bad + 1] = where .. ".name" end
	if not ARG_TYPES[arg.type] then bad[#bad + 1] = where .. ".type " .. tostring(arg.type) end
	if type(arg.label) ~= "string" or arg.label == "" then bad[#bad + 1] = where .. ".label" end
	if arg.required ~= nil and type(arg.required) ~= "boolean" then
		bad[#bad + 1] = where .. ".required"
	end
	if arg.type == "enum" then
		if type(arg.values) ~= "table" or #arg.values == 0 then
			bad[#bad + 1] = where .. ".values"
		else
			for _, v in ipairs(arg.values) do
				if type(v) ~= "string" then bad[#bad + 1] = where .. ".values: 글이 아닌 값" end
			end
		end
	elseif arg.values ~= nil then
		bad[#bad + 1] = where .. ".values 는 enum 에만"
	end
	if arg.type == "ref" then
		if not REF_KINDS[arg.ref] then bad[#bad + 1] = where .. ".ref " .. tostring(arg.ref) end
	elseif arg.ref ~= nil then
		bad[#bad + 1] = where .. ".ref 는 ref 에만"
	end
	for _, k in ipairs({ "min", "max" }) do
		if arg[k] ~= nil and type(arg[k]) ~= "number" then bad[#bad + 1] = where .. "." .. k end
	end
	if arg.min ~= nil and arg.max ~= nil and arg.min > arg.max then
		bad[#bad + 1] = where .. ": min > max"
	end
	if arg.accept ~= nil then
		if arg.type ~= "file" or type(arg.accept) ~= "table" or #arg.accept == 0 then
			bad[#bad + 1] = where .. ".accept"
		end
	end
	if arg.dir ~= nil and (arg.type ~= "file" or type(arg.dir) ~= "string") then
		bad[#bad + 1] = where .. ".dir"
	end
	if arg.suggest ~= nil and (type(arg.suggest) ~= "table" or #arg.suggest == 0) then
		bad[#bad + 1] = where .. ".suggest"
	end
	-- 기본값은 그 타입의 값이어야 한다
	local d = arg.default
	if d ~= nil then
		local okDefault = true
		if arg.type == "enum" then
			okDefault = false
			for _, v in ipairs(arg.values or {}) do
				if v == d then okDefault = true end
			end
		elseif arg.type == "integer" then
			okDefault = isInteger(d)
		elseif arg.type == "number" then
			okDefault = type(d) == "number"
		elseif arg.type == "boolean" then
			okDefault = type(d) == "boolean"
		elseif arg.type == "scalar" then
			okDefault = type(d) == "boolean" or type(d) == "number" or type(d) == "string"
		elseif arg.type == "string" or arg.type == "text" then
			okDefault = type(d) == "string"
		else
			okDefault = false
		end
		if okDefault and type(d) == "number" then
			if (arg.min ~= nil and d < arg.min) or (arg.max ~= nil and d > arg.max) then
				okDefault = false
			end
		end
		if not okDefault then bad[#bad + 1] = where .. ".default " .. tostring(d) end
	end
end

-- 인자 배열의 형식 문제 (이름 겹침 포함)
local function argsProblems(args, where, bad, allowEventTypes)
	if type(args) ~= "table" then
		bad[#bad + 1] = where .. ": 배열이 아니다"
		return
	end
	local names = {}
	for i, arg in ipairs(args) do
		local w = where .. "[" .. i .. "]"
		argProblems(arg, w, bad)
		if type(arg) == "table" then
			if names[arg.name] then bad[#bad + 1] = w .. ": 이름이 겹친다 " .. tostring(arg.name) end
			names[arg.name] = true
			if not allowEventTypes and EVENT_ONLY[arg.type] then
				bad[#bad + 1] = w .. ": 이벤트 칸 전용 타입 " .. tostring(arg.type)
			end
		end
	end
end

-- 요약 글의 {이름} 이 인자 이름인가
local function summaryProblems(cmd, where, bad)
	if cmd.summary == nil then return end
	if type(cmd.summary) ~= "string" then
		bad[#bad + 1] = where .. ".summary"
		return
	end
	for name in cmd.summary:gmatch("{([^}]*)}") do
		if findArg(cmd.args, name) == nil then
			bad[#bad + 1] = where .. ".summary: 모르는 인자 " .. name
		end
	end
end

-- 경로 목록을 집합으로 비교하고 모자란 것과 남는 것을 글로
local function setDiff(actual, expected)
	local a, e = {}, {}
	for _, p in ipairs(actual) do a[p] = true end
	for _, p in ipairs(expected) do e[p] = true end
	local missing, extra = {}, {}
	for p in pairs(e) do if not a[p] then missing[#missing + 1] = p end end
	for p in pairs(a) do if not e[p] then extra[#extra + 1] = p end end
	table.sort(missing)
	table.sort(extra)
	return missing, extra
end

-- 스키마의 인자 배열과 엔진의 인자 명세를 양방향으로 대조한다
local function compareArgs(fromSchema, fromEngine, where, bad)
	local a, b = {}, {}
	for _, arg in ipairs(fromSchema or {}) do a[#a + 1] = tostring(arg.name) end
	for _, arg in ipairs(fromEngine or {}) do b[#b + 1] = tostring(arg.name) end
	if join(a) ~= join(b) then
		bad[#bad + 1] = where .. ": 스키마 {" .. join(a) .. "} / 엔진 {" .. join(b) .. "}"
	end
	for _, s in ipairs(fromSchema or {}) do
		local e = findArg(fromEngine, s.name)
		local w = where .. "." .. tostring(s.name)
		if e ~= nil then
			for _, k in ipairs(COMPARED_KEYS) do
				local sv, ev = s[k], e[k]
				if k == "required" then
					sv, ev = sv == true, ev == true
					if SPECIAL_REQUIRED[w] then sv = not sv end
				end
				if sv ~= ev then
					bad[#bad + 1] = w .. "." .. k .. ": 스키마 " .. tostring(s[k]) .. " / 엔진 " .. tostring(e[k])
				end
			end
			if join(s.values or {}) ~= join(e.values or {}) then
				bad[#bad + 1] = w .. ".values: 스키마 {" .. join(s.values or {}) .. "} / 엔진 {"
					.. join(e.values or {}) .. "}"
			end
		end
	end
end

-- 스키마 타입의 올바른 표본 값 (엔진의 명세를 보지 않고 스키마만으로 만든다)
local function validSample(arg, schema)
	local t = arg.type
	if t == "string" or t == "text" or t == "ref" then return "a" end
	if t == "file" then return "./resources/audio/door.wav" end
	if t == "integer" then return arg.min or 1 end
	if t == "number" then return (arg.min or 0) + 0.5 end
	if t == "boolean" then return true end
	if t == "enum" then return arg.values[1] end
	if t == "scalar" then return 1 end
	if t == "face" then return { set = next(schema.assets.face), index = 0 } end
	if t == "options" then return { "a" } end
	if t == "route" then return { schema.route.moves[1] } end
	if t == "condition" then return { flag = "a" } end
	if t == "json" then return { a = { 1, "x" } } end
	return nil
end

-- 스키마 타입이 받지 않는 값들. json 은 어떤 값이든 받는다
local function wrongSamples(arg)
	local t = arg.type
	local out = {}
	if t == "string" or t == "text" or t == "ref" or t == "enum" then
		out = { 5, true, { a = 1 }, { 1 } }
	elseif t == "file" then
		out = { "", 5, { a = 1 } }
	elseif t == "integer" then
		out = { 1.5, "1", true, { a = 1 } }
	elseif t == "number" then
		out = { "1", true, { a = 1 } }
	elseif t == "boolean" then
		out = { "yes", 1, { a = 1 } }
	elseif t == "scalar" then
		out = { { a = 1 }, { 1 } }
	elseif t == "face" then
		out = { 3, "npc", { 1, 2 }, { index = 0 } }
	elseif t == "options" or t == "route" then
		out = { "a", { a = "b" }, { "a", 5 } }
	elseif t == "condition" then
		out = { "a", { 1, 2 } }
	end
	if t == "enum" then out[#out + 1] = "없는 값" end
	if (t == "integer" or t == "number") and arg.min ~= nil then out[#out + 1] = arg.min - 1 end
	if (t == "integer" or t == "number") and arg.max ~= nil then out[#out + 1] = arg.max + 1 end
	if t == "options" and arg.min ~= nil and arg.min > 0 then out[#out + 1] = {} end
	return out
end

local function shallowCopy(t)
	local out = {}
	for k, v in pairs(t) do out[k] = v end
	return out
end

-- 문제 중에 그 인자의 경로(또는 그 아래)가 있는가
local function hits(problems, here)
	for _, p in ipairs(problems) do
		local path = p.path
		if path == here or path:sub(1, #here + 1) == here .. "."
			or path:sub(1, #here + 1) == here .. "[" then
			return true
		end
	end
	return false
end

local function shown(v)
	if type(v) == "table" then return Shape.isArray(v) and "[배열]" or "{객체}" end
	return type(v) .. " " .. tostring(v)
end

-- ---- 케이스 ------------------------------------------------------------------

function M.run(t)
	local schema, why = Json.Load(SCHEMA_PATH)
	t.check(type(schema) == "table", "event-commands.json 을 읽는다", why)
	if type(schema) ~= "table" then return end
	local describe = Commands.describe()

	-- [A] 형식 -----------------------------------------------------------------
	do
		t.check_eq(schema.version, 1, "스키마 버전은 1")
		local bad = {}

		local ev = schema.event
		if type(ev) ~= "table" then
			bad[#bad + 1] = "event: 객체가 아니다"
		else
			argsProblems(ev.fields, "event.fields", bad, true)
			if type(ev.reserved) ~= "table" then bad[#bad + 1] = "event.reserved" end
		end

		local codes = {}
		for i, cmd in ipairs(schema.commands or {}) do
			local w = "commands[" .. i .. "]"
			if type(cmd.code) ~= "string" or cmd.code == "" then bad[#bad + 1] = w .. ".code" end
			if codes[cmd.code] then bad[#bad + 1] = w .. ": code 가 겹친다 " .. tostring(cmd.code) end
			codes[cmd.code] = true
			if type(cmd.label) ~= "string" or cmd.label == "" then bad[#bad + 1] = w .. ".label" end
			if type(cmd.group) ~= "string" or cmd.group == "" then bad[#bad + 1] = w .. ".group" end
			if cmd.ends ~= nil and cmd.ends ~= true then bad[#bad + 1] = w .. ".ends 는 true 만" end
			argsProblems(cmd.args, w .. ".args", bad, false)
			summaryProblems(cmd, w, bad)
			local listNames = {}
			for j, list in ipairs(cmd.lists or {}) do
				local lw = w .. ".lists[" .. j .. "]"
				if type(list.name) ~= "string" or list.name == "" then bad[#bad + 1] = lw .. ".name" end
				if listNames[list.name] or findArg(cmd.args, list.name) ~= nil then
					bad[#bad + 1] = lw .. ": 이름이 겹친다 " .. tostring(list.name)
				end
				listNames[list.name] = true
				if type(list.label) ~= "string" or list.label == "" then bad[#bad + 1] = lw .. ".label" end
				if list.perOption ~= nil then
					local opt = findArg(cmd.args, list.perOption)
					if opt == nil or opt.type ~= "options" then
						bad[#bad + 1] = lw .. ".perOption 은 options 인자의 이름"
					end
				end
			end
		end

		local kinds = {}
		for i, cond in ipairs(schema.conditions or {}) do
			local w = "conditions[" .. i .. "]"
			if type(cond.kind) ~= "string" or cond.kind == "" then bad[#bad + 1] = w .. ".kind" end
			if kinds[cond.kind] then bad[#bad + 1] = w .. ": kind 가 겹친다" end
			kinds[cond.kind] = true
			if type(cond.label) ~= "string" then bad[#bad + 1] = w .. ".label" end
			argsProblems(cond.args, w .. ".args", bad, false)
			local first = (cond.args or {})[1]
			if type(first) ~= "table" or first.name ~= cond.kind or first.required ~= true then
				bad[#bad + 1] = w .. ": 첫 인자는 kind 와 같은 이름의 필수 인자"
			end
		end

		for kind, sets in pairs(schema.assets or {}) do
			for name, list in pairs(sets) do
				local w = "assets." .. kind .. "." .. name
				if type(list) ~= "table" or #list == 0 then
					bad[#bad + 1] = w .. ": 후보가 없다"
				else
					for _, path in ipairs(list) do
						if type(path) ~= "string" or path:sub(1, 12) ~= "./resources/" then
							bad[#bad + 1] = w .. ": ./resources/ 꼴이 아니다 " .. tostring(path)
						end
					end
				end
			end
		end

		local route = schema.route or {}
		if type(route.moves) ~= "table" or #route.moves == 0 then bad[#bad + 1] = "route.moves" end
		if type(route.turnPrefix) ~= "string" then bad[#bad + 1] = "route.turnPrefix" end
		if type(route.waitPrefix) ~= "string" then bad[#bad + 1] = "route.waitPrefix" end

		local known = Commands.argTypes()
		local unknown = {}
		for _, cmd in ipairs(schema.commands or {}) do
			for _, arg in ipairs(cmd.args or {}) do
				if not known[arg.type] then unknown[#unknown + 1] = tostring(cmd.code) .. "." .. tostring(arg.name) end
			end
		end
		for _, cond in ipairs(schema.conditions or {}) do
			for _, arg in ipairs(cond.args or {}) do
				if not known[arg.type] then unknown[#unknown + 1] = tostring(cond.kind) .. "." .. tostring(arg.name) end
			end
		end
		t.check(#unknown == 0, "커맨드와 조건의 인자 타입을 엔진 검증이 안다", table.concat(unknown, ", "))

		t.check(#bad == 0, "스키마가 형식을 지킨다", table.concat(bad, ", "))
		t.check_eq(#(schema.commands or {}), 17, "커맨드 17종을 다 적었다")
		t.check_eq(#(schema.conditions or {}), 3, "조건 세 꼴을 다 적었다")
	end

	-- [B] 커맨드 목록 ------------------------------------------------------------
	do
		local codes = {}
		for _, cmd in ipairs(schema.commands or {}) do codes[#codes + 1] = cmd.code end
		t.check_eq(join(sortedCopy(codes)), join(Commands.codes()),
			"스키마의 code 집합 == Commands.codes()")
	end

	-- [C] 인자 명세 ---------------------------------------------------------------
	do
		local bad = {}
		for _, code in ipairs(Commands.codes()) do
			local cmd = findCommand(schema, code)
			local d = describe[code]
			if cmd ~= nil and d ~= nil then
				compareArgs(cmd.args, d.args, code, bad)
			end
		end
		t.check(#bad == 0, "커맨드마다 인자 명세가 스키마의 args 와 같다 (양방향)", table.concat(bad, "; "))

		for key in pairs(SPECIAL_REQUIRED) do
			local code, name = key:match("^(.-)%.(.+)$")
			local arg = findArg((findCommand(schema, code) or {}).args, name)
			t.check(arg ~= nil and arg.required == true, key .. " 는 스키마에서 필수")
			t.check_eq(describe[code].required[name], nil, key .. " 는 인자 명세가 아니라 따로 규칙이 본다")
		end
		-- script.name 의 따로 규칙이 실제로 도는지
		local _, errors = Commands.validate({ { code = "script" } })
		t.check(#errors == 1 and errors[1]:find("%[1%]%.name") ~= nil,
			"이름 없는 script 는 .name 에 걸린다", table.concat(errors, " "))

		-- 스키마의 인자마다: 표본으로 채운 커맨드는 통과하고, 그 인자에 틀린 타입의 값을 넣거나
		-- 필수 인자를 빼면 validate 가 그 인자의 경로에 문제를 낸다. 새 인자를 스키마에 더하고
		-- 엔진이 검사하지 않으면 여기서 깨진다.
		local env = { scripts = { a = function() end } }
		local missed, tried = {}, 0
		for _, spec in ipairs(schema.commands or {}) do
			local base = { code = spec.code }
			for _, arg in ipairs(spec.args or {}) do
				if arg.required then base[arg.name] = validSample(arg, schema) end
			end
			local full = shallowCopy(base)
			for _, arg in ipairs(spec.args or {}) do full[arg.name] = validSample(arg, schema) end
			local _, baseErrors = Commands.validate({ base }, env)
			t.check(#baseErrors == 0, spec.code .. ": 필수 인자만 채우면 통과한다", table.concat(baseErrors, "; "))
			local _, fullErrors = Commands.validate({ full }, env)
			t.check(#fullErrors == 0, spec.code .. ": 모든 인자를 스키마 타입으로 채우면 통과한다",
				table.concat(fullErrors, "; "))
			for _, arg in ipairs(spec.args or {}) do
				local cases = wrongSamples(arg)
				if arg.required then cases[#cases + 1] = "(없음)" end
				for _, wrong in ipairs(cases) do
					local cmd = shallowCopy(full)
					if wrong == "(없음)" then cmd[arg.name] = nil else cmd[arg.name] = wrong end
					tried = tried + 1
					if not hits(Commands.problems({ cmd }, env), "[1]." .. arg.name) then
						missed[#missed + 1] = spec.code .. "." .. arg.name .. " = " .. shown(wrong)
					end
				end
			end
		end
		t.check(#missed == 0 and tried > 100,
			"스키마의 인자마다 틀린 타입과 빠진 필수를 그 경로에서 거절한다 (" .. tried .. "가지)",
			table.concat(missed, "; "))
	end

	-- [D] 하위 목록 ---------------------------------------------------------------
	do
		local bad = {}
		for _, code in ipairs(Commands.codes()) do
			local cmd = findCommand(schema, code)
			local d = describe[code]
			if cmd ~= nil and d ~= nil then
				local names, perOption = {}, {}
				for _, list in ipairs(cmd.lists or {}) do
					names[#names + 1] = list.name
					if list.perOption ~= nil then perOption[list.name] = list.perOption end
				end
				if join(names) ~= join(d.lists) then
					bad[#bad + 1] = code .. ": 스키마 {" .. join(names) .. "} / describe {" .. join(d.lists) .. "}"
				end
				for name, arg in pairs(d.perOption) do
					if perOption[name] ~= arg then bad[#bad + 1] = code .. "." .. name .. ".perOption" end
				end
				for name in pairs(perOption) do
					if d.perOption[name] == nil then bad[#bad + 1] = code .. "." .. name .. ": 항목마다가 아니다" end
				end
			end
		end
		t.check(#bad == 0, "하위 목록 이름과 순서가 describe 와 같다", table.concat(bad, "; "))
		t.check_eq(join(describe.choice.lists), "branches", "choice 의 하위 목록")
		t.check_eq(join(describe["if"].lists), "thenDo,elseDo", "if 의 하위 목록")
	end

	-- [E] 조건 ---------------------------------------------------------------------
	do
		local kinds = {}
		for _, cond in ipairs(schema.conditions or {}) do kinds[#kinds + 1] = cond.kind end
		t.check_eq(join(kinds), join(Commands.CONDITIONS), "조건의 꼴과 순서 == Commands.CONDITIONS")

		-- 꼴마다 인자 명세가 같고, 판정하는 꼴의 인자마다 틀린 값을 .cond.<인자> 에서 거절한다
		local condDescribe = Commands.describeConditions()
		t.check_eq(join(keysOf(condDescribe)), join(sortedCopy(Commands.CONDITIONS)),
			"조건 명세의 꼴 == CONDITIONS")
		local bad, missed, tried = {}, {}, 0
		for _, cond in ipairs(schema.conditions or {}) do
			compareArgs(cond.args, condDescribe[cond.kind], "conditions." .. tostring(cond.kind), bad)
			local full = {}
			for _, arg in ipairs(cond.args or {}) do full[arg.name] = validSample(arg, schema) end
			local _, okErrors = Commands.validate({ { code = "if", cond = full } })
			t.check(#okErrors == 0, cond.kind .. " 조건: 스키마 타입으로 채우면 통과한다", table.concat(okErrors, "; "))
			for _, arg in ipairs(cond.args or {}) do
				for _, wrong in ipairs(wrongSamples(arg)) do
					local c = shallowCopy(full)
					c[arg.name] = wrong
					tried = tried + 1
					if not hits(Commands.problems({ { code = "if", cond = c } }), "[1].cond." .. arg.name) then
						missed[#missed + 1] = cond.kind .. "." .. arg.name .. " = " .. shown(wrong)
					end
				end
			end
		end
		t.check(#bad == 0, "조건 꼴마다 인자 명세가 스키마와 같다 (양방향)", table.concat(bad, "; "))
		t.check(#missed == 0 and tried > 20,
			"조건의 인자마다 틀린 값을 .cond.<인자> 에서 거절한다 (" .. tried .. "가지)", table.concat(missed, "; "))

		-- 비교 연산의 뜻. 스키마의 op 값마다 참인 경우와 거짓인 경우를 만들어 판정한다
		local EXPECT = {
			["=="] = function(a, b) return a == b end,
			["~="] = function(a, b) return a ~= b end,
			["<"] = function(a, b) return a < b end,
			["<="] = function(a, b) return a <= b end,
			[">"] = function(a, b) return a > b end,
			[">="] = function(a, b) return a >= b end,
		}
		local Inventory = require("scripts/lua/rpg/inventory")
		local bag = {}
		Inventory.give(bag, "silver", 2)
		local samples = {
			var = function(op, v) return Commands.test({ var = "n", op = op, value = v }, { n = 2 }) end,
			item = function(op, v) return Commands.test({ item = "silver", op = op, value = v }, bag) end,
		}
		for kind, judge in pairs(samples) do
			local cond = nil
			for _, c in ipairs(schema.conditions or {}) do
				if c.kind == kind then cond = c end
			end
			local opArg = findArg(cond and cond.args, "op")
			t.check(opArg ~= nil and opArg.type == "enum", kind .. " 조건에 op 고르기가 있다")
			for _, op in ipairs(opArg and opArg.values or {}) do
				local expect = EXPECT[op]
				t.check(expect ~= nil, kind .. ": 연산 " .. op .. " 의 뜻을 안다")
				if expect ~= nil then
					local seen = {}
					local wrong = {}
					for _, v in ipairs({ 1, 2, 3 }) do
						local got = judge(op, v)
						seen[got] = true
						if got ~= expect(2, v) then wrong[#wrong + 1] = "2 " .. op .. " " .. v end
					end
					t.check(#wrong == 0 and seen[true] and seen[false],
						kind .. ": " .. op .. " 이 참과 거짓을 가른다", table.concat(wrong, ", "))
				end
			end
		end

		-- 기본값: var 의 op 는 ==, value 는 0
		local varCond = schema.conditions and schema.conditions[3] or {}
		t.check_eq((findArg(varCond.args, "op") or {}).default, "==", "var 의 op 기본값은 ==")
		t.check(Commands.test({ var = "n", value = 2 }, { n = 2 })
			and not Commands.test({ var = "n", value = 3 }, { n = 2 }), "op 가 없으면 == 로 판정한다")
		t.check(Commands.test({ var = "n", op = "==" }, {}), "value 가 없으면 0")
		-- item 은 op 에 기본값을 적지 않는다: 둘 다 없으면 하나 이상, op 만 없으면 >=, value 만 없으면 1
		local itemCond = schema.conditions and schema.conditions[1] or {}
		t.check_eq((findArg(itemCond.args, "op") or {}).default, nil, "item 의 op 에는 기본값이 없다")
		t.check(Commands.test({ item = "silver" }, bag), "item 만 있으면 하나 이상")
		t.check(Commands.test({ item = "silver", value = 2 }, bag)
			and not Commands.test({ item = "silver", value = 3 }, bag), "op 만 없으면 >=")
		t.check(Commands.test({ item = "silver", op = ">" }, bag)
			and not Commands.test({ item = "silver", op = ">" }, {}), "value 만 없으면 1")

		-- setVar 의 계산
		local setVar = findCommand(schema, "setVar")
		local opArg = findArg(setVar and setVar.args, "op")
		t.check_eq(join(opArg and opArg.values or {}), join(Commands.SET_VAR_OPS), "setVar 의 op == SET_VAR_OPS")
	end

	-- [F] 이벤트 칸 ----------------------------------------------------------------
	do
		local fields = (schema.event or {}).fields or {}
		local dirs = keysOf(Character.DIR_VECTORS)
		local trigger = findArg(fields, "trigger")
		t.check_eq(join(sortedCopy(trigger and trigger.values)), join(keysOf(Event.TRIGGERS)),
			"트리거 == Event.TRIGGERS")
		t.check_eq(trigger and trigger.default, "action", "트리거의 기본값은 action (Event.new 와 같다)")
		t.check_eq(Event.new{ id = "d" }.trigger, "action", "Event.new 의 기본 트리거")
		local dir = findArg(fields, "dir")
		t.check_eq(join(sortedCopy(dir and dir.values)), join(dirs), "이벤트 방향 == DIR_VECTORS")
		for _, code in ipairs({ "transfer", "turn" }) do
			local arg = findArg((findCommand(schema, code) or {}).args, "dir")
			t.check_eq(join(sortedCopy(arg and arg.values)), join(dirs), code .. ".dir == DIR_VECTORS")
		end
		t.check_eq(join(sortedCopy((schema.event or {}).reserved)), join(keysOf(MapData.RESERVED_IDS)),
			"예약 id == MapData.RESERVED_IDS")
		-- 깃발과 변수가 쓸 수 없는 state 자리 (소지품). 커맨드 검사와 시작 상태가 같은 이름을 막는다
		t.check_eq(join(sortedCopy((schema.state or {}).reserved)),
			require("scripts/lua/rpg/inventory").KEY, "state.reserved == Inventory.KEY")

		-- 칸 이름과 순서 (1.4절의 키 순서가 이 순서다)
		local names = {}
		for _, f in ipairs(fields) do names[#names + 1] = f.name end
		t.check_eq(join(names), "id,x,y,dir,trigger,charset,through,solid,speed,wander,commands",
			"이벤트 칸의 이름과 순서")

		local route = schema.route or {}
		t.check_eq(join(sortedCopy(route.moves)), join(dirs), "이동 루트의 걸음 == DIR_VECTORS")
		local c = Character.new{ tx = 5, ty = 5, dir = "down", canPass = function() return true end }
		c:setRoute({ tostring(route.turnPrefix) .. "left", tostring(route.waitPrefix) .. "100" })
		c:update(1 / 60)
		t.check_eq(c.dir, "left", "turnPrefix 로 방향만 돌린다")
		t.check(c.tx == 5 and c.ty == 5, "turnPrefix 는 움직이지 않는다")
		c:update(1 / 60)
		t.check_eq(c:isRouteDone(), false, "waitPrefix 로 기다린다")
		for _ = 1, 20 do c:update(1 / 60) end
		t.check_eq(c:isRouteDone(), true, "기다린 뒤 루트가 끝난다")
	end

	-- [G] 자산과 시트 --------------------------------------------------------------
	do
		local assets = schema.assets or {}
		t.check_eq(join(keysOf(assets)), join(keysOf(Assets.SETS)), "자산 종류 == Assets.SETS")
		for kind, sets in pairs(Assets.SETS) do
			local fromSchema = assets[kind] or {}
			t.check_eq(join(keysOf(fromSchema)), join(keysOf(sets)), kind .. " 이름 == Assets.SETS")
			for name, list in pairs(sets) do
				t.check_eq(join(fromSchema[name] or {}), join(list),
					kind .. "." .. name .. " 후보 목록이 같다 (순서까지)")
			end
		end

		local sheets = schema.sheets or {}
		local cs = sheets.charset or {}
		for _, k in ipairs({ "frameW", "frameH", "sheetCols", "perSheet", "patterns", "standPattern" }) do
			t.check_eq(cs[k], Specs.charset[k], "sheets.charset." .. k .. " == Specs.charset")
		end
		local rows = cs.dirRows or {}
		t.check_eq(join(keysOf(rows)), join(keysOf(Specs.charset.dirRows)), "dirRows 의 방향")
		for d, row in pairs(Specs.charset.dirRows) do
			t.check_eq(rows[d], row, "dirRows." .. d)
		end
		local face = sheets.face or {}
		t.check_eq(face.size, Specs.faceset.size, "sheets.face.size == Specs.faceset")
		t.check_eq(face.cols, Specs.faceset.cols, "sheets.face.cols == Specs.faceset")
		t.check_eq(face.perSheet, Specs.faceset.perSheet, "sheets.face.perSheet == Specs.faceset")
	end

	-- [H] 맵 파일과 정의 파일 -------------------------------------------------------
	local config = Config.load()
	local defs = {}
	for _, entry in ipairs(config and config.maps or {}) do
		local ok, def = pcall(require, (entry.def:gsub("%.lua$", "")))
		if ok then defs[entry.name] = def end
	end
	do
		-- 맵 파일 → 정의 파일의 scripts (script 커맨드의 이름 확인용)
		local scriptsFor = {}
		for _, entry in ipairs(config and config.maps or {}) do
			local def = defs[entry.name]
			if def ~= nil then
				scriptsFor[entry.file] = def.scripts
				for _, alt in ipairs(entry.alt or {}) do scriptsFor[alt] = def.scripts end
			end
		end
		for _, file in ipairs(MAP_FILES) do
			local events, _, err = MapData.loadEvents(Config.projectPath(file))
			t.check(err == nil, file .. ": 읽는다", err)
			local ok, problems = MapData.validateEvents(events, { scripts = scriptsFor[file] })
			local lines = {}
			for _, p in ipairs(problems) do lines[#lines + 1] = p.path .. ": " .. p.message end
			t.check(ok, file .. ": 이벤트 " .. #events .. "개가 검사를 통과한다", table.concat(lines, "; "))
		end
		for name, def in pairs(defs) do
			local bad = {}
			for _, ev in ipairs(def.events or {}) do
				if ev.commands ~= nil then
					local ok, errors = Commands.validate(ev.commands, { scripts = def.scripts })
					if not ok then bad[#bad + 1] = tostring(ev.id) .. " " .. table.concat(errors, " ") end
				end
			end
			t.check(#bad == 0, name .. ": 정의 파일의 커맨드가 검증을 통과한다", table.concat(bad, "; "))
		end
	end

	-- [I] 경로 픽스처 --------------------------------------------------------------
	do
		local fixture, ferr = Json.Load(FIXTURE_PATH)
		local expected, eerr = Json.Load(FIXTURE_PATHS_PATH)
		t.check(type(fixture) == "table", "invalid_events.json 을 읽는다", ferr)
		t.check(type(expected) == "table", "invalid_events.paths.json 을 읽는다", eerr)
		if type(fixture) == "table" and type(expected) == "table" then
			local _, problems, valid = MapData.validateEvents(fixture.events)
			local actual = {}
			for _, p in ipairs(problems) do actual[#actual + 1] = p.path end
			local missing, extra = setDiff(actual, expected.paths or {})
			t.check(#missing == 0 and #extra == 0,
				"경로 집합이 픽스처와 같다 (" .. #(expected.paths or {}) .. "개)",
				"모자람: " .. table.concat(missing, " ") .. " | 남음: " .. table.concat(extra, " "))
			local ids = {}
			for _, ev in ipairs(valid) do ids[#ids + 1] = ev.id end
			t.check_eq(join(ids), "ok,tail", "픽스처의 올바른 이벤트 둘만 남는다")
			local hasScript, nullSlots = false, 0
			for i = 1, Shape.length(fixture.events) do
				local ev = fixture.events[i]
				if ev == nil then nullSlots = nullSlots + 1 end
				if type(ev) == "table" and type(ev.commands) == "table" then
					Commands.walk(ev.commands, function(cmd)
						if cmd.code == "script" then hasScript = true end
					end)
				end
			end
			t.check(not hasScript, "픽스처에는 script 커맨드가 없다 (에디터가 이름을 확인할 수 없다)")
			t.check(nullSlots > 0, "픽스처의 events 가운데에 null 이 있다 (null 도 한 칸으로 센다)")
		end
	end

	-- [J] 게임 설정 ----------------------------------------------------------------
	do
		t.check(config ~= nil, "rpg-game.json 을 읽는다")
		if config == nil then return end
		local names, fileSet = {}, {}
		local rtpOff = not Assets.rtpEnabled()
		for i, entry in ipairs(config.maps) do
			local w = "maps[" .. i .. "] " .. tostring(entry.name)
			t.check(type(entry.name) == "string" and entry.name ~= "" and names[entry.name] == nil,
				w .. ": 이름이 있고 겹치지 않는다")
			names[entry.name] = true
			t.check(type(entry.file) == "string" and entry.file:sub(1, 2) ~= "./",
				w .. ": file 은 ./ 없는 프로젝트 경로")
			fileSet[entry.file] = true
			local data = Json.Load(Config.projectPath(entry.file))
			t.check(type(data) == "table", w .. ": 맵 파일이 있다")
			local def = defs[entry.name]
			t.check(def ~= nil, w .. ": 정의 파일을 require 한다 (" .. tostring(entry.def) .. ")")
			if def ~= nil then
				local opened = Config.bare(def.map)
				local allowed = opened == entry.file
				for _, alt in ipairs(entry.alt or {}) do
					if opened == alt then allowed = not rtpOff end
				end
				t.check(allowed, w .. ": 정의 파일이 여는 맵이 file 이나 (RTP 가 있으면) alt",
					tostring(def.map))
			end
			for _, alt in ipairs(entry.alt or {}) do
				fileSet[alt] = true
				local altData = Json.Load(Config.projectPath(alt))
				t.check(type(altData) == "table" and type(data) == "table"
					and altData.width == data.width and altData.height == data.height,
					w .. ": alt " .. alt .. " 가 있고 크기가 file 과 같다")
			end
		end
		local listed = {}
		for _, file in ipairs(MAP_FILES) do listed[file] = true end
		for file in pairs(fileSet) do
			t.check(listed[file], file .. " 가 이 테스트의 맵 파일 목록에 있다")
		end

		local modules = Config.mapModules(config)
		t.check_eq(join(keysOf(modules)), "inn,port_town,room,village", "등록된 맵 넷")
		t.check_eq(modules.port_town, "scripts/lua/maps/port_town", "정의 모듈 경로는 def 에서 .lua 를 뗀 것")

		-- 게임의 시작 맵이 등록되어 있다 (game.lua 의 START_MAP)
		local source = readFile(GAME_LUA) or ""
		local startMap = source:match('local%s+START_MAP%s*=%s*"([%w_]+)"')
		t.check(startMap ~= nil and names[startMap], "rpgdemo 의 시작 맵이 maps 에 있다",
			tostring(startMap))

		-- 커맨드가 가리키는 맵과 아이템이 등록되어 있다 (맵 파일과 정의 파일 모두)
		local Items = require("scripts/lua/games/rpgdemo/items")
		local usedItems, usedMaps = {}, {}
		local function collect(commands)
			Commands.walk(commands, function(cmd)
				if (cmd.code == "giveItem" or cmd.code == "takeItem") and cmd.item ~= nil then
					usedItems[cmd.item] = true
				elseif cmd.code == "if" and type(cmd.cond) == "table" and cmd.cond.item ~= nil then
					usedItems[cmd.cond.item] = true
				elseif cmd.code == "transfer" and cmd.map ~= nil then
					usedMaps[cmd.map] = true
				end
			end)
		end
		for _, file in ipairs(MAP_FILES) do
			for _, ev in ipairs((MapData.loadEvents(Config.projectPath(file)))) do
				if type(ev) == "table" then collect(ev.commands) end
			end
		end
		for _, def in pairs(defs) do
			for _, ev in ipairs(def.events or {}) do collect(ev.commands) end
		end
		t.check(next(usedItems) ~= nil, "커맨드가 쓰는 아이템을 찾았다")
		for id in pairs(usedItems) do
			t.check(Items[id] ~= nil, "아이템 표에 " .. id .. " 가 있다")
		end
		for name in pairs(usedMaps) do
			t.check(names[name], "transfer 가 가리키는 맵 " .. name .. " 가 등록되어 있다")
		end

		-- 아이템 표는 Lua 에서 JSON 으로 옮겼다. 옮기기 전과 같은 값이다
		t.check_eq(config.items, "resources/data/items.json", "아이템 표 경로")
		local ITEMS = {
			warehouse_key = { "창고 열쇠", 10, "여관 주인이 삼 년째 맡아 둔 열쇠. 손잡이가 반들반들하다." },
			lamp_oil = { "등유 한 통", 20, "창고에 남아 있던 등유. 아직 맑다." },
			silver = { "은화", 30, "이 지방에서 쓰는 은화. 여관 하루치가 두 닢이다." },
			shell = { "조개 목걸이", 40, "아이가 실에 꿰어 준 것. 숲에서 주웠다고 했다." },
		}
		t.check_eq(join(keysOf(Items)), join(keysOf(ITEMS)), "아이템 넷")
		for id, v in pairs(ITEMS) do
			local item = Items[id] or {}
			t.check(item.name == v[1] and item.order == v[2] and item.desc == v[3]
				and math.type(item.order) == "integer", "아이템 " .. id .. " 의 이름, 순서, 설명")
		end

		-- 에디터의 실행 변수
		local play = config.play or {}
		local function same(actual, expected, label)
			local bad = {}
			for k, v in pairs(expected) do
				if (actual or {})[k] ~= v then bad[#bad + 1] = k end
			end
			for k in pairs(actual or {}) do
				if expected[k] == nil then bad[#bad + 1] = k end
			end
			t.check(#bad == 0, label, table.concat(bad, ", "))
		end
		same(play.env, {
			INITIAL2D_SCRIPT = "lua",
			INITIAL2D_SCENE = "rpg",
			INITIAL2D_MAP = "{rpg.map}",
			INITIAL2D_RPG_AT = "{cx},{cy},{dir}",
			INITIAL2D_RPG_STATE = "{state}",
			INITIAL2D_RPG_TRACE = "1",
		}, "play.env 는 RPG 씬을 그 맵과 그 칸으로 연다")
		same(play.probe, {
			INITIAL2D_AUTOPLAY = "1",
			INITIAL2D_RPG_ROUTE = "{route}",
			INITIAL2D_RPG_HOLD = "{event}",
			INITIAL2D_RPG_TRACE = "1",
		}, "play.probe는 자동 재생 변수 (그 이벤트를 제자리에 세우고 늘 trace를 켠다)")

		-- 알데바란의 실행 변수는 알데바란 맵에만 붙는다 (등록된 RPG 맵과 겹치지 않는다)
		local objects = Json.Load(MAP_OBJECTS_PATH) or {}
		local globs = (objects.play or {}).maps or {}
		t.check_eq(join(globs), "aldebaran_*", "map-objects.json 의 play.maps")
		for file in pairs(fileSet) do
			local base = file:match("([^/]+)$")
			for _, glob in ipairs(globs) do
				local pattern = "^" .. glob:gsub("[%.%-%+%?%(%)%[%]%^%$%%]", "%%%0"):gsub("%*", ".*") .. "$"
				t.check(not base:match(pattern), base .. " 는 " .. glob .. " 에 걸리지 않는다")
			end
		end
	end
end

return M
