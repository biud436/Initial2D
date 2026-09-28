-- 씬 로더 params 픽스처 씬 (tests/run_engine_tests.py 가 구동, r1-scene-loader.md 5.4절)
--
-- tests/fixtures/scenes/params_v1.json (러너가 ./fixtures/ 로 복사)을 열어 컴포넌트마다 받은 params
-- (기본값만, 덮어쓴 값, 한 오브젝트의 두 컴포넌트, 선언이 없는 컴포넌트)와 훅에 넘어간 값, params 로
-- 움직인 오브젝트의 위치를 stdout 으로 알린다. mruby_scene_params_scene.rb 가 같은 줄을 찍는다.

local SceneLoader = require("scripts/lua/scene_loader")

local scene
local custom
local ticks = 0

-- 값을 두 언어가 같은 글자로 찍는다: 문자열은 따옴표와 \n, 배열은 [..], 객체는 키 순서의 {k=v}
local function show(v)
	if type(v) == "string" then return '"' .. v:gsub("\n", "\\n") .. '"' end
	if type(v) ~= "table" then return tostring(v) end
	local parts = {}
	if #v > 0 then
		for i, x in ipairs(v) do parts[i] = show(x) end
		return "[" .. table.concat(parts, ",") .. "]"
	end
	local keys = {}
	for k in pairs(v) do keys[#keys + 1] = k end
	table.sort(keys)
	for i, k in ipairs(keys) do parts[i] = k .. "=" .. show(v[k]) end
	return "{" .. table.concat(parts, ",") .. "}"
end

-- params 표 하나를 "k=v k=v" 로 (키 순서)
local function fields(t)
	local keys = {}
	for k in pairs(t) do keys[#keys + 1] = k end
	table.sort(keys)
	local parts = {}
	for i, k in ipairs(keys) do parts[i] = k .. "=" .. show(t[k]) end
	return table.concat(parts, " ")
end

function Initialize()
	scene = SceneLoader.open("fixtures/scenes/params_v1.json")
	local ids = {}
	for _, obj in ipairs(scene:objects()) do ids[#ids + 1] = obj.id end
	print("params:order:" .. table.concat(ids, ","))
	for _, id in ipairs({ "plain", "custom", "pair" }) do
		print("params:" .. id .. ":" .. fields(scene:find(id).probes[1]))
	end
	print("params:probes:pair=" .. #scene:find("pair").probes)
	print("params:loose:" .. fields(scene:find("loose").loose))
	-- 컴포넌트마다 따로 만든 표다: 한 곳을 고쳐도 다른 오브젝트의 표와 선언의 기본값은 그대로다
	local plain, pair = scene:find("plain").probes[1], scene:find("pair").probes[1]
	plain.title = "고침"
	local decl = SceneLoader.declaration("components/sample/probe")
	print("params:separate:" .. tostring(plain ~= pair and pair.title == "제목" and decl.fields[1].default == "제목"))
	-- 같은 픽스처에서 custom 의 kind 만 values 밖으로 바꾼 표는 검증이 거부한다
	local bad = Json.Load("./fixtures/scenes/params_v1.json")
	bad.objects[2].params["components/sample/probe"].kind = "sky"
	local _, err = SceneLoader.validate(bad)
	print("params:error:" .. tostring(err))
	custom = scene:find("custom")
end

function Update(elapsed)
	if ticks >= 3 then return end
	scene = scene:tick(elapsed)
	ticks = ticks + 1
	local mark = scene:find("mark")
	print("params:tick" .. ticks .. ":mark=" .. mark.x .. "," .. mark.y)
	if ticks == 3 then GameExit() end
end

function Render()
	scene:draw()
end

function Destroy()
	scene:close()
	local log = {}
	for i, s in ipairs(custom.probeLog) do log[i] = s end
	table.sort(log)   -- 첫 render 와 첫 update 의 순서는 프레임 속도에 달려 있어 정렬해 찍는다
	print("params:hooks:" .. table.concat(log, ","))
	print("params:closed:" .. tostring(scene:isClosed()))
end
