-- input_replay.lua : 입력 시퀀스 재생기 (검수 인프라, docs/plans/09-testing.md 3.4절)
--
-- 엔진 Input 모듈과 같은 API를 갖는 가짜 Input을 만들어, 프레임 번호에 맞춰
-- 정해진 입력을 재생한다. 고정 타임스텝(16ms) 덕분에 같은 시나리오는 항상
-- 같은 결과를 낸다. 상태 전이 의미는 엔진의 4-상태 머신과 동일하다:
--   IsKeyDown  = 이번 프레임에 눌리기 시작 (rising edge)
--   IsKeyPress = 계속 눌려 있음
--   IsKeyUp    = 이번 프레임에 떼어짐 (falling edge)
--
-- 시나리오 형식:
--   {
--     { at = 10, press = "SPACE" },          -- 프레임 10부터 키가 눌림
--     { at = 15, release = "SPACE" },        -- 프레임 15에 떼어짐
--     { at = 20, mouse = { x = 100, y = 200 } },  -- 마우스 이동
--     { at = 21, click = 0 },                -- 마우스 버튼 0 누름
--     { at = 23, unclick = 0 },
--     { at = 30, wheel = -1 },
--     { at = 40, touchdown = { id = 1, x = 80, y = 360 } },  -- 손가락 1 누름
--     { at = 45, touchmove = { id = 1, x = 120, y = 360 } }, -- 끌기
--     { at = 50, touchup = { id = 1 } },     -- 뗌 (그 틱에 phase "up"으로 보인다)
--   }
-- 키는 이름("SPACE") 또는 VK 정수(32) 둘 다 허용한다.
-- 터치는 엔진의 멀티터치 API(GetTouchCount/GetTouch)와 같은 의미로 재생된다:
-- 누른 첫 틱은 "down", 이후 "press", 뗀 틱은 "up"으로 한 틱 보인 뒤 사라진다.
--
-- 사용법 (씬의 Update 첫 줄에서 tick을 호출한다):
--   local replay = require("scripts/luatests/input_replay")
--   local r = replay.new(scenario)
--   r:install()            -- _G.Input 을 교체
--   function Update(e) r:tick() ... end
--   r:restore()            -- 원래 Input 복구

local M = {}

-- Win32 가상 키 코드 (엔진 전 플랫폼 공통 관례, src/platform/WinTypes.h)
M.KEYS = {
    BACKSPACE = 8, TAB = 9, RETURN = 13, SHIFT = 16, CONTROL = 17, MENU = 18,
    ESCAPE = 27, SPACE = 32,
    PRIOR = 33, NEXT = 34, END = 35, HOME = 36,
    LEFT = 37, UP = 38, RIGHT = 39, DOWN = 40,
    INSERT = 45, DELETE = 46,
}
for i = 0, 25 do M.KEYS[string.char(65 + i)] = 65 + i end   -- A~Z
for i = 0, 9 do M.KEYS[tostring(i)] = 48 + i end            -- 0~9

local function resolveKey(key)
    if type(key) == "number" then return key end
    local vk = M.KEYS[key]
    assert(vk ~= nil, "input_replay: 알 수 없는 키 이름 " .. tostring(key))
    return vk
end

local Replay = {}
Replay.__index = Replay

