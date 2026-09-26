-- aldebaran_map_objects_test.lua : 알데바란 맵 오브젝트의 단위 테스트
-- (docs/plans/m1-map-objects.md)
--
-- 스테이지 배치(시작 지점, 체크포인트, 몬스터, 흔적, 구간, 빛기둥)는 맵 파일의
-- objects에 있고, 오브젝트의 타입과 칸은 resources/schema/map-objects.json이 정한다.
--   [A] 스키마 파일이 에디터가 읽는 형식을 지킨다
--   [B] 두 맵의 오브젝트가 스키마를 지킨다 (검사기가 실제로 잡는지도 본다)
--   [C] 스키마의 목록이 게임 데이터(몬스터 종, 힘, 구간 이름)와 같다
--   [D] 스테이지 모듈이 맵에서 만든 표가 아래의 고정값과 같다 (정수와 실수의 구분까지)
--   [E] INITIAL2D_ALDEBARAN_STAGE가 스테이지 id, 맵 이름, 맵 파일 경로를 모두 받는다
--   [F] INITIAL2D_ALDEBARAN_AT으로 옮긴 시작 x가 지면 속이면 지면 위로 올린다
--   [G] 옮긴 시작 x가 구덩이 위면 그 칸의 발판이나 가까운 칸의 땅에 세운다

local Monsters = require("scripts/lua/games/aldebaran/data/monsters")
local Combat = require("scripts/lua/games/aldebaran/combat")
local Stages = require("scripts/lua/games/aldebaran/stages/init")
local Placement = require("scripts/lua/games/aldebaran/stages/placement")
local Player = require("scripts/lua/games/aldebaran/player")

local M = {}

local SCHEMA_PATH = "./resources/schema/map-objects.json"
local MAPS = {
	forest = "./resources/maps/aldebaran_forest.json",
	tomb = "./resources/maps/aldebaran_tomb.json",
}

-- ---- 고정값 ------------------------------------------------------------------
-- 스테이지 모듈이 맵에서 만들어야 하는 표. 몬스터 id와 난수 소비가 배치 순서를
-- 따르므로 spawns는 순서까지 같아야 한다.

local FOREST = {
	START = { x = 56, y = 384 },
	CHECKPOINTS = {
		{ x = 1552, y = 304 },
		{ x = 2400, y = 352 },
	},
	SECTIONS = {
		{ name = "entrance", x1 = 767 },
		{ name = "road", x1 = 1599 },
		{ name = "gorge", x1 = 2367 },
		{ name = "den", x1 = 3263 },
		{ name = "altar", x1 = 4096 },
	},
	spawns = {
		{ species = "spider", x = 224, y = 384, minX = 180, maxX = 280 },
		{ species = "spider", x = 672, y = 352, minX = 630, maxX = 730 },
		{ species = "spider", x = 900, y = 352, minX = 860, maxX = 960 },
		{ species = "spider", x = 1056, y = 336, minX = 1010, maxX = 1120 },
		{ species = "spider", x = 1400, y = 304, minX = 1370, maxX = 1450 },
		{ species = "spider", x = 1470, y = 304, minX = 1440, maxX = 1520 },
		{ species = "spider", x = 1700, y = 304, minX = 1660, maxX = 1760 },
		{ species = "wolf", x = 1990, y = 304, minX = 1950, maxX = 2030 },
		{ species = "spider", x = 2290, y = 320, minX = 2260, maxX = 2340 },
		{ species = "wolf", x = 2760, y = 368, minX = 2700, maxX = 2820 },
		{ species = "wolf", x = 2830, y = 368, minX = 2770, maxX = 2890 },
		{ species = "wolf", x = 3060, y = 368, minX = 3010, maxX = 3120 },
		{ species = "wolf", x = 3120, y = 368, minX = 3060, maxX = 3180 },
		{ species = "blackwolf", x = 3220, y = 368, minX = 3160, maxX = 3250 },
		{ species = "wolf", x = 3450, y = 384, minX = 3400, maxX = 3520 },
		{ species = "monkey", x = 3860, y = 384, minX = 3640, maxX = 4040, boss = true },
	},
	LANDMARKS = {
		{ id = "tracks", x0 = 300, x1 = 348, title = "여러 갈래의 발자국",
		  text = "발자국이 여럿이다. 그놈은 혼자가 아니었다.", skill = "edge" },
		{ id = "road", x0 = 790, x1 = 838, title = "다져진 포석",
		  text = "밟혀 다져진 돌길이다. 숲이 나중에 덮은 것이다.", skill = "read" },
		{ id = "cart", x0 = 1640, x1 = 1688, title = "버려진 짐수레",
		  text = "짐이 그대로 실려 있다. 사람들은 급히 떠났다.", skill = "leap" },
		{ id = "cage", x0 = 2440, x1 = 2488, title = "부서진 우리",
		  text = "실험실의 우리다. 안개는 저들이 열매를 태워 만든다.",
		  hallucination = 3.0, skill = "berserk" },
		{ id = "altar", x0 = 3700, x1 = 3748, title = "네 개의 화두",
		  text = "고대 문자와 굳은 피. 지도에 그려진 것이 이곳이었다.", skill = "bolt" },
	},
	-- { x, 지금 구간, 다음 구간, 섞는 비율 }. 비율의 0은 정수, 나머지는 실수다
	SECTION_AT = {
		{ 0, "entrance", "road", 0 },
		{ 700, "entrance", "road", (96 - 67) / 192 },
		{ 767, "entrance", "road", 96 / 192 },
		{ 768, "entrance", "road", 0.5 + 1 / 192 },
		{ 800.5, "entrance", "road", 0.5 + 33.5 / 192 },
		{ 1000, "road", "gorge", 0 },
		{ 1550, "road", "gorge", (96 - 49) / 192 },
		{ 3263, "den", "altar", 96 / 192 },
		{ 3300, "den", "altar", 0.5 + 37 / 192 },
		{ 4096, "altar", "altar", 0 },
		{ 5000, "altar", "altar", 0 },
	},
}

