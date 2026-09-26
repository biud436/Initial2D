-- api_surface_test.lua : 엔진이 Lua에 노출하는 API 표면의 계약 검증.
-- 바인딩이 실수로 빠지거나 이름이 바뀌면 여기서 잡힌다.
-- 새 바인딩을 추가하면(1단계: GetTextWidth, Json.Load 등) 이 목록도 갱신할 것.
--
-- 아래의 명시적 목록은 두 번째 의견이다. 기준은 API 명세
-- resources/api/initial2d-api.json (R2, docs/plans/r2-api-stubs.md)이고, 끝의 checkSpec 이
-- 명세와 VM 을 양방향으로 대조한다. 바인딩을 더하거나 바꾸면 명세도 고치고
-- python3 tools/gen_api_stubs.py 로 스텁을 다시 만든다.

local M = {}

local GLOBALS = {
    "print", "MessageBox", "LoadScript", "PreparaFont", "DrawText",
    "GetTextWidth",
    "WindowWidth", "WindowHeight", "SetRenderScale", "GetRenderScale",
    "GetFrameCount", "GameExit",
    "draw_text", "draw_point", "draw_set_color",
    "GetCurrentDirectory", "SetAppIcon", "GetResourcesFiles",
}

local MODULES = {
    Input = { "IsKeyDown", "IsKeyUp", "IsKeyPress", "IsAnyKeyDown",
              "GetMouseX", "GetMouseY", "IsMouseDown", "IsMouseUp",
              "IsMousePress", "IsAnyMouseDown", "GetMouseZ", "SetMouseZ",
              "GetTouchCount", "GetTouch" },
    Audio = { "PlayMusic", "PlaySound", "SetVolume", "GetVolume",
              "PauseMusic", "StopMusic", "ResumeMusic", "IsPlayingMusic",
              "FadeOutMusic", "SetMusicPosition", "ReleaseMusic" },
    TextureManager = { "Load", "Remove", "IsValid" },
    Json = { "Load" },
    Sprite = { "Create", "Update", "Draw", "Dispose", "SetPosition", "GetPosition",
               "SetScale", "SetAngle", "SetVisible", "SetOpacity",
               "SetFrames", "SetCurrentFrame", "SetRect", "SetLoop",
               "SetSheetGrid", "GetRect" },
}

-- ---- 명세 대조 (R2) ---------------------------------------------------------
-- 두 방향으로 본다.
--   1. 명세 -> VM: 명세의 Lua 이름이 전부 VM 에 함수로 있다
--   2. VM -> 명세: VM 에 있는 엔진 함수가 전부 명세에 있다. 엔진 함수는 C 함수로 가려낸다.
--      전역은 _G 에서 Lua 표준 전역(STD_GLOBALS)을 뺀 C 함수이고, 모듈은 C 함수를 담은
--      표준 밖의 전역 표다. 그래서 바인딩을 더하고 명세를 안 고치면 여기서 깨진다
-- 덤으로, 인자 없는 getter(명세의 rubyKind 가 getter 나 predicate)는 불러서 반환 타입이
-- 명세와 맞는지 본다. 클래스는 싸게 만들 수 있는 인스턴스(PROBES)로 본다.

local API_PATH = "./resources/api/initial2d-api.json"

-- Lua 5.3 luaL_openlibs 가 넣는 전역. 엔진이 print 를 갈아 끼우지만 이름은 표준이라
-- 훑기에서는 빼고, 명세 -> VM 방향에서 확인한다.
local STD_GLOBALS = {}
for _, name in ipairs({ "_G", "_VERSION", "assert", "collectgarbage", "coroutine", "debug",
    "dofile", "error", "getmetatable", "io", "ipairs", "load", "loadfile", "math", "next",
    "os", "package", "pairs", "pcall", "print", "rawequal", "rawget", "rawlen", "rawset",
    "require", "select", "setmetatable", "string", "table", "tonumber", "tostring", "type",
    "utf8", "xpcall" }) do
    STD_GLOBALS[name] = true
end

-- 훑기가 제대로 도는지 보는 기준. 이 일곱은 반드시 엔진 표로 발견되어야 한다
local KNOWN_MODULES = { "Input", "Audio", "TextureManager", "Json", "Sprite", "Tilemap", "FontEx" }

