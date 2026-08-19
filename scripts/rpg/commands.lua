-- commands.lua : 이벤트 커맨드 (9단계, docs/plans/10-demo-v2.md)
--
-- 이벤트 하나를 **데이터 목록**으로 적는다. 6단계에서는 이벤트가 Lua 함수였고
-- 그것은 사람이 쓰기에는 좋았지만 맵 에디터가 만들 수도 읽을 수도 없었다
-- (이슈 24). 커맨드 목록은 순수 데이터라 JSON으로 오갈 수 있다.
--
--   commands = {
--     { code = "message", name = "선장", text = "저녁 물때에 배가 뜨네." },
--     { code = "choice", options = { "떠난다", "더 둘러본다" }, cancel = 2,
--       branches = {
--         { { code = "scene", name = "title", fade = 30 } },
--         { { code = "message", text = "해가 지기 전에는 오게." } },
--       } },
--   }
--
-- 실행기(interpreter.lua)는 이 파일의 존재를 모른다. compile이 커맨드 목록을
-- 6단계와 똑같은 `function(self, ctx)` 하나로 바꿔 주고, 실행기는 그것을
-- 코루틴으로 돌릴 뿐이다. 그래서 `script = function(self, ctx) ... end`로 적은
-- 옛 이벤트도 그대로 돈다 — 커맨드로 적기 어려운 것(전투, 미니게임)은 계속
-- 그쪽에 남기라는 뜻이기도 하다 (`script` 커맨드가 그 통로다).
--
-- 분기는 중첩이지 점프가 아니다. RPG Maker는 평탄한 목록에 들여쓰기로 분기를
-- 표현하지만, JSON과 웹 에디터에는 중첩 배열이 다루기 쉽고 라벨 관리가 없다.

local M = {}

-- ---- 조건 -----------------------------------------------------------------

local COMPARE = {
	["=="] = function(a, b) return a == b end,
	["="] = function(a, b) return a == b end,
	["~="] = function(a, b) return a ~= b end,
	["!="] = function(a, b) return a ~= b end,
	["<"] = function(a, b) return a < b end,
	["<="] = function(a, b) return a <= b end,
	[">"] = function(a, b) return a > b end,
	[">="] = function(a, b) return a >= b end,
}

--- 조건 하나를 판정한다. 조건이 없으면 참.
--   { flag = "heardAltar" }                    깃발이 참인가
--   { flag = "booked", equals = false }        값 비교
--   { var = "silver", op = ">=", value = 2 }   수 비교
function M.test(cond, state)
	if cond == nil then return true end
	state = state or {}

	if cond.flag ~= nil then
		local v = state[cond.flag]
		if cond.equals ~= nil then return v == cond.equals end
		return v ~= nil and v ~= false
	end

	if cond.var ~= nil then
		local op = COMPARE[cond.op or "=="]
		if op == nil then return false end
		return op(tonumber(state[cond.var]) or 0, tonumber(cond.value) or 0)
	end

	return true
end

-- ---- 커맨드 ---------------------------------------------------------------
--
-- 각 항목: run(cmd, self, ctx, env, runList) 와 검증에 쓰는 필수 인자 목록.
-- lists 는 그 커맨드가 품고 있는 하위 목록의 위치다 (검증이 따라 들어간다).

local HANDLERS = {}
local SPEC = {}

local function define(code, spec, run)
	SPEC[code] = spec
	HANDLERS[code] = run
end

define("message", { text = "string" }, function(cmd, _, ctx)
	local opts = nil
	if cmd.name ~= nil or cmd.face ~= nil then
		opts = { name = cmd.name, face = cmd.face }
	end
	ctx.message(cmd.text, opts)
end)

define("choice", { options = "table" }, function(cmd, self, ctx, env, runList)
	local pick = ctx.choice(cmd.options, { cancelIndex = cmd.cancel })
	local branch = cmd.branches ~= nil and cmd.branches[pick] or nil
	if branch ~= nil then
		runList(branch, self, ctx, env)
	end
	return pick
end)

define("wait", { ms = "number" }, function(cmd, _, ctx)
	ctx.wait(cmd.ms)
end)

define("transfer", { map = "string" }, function(cmd, _, ctx)
	-- 이 뒤의 커맨드는 실행되지 않는다 (맵이 통째로 바뀐다)
	ctx.transfer(cmd.map, cmd.x, cmd.y, cmd.dir)
end)

define("moveRoute", { target = "string", route = "table" }, function(cmd, _, ctx)
	ctx.moveRoute(cmd.target, cmd.route, { wait = cmd.wait, loop = cmd.loop })
end)

define("turn", { target = "string", dir = "string" }, function(cmd, _, ctx)
	ctx.turn(cmd.target, cmd.dir)
end)

define("setFlag", { key = "string" }, function(cmd, _, ctx)
	local value = cmd.value
	if value == nil then value = true end
	ctx.state[cmd.key] = value
end)

define("setVar", { key = "string" }, function(cmd, _, ctx)
	local now = tonumber(ctx.state[cmd.key]) or 0
	local amount = tonumber(cmd.value) or 0
	local op = cmd.op or "="
	if op == "+" then
		ctx.state[cmd.key] = now + amount
	elseif op == "-" then
		ctx.state[cmd.key] = now - amount
	else
		ctx.state[cmd.key] = amount
	end
end)