local TOMB = {
	START = { x = 56, y = 384 },
	CHECKPOINTS = {
		{ x = 1984, y = 400 },
		{ x = 3008, y = 384 },
	},
	SECTIONS = {
		{ name = "chest", x1 = 895 },
		{ name = "moon", x1 = 1919 },
		{ name = "stars", x1 = 2943 },
		{ name = "ruin", x1 = 4031 },
		{ name = "sun", x1 = 5119 },
	},
	CLIMATE = {
		moon = { kind = "snow", friction = 0.34, flakes = 40 },
		stars = { kind = "light", period = 4.0, lit = 2.2,
		          pillars = { 2180, 2420, 2660 }, halfW = 44 },
		ruin = { kind = "hail", interval = 1.6, warn = 0.5, damage = 9,
		         speed = 320, halfW = 5, count = 2 },
		sun = { kind = "flood", period = 9.0, low = 400, high = 336,
		        moveMult = 0.55, jumpMult = 0.72 },
	},
	spawns = {
		{ species = "sentinel", x = 640, y = 384, minX = 600, maxX = 700 },
		{ species = "soul", x = 1040, y = 336, minX = 990, maxX = 1120 },
		{ species = "soul", x = 1300, y = 300, minX = 1250, maxX = 1380 },
		{ species = "sentinel", x = 1500, y = 400, minX = 1450, maxX = 1560 },
		{ species = "soul", x = 1700, y = 288, minX = 1640, maxX = 1780 },
		{ species = "soul", x = 2200, y = 300, minX = 2140, maxX = 2280 },
		{ species = "soul", x = 2440, y = 268, minX = 2380, maxX = 2520 },
		{ species = "soul", x = 2680, y = 300, minX = 2620, maxX = 2760 },
		{ species = "sentinel", x = 2860, y = 384, minX = 2800, maxX = 2920 },
		{ species = "shard", x = 3120, y = 384, minX = 3060, maxX = 3180 },
		{ species = "sentinel", x = 3440, y = 368, minX = 3400, maxX = 3500 },
		{ species = "shard", x = 3560, y = 368, minX = 3500, maxX = 3640 },
		{ species = "soul", x = 3700, y = 300, minX = 3650, maxX = 3800 },
		{ species = "shard", x = 3900, y = 384, minX = 3840, maxX = 3980 },
		{ species = "sentinel", x = 4180, y = 400, minX = 4130, maxX = 4240 },
		{ species = "soul", x = 4320, y = 300, minX = 4260, maxX = 4400 },
		{ species = "shard", x = 4420, y = 400, minX = 4360, maxX = 4480 },
		{ species = "apophis", x = 4720, y = 400, minX = 4300, maxX = 5040, boss = true },
	},
	LANDMARKS = {
		{ id = "chest", x0 = 300, x1 = 348, title = "열려 있는 가슴",
		  text = "사자의 가슴이 문이다. 닫힌 적이 없다. 언제든 나올 수 있게 지었다." },
		{ id = "moon", x0 = 1440, x1 = 1488, title = "달의 방",
		  text = "달의 기운으로 태양의 방을 고른다고 했다. 눈이 내리는 이유다." },
		{ id = "stars", x0 = 2360, x1 = 2408, title = "별들의 노래",
		  text = "별들은 황제의 탄생을 칭송하며 노래를 부르고 빛의 축제를 여느니라." },
		{ id = "ruin", x0 = 3260, x1 = 3308, title = "파괴의 방",
		  text = "여기 수호자가 있다. 기후를 쥔 자다. 방마다 다른 하늘은 그의 것이다." },
		{ id = "sarc", x0 = 4020, x1 = 4068, title = "닫히지 않은 석관",
		  text = "신하와 자식들을 함께 묻었다. 그들이 아직 이 방을 지킨다." },
	},
	SECTION_AT = {
		{ 0, "chest", "moon", 0 },
		{ 850, "chest", "moon", (96 - 45) / 192 },
		{ 896, "chest", "moon", 0.5 + 1 / 192 },
		{ 1871, "moon", "stars", (96 - 48) / 192 },
		{ 2400, "stars", "ruin", 0 },
		{ 4100, "ruin", "sun", 0.5 + 69 / 192 },
		{ 5119, "sun", "sun", 0 },
		{ 6000, "sun", "sun", 0 },
	},
}