-- getter 를 불러 볼 인스턴스. 텍스처가 없어도 Sprite 는 만들어진다 (그리지만 않는다)
local PROBES = {
    Sprite = { ctor = "Sprite.Create", args = { 0, 0, 16, 16, 1, "api_surface_probe" } },
    Tilemap = { ctor = "Tilemap.Load", args = { "./fixtures/maps/sample_v1.json" } },
    FontEx = { ctor = "FontEx.Create", args = { "api_surface_probe", 16, 64, 16 } },
}

local function isCFunction(v)
    return type(v) == "function" and debug.getinfo(v, "S").what == "C"
end

-- "Sprite.Create" 같은 점 경로를 _G 에서 찾는다
local function resolve(path)
    local v = _G
    for part in string.gmatch(path, "[^%.]+") do
        if type(v) ~= "table" then return nil end
        v = v[part]
    end
    return v
end

local function describe(v)
    if type(v) == "number" then return math.type(v) end
    return type(v)
end

-- 명세의 타입 식(number, integer|nil, string[])과 Lua 값을 견준다.
-- 클래스 이름(Sprite 등)은 Lua 에서 숫자 핸들이다.
local function matchesType(v, expr)
    for alt in string.gmatch(expr, "[^|]+") do
        if alt:sub(-2) == "[]" then
            if type(v) == "table" then
                local ok = true
                for _, e in ipairs(v) do
                    if not matchesType(e, alt:sub(1, -3)) then ok = false break end
                end
                if ok then return true end
            end
        elseif alt == "any" then return true
        elseif alt == "nil" then if v == nil then return true end
        elseif alt == "number" then if type(v) == "number" then return true end
        elseif alt == "integer" then if math.type(v) == "integer" then return true end
        elseif alt == "string" or alt == "symbol" then if type(v) == "string" then return true end
        elseif alt == "boolean" then if type(v) == "boolean" then return true end
        elseif alt == "table" or alt == "array" then if type(v) == "table" then return true end
        elseif alt == "function" then if type(v) == "function" then return true end
        elseif type(v) == "number" then return true
        end
    end
    return false
end

-- expected 는 타입 식 하나 또는 여러 값 반환의 목록. 어긋난 것을 mismatches 에 쌓는다
local function checkReturns(label, expected, results, mismatches)
    if type(expected) == "table" then
        for i, expr in ipairs(expected) do
            if not matchesType(results[i], expr) then
                mismatches[#mismatches + 1] = string.format("%s[%d] 실제 %s, 명세 %s",
                    label, i, describe(results[i]), expr)
            end
        end
    elseif not matchesType(results[1], expected) then
        mismatches[#mismatches + 1] = string.format("%s 실제 %s, 명세 %s",
            label, describe(results[1]), expected)
    end
end

local function requiredCount(params)
    local n = 0
    for _, p in ipairs(params or {}) do
        if not p.optional and not p.variadic then n = n + 1 end
    end
    return n
end

-- 인자 없이 불러도 되는 getter 인가 (명세 도구가 getter 에 필수 인자가 없음을 보장한다)
local function isSafeGetter(fn)
    return fn.ruby ~= nil and (fn.rubyKind == "getter" or fn.rubyKind == "predicate")
        and requiredCount(fn.luaParams or fn.params) == 0
end

