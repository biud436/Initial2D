-- event.lua : 맵 위의 이벤트 (6단계, docs/plans/06-rpg-events.md)
--
-- 이벤트는 "위치 + 트리거 + Lua 함수"다. R2K3처럼 이벤트 커맨드를 목록으로
-- 쌓지 않는다 — 우리에게는 이미 완전한 언어가 있고, 코루틴이 "대화창이 닫힐
-- 때까지 대기" 같은 흐름을 그대로 표현한다 (실행은 interpreter.lua).
--
-- 외형(charset)이 있으면 5단계의 character.lua를 그대로 재사용한다. 외형이
-- 없으면 보이지 않는 트리거 타일이며 통행을 막지 않는다.
--
-- 이 파일도 엔진 전역을 부르지 않는다. 캐릭터 생성은 주입받은 씬이 한다.
--
-- 이벤트 정의 파일 (scripts/maps/<맵이름>.lua):
--   return {
--     events = {
--       { id = "villager", x = 12, y = 7, trigger = "action",
--         charset = { file = "./resources/charsets/placeholder.png", index = 2 },
--         commands = { { code = "message", text = "안녕하세요" } } },
--     },
--   }
--
-- 9단계부터 이벤트의 본문은 **커맨드 목록**(commands)이 기본이고, Lua 함수(script)는
-- 커맨드로 적기 어려운 경우의 탈출구다. 둘 다 없으면 보이기만 하는 이벤트다.

local Commands = require("scripts/rpg/commands")

local M = {}

M.TRIGGERS = { action = true, touch = true, auto = true, parallel = true }

local Event = {}
Event.__index = Event
M.Event = Event

--- @param opts.id       이벤트 이름 (moveRoute 대상 지정과 로그에 쓴다)
-- @param opts.x, opts.y 타일 좌표
-- @param opts.trigger   "action" | "touch" | "auto" | "parallel"
-- @param opts.commands  커맨드 배열 (9단계). script가 없으면 이것을 컴파일해 쓴다
-- @param opts.script    function(self, ctx) — 커맨드로 적기 어려운 이벤트의 탈출구
-- @param opts.scripts   commands 안의 script 커맨드가 이름으로 부를 함수 표
-- @param opts.charset   { file =, index = } 외형 (없으면 보이지 않는 트리거)
-- @param opts.dir       시작 방향
-- @param opts.through   true면 외형이 있어도 통행을 막지 않는다
function M.new(opts)
	opts = opts or {}
	assert(opts.id ~= nil, "event: id가 필요하다")
	local trigger = opts.trigger or "action"
	assert(M.TRIGGERS[trigger], "event: 알 수 없는 트리거 " .. tostring(trigger))
	assert(opts.script == nil or type(opts.script) == "function",
		"event: script는 함수여야 한다")

	-- 커맨드 목록은 여기서 한 번 검사하고 함수로 바꾼다. 틀린 커맨드는 실행 도중이
	-- 아니라 맵을 열 때, 어느 자리인지와 함께 드러나야 한다.
	local script = opts.script
	if script == nil and opts.commands ~= nil then
		local env = { scripts = opts.scripts }
		local ok, errors = Commands.validate(opts.commands, env)
		assert(ok, "event '" .. tostring(opts.id) .. "'의 커맨드가 잘못되었다:\n  "
			.. table.concat(errors or {}, "\n  "))
		script = Commands.compile(opts.commands, env)
	end

	local self = setmetatable({}, Event)
	self.id = opts.id
	self.x = opts.x or 0
	self.y = opts.y or 0
	self.dir = opts.dir or "down"
	self.trigger = trigger
	self.script = script
	self.commands = opts.commands
	self.charset = opts.charset
	self.through = opts.through or false
	self.solid = opts.solid            -- nil이면 외형 유무로 판단한다
	self.enabled = opts.enabled ~= false
	self.character = nil    -- 외형이 있으면 씬이 채운다
	self.data = opts.data   -- 정의 파일이 넘긴 임의의 값 (스크립트가 쓴다)
	return self
end

--- 지금 서 있는 타일. 외형이 있으면 캐릭터가 진실이다 (이동 루트로 움직인다).
function Event:tile()
	if self.character ~= nil then
		return self.character.tx, self.character.ty
	end
	return self.x, self.y
end

--- 통행을 막는가. 기본은 "외형이 있으면 막는다"이고, solid를 직접 지정하면
--- 외형 없는 이벤트도 막을 수 있다 (잠긴 문, 보이지 않는 벽).
function Event:isSolid()
	if not self.enabled then return false end
	if self.solid ~= nil then return self.solid end
	return self.character ~= nil and not self.through
