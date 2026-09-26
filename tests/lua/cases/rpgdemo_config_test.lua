-- rpgdemo_config_test.lua : rpg-game.json 과 items.json 의 모양 검사 (docs/plans/m2-rpg-events.md 2.4, 2.5절)
--
-- 두 파일도 맵 파일의 events 와 같은 모양 규칙(jsonshape.lua)을 따른다. 배열은 칸 수만큼 보고
-- null 칸은 그 경로의 문제, 배열 자리의 객체도 문제다. 틀린 항목만 빼고 나머지는 쓴다.
-- 가짜 loader 에 Json.Load 가 만드는 꼴(null 은 구멍, 객체는 글 키)의 표를 넣는다.

local M = {}

local function pathsOf(problems)
	local out = {}
	for _, p in ipairs(problems or {}) do out[#out + 1] = p.path end
	table.sort(out)
	return table.concat(out, " ")
end

local function keysOf(t)
	local out = {}
	for k in pairs(t or {}) do out[#out + 1] = tostring(k) end
	table.sort(out)
	return table.concat(out, ",")
end

local function loaderOf(files)
	return function(path)
		local data = files[path]
		if data == nil then return nil, "없는 파일 " .. tostring(path) end
		return data
	end
end

local function entry(name)
	return { name = name, file = "resources/maps/" .. name .. ".json",
		def = "scripts/lua/maps/" .. name .. ".lua" }
end

local function configWith(maps, extra)
	local data = { version = 1, maps = maps, items = "resources/data/items.json" }
	for k, v in pairs(extra or {}) do data[k] = v end
	return data
end

function M.run(t)
	local Config = require("scripts/lua/games/rpgdemo/config")
	local PATH = Config.PATH

	-- ---- [1] 올바른 설정 -------------------------------------------------------
	local config, problems = Config.load(loaderOf({
		[PATH] = configWith({ entry("port_town"), entry("inn") }),
	}))
	t.check(config ~= nil and #problems == 0, "올바른 설정은 문제가 없다", pathsOf(problems))
	t.check_eq(keysOf(Config.mapModules(config)), "inn,port_town", "맵 둘")
	t.check_eq(Config.mapEntry(config, "inn").file, "resources/maps/inn.json", "이름으로 항목을 찾는다")

	-- ---- [2] maps 가운데의 null 과 틀린 항목: 그것만 빼고 나머지 맵은 쓴다 ---------
	local maps = { entry("port_town") }
	maps[3] = entry("inn")                                        -- maps[2] 는 null
	maps[4] = "village"                                           -- 객체가 아니다
	maps[5] = { name = "", file = "a.json", def = "a.lua" }       -- 빈 이름
	maps[6] = { name = "room", file = 3, def = "r.lua" }          -- file 이 글이 아니다
	maps[7] = { name = "cave", file = "c.json" }                  -- def 가 없다
	maps[8] = entry("inn")                                        -- 이름이 겹친다
	maps[9] = { name = "shop", file = "s.json", def = "s.lua", alt = "s_rtp.json" }
	maps[10] = { name = "hall", file = "h.json", def = "h.lua", alt = { "h_rtp.json", 5 } }
	maps[11] = { 1, 2 }                                           -- 배열
	maps[12] = entry("village")
	config, problems = Config.load(loaderOf({ [PATH] = configWith(maps) }))
	t.check(config ~= nil, "틀린 항목이 있어도 설정은 쓴다")
	t.check_eq(pathsOf(problems), "maps[10].alt[2] maps[11] maps[2] maps[4] maps[5].name maps[6].file "
		.. "maps[7].def maps[8].name maps[9].alt", "문제마다 경로 하나 (null 칸 포함)")
	t.check_eq(keysOf(Config.mapModules(config)), "inn,port_town,village",
		"null 뒤의 맵도 등록되고 틀린 항목만 빠진다")
	t.check_eq(#config.maps, 3, "config.maps 는 쓸 수 있는 항목만")
	t.check_eq(Config.mapEntry(config, "inn").file, "resources/maps/inn.json", "겹친 이름은 앞의 것")

	-- ---- [3] 파일 전체를 쓸 수 없는 경우: 자리 하나와 이유 ----------------------
	local byName = {}
	for _, file in ipairs({
		{ "object_maps", configWith({ port_town = entry("port_town") }) },
		{ "string_maps", configWith("port_town") },
		{ "no_maps", { version = 1, items = "resources/data/items.json" } },
		{ "version", { version = 2, maps = {} } },
		{ "root_array", { 1, 2 } },
	}) do
		local c, p = Config.load(loaderOf({ [PATH] = file[2] }))
		byName[file[1]] = { config = c, problems = p }
	end
	for name, want in pairs({ object_maps = "maps", string_maps = "maps", no_maps = "maps",
		version = "version", root_array = "" }) do
		local got = byName[name]
		t.check(got.config == nil and #got.problems == 1 and got.problems[1].path == want,
			name .. ": 설정 없이 문제 하나, 자리 '" .. want .. "'", pathsOf(got.problems))
	end
	local c, p = Config.load(loaderOf({}))
	t.check(c == nil and #p == 1 and p[1].path == "" and p[1].message:find("없는 파일") ~= nil,
		"읽지 못하면 파서의 이유")
	config, problems = Config.load(loaderOf({ [PATH] = configWith({}) }))
	t.check(config ~= nil and #problems == 0 and #config.maps == 0, "빈 maps 는 문제가 아니다")

	-- ---- [4] items 경로 --------------------------------------------------------
	config, problems = Config.load(loaderOf({ [PATH] = configWith({ entry("inn") }, { items = 5 }) }))
	t.check(config ~= nil and pathsOf(problems) == "items" and config.items == nil,
		"items 경로가 글이 아니면 문제 하나이고 경로를 비운다")
	local noItems = configWith({ entry("inn") })
	noItems.items = nil
	config, problems = Config.load(loaderOf({ [PATH] = noItems }))
	t.check_eq(pathsOf(problems), "items", "items 경로가 없어도 문제")
	local items, itemProblems, itemsPath = Config.loadItems(config)
	t.check(next(items) == nil and #itemProblems == 0 and itemsPath == nil,
		"경로가 없으면 아이템 표는 빈 표이고 여기서 다시 알리지 않는다")

	-- ---- [5] items.json ----------------------------------------------------------
	local ITEMS = "./resources/data/items.json"
	local good = { version = 1, items = {
		{ id = "key", name = "열쇠", desc = "문을 연다", order = 10 },
		{ id = "oil", name = "등유", order = 20.0 },
	} }
	config = configWith({ entry("inn") })
	items, itemProblems, itemsPath = Config.loadItems(config, loaderOf({ [ITEMS] = good }))
	t.check(#itemProblems == 0 and keysOf(items) == "key,oil", "올바른 아이템 표", pathsOf(itemProblems))
	t.check_eq(itemsPath, "resources/data/items.json", "읽은 경로 (rpg:error 의 자리)")
	t.check_eq(items.key.name, "열쇠", "id 로 찾는다")

	local list = { { id = "key", name = "열쇠" } }
	list[3] = { id = "oil", name = "등유" }                 -- items[2] 는 null
	list[4] = "silver"                                      -- 객체가 아니다
	list[5] = { name = "이름만" }                           -- id 가 없다
	list[6] = { id = "key", name = "둘째 열쇠" }            -- id 가 겹친다
	list[7] = { id = "shell", name = { "조개" } }           -- 이름이 글이 아니다
	list[8] = { id = "coin", desc = 3 }                     -- 설명이 글이 아니다
	list[9] = { id = "gem", order = 1.5 }                   -- 순서가 정수가 아니다
	list[10] = { 1, 2 }                                     -- 배열
	list[11] = { id = "rope" }                              -- 이름, 설명, 순서는 없어도 된다
	items, itemProblems = Config.loadItems(config, loaderOf({ [ITEMS] = { version = 1, items = list } }))
	t.check_eq(pathsOf(itemProblems), "items[10] items[2] items[4] items[5].id items[6].id items[7].name "
		.. "items[8].desc items[9].order", "문제마다 경로 하나 (null 칸 포함)")
	t.check_eq(keysOf(items), "key,oil,rope", "null 뒤의 아이템도 쓰고 틀린 항목만 뺀다")
	t.check_eq(items.key.name, "열쇠", "겹친 id 는 앞의 것")

	for name, data in pairs({
		object_items = { version = 1, items = { key = { id = "key", name = "열쇠" } } },
		string_items = { version = 1, items = "key" },
		no_items = { version = 1 },
	}) do
		items, itemProblems = Config.loadItems(config, loaderOf({ [ITEMS] = data }))
		t.check(next(items) == nil and pathsOf(itemProblems) == "items",
			name .. ": 빈 표와 items 자리의 문제 하나", pathsOf(itemProblems))
	end
	items, itemProblems = Config.loadItems(config, loaderOf({ [ITEMS] = { 1, 2 } }))
	t.check(next(items) == nil and #itemProblems == 1 and itemProblems[1].path == "",
		"파일이 객체가 아니면 자리 없는 문제 하나")
	items, itemProblems = Config.loadItems(config, loaderOf({}))
	t.check(next(items) == nil and #itemProblems == 1 and itemProblems[1].message:find("없는 파일") ~= nil,
		"읽지 못하면 파서의 이유")
	items, itemProblems = Config.loadItems(config, loaderOf({ [ITEMS] = { version = 1, items = {} } }))
	t.check(next(items) == nil and #itemProblems == 0, "빈 items 는 문제가 아니다")

	-- ---- [6] rpg:error 의 자리 글 ------------------------------------------------
	t.check_eq(Config.where("rpg-game.json", "maps[2]"), "rpg-game.json:maps[2]", "파일:경로")
	t.check_eq(Config.where("resources/data/items.json", ""), "resources/data/items.json", "경로가 없으면 파일만")
	t.check_eq(Config.where("rpg-game.json", nil), "rpg-game.json", "nil 경로도 파일만")

	-- ---- [7] 저장소의 두 파일은 문제가 없다 ---------------------------------------
	config, problems = Config.load()
	t.check(config ~= nil and #problems == 0, "resources/data/rpg-game.json 에 문제가 없다", pathsOf(problems))
	items, itemProblems = Config.loadItems(config)
	t.check(#itemProblems == 0 and keysOf(items) == "lamp_oil,shell,silver,warehouse_key",
		"resources/data/items.json 에 문제가 없다", pathsOf(itemProblems))
end

return M