local function sortedKeys(map)
    local out = {}
    for k in pairs(map) do out[#out + 1] = k end
    table.sort(out)
    return out
end

local function checkSpec(t)
    local api, err = Json.Load(API_PATH)
    t.check(type(api) == "table", "명세 JSON 을 읽는다 (" .. API_PATH .. ")", err)
    if type(api) ~= "table" then return end
    t.check_eq(api.version, 1, "명세 version")

    local specGlobals = {}   -- 명세가 말하는 Lua 전역 함수 이름
    local specTables = {}    -- 표 이름 -> 명세가 말하는 함수 이름 집합

    -- 1. 명세 -> VM: 모듈 (lua 가 null 인 모듈의 함수는 전역이다)
    for _, m in ipairs(api.modules) do
        local missing, count = {}, 0
        if m.lua then specTables[m.lua] = specTables[m.lua] or {} end
        for _, fn in ipairs(m.functions) do
            if fn.lua then
                count = count + 1
                local value
                if m.lua then
                    specTables[m.lua][fn.lua] = true
                    value = resolve(m.lua .. "." .. fn.lua)
                else
                    specGlobals[fn.lua] = true
                    value = _G[fn.lua]
                end
                if type(value) ~= "function" then
                    missing[#missing + 1] = (m.lua and (m.lua .. ".") or "") .. fn.lua
                end
            end
        end
        if count > 0 then
            t.check(#missing == 0,
                string.format("명세 -> VM: %s%s 의 Lua 함수 %d개가 있다",
                    m.name, m.lua and "" or " (전역)", count),
                "VM 에 없음: " .. table.concat(missing, ", "))
        end
    end

    -- 1. 명세 -> VM: 클래스 (Lua 는 숫자 핸들을 받는 함수 표)
    for _, c in ipairs(api.classes) do
        if c.lua then
            local names = specTables[c.lua] or {}
            specTables[c.lua] = names
            local missing, count = {}, 0
            for _, k in ipairs(c.constructors) do
                if k.lua then
                    count = count + 1
                    names[k.lua:match("[^%.]+$")] = true
                    if type(resolve(k.lua)) ~= "function" then missing[#missing + 1] = k.lua end
                end
            end
            for _, fn in ipairs(c.methods) do
                if fn.lua then
                    count = count + 1
                    names[fn.lua] = true
                    if type(resolve(c.lua .. "." .. fn.lua)) ~= "function" then
                        missing[#missing + 1] = c.lua .. "." .. fn.lua
                    end
                end
            end
            t.check(#missing == 0,
                string.format("명세 -> VM: 클래스 %s 의 Lua 함수 %d개가 있다", c.name, count),
                "VM 에 없음: " .. table.concat(missing, ", "))
        end
    end

    -- 2. VM -> 명세: _G 를 훑어 엔진 전역 함수와 엔진 표를 찾는다
    local cGlobals, unknownGlobals = 0, {}
    local engineTables = {}   -- 표 이름 -> C 함수 이름 목록
    for name, value in pairs(_G) do
        if type(name) == "string" and not STD_GLOBALS[name] then
            if isCFunction(value) then
                cGlobals = cGlobals + 1
                if not specGlobals[name] then unknownGlobals[#unknownGlobals + 1] = name end
            elseif type(value) == "table" then
                local fns = {}
                for k, v in pairs(value) do
                    if type(k) == "string" and isCFunction(v) then fns[#fns + 1] = k end
                end
                if #fns > 0 then
                    table.sort(fns)
                    engineTables[name] = fns
                end
            end
        end
    end
    table.sort(unknownGlobals)
    t.check(#unknownGlobals == 0,
        string.format("VM -> 명세: 엔진 전역 함수 %d개가 모두 명세에 있다", cGlobals),
        "명세에 없음: " .. table.concat(unknownGlobals, ", "))

    local notFound = {}
    for _, name in ipairs(KNOWN_MODULES) do
        if engineTables[name] == nil then notFound[#notFound + 1] = name end
    end
    t.check(#notFound == 0, "VM 훑기가 알려진 엔진 모듈 일곱을 모두 찾는다",
        "못 찾음: " .. table.concat(notFound, ", "))

    for _, name in ipairs(sortedKeys(engineTables)) do
        local fns = engineTables[name]
        local described = specTables[name]
        if described == nil then
            t.check(false, "VM -> 명세: 엔진 표 " .. name .. " 가 명세에 있다",
                "명세에 없는 모듈 (C 함수: " .. table.concat(fns, ", ") .. ")")
        else
            local missing = {}
            for _, fnName in ipairs(fns) do
                if not described[fnName] then missing[#missing + 1] = fnName end
            end
            t.check(#missing == 0,
                string.format("VM -> 명세: %s 의 C 함수 %d개가 모두 명세에 있다", name, #fns),
                "명세에 없음: " .. table.concat(missing, ", "))
        end
    end

    -- 3. 인자 없는 getter 의 반환 타입 (모듈과 전역)
    local mismatches, called = {}, 0
    for _, m in ipairs(api.modules) do
        for _, fn in ipairs(m.functions) do
            if fn.lua and isSafeGetter(fn) then
                local label = (m.lua and (m.lua .. ".") or "") .. fn.lua
                local f = resolve(label)
                if type(f) == "function" then
                    called = called + 1
                    checkReturns(label, fn.luaReturns or fn.returns, table.pack(f()), mismatches)
                end
            end
        end
    end
    t.check(#mismatches == 0,
        string.format("인자 없는 getter %d개의 반환 타입이 명세와 맞다", called),
        table.concat(mismatches, "; "))

    -- 3. 클래스: 생성자의 반환 타입과 인스턴스 getter 의 반환 타입
    for _, c in ipairs(api.classes) do
        local probe = c.lua and PROBES[c.lua]
        if probe then
            local ctorSpec, disposeName
            for _, k in ipairs(c.constructors) do
                if k.lua == probe.ctor then ctorSpec = k end
            end
            for _, fn in ipairs(c.methods) do
                if fn.ruby == "dispose" then disposeName = fn.lua end
            end
            local ctor = resolve(probe.ctor)
            t.check(ctorSpec ~= nil and type(ctor) == "function", "명세와 VM 에 " .. probe.ctor .. " 가 있다")
            if ctorSpec ~= nil and type(ctor) == "function" then
                local results = table.pack(ctor(table.unpack(probe.args)))
                local handle = results[1]
                local ctorMismatch = {}
                checkReturns(probe.ctor, ctorSpec.luaReturns or ctorSpec.returns, results, ctorMismatch)
                local ok = #ctorMismatch == 0 and type(handle) == "number" and handle ~= 0
                t.check(ok, probe.ctor .. " 가 명세의 타입으로 핸들을 돌려준다",
                    table.concat(ctorMismatch, "; ") .. " " .. tostring(results[2]))
                if ok then
                    local classMismatch, n = {}, 0
                    for _, fn in ipairs(c.methods) do
                        if fn.lua and isSafeGetter(fn) then
                            local f = resolve(c.lua .. "." .. fn.lua)
                            if type(f) == "function" then
                                n = n + 1
                                checkReturns(c.lua .. "." .. fn.lua, fn.luaReturns or fn.returns,
                                    table.pack(f(handle)), classMismatch)
                            end
                        end
                    end
                    if n > 0 then
                        t.check(#classMismatch == 0,
                            string.format("%s 인스턴스 getter %d개의 반환 타입이 명세와 맞다", c.name, n),
                            table.concat(classMismatch, "; "))
                    end
                    if disposeName then resolve(c.lua .. "." .. disposeName)(handle) end
                end
            end
        end
    end
end

function M.run(t)
    for _, name in ipairs(GLOBALS) do
        t.check_type(_G[name], "function", "전역 " .. name)
    end

    for moduleName, fns in pairs(MODULES) do
        t.check_type(_G[moduleName], "table", "모듈 " .. moduleName)
        if type(_G[moduleName]) == "table" then
            for _, fn in ipairs(fns) do
                t.check_type(_G[moduleName][fn], "function", moduleName .. "." .. fn)
            end
        end
    end

    -- 값 계약: 논리 해상도 (game.json, INITIAL2D_WINDOW, 렌더 배율로 결정된다)
    t.check_type(WindowWidth(), "number", "WindowWidth()가 숫자를 돌려준다")
    t.check(WindowWidth() > 0 and WindowHeight() > 0, "논리 해상도가 양수다")

    -- 렌더 배율: 논리 해상도를 나눈다. 다른 케이스에 영향이 없도록 반드시 되돌린다.
    local baseW, baseH = WindowWidth(), WindowHeight()
    t.check_eq(GetRenderScale(), 1, "기본 배율은 1")
    t.check_eq(SetRenderScale(2), 2, "SetRenderScale은 적용된 배율을 돌려준다")
    t.check(WindowWidth() == baseW // 2 and WindowHeight() == baseH // 2,
        "배율 2에서 논리 해상도는 절반", WindowWidth() .. "x" .. WindowHeight())
    t.check_eq(SetRenderScale(-5), 1, "0 이하는 1로 잘린다")
    t.check_eq(SetRenderScale(100), 16, "상한 16으로 잘린다")
    SetRenderScale(1)
    t.check(WindowWidth() == baseW and WindowHeight() == baseH,
        "배율을 1로 되돌리면 원래 해상도")

    -- 값 계약: 멀티터치 (T1). 헤드리스에는 손가락이 없다.
    t.check_eq(Input.GetTouchCount(), 0, "헤드리스: 터치 없음")
    t.check_eq(Input.GetTouch(1), nil, "범위 밖 GetTouch는 nil")

    -- 명세 대조 (R2). 배율을 1로 되돌린 뒤라 getter 가 기본 상태를 본다
    checkSpec(t)
end

return M