function M.new(scenario)
    local self = setmetatable({}, Replay)
    self.frame = 0
    self.keyDown, self.keyPrev = {}, {}
    self.btnDown, self.btnPrev = {}, {}
    self.touchNow, self.touchPrev = {}, {}   -- id → { x, y }
    self.mx, self.my, self.wheelValue = 0, 0, 0
    self.saved = nil

    -- 프레임 → 이벤트 목록 색인
    self.events = {}
    for _, ev in ipairs(scenario or {}) do
        assert(type(ev.at) == "number", "input_replay: 이벤트에 at(프레임)이 필요함")
        self.events[ev.at] = self.events[ev.at] or {}
        table.insert(self.events[ev.at], ev)
    end

    -- 엔진 Input과 같은 표면의 API 테이블
    local api = {}
    self.api = api
    function api.IsKeyDown(vk) return self.keyDown[vk] == true and self.keyPrev[vk] ~= true end
    function api.IsKeyPress(vk) return self.keyDown[vk] == true and self.keyPrev[vk] == true end
    function api.IsKeyUp(vk) return self.keyDown[vk] ~= true and self.keyPrev[vk] == true end
    function api.IsAnyKeyDown()
        for vk, v in pairs(self.keyDown) do
            if v and self.keyPrev[vk] ~= true then return true end
        end
        return false
    end
    function api.IsMouseDown(btn) return self.btnDown[btn] == true and self.btnPrev[btn] ~= true end
    function api.IsMousePress(btn) return self.btnDown[btn] == true and self.btnPrev[btn] == true end
    function api.IsMouseUp(btn) return self.btnDown[btn] ~= true and self.btnPrev[btn] == true end
    function api.IsAnyMouseDown()
        for btn, v in pairs(self.btnDown) do
            if v and self.btnPrev[btn] ~= true then return true end
        end
        return false
    end
    function api.GetMouseX() return self.mx end
    function api.GetMouseY() return self.my end
    function api.GetMouseZ() return self.wheelValue end
    function api.SetMouseZ(v) self.wheelValue = v end

    -- 멀티터치 (T1). 엔진과 같은 의미: 이번 틱의 손가락 목록에 뗀 손가락이
    -- "up"으로 한 틱 남는다. 순서는 id 정렬로 고정한다 (결정성).
    local function touchList()
        local list = {}
        for id, p in pairs(self.touchNow) do
            list[#list + 1] = { id = id, x = p.x, y = p.y,
                phase = self.touchPrev[id] ~= nil and "press" or "down" }
        end
        for id, p in pairs(self.touchPrev) do
            if self.touchNow[id] == nil then
                list[#list + 1] = { id = id, x = p.x, y = p.y, phase = "up" }
            end
        end
        table.sort(list, function(a, b) return a.id < b.id end)
        return list
    end
    function api.GetTouchCount() return #touchList() end
    function api.GetTouch(i)
        local t = touchList()[i]
        if t == nil then return nil end
        return t.id, t.x, t.y, t.phase
    end

    return self
end

--- 매 프레임 호출한다. 이전 상태를 스냅샷한 뒤 이번 프레임의 이벤트를 적용한다.
function Replay:tick()
    for k, v in pairs(self.keyPrev) do self.keyPrev[k] = nil end
    for k, v in pairs(self.keyDown) do self.keyPrev[k] = v end
    for k, v in pairs(self.btnPrev) do self.btnPrev[k] = nil end
    for k, v in pairs(self.btnDown) do self.btnPrev[k] = v end
    for k in pairs(self.touchPrev) do self.touchPrev[k] = nil end
    for id, p in pairs(self.touchNow) do self.touchPrev[id] = { x = p.x, y = p.y } end

    self.frame = self.frame + 1
    local list = self.events[self.frame]
    if list then
        for _, ev in ipairs(list) do
            if ev.press then self.keyDown[resolveKey(ev.press)] = true end
            if ev.release then self.keyDown[resolveKey(ev.release)] = nil end
            if ev.click then self.btnDown[ev.click] = true end
            if ev.unclick then self.btnDown[ev.unclick] = nil end
            if ev.mouse then self.mx, self.my = ev.mouse.x, ev.mouse.y end
            if ev.wheel then self.wheelValue = ev.wheel end
            if ev.touchdown then
                self.touchNow[ev.touchdown.id] = { x = ev.touchdown.x, y = ev.touchdown.y }
            end
            if ev.touchmove and self.touchNow[ev.touchmove.id] ~= nil then
                self.touchNow[ev.touchmove.id] = { x = ev.touchmove.x, y = ev.touchmove.y }
            end
            if ev.touchup then self.touchNow[ev.touchup.id] = nil end
        end
    end
end

--- 다음 tick에 적용될 이벤트를 지금 예약한다.
-- 시나리오를 미리 다 적어 두는 대신, 화면 상태를 보고 다음 입력을 정하는
-- 대화형 시나리오(8단계의 데모 인수 테스트)에서 쓴다.
function Replay:schedule(ev, delay)
    local at = self.frame + (delay or 1)
    self.events[at] = self.events[at] or {}
    table.insert(self.events[at], ev)
    return self
end

--- 다음 tick부터 키를 누른 채로 둔다 (뗄 때까지 계속 눌려 있다)
function Replay:press(key)
    return self:schedule{ press = key }
end

--- 다음 tick에 키를 뗀다
function Replay:release(key)
    return self:schedule{ release = key }
end

--- 한 tick만 눌렀다 뗀다 (결정키처럼 엣지로 쓰는 입력)
function Replay:tap(key)
    self:schedule({ press = key }, 1)
    return self:schedule({ release = key }, 2)
end

--- 남은 이벤트가 없으면 true (시나리오 종료 판정용)
function Replay:finished()
    for at in pairs(self.events) do
        if at > self.frame then return false end
    end
    return true
end

function Replay:install()
    self.saved = _G.Input
    _G.Input = self.api
end

function Replay:restore()
    if self.saved then
        _G.Input = self.saved
        self.saved = nil
    end
end

return M