end

function Event:turnToward(tx, ty)
	if self.character == nil then return end
	local ex, ey = self:tile()
	local dx, dy = tx - ex, ty - ey
	if math.abs(dx) > math.abs(dy) then
		self.character:turn(dx > 0 and "right" or "left")
	elseif dy ~= 0 then
		self.character:turn(dy > 0 and "down" or "up")
	end
end

-- ---- 관리자 --------------------------------------------------------------
--
-- 맵 하나 분량의 이벤트를 들고 트리거를 감지한다. 플레이어의 타일이 바뀌는
-- 순간을 스스로 기억하므로(prevTile), 씬은 update만 불러 주면 된다.

local Manager = {}
Manager.__index = Manager
M.Manager = Manager

function M.newManager(opts)
	opts = opts or {}
	local self = setmetatable({}, Manager)
	self.events = {}
	self.byId = {}
	self.player = opts.player          -- Character
	self.interpreter = opts.interpreter
	self.prevTx, self.prevTy = nil, nil
	return self
end

function Manager:add(event)
	table.insert(self.events, event)
	self.byId[event.id] = event
	return event
end

function Manager:get(id)
	return self.byId[id]
end

function Manager:clear()
	self.events = {}
	self.byId = {}
	self.prevTx, self.prevTy = nil, nil
end

--- 그 칸에 있는 이벤트 (여러 개면 먼저 등록된 것)
function Manager:at(tx, ty, trigger)
	for _, e in ipairs(self.events) do
		if e.enabled and (trigger == nil or e.trigger == trigger) then
			local ex, ey = e:tile()
			if ex == tx and ey == ty then return e end
		end
	end
	return nil
end

--- 통행 판정용: 그 칸을 막는 이벤트가 있는가 (map_scene의 canPass가 부른다)
function Manager:blocksTile(tx, ty, except)
	for _, e in ipairs(self.events) do
		-- except는 캐릭터로 들어온다 (map_scene의 통행 판정). 이벤트 자신도 함께 뺀다.
		if e ~= except and e.character ~= except and e:isSolid() then
			local ex, ey = e:tile()
			if ex == tx and ey == ty then return true end
		end
	end
	return false
end

--- 결정키를 눌렀을 때 실행할 이벤트. 바라보는 칸을 먼저 보고, 없으면 발밑을 본다.
function Manager:actionTarget()
	if self.player == nil then return nil end
	local fx, fy = self.player:frontTile()
	local found = self:at(fx, fy, "action")
	if found ~= nil then return found end
	return self:at(self.player.tx, self.player.ty, "action")
end

--- 결정키 처리. 실행을 시작했으면 true.
function Manager:confirm()
	if self.interpreter == nil or self.interpreter:isBusy() then return false end
	local target = self:actionTarget()
	if target == nil or target.script == nil then return false end
	target:turnToward(self.player.tx, self.player.ty)   -- 말을 걸면 돌아본다
	return self.interpreter:start(target)
end

--- 맵에 들어갈 때 한 번: auto는 즉시 실행(조작 잠금), parallel은 상시 실행.
function Manager:onMapStart()
	if self.interpreter == nil then return end
	for _, e in ipairs(self.events) do
		if e.enabled and e.script ~= nil and e.trigger == "parallel" then
			self.interpreter:start(e)
		end
	end
	for _, e in ipairs(self.events) do
		if e.enabled and e.script ~= nil and e.trigger == "auto" then
			self.interpreter:start(e)
			break   -- auto는 하나만 (여러 개면 첫 번째. 나머지는 다음 진입에)
		end
	end
	if self.player ~= nil then
		self.prevTx, self.prevTy = self.player.tx, self.player.ty
	end
end

--- 매 프레임. 플레이어가 칸을 옮긴 순간에 touch 트리거를 본다.
function Manager:update()
	if self.player == nil or self.interpreter == nil then return end

	local tx, ty = self.player.tx, self.player.ty
	if self.prevTx == nil then
		self.prevTx, self.prevTy = tx, ty
		return
	end

	if tx ~= self.prevTx or ty ~= self.prevTy then
		self.prevTx, self.prevTy = tx, ty
		if not self.interpreter:isBusy() then
			local e = self:at(tx, ty, "touch")
			if e ~= nil and e.script ~= nil then
				self.interpreter:start(e)
			end
		end
	end
end

return M