-- ---- 도구 --------------------------------------------------------------------

--- 두 값을 끝까지 비교해 다른 자리를 out에 적는다. 숫자는 math.type까지 같아야 한다
local function diff(actual, expected, path, out)
	if type(actual) ~= type(expected) then
		out[#out + 1] = path .. ": " .. type(actual) .. ", 기대 " .. type(expected)
		return
	end
	if type(expected) == "number" then
		if math.type(actual) ~= math.type(expected) or actual ~= expected then
			out[#out + 1] = string.format("%s: %s(%s), 기대 %s(%s)", path,
				tostring(actual), math.type(actual), tostring(expected), math.type(expected))
		end
	elseif type(expected) == "table" then
		for k, v in pairs(expected) do diff(actual[k], v, path .. "." .. tostring(k), out) end
		for k in pairs(actual) do
			if expected[k] == nil then out[#out + 1] = path .. "." .. tostring(k) .. ": 기대에 없는 칸" end
		end
	elseif actual ~= expected then
		out[#out + 1] = path .. ": " .. tostring(actual) .. ", 기대 " .. tostring(expected)
	end
end

local function checkSame(t, actual, expected, label)
	local out = {}
	diff(actual, expected, "", out)
	t.check(#out == 0, label, table.concat(out, " / "))
end

local function setOf(list)
	local s = {}
	for _, v in ipairs(list or {}) do s[v] = true end
	return s
end

local function count(tbl)
	local n = 0
	for _ in pairs(tbl) do n = n + 1 end
	return n
end

local SHAPES = setOf({ "point", "band", "rect" })
local COLORS = setOf({ "accent", "danger", "warning", "success", "muted" })
local FIELD_TYPES = setOf({ "string", "text", "number", "integer", "boolean", "enum" })

--- 오브젝트 목록을 스키마에 대어 보고 문제 문장의 목록을 돌려준다. 에디터의 validateObjects
-- 규칙에 더해 스키마에 없는 props 칸(게임이 조용히 무시하는 오타)과 범위 밖 x도 문제로 친다.
local function validate(objects, schema)
	local problems = {}
	local function add(msg) problems[#problems + 1] = msg end
	local types = {}
	for _, spec in ipairs(schema.types) do types[spec.type] = spec end
	local ids, uniques = {}, {}
	for i, o in ipairs(objects) do
		local where = "objects[" .. (i - 1) .. "]"
		if type(o.id) ~= "string" or o.id == "" then
			add(where .. ": id가 없다")
		elseif ids[o.id] then
			add(where .. ": id가 겹친다 (" .. o.id .. ")")
		else
			ids[o.id] = true
		end
		if type(o.x) ~= "number" then add(where .. ": x가 숫자가 아니다") end
		if o.y ~= nil and type(o.y) ~= "number" then add(where .. ": y가 숫자가 아니다") end
		local spec = types[o.type]
		if spec == nil then
			add(where .. ": 스키마에 없는 타입 " .. tostring(o.type))
		else
			if spec.unique then uniques[o.type] = (uniques[o.type] or 0) + 1 end
			local shape = spec.shape or "point"
			if (shape == "band" or shape == "rect")
				and not (type(o.width) == "number" and o.width > 0) then
				add(where .. ": 폭이 없다")
			end
			if shape == "rect" and not (type(o.height) == "number" and o.height > 0) then
				add(where .. ": 높이가 없다")
			end
			local props = o.props or {}
			local known, lo, hi = {}, nil, nil
			for _, f in ipairs(spec.fields or {}) do
				known[f.name] = true
				if f.role == "rangeMin" then lo = f.name end
				if f.role == "rangeMax" then hi = f.name end
				local v = props[f.name]
				local at = where .. ".props." .. f.name
				if v == nil then
					if f.required then add(at .. ": 비어 있다") end
				else
					local ok = true
					if f.type == "string" or f.type == "text" then ok = type(v) == "string"
					elseif f.type == "number" then ok = type(v) == "number"
					elseif f.type == "integer" then ok = math.type(v) == "integer"
					elseif f.type == "boolean" then ok = type(v) == "boolean"
					elseif f.type == "enum" then ok = type(v) == "string" and setOf(f.values)[v] == true
					end
					if not ok then add(at .. ": 값 " .. tostring(v) .. "이 " .. f.type .. "이 아니다") end
					if type(v) == "number" then
						if f.min ~= nil and v < f.min then add(at .. ": 최솟값보다 작다") end
						if f.max ~= nil and v > f.max then add(at .. ": 최댓값보다 크다") end
					end
				end
			end
			for k in pairs(props) do
				if not known[k] then add(where .. ".props." .. tostring(k) .. ": 스키마에 없는 칸") end
			end
			if lo ~= nil and hi ~= nil and type(props[lo]) == "number" and type(props[hi]) == "number" then
				if props[lo] > props[hi] then
					add(where .. ": 범위가 뒤집혔다")
				elseif type(o.x) == "number" and (o.x < props[lo] or o.x > props[hi]) then
					add(where .. ": x가 범위 밖이다")
				end
			end
		end
	end
	for typeName, n in pairs(uniques) do
		if n > 1 then add(typeName .. "은 하나만 둘 수 있다 (" .. n .. "개)") end
	end
	return problems
end

local function typeSpec(schema, name)
	for _, spec in ipairs(schema.types) do
		if spec.type == name then return spec end
	end
	return nil
end

local function fieldSpec(spec, name)
	for _, f in ipairs(spec.fields or {}) do
		if f.name == name then return f end
	end
	return nil
end

-- ---- 케이스 ------------------------------------------------------------------

function M.run(t)
	local schema, why = Json.Load(SCHEMA_PATH)
	t.check(schema ~= nil, "스키마 파일을 읽는다", why)
	if schema == nil then return end
	local maps = {}
	for id, path in pairs(MAPS) do
		local data, err = Json.Load(path)
		t.check(data ~= nil, id .. ": 맵 파일을 읽는다", err)
		if data == nil then return end
		maps[id] = data
	end

	-- [A] 스키마 형식 (schema.ts의 parseObjectSchema가 거절하는 것이 없다)
	do
		t.check_eq(schema.version, 1, "스키마 버전은 1")
		local seen, bad = {}, {}
		for i, spec in ipairs(schema.types) do
			local where = "types[" .. (i - 1) .. "]"
			if type(spec.type) ~= "string" or spec.type == "" then bad[#bad + 1] = where .. ".type" end
			if seen[spec.type] then bad[#bad + 1] = where .. ": 타입이 겹친다" end
			seen[spec.type] = true
			if not SHAPES[spec.shape or "point"] then bad[#bad + 1] = where .. ".shape" end
			if not COLORS[spec.color or "accent"] then bad[#bad + 1] = where .. ".color" end
			if type(spec.label) ~= "string" then bad[#bad + 1] = where .. ".label" end
			local names = {}
			for j, f in ipairs(spec.fields or {}) do
				local fw = where .. ".fields[" .. (j - 1) .. "]"
				if type(f.name) ~= "string" or f.name == "" then bad[#bad + 1] = fw .. ".name" end
				if names[f.name] then bad[#bad + 1] = fw .. ": 칸이 겹친다" end
				names[f.name] = true
				if not FIELD_TYPES[f.type] then bad[#bad + 1] = fw .. ".type" end
				if f.type == "enum" and (type(f.values) ~= "table" or #f.values == 0) then
					bad[#bad + 1] = fw .. ".values"
				end
				if type(f.label) ~= "string" then bad[#bad + 1] = fw .. ".label" end
			end
		end
		t.check(#bad == 0, "스키마의 타입과 칸이 형식을 지킨다", table.concat(bad, ", "))
		for _, name in ipairs({ "start", "checkpoint", "spawn", "landmark", "section", "light" }) do
			t.check(seen[name], "스키마에 타입 " .. name .. "이 있다")
		end
		t.check_eq(count(seen), 6, "타입은 여섯이다")
		t.check_eq(typeSpec(schema, "start").unique, true, "시작 지점은 하나만")
		t.check_eq(typeSpec(schema, "landmark").shape, "band", "흔적은 띠")
		t.check_eq(typeSpec(schema, "section").shape, "band", "구간은 띠")
		t.check_eq(typeSpec(schema, "spawn").color, "danger", "몬스터는 위험색")

		local env = schema.play and schema.play.env or {}
		checkSame(t, env, {
			INITIAL2D_SCENE = "aldebaran",
			INITIAL2D_SKIP_INTRO = "1",
			INITIAL2D_ALDEBARAN_STAGE = "{map.name}",
			INITIAL2D_ALDEBARAN_AT = "{x}",
		}, "실행 환경 변수는 스테이지 씬을 그 맵과 그 x로 연다")
	end

	-- [B] 두 맵의 오브젝트가 스키마를 지킨다
	do
		for _, id in ipairs(Stages.order) do
			local data = maps[id]
			t.check_eq(data.version, 2, id .. ": 맵 포맷 v2")
			local objects = data.objects or {}
			local problems = validate(objects, schema)
			t.check(#problems == 0, id .. ": 오브젝트 " .. #objects .. "개가 스키마를 지킨다",
				table.concat(problems, " / "))
			local byType = {}
			for _, o in ipairs(objects) do byType[o.type] = (byType[o.type] or 0) + 1 end
			t.check_eq(byType.start, 1, id .. ": 시작 지점이 하나 있다")
			t.check_eq(byType.section, 5, id .. ": 구간은 다섯")

			-- 구간 띠는 0에서 시작해 빈틈 없이 이어진다 (구간은 오른끝만 보므로 틈은 조용히 묻힌다)
			local bands = {}
			for _, o in ipairs(objects) do
				if o.type == "section" then bands[#bands + 1] = o end
			end
			table.sort(bands, function(a, b) return a.x < b.x end)
			local edge, gaps = 0, {}
			for _, b in ipairs(bands) do
				if b.x ~= edge then gaps[#gaps + 1] = b.id .. "@" .. b.x end
				edge = b.x + b.width
			end
			t.check(#gaps == 0, id .. ": 구간 띠가 0부터 이어진다", table.concat(gaps, ", "))
		end
		t.check_eq(maps.forest.name, "aldebaran_forest", "숲 맵의 이름")
		t.check_eq(maps.tomb.name, "aldebaran_tomb", "무덤 맵의 이름")
	end

	-- [B2] 검사기가 실제로 잡는가 (통과만 보면 검사기가 망가져도 모른다)
	do
		local function caught(objects, label)
			t.check(#validate(objects, schema) > 0, "검사기가 잡는다: " .. label)
		end
		local ok = { id = "s", type = "spawn", x = 10, y = 0,
			props = { species = "wolf", minX = 0, maxX = 20 } }
		t.check_eq(#validate({ ok }, schema), 0, "검사기가 올바른 몬스터는 통과시킨다")
		caught({ { id = "s", type = "spawn", x = 10, y = 0,
			props = { species = "dragon", minX = 0, maxX = 20 } } }, "모르는 종")
		caught({ { id = "s", type = "spawn", x = 10, y = 0,
			props = { species = "wolf", minX = 30, maxX = 20 } } }, "뒤집힌 순찰 범위")
		caught({ { id = "s", type = "spawn", x = 50, y = 0,
			props = { species = "wolf", minX = 0, maxX = 20 } } }, "순찰 범위 밖의 x")
		caught({ { id = "s", type = "spawn", x = 10, y = 0,
			props = { minX = 0, maxX = 20 } } }, "빠진 종")
		caught({ { id = "s", type = "spawn", x = 10, y = 0,
			props = { species = "wolf", minX = 0, maxX = 20, bos = true } } }, "스키마에 없는 칸")
		caught({ { id = "a", type = "start", x = 0, y = 0 },
			{ id = "b", type = "start", x = 1, y = 0 } }, "시작 지점 둘")
		caught({ { id = "l", type = "landmark", x = 0, y = 0,
			props = { title = "t", text = "x" } } }, "폭이 없는 흔적")
		caught({ { id = "l", type = "landmark", x = 0, y = 0, width = 48,
			props = { title = "t", text = "x", skill = "fly" } } }, "모르는 힘")
		caught({ { id = "q", type = "mystery", x = 0, y = 0 } }, "모르는 타입")
		caught({ ok, ok }, "겹치는 id")
	end

	-- [C] 스키마의 목록이 게임 데이터와 같다
	do
		local species = fieldSpec(typeSpec(schema, "spawn"), "species")
		local values = setOf(species.values)
		t.check_eq(#species.values, count(Monsters.species), "종 목록의 길이가 종별 표와 같다")
		t.check_eq(count(values), #species.values, "종 목록에 겹치는 것이 없다")
		for key in pairs(Monsters.species) do
			t.check(values[key], "종 목록에 " .. key .. "이 있다")
		end

		local skill = fieldSpec(typeSpec(schema, "landmark"), "skill")
		checkSame(t, skill.values, Combat.SKILL_ORDER, "흔적의 힘 목록은 Combat.SKILL_ORDER")

		local names = {}
		for _, id in ipairs(Stages.order) do
			for _, s in ipairs(Stages.get(id).SECTIONS) do names[#names + 1] = s.name end
		end
		checkSame(t, fieldSpec(typeSpec(schema, "section"), "name").values, names,
			"구간 이름 목록은 두 스테이지의 구간 이름을 순서대로 모은 것")

		t.check_eq(fieldSpec(typeSpec(schema, "spawn"), "minX").role, "rangeMin", "minX는 순찰 왼끝")
		t.check_eq(fieldSpec(typeSpec(schema, "spawn"), "maxX").role, "rangeMax", "maxX는 순찰 오른끝")
	end

	-- [D] 스테이지 모듈이 만든 표가 고정값과 같다
	do
		for id, want in pairs({ forest = FOREST, tomb = TOMB }) do
			local stage = Stages.get(id)
			checkSame(t, stage.START, want.START, id .. ": START")
			-- taken은 씬(과 다른 테스트)이 적는 표시라 비교에서 뺀다
			local checkpoints = {}
			for i, cp in ipairs(stage.CHECKPOINTS) do
				checkpoints[i] = {}
				for k, v in pairs(cp) do
					if k ~= "taken" then checkpoints[i][k] = v end
				end
			end
			checkSame(t, checkpoints, want.CHECKPOINTS, id .. ": CHECKPOINTS")
			checkSame(t, stage.SECTIONS, want.SECTIONS, id .. ": SECTIONS")
			checkSame(t, stage.spawns, want.spawns, id .. ": spawns (순서 포함)")
			checkSame(t, stage.LANDMARKS, want.LANDMARKS, id .. ": LANDMARKS")
			checkSame(t, stage.CLIMATE, want.CLIMATE, id .. ": CLIMATE")
			checkSame(t, stage.SIGNS, {}, id .. ": SIGNS는 비어 있다")
			t.check_eq(stage.SECTION_FADE, 96, id .. ": 구간 경계의 폭")
			local bad = {}
			for _, row in ipairs(want.SECTION_AT) do
				local cur, nxt, blend = stage.sectionAt(row[1])
				local out = {}
				diff({ cur, nxt, blend }, { row[2], row[3], row[4] }, "@" .. row[1], out)
				for _, line in ipairs(out) do bad[#bad + 1] = line end
			end
			t.check(#bad == 0, id .. ": sectionAt의 결과 " .. #want.SECTION_AT .. "곳",
				table.concat(bad, " / "))
		end

		-- 정수와 실수: JSON의 3은 정수가 되므로 원래 실수였던 칸은 모듈이 실수로 바꾼다
		local forest = Stages.get("forest")
		t.check_eq(math.type(forest.LANDMARKS[4].hallucination), "float", "환각 시간은 실수")
		t.check_eq(math.type(forest.START.x), "integer", "시작 x는 정수")
		t.check_eq(math.type(forest.spawns[1].minX), "integer", "순찰 범위는 정수")
		t.check_eq(math.type(forest.SECTIONS[1].x1), "integer", "구간 오른끝은 정수")
		t.check_eq(math.type(Stages.get("tomb").CLIMATE.stars.pillars[1]), "integer", "빛기둥 x는 정수")

		-- 표는 한 번 만들어 두고 같은 것을 돌려준다 (씬이 cp.taken을 적는다)
		t.check(Stages.get("forest").CHECKPOINTS == forest.CHECKPOINTS, "체크포인트 표는 같은 표다")
	end

	-- [E] 스테이지 이름: id, 맵 이름, 맵 파일 경로
	do
		local forest, tomb = Stages.get("forest"), Stages.get("tomb")
		t.check(Stages.get("aldebaran_forest") == forest, "맵 이름 aldebaran_forest는 숲")
		t.check(Stages.get("aldebaran_tomb") == tomb, "맵 이름 aldebaran_tomb은 무덤")
		t.check(Stages.get("resources/maps/aldebaran_tomb.json") == tomb, "프로젝트 기준 맵 경로")
		t.check(Stages.get("./resources/maps/aldebaran_forest.json") == forest, "./로 시작하는 맵 경로")
		t.check(Stages.get("/home/me/game/resources/maps/aldebaran_tomb.json") == tomb, "절대 경로")
		t.check(Stages.get("C:\\game\\resources\\maps\\aldebaran_forest.json") == forest,
			"역슬래시 경로")
		t.check(Stages.get("aldebaran_forest.json") == forest, "파일 이름만")
		local none, why = Stages.get("aldebaran_desert")
		t.check_eq(none, nil, "모르는 맵 이름은 nil")
		t.check_eq(why, "모르는 스테이지 'aldebaran_desert'", "모르는 맵 이름의 이유")
		t.check_eq(Stages.get("resources/maps/other/aldebaran_forest.json"), nil,
			"다른 폴더의 같은 이름 파일은 아니다")
		for _, id in ipairs(Stages.order) do
			t.check_eq(Stages.get(maps[id].name).id, id,
				id .. ": 맵 파일의 name으로 그 스테이지를 연다 ({map.name})")
		end
	end

	-- [F] 옮긴 시작 x의 y: 시작 지점의 y(384)에서 발이 지면 속이면 한 칸씩 올린다
	do
		local function standOn(path, x)
			local map = Tilemap.Load(path)
			local w, h, tw, th = Tilemap.GetSize(map)
			local function solid(px, py)
				if px < 0 or px >= w * tw then return true end
				if py < 0 or py >= h * th then return false end
				return not Tilemap.IsPassable(map, math.floor(px / tw), math.floor(py / th))
			end
			local y = Placement.standY(x, 384, solid, th)
			Tilemap.Dispose(map)
			return y
		end
		t.check_eq(standOn(MAPS.forest, 224), 384, "숲 입구의 평지는 그대로 384")
		t.check_eq(standOn(MAPS.forest, 1400), 304, "옛 길의 턱 위(지면 304)로 올린다")
		t.check_eq(standOn(MAPS.forest, 1990), 304, "절벽의 어깨 위(지면 304)로 올린다")
		t.check_eq(standOn(MAPS.tomb, 2480), 384, "별들의 방은 바닥이 더 낮아 그대로 (떨어진다)")
		t.check_eq(Placement.standY(10, 384, function() return true end, 16), 384,
			"위가 끝까지 막혔으면 그대로")
	end

	-- [G] 옮긴 시작 x의 설 자리: 구덩이 위면 그 칸의 발판이나 가까운 칸의 땅에 세운다.
	-- 숲의 협곡은 열 128~131과 135~139가 지면 304 한 줄(발판)이고 아래가 비었으며,
	-- 열 132~134는 위아래가 다 빈 구덩이다.
	do
		local function withSolid(path, fn)
			local map = Tilemap.Load(path)
			local w, h, tw, th = Tilemap.GetSize(map)
			local function solid(px, py)
				if px < 0 or px >= w * tw then return true end
				if py < 0 or py >= h * th then return false end
				return not Tilemap.IsPassable(map, math.floor(px / tw), math.floor(py / th))
			end
			local out = fn(solid, w, h, tw, th)
			Tilemap.Dispose(map)
			return out
		end
		-- 열의 막힌 행 목록 ("19"나 "19,21,22")
		local function solidRows(path, col)
			return withSolid(path, function(solid, _, h, tw, th)
				local rows = {}
				for r = 0, h - 1 do
					if solid(col * tw + tw // 2, r * th) then rows[#rows + 1] = tostring(r) end
				end
				return table.concat(rows, ",")
			end)
		end
		local function spotOn(path, x)
			return withSolid(path, function(solid, _, h, tw, th)
				local sx, sy = Placement.startSpot(x, 384, solid, tw, th, h * th, Player.BODY_H)
				return string.format("%g %g", sx, sy)
			end)
		end

		for _, col in ipairs({ 128, 131, 135, 139 }) do
			t.check_eq(solidRows(MAPS.forest, col), "19", "숲 열 " .. col .. "은 발판 한 줄 (전제)")
		end
		for _, col in ipairs({ 132, 133, 134 }) do
			t.check_eq(solidRows(MAPS.forest, col), "", "숲 열 " .. col .. "은 빈 구덩이 (전제)")
		end
		t.check_eq(solidRows(MAPS.forest, 113), "19,21,22,23,24,25,26,27",
			"숲 열 113은 발판 아래에 한 칸 틈 (전제)")

		t.check_eq(spotOn(MAPS.forest, 2054), "2054 304", "발판 칸은 x 그대로 발판 위(304)")
		t.check_eq(spotOn(MAPS.forest, 2200), "2200 304", "발판 칸 x 2200도 발판 위")
		t.check_eq(spotOn(MAPS.forest, 2120), "2104 304", "구덩이 왼쪽 열은 왼쪽 한 칸 발판 가운데로")
		t.check_eq(spotOn(MAPS.forest, 2136), "2104 304", "구덩이 가운데 열은 거리가 같아 왼쪽으로")
		t.check_eq(spotOn(MAPS.forest, 2152), "2168 304", "구덩이 오른쪽 열은 오른쪽 한 칸 발판으로")
		t.check_eq(withSolid(MAPS.forest, function(solid) return Placement.standY(1816, 384, solid, 16) end),
			336, "standY만으로는 한 칸 틈(336)에 끼인다")
		t.check_eq(spotOn(MAPS.forest, 1816), "1816 304", "몸이 안 들어가는 틈이면 그 위 발판(304)")

		-- 지면이 있는 자리는 standY와 같다 (인수 씬이 쓰는 무덤의 2480, 4300 포함)
		t.check_eq(spotOn(MAPS.forest, 224), "224 384", "숲 입구의 평지는 그대로 384")
		t.check_eq(spotOn(MAPS.forest, 1400), "1400 304", "옛 길의 턱 위(304)")
		t.check_eq(spotOn(MAPS.forest, 1990), "1990 304", "절벽의 어깨 위(304)")
		t.check_eq(spotOn(MAPS.tomb, 2480), "2480 384", "별들의 방은 그대로 384 (떨어진다)")
		t.check_eq(spotOn(MAPS.tomb, 4300), "4300 384", "태양의 방은 그대로 384 (떨어진다)")

		-- 찾는 거리는 좌우 REACH(16)칸까지. 열 10~43이 빈 구덩이인 가짜 지형
		local function pit(px, py)
			local col = math.floor(px / 16)
			return py >= 384 and py < 448 and (col < 10 or col > 43)
		end
		local function spot(x, solid)
			local sx, sy = Placement.startSpot(x, 384, solid or pit, 16, 16, 448, Player.BODY_H)
			return string.format("%g %g", sx, sy)
		end
		t.check_eq(Placement.REACH, 16, "찾는 거리는 16칸")
		t.check_eq(spot(28 * 16 + 3), "712 384", "열 28은 16칸 오른쪽 열 44로")
		t.check_eq(spot(27 * 16 + 3), "435 384", "열 27은 양쪽 땅이 16칸 밖이라 그대로")
		t.check_eq(spot(25 * 16), "152 384", "열 25는 16칸 왼쪽 열 9로")
		t.check_eq(spot(10, function() return true end), "10 384", "위가 끝까지 막힌 곳뿐이면 그대로")
	end
end

return M