define("if", { cond = "table" }, function(cmd, self, ctx, env, runList)
	-- `참 and thenDo or elseDo`로 쓰면 안 된다. thenDo가 없는 참 분기가
	-- elseDo로 새어 나간다 (Lua의 and/or 관용구가 nil에서 무너지는 자리).
	local branch
	if M.test(cmd.cond, ctx.state) then
		branch = cmd.thenDo
	else
		branch = cmd.elseDo
	end
	if branch ~= nil then
		runList(branch, self, ctx, env)
	end
end)

define("playSe", { file = "string" }, function(cmd, _, ctx)
	ctx.playSe(cmd.file, cmd.id)
end)

define("playBgm", { file = "string" }, function(cmd, _, ctx)
	ctx.playBgm(cmd.file, { volume = cmd.volume, fade = cmd.fade })
end)

define("showLocation", { text = "string" }, function(cmd, _, ctx)
	ctx.showLocation(cmd.text, cmd.seconds)
end)

define("scene", { name = "string" }, function(cmd, _, ctx)
	-- 씬이 통째로 바뀌므로 이 뒤의 커맨드는 실행되지 않는다
	ctx.scene(cmd.name, { fade = cmd.fade, text = cmd.text })
end)

define("script", {}, function(cmd, self, ctx, env)
	local fn = cmd.run
	if fn == nil and cmd.name ~= nil then
		fn = env ~= nil and env.scripts ~= nil and env.scripts[cmd.name] or nil
	end
	assert(type(fn) == "function",
		"commands: script 커맨드가 부를 함수가 없다 (" .. tostring(cmd.name) .. ")")
	return fn(self, ctx, cmd.args)
end)

define("comment", {}, function() end)

--- 하위 목록을 품는 커맨드와 그 자리 (검증이 따라 들어간다)
local NESTED = {
	choice = function(cmd)
		local out = {}
		for i, branch in ipairs(cmd.branches or {}) do
			out[#out + 1] = { path = ".branches[" .. i .. "]", list = branch }
		end
		return out
	end,
	["if"] = function(cmd)
		local out = {}
		if cmd.thenDo ~= nil then out[#out + 1] = { path = ".thenDo", list = cmd.thenDo } end
		if cmd.elseDo ~= nil then out[#out + 1] = { path = ".elseDo", list = cmd.elseDo } end
		return out
	end,
}

--- 알고 있는 커맨드 이름 목록 (문서와 테스트가 읽는다)
function M.codes()
	local list = {}
	for code in pairs(HANDLERS) do list[#list + 1] = code end
	table.sort(list)
	return list
end

-- ---- 실행 -----------------------------------------------------------------

local function runList(list, self, ctx, env)
	for _, cmd in ipairs(list) do
		local run = HANDLERS[cmd.code]
		-- compile 전에 validate를 거치는 것이 정상 경로지만, 손으로 만든 목록이
		-- 바로 들어올 수도 있어 여기서도 분명하게 죽는다.
		assert(run ~= nil, "commands: 알 수 없는 code " .. tostring(cmd.code))
		run(cmd, self, ctx, env, runList)
	end
end

--- 커맨드 목록을 이벤트 스크립트 함수 하나로 바꾼다.
-- @param list      커맨드 배열
-- @param env.scripts  script 커맨드가 이름으로 부를 함수 표
-- @return function(self, ctx)
function M.compile(list, env)
	assert(type(list) == "table", "commands: 커맨드 목록이 필요하다")
	return function(self, ctx)
		runList(list, self, ctx, env)
	end
end

-- ---- 검증 -----------------------------------------------------------------

local function checkList(list, path, errors, env)
	if type(list) ~= "table" then
		errors[#errors + 1] = path .. ": 커맨드 목록이 배열이 아니다"
		return
	end

	for i, cmd in ipairs(list) do
		local here = path .. "[" .. i .. "]"
		if type(cmd) ~= "table" then
			errors[#errors + 1] = here .. ": 커맨드가 테이블이 아니다"
		elseif HANDLERS[cmd.code] == nil then
			errors[#errors + 1] = here .. ": 알 수 없는 code " .. tostring(cmd.code)
		else
			for field, kind in pairs(SPEC[cmd.code]) do
				if type(cmd[field]) ~= kind then
					errors[#errors + 1] = here .. "." .. field .. ": " .. kind
						.. "이(가) 필요하다 (지금은 " .. type(cmd[field]) .. ")"
				end
			end
			if cmd.code == "choice" and #(cmd.options or {}) == 0 then
				errors[#errors + 1] = here .. ".options: 항목이 하나 이상 필요하다"
			end
			if cmd.code == "script" then
				local hasRun = type(cmd.run) == "function"
				local named = cmd.name ~= nil
					and env ~= nil and env.scripts ~= nil and env.scripts[cmd.name] ~= nil
				if not hasRun and not named then
					errors[#errors + 1] = here
						.. ".name: 등록되지 않은 스크립트 " .. tostring(cmd.name)
				end
			end
			local nested = NESTED[cmd.code]
			if nested ~= nil then
				for _, child in ipairs(nested(cmd)) do
					checkList(child.list, here .. child.path, errors, env)
				end
			end
		end
	end
end

--- 커맨드 목록을 검사한다. 실행 도중이 아니라 맵을 열 때 틀린 곳을 알기 위한 것이다.
-- @return ok, errors  (errors는 "[2].branches[1][3]: 알 수 없는 code ..." 꼴의 배열)
function M.validate(list, env)
	local errors = {}
	checkList(list, "", errors, env)
	return #errors == 0, errors
end

return M
