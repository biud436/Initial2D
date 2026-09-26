-- scene_loader_test.lua : 씬 로더 검증 (R1, docs/plans/r1-scene-loader.md)
-- 엔진 VM 에서 돌므로 스프라이트와 텍스처는 진짜다. 컴포넌트는 워크 디렉터리의
-- scripts/lua/components/ 에 임시 파일로 만들어 require 경로까지 실제로 통과시킨다.

local M = {}

local SceneLoader = require("scripts/lua/scene_loader")

local TILESET = "resources/tiles/tileset16-8x13.png"   -- 128x208, 16px 타일 8열

local function sceneOf(objects, extra)
    local tbl = { version = 1, name = "t", objects = objects }
    for k, v in pairs(extra or {}) do tbl[k] = v end
    return tbl
end

local function writeFile(path, text)
    local f = assert(io.open(path, "w"))
    f:write(text)
    f:close()
end

local function ids(scene)
    local out = {}
    for _, o in ipairs(scene:objects()) do out[#out + 1] = o.id end
    return table.concat(out, ",")
end

function M.run(t)
    t.check_type(SceneLoader.open, "function", "SceneLoader.open 존재")
    t.check_type(SceneLoader.validate, "function", "SceneLoader.validate 존재")
    t.check_eq(SceneLoader.VERSION, 1, "씬 포맷 버전은 1")

    -- [검증] 버전, 중복 id, 모르는 타입, 빈 id, sprite 의 image, 모르는 키
    local ok, err = SceneLoader.validate({ version = 2, objects = {} })
    t.check(not ok and err:find("version") and err:find("2", 1, true), "버전 2 는 거부하고 버전을 말한다", err)
    ok, err = SceneLoader.validate({ objects = {} })
    t.check(not ok and err:find("version"), "버전이 없어도 거부", err)
    ok, err = SceneLoader.validate("no")
    t.check(not ok, "표가 아니면 거부")
    ok, err = SceneLoader.validate(sceneOf({ { id = "a", type = "node" }, { id = "a", type = "node" } }))
    t.check(not ok and err:find("duplicate") and err:find("'a'", 1, true), "중복 id 는 거부하고 id 를 말한다", err)
    ok, err = SceneLoader.validate(sceneOf({ { id = "g", type = "ghost" } }))
    t.check(not ok and err:find("unknown type") and err:find("ghost"), "모르는 타입은 거부하고 타입을 말한다", err)
    ok, err = SceneLoader.validate(sceneOf({ { id = "", type = "node" } }))
    t.check(not ok and err:find("id"), "빈 id 는 거부", err)
    ok, err = SceneLoader.validate(sceneOf({ { type = "node" } }))
    t.check(not ok and err:find("id"), "id 가 없으면 거부", err)
    ok, err = SceneLoader.validate(sceneOf({ { id = "s", type = "sprite", props = {} } }))
    t.check(not ok and err:find("image"), "sprite 는 props.image 가 필요", err)
    ok, err = SceneLoader.validate(sceneOf({ { id = "s", type = "sprite", props = { image = "x.png", opacity = 300 } } }))
    t.check(not ok and err:find("opacity"), "opacity 는 0..255", err)
    ok, err = SceneLoader.validate(sceneOf({ { id = "s", type = "sprite", props = { image = "x.png", frames = 0 } } }))
    t.check(not ok and err:find("frames"), "frames 는 1 이상", err)
    ok, err = SceneLoader.validate(sceneOf({ { id = "n", type = "node", x = "1" } }))
    t.check(not ok and err:find("x"), "x 는 숫자여야 한다", err)
    ok, err = SceneLoader.validate(sceneOf({ { id = "n", type = "node", scripts = { 3 } } }))
    t.check(not ok and err:find("scripts"), "scripts 항목은 문자열이어야 한다", err)
    ok, err = SceneLoader.validate(sceneOf({ { id = "l", type = "text", props = { color = { 1, 2 } } } }))
    t.check(not ok and err:find("color"), "color 는 [r, g, b] 나 [r, g, b, a]", err)
    ok, err = SceneLoader.validate(sceneOf({ { id = "m", type = "tilemap", props = {} } }))
    t.check(not ok and err:find("map"), "확장 타입의 validate 도 불린다 (tilemap 은 map 이 필요)", err)
    ok, err = SceneLoader.validate(sceneOf({
        { id = "n", type = "node", editorOnly = { locked = true } },
        { id = "m", type = "tilemap", props = { map = "resources/maps/sample.json" } },
    }, { editorOnly = { note = "보존" }, camera = { x = 1 } }))
    t.check(ok, "모르는 키는 무시하고, 확장 타입 tilemap 은 안다", err)

    -- [열기 실패] 없는 컴포넌트, 없는 파일, 없는 이미지
    local okp, e = pcall(SceneLoader.fromTable,
        sceneOf({ { id = "n", type = "node", scripts = { "components/no_such_component" } } }))
    t.check(not okp and tostring(e):find("no_such_component", 1, true)
        and tostring(e):find("scripts/lua/components/no_such_component.lua", 1, true),
        "없는 컴포넌트 모듈은 논리 이름과 파일 경로를 말하며 실패", e)
    okp, e = pcall(SceneLoader.open, "no_such_scene")
    t.check(not okp and tostring(e):find("resources/scenes/no_such_scene.json", 1, true),
        "없는 씬 이름은 찾은 경로를 말하며 실패", e)
    okp, e = pcall(SceneLoader.fromTable,
        sceneOf({ { id = "s", type = "sprite", props = { image = "resources/no_such.png" } } }))
    t.check(not okp and tostring(e):find("no_such.png", 1, true), "없는 이미지는 실패", e)
    okp, e = pcall(SceneLoader.fromTable, { version = 3 })
    t.check(not okp and tostring(e):find("version"), "fromTable 도 검증한다", e)

    -- [기본값] x, y, visible, props, scripts
    local scene = SceneLoader.fromTable(sceneOf({ { id = "n", type = "node" } }))
    local n = scene:find("n")
    t.check(n ~= nil, "find 로 찾는다")
    t.check_eq(n.x, 0, "x 기본 0")
    t.check_eq(n.y, 0, "y 기본 0")
    t.check_eq(n.visible, true, "visible 기본 true")
    t.check(type(n.props) == "table" and next(n.props) == nil, "props 기본 빈 표")
    t.check(type(n.scripts) == "table" and #n.scripts == 0, "scripts 기본 빈 배열")
    t.check_eq(n.sprite, nil, "node 는 sprite 가 없다")
    t.check_eq(n.scene, scene, "obj.scene 은 씬")
    t.check_eq(n.type, "node", "type 이 남는다")
    t.check_eq(scene.name, "t", "scene.name 은 파일의 name")
    t.check(type(scene.state) == "table", "scene.state 는 빈 표")
    t.check_eq(scene:find("nope"), nil, "없는 id 는 nil")
    scene:close()
    t.check(scene:isClosed(), "close 뒤 isClosed")
    okp = pcall(scene.tick, scene, 16)
    t.check(not okp, "닫힌 씬은 tick 할 수 없다")

    -- [훅 순서] 임시 컴포넌트 파일로 init -> update -> render -> destroy 가 오브젝트 순서대로
    LUATEST_HOOKS = {}
    writeFile("./scripts/lua/components/luatest_hooks.lua", [[
local M = {}
function M.init(obj, scene) LUATEST_HOOKS[#LUATEST_HOOKS + 1] = "init:" .. obj.id; obj.props.seen = (obj.props.seen or 0) + 1 end
function M.update(obj, scene, elapsed) LUATEST_HOOKS[#LUATEST_HOOKS + 1] = "update:" .. obj.id .. ":" .. elapsed end
function M.render(obj, scene) LUATEST_HOOKS[#LUATEST_HOOKS + 1] = "render:" .. obj.id end
function M.destroy(obj, scene) LUATEST_HOOKS[#LUATEST_HOOKS + 1] = "destroy:" .. obj.id end
return M
]])
    writeFile("./scripts/lua/components/luatest_tail.lua", [[
local M = {}
function M.init(obj, scene) LUATEST_HOOKS[#LUATEST_HOOKS + 1] = "tail-init:" .. obj.id end
return M
]])
    scene = SceneLoader.fromTable(sceneOf({
        { id = "a", type = "node", scripts = { "components/luatest_hooks", "components/luatest_tail" } },
        { id = "b", type = "node", scripts = { "components/luatest_hooks" }, visible = false },
        { id = "c", type = "node", scripts = { "components/luatest_hooks" } },
    }))
    t.check_eq(table.concat(LUATEST_HOOKS, " "), "init:a tail-init:a init:b init:c",
        "init 은 모든 오브젝트를 만든 뒤 오브젝트 순서, 컴포넌트 순서대로")
    t.check_eq(scene:find("a").props.seen, 1, "init 은 오브젝트당 한 번")
    LUATEST_HOOKS = {}
    local next_scene = scene:tick(16)
    t.check_eq(next_scene, scene, "전환이 없으면 tick 은 자기 자신을 돌려준다")
    t.check_eq(table.concat(LUATEST_HOOKS, " "), "update:a:16 update:b:16 update:c:16",
        "update 는 순서대로, elapsed 를 넘긴다 (보이지 않는 오브젝트도 update 는 된다)")
    LUATEST_HOOKS = {}
    scene:draw()
    t.check_eq(table.concat(LUATEST_HOOKS, " "), "render:a render:c",
        "render 는 순서대로, visible=false 인 오브젝트는 건너뛴다")
    LUATEST_HOOKS = {}
    scene:close()
    t.check_eq(table.concat(LUATEST_HOOKS, " "), "destroy:a destroy:b destroy:c", "destroy 는 close 때 순서대로")

    -- [spawn, remove, find]
    scene = SceneLoader.fromTable(sceneOf({ { id = "a", type = "node" }, { id = "c", type = "node" } }))
    LUATEST_HOOKS = {}
    local b = scene:spawn({ id = "b", type = "node", scripts = { "components/luatest_hooks" } }, "a")
    t.check_eq(ids(scene), "a,b,c", "spawn(spec, afterId) 는 그 오브젝트 바로 뒤에 끼운다")
    t.check_eq(table.concat(LUATEST_HOOKS, " "), "init:b", "spawn 은 init 을 바로 부른다")
    t.check_eq(scene:find("b"), b, "spawn 이 돌려준 것이 find 로 찾는 것")
    t.check_eq(b.scene, scene, "spawn 한 오브젝트도 scene 을 안다")
    local auto = scene:spawn({ type = "node", props = { tag = 1 } })
    t.check(type(auto.id) == "string" and auto.id ~= "" and scene:find(auto.id) == auto, "id 가 없으면 만들어 준다", auto.id)
    t.check_eq(ids(scene), "a,b,c," .. auto.id, "afterId 가 없으면 맨 뒤")
    local auto2 = scene:spawn({ type = "node" })
    t.check(auto2.id ~= auto.id, "자동 id 는 겹치지 않는다")
    okp, e = pcall(scene.spawn, scene, { id = "a", type = "node" })
    t.check(not okp and tostring(e):find("'a'", 1, true), "이미 있는 id 로 spawn 하면 실패", e)
    okp, e = pcall(scene.spawn, scene, { id = "z", type = "ghost" })
    t.check(not okp and tostring(e):find("ghost"), "모르는 타입으로 spawn 하면 실패", e)
    okp, e = pcall(scene.spawn, scene, { id = "z", type = "node" }, "nope")
    t.check(not okp and tostring(e):find("nope"), "없는 afterId 는 실패", e)
    t.check_eq(scene:find("z"), nil, "실패한 spawn 은 오브젝트를 남기지 않는다")
    LUATEST_HOOKS = {}
    t.check_eq(scene:remove("b"), true, "remove 는 true")
    t.check_eq(table.concat(LUATEST_HOOKS, " "), "destroy:b", "remove 는 destroy 를 부른다")
    t.check_eq(scene:find("b"), nil, "remove 뒤 find 는 nil")
    t.check_eq(ids(scene), "a,c," .. auto.id .. "," .. auto2.id, "remove 뒤 순서")
    t.check_eq(scene:remove("b"), false, "없는 id 의 remove 는 false")
    t.check_eq(#scene:objects(), 4, "objects() 는 남은 것만")
    -- update 도중의 spawn 과 remove
    writeFile("./scripts/lua/components/luatest_spawner.lua", [[
local M = {}
function M.update(obj, scene, elapsed)
    if obj.props.done then return end
    obj.props.done = true
    scene:spawn({ id = "child", type = "node", scripts = { "components/luatest_hooks" } })
    scene:remove("c")
end
return M
]])
    scene:spawn({ id = "sp", type = "node", scripts = { "components/luatest_spawner" } })
    LUATEST_HOOKS = {}
    scene:tick(16)
    t.check(scene:find("child") ~= nil and scene:find("c") == nil, "update 안에서 spawn 과 remove 가 된다")
    t.check_eq(table.concat(LUATEST_HOOKS, " "), "init:child", "이번 틱에 만든 것은 init 만 (update 는 다음 틱부터)")
    LUATEST_HOOKS = {}
    scene:tick(16)
    t.check_eq(table.concat(LUATEST_HOOKS, " "), "update:child:16", "다음 틱부터 update")
    scene:close()

    -- [switch] tick 이 새 씬을 돌려주고 옛 씬은 닫힌다 (경로로도 연다)
    writeFile("./luatest_next.json", '{ "version": 1, "name": "next", "objects": [ { "id": "n2", "type": "node" } ] }')
    scene = SceneLoader.fromTable(sceneOf({ { id = "a", type = "node", scripts = { "components/luatest_hooks" } } }))
    local old = scene
    scene:switch("./luatest_next.json")
    LUATEST_HOOKS = {}
    scene = scene:tick(16)
    t.check(scene ~= old, "switch 뒤 tick 은 새 씬을 돌려준다")
    t.check_eq(scene.name, "next", "새 씬의 이름")
    t.check(scene:find("n2") ~= nil, "새 씬의 오브젝트")
    t.check(old:isClosed(), "옛 씬은 닫혔다")
    t.check_eq(table.concat(LUATEST_HOOKS, " "), "update:a:16 destroy:a", "전환 틱: 옛 씬의 update 뒤 destroy")
    scene:close()
    os.remove("./luatest_next.json")

    -- [스크립트 이름 풀기] 언어별 폴더
    t.check_eq(SceneLoader.componentPath("components/bird"), "scripts/lua/components/bird.lua", "논리 이름 -> Lua 파일")
    t.check_eq(SceneLoader.componentModule("components/flappy/pipes"), "scripts/lua/components/flappy/pipes", "논리 이름 -> require 이름")
    t.check_eq(SceneLoader.scenePath("flappy"), "./resources/scenes/flappy.json", "씬 이름 -> 경로")
    t.check_eq(SceneLoader.scenePath("fixtures/scenes/sample_v1.json"), "./fixtures/scenes/sample_v1.json", "경로는 그대로")
    t.check_eq(SceneLoader.resolveType("node"), "core", "코어 타입")
    t.check(type(SceneLoader.resolveType("tilemap")) == "table", "확장 타입은 scene_types/ 에서 게으르게 읽는다")
    t.check_eq(SceneLoader.resolveType("ghost"), nil, "모르는 타입은 nil")
    SceneLoader.registerType("luatest_ext", {
        create = function(obj) obj.created = true end,
        drawBelow = function(obj) LUATEST_HOOKS[#LUATEST_HOOKS + 1] = "below:" .. obj.id end,
        drawAbove = function(obj) LUATEST_HOOKS[#LUATEST_HOOKS + 1] = "above:" .. obj.id end,
        destroy = function(obj) obj.created = false end,
    })
    scene = SceneLoader.fromTable(sceneOf({
        { id = "e", type = "luatest_ext" },
        { id = "n", type = "node", scripts = { "components/luatest_hooks" } },
    }))
    t.check_eq(scene:find("e").created, true, "코드로 등록한 확장 타입의 create")
    LUATEST_HOOKS = {}
    scene:draw()
    t.check_eq(table.concat(LUATEST_HOOKS, " "), "below:e render:n above:e", "확장 타입의 아래 층 -> 오브젝트 -> 위 층")
    scene:close()
    t.check_eq(scene:find("e"), nil, "close 뒤 find 는 nil")

    -- [sprite props -> Sprite API]
    scene = SceneLoader.fromTable(sceneOf({
        { id = "sp", type = "sprite", x = 10, y = 20, props = {
            image = TILESET, width = 16, height = 16, frames = 4, scale = 2, angle = 45,
            opacity = 128, loop = false, startFrame = 1, endFrame = 3, frameDelay = 60 } },
        { id = "one", type = "sprite", props = { image = TILESET, width = 16, height = 16, frames = 4, startFrame = 2 } },
        { id = "whole", type = "sprite", props = { image = TILESET } },
        { id = "strip", type = "sprite", props = { image = TILESET, frames = 4 } },
    }))
    local sp = scene:find("sp")
    t.check(sp.sprite ~= nil and sp.sprite ~= 0, "sprite 핸들이 있다")
    t.check_eq(Sprite.GetWidth(sp.sprite), 16, "width -> 프레임 폭")
    t.check_eq(Sprite.GetHeight(sp.sprite), 16, "height -> 프레임 높이")
    t.check_eq(sp.frameWidth, 16, "obj.frameWidth")
    t.check_eq(Sprite.GetStartFrame(sp.sprite), 1, "startFrame -> SetFrames 의 시작")
    t.check_eq(Sprite.GetEndFrame(sp.sprite), 3, "endFrame 3 -> 엔진의 끝 프레임 3 (SetFrames 에는 4 를 넘긴다)")
    t.check_eq(Sprite.GetCurrentFrame(sp.sprite), 1, "현재 프레임은 startFrame")
    local r = Sprite.GetRect(sp.sprite)
    t.check(r.x == 16 and r.y == 0, "frames 4 는 가로 한 줄 (프레임 1 = x 16, y 0)", r.x .. "," .. r.y)
    t.check_eq(Sprite.GetScale(sp.sprite), 2, "scale")
    t.check_eq(Sprite.GetAngle(sp.sprite), 45, "angle (도)")
    t.check_eq(Sprite.GetOpacity(sp.sprite), 128, "opacity")
    t.check_eq(Sprite.GetFrameDelay(sp.sprite), 60, "frameDelay (ms)")
    t.check_eq(Sprite.GetVisible(sp.sprite), true, "visible")
    local one = scene:find("one")
    t.check_eq(Sprite.GetStartFrame(one.sprite), 2, "endFrame 0: 시작 프레임 2")
    t.check_eq(Sprite.GetEndFrame(one.sprite), 2, "endFrame 0 은 한 프레임 (끝 = 시작)")
    t.check_eq(Sprite.GetCurrentFrame(one.sprite), 2, "endFrame 0: 현재 프레임도 startFrame")
    t.check_eq(Sprite.GetFrameDelay(one.sprite), 100, "frameDelay 기본 100ms")
    local whole = scene:find("whole")
    t.check_eq(Sprite.GetWidth(whole.sprite), 128, "width 0 은 이미지 폭 전체 (PNG 헤더에서 읽는다)")
    t.check_eq(Sprite.GetHeight(whole.sprite), 208, "height 0 은 이미지 높이 전체")
    t.check_eq(Sprite.GetWidth(scene:find("strip").sprite), 32, "width 0 에 frames 4 면 폭을 4 로 나눈다")
    t.check_eq(TextureManager.IsValid("./" .. TILESET), true, "텍스처 id 는 이미지 경로")
    -- 매 틱 obj -> 스프라이트
    sp.x, sp.y = 33, 44
    sp.visible = false
    sp.props.opacity = 200.7
    sp.props.scale = 3
    sp.props.angle = 90
    scene:tick(0)
    local px, py = Sprite.GetPosition(sp.sprite)
    t.check(px == 33 and py == 44, "tick 이 obj.x, obj.y 를 스프라이트에 옮긴다", px .. "," .. py)
    t.check_eq(Sprite.GetVisible(sp.sprite), false, "tick 이 obj.visible 을 옮긴다")
    t.check_eq(Sprite.GetOpacity(sp.sprite), 200, "tick 이 props.opacity 를 옮긴다 (정수로)")
    t.check_eq(Sprite.GetScale(sp.sprite), 3, "tick 이 props.scale 을 옮긴다")
    t.check_eq(Sprite.GetAngle(sp.sprite), 90, "tick 이 props.angle 을 옮긴다")
    scene:close()
    t.check_eq(TextureManager.IsValid("./" .. TILESET), false, "close 가 텍스처를 놓는다")

    -- [text] 폰트 준비와 그리기 (엔진 API 호출이 깨지지 않는다)
    scene = SceneLoader.fromTable(sceneOf({
        { id = "l", type = "text", x = 5, y = 6, props = { text = "한 줄\n두 줄", font = "resources/fonts/hangul.fnt", color = { 255, 0, 0 } } },
        { id = "num", type = "text", props = { text = 12 } },
    }))
    t.check_eq(scene:find("l").props.text, "한 줄\n두 줄", "text 는 줄바꿈과 한글을 그대로 든다")
    t.check_eq(scene:find("num").props.font, "", "font 기본 빈 문자열 (게임이 준비한 폰트를 쓴다)")
    t.check_eq(scene:find("l").props.color[1], 255, "color 는 props 에 보존된다")
    okp, e = pcall(scene.draw, scene)
    t.check(okp, "text 오브젝트를 그릴 수 있다", e)
    scene:close()
    okp, e = pcall(SceneLoader.fromTable, sceneOf({ { id = "l", type = "text", props = { font = "resources/fonts/none.fnt" } } }))
    t.check(not okp and tostring(e):find("none.fnt", 1, true), "없는 폰트는 실패", e)

    -- [픽스처 파일] tests/fixtures/scenes/sample_v1.json (에디터와 공유)
    scene = SceneLoader.open("fixtures/scenes/sample_v1.json")
    t.check_eq(scene.name, "sample", "픽스처의 name")
    t.check_eq(ids(scene), "map,tile,anim,mover,label", "픽스처의 오브젝트 순서")
    t.check_eq(scene.source.editorOnly.note, "보존", "루트의 모르는 키는 source 에 남는다")
    t.check_eq(scene:find("tile").spec.editorOnly.locked, true, "오브젝트의 모르는 키는 spec 에 남는다")
    t.check(scene:find("map").tilemap ~= nil and scene:find("map").layerCount == 2, "tilemap 이 만들어졌다")
    t.check_eq(scene:find("tile").frameWidth, 48, "tile1.png 의 폭 48 (width 0)")
    t.check_eq(Sprite.GetCurrentFrame(scene:find("anim").sprite), 1, "anim 은 프레임 1 (눌린 버튼) 에 멈춰 있다")
    t.check_eq(scene:find("anim").frameWidth, 96, "actionbtn.png 192x96 을 두 프레임으로")
    scene:tick(16)
    t.check_eq(scene:find("tile").x, 198, "mover 컴포넌트가 tile 을 102 옮겼다")
    scene:tick(16)
    scene:tick(16)
    t.check_eq(scene:find("tile").x, 300, "limit 300 에서 멈춘다")
    okp, e = pcall(scene.draw, scene)
    t.check(okp, "픽스처 씬을 그릴 수 있다", e)
    scene:close()
    t.check_eq(scene:find("map"), nil, "close 뒤 tilemap 오브젝트도 없다")

    os.remove("./scripts/lua/components/luatest_hooks.lua")
    os.remove("./scripts/lua/components/luatest_tail.lua")
    os.remove("./scripts/lua/components/luatest_spawner.lua")
    LUATEST_HOOKS = nil
end

return M
