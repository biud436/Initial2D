-- buttons_test.lua : 동작 버튼(scripts/ui/buttons.lua)의 판정 로직 검증 (T1)
--
-- 히트 슬롭(판정 반경 1.25배), 슬롭 겹침의 승자 결정, 그리고 멀티터치로
-- 두 버튼이 동시에 눌리는 것을 가짜 포인터와 가짜 Image로 검증한다.

local M = {}

local function fakeImage()
    local img = {}
    function img.setLoop() end
    function img.setScale() end
    function img.setPosition() end
    function img.setFrames() end
    function img.setCurrentFrame() end
    function img.update() end
    function img.draw() end
    function img.dispose() end
    return img
end

local function pt(id, x, y, phase)
    return { id = id, x = x, y = y,
        down = phase == "down", held = phase ~= "up", up = phase == "up" }
end

function M.run(t)
    local Buttons = require("scripts/ui/buttons")
    t.check_type(Buttons.hit, "function", "Buttons.hit 존재")
    t.check_type(Buttons.pick, "function", "Buttons.pick 존재")

    -- 히트 슬롭: 표시 반경 밖이라도 1.25배 안이면 맞는다
    local item = { x = 100, y = 100, size = 40 }   -- 중심 (120, 120), 반경 20
    t.check(Buttons.hit(item, 120, 141) == false, "표시 반경 밖")
    t.check(Buttons.hit(item, 120, 141, 1.25) == true, "슬롭 반경 안")
    t.check(Buttons.hit(item, 120, 146, 1.25) == false, "슬롭 반경 밖")

    -- 승자 결정: 겹치는 자리는 중심이 가까운 버튼이 먹는다
    local a = { id = "a", x = 0, y = 0, size = 40 }      -- 중심 (20, 20)
    local b = { id = "b", x = 44, y = 0, size = 40 }     -- 중심 (64, 20)
    local picked = Buttons.pick({ a, b }, 40, 20, 1.25)  -- a까지 20, b까지 24
    t.check_eq(picked ~= nil and picked.id or nil, "a", "겹침: 가까운 쪽이 이긴다")
    picked = Buttons.pick({ a, b }, 46, 20, 1.25)        -- a까지 26 > 25 (슬롭 밖), b까지 18
    t.check_eq(picked ~= nil and picked.id or nil, "b", "겹침: 반대쪽")
    t.check_eq(Buttons.pick({ a, b }, 200, 200, 1.25), nil, "빈 곳은 nil")

    -- 멀티터치: 두 손가락이 두 버튼을 동시에 누른다
    local pad = Buttons.new{
        imageFactory = fakeImage,
        items = {
            { id = "jump", x = 300, y = 380, size = 60 },     -- 중심 (330, 410)
            { id = "attack", x = 220, y = 380, size = 60 },   -- 중심 (250, 410)
        },
    }
    pad.update({ pt(1, 330, 410, "down"), pt(2, 250, 410, "down") })
    t.check(pad.pressed("jump") and pad.pressed("attack"), "동시 두 버튼 엣지")

    -- 엣지는 down 틱에만, held는 누르는 동안 계속
    pad.update({ pt(1, 330, 410, "press"), pt(2, 250, 410, "press") })
    t.check(not pad.pressed("jump") and not pad.pressed("attack"), "press 틱은 엣지 아님")
    t.check(pad.items[1].held and pad.items[2].held, "press 틱에도 held")

    -- 뗀 손가락은 누르지 못한다
    pad.update({ pt(1, 330, 410, "up"), pt(2, 250, 410, "press") })
    t.check(not pad.items[1].held and pad.items[2].held, "up은 held 아님")

    -- 한 포인터는 버튼 하나만 먹는다 (두 버튼 사이 겹침 자리)
    local mid = Buttons.new{
        imageFactory = fakeImage,
        items = {
            { id = "l", x = 0, y = 0, size = 40 },
            { id = "r", x = 44, y = 0, size = 40 },
        },
    }
    mid.update({ pt(1, 40, 20, "down") })
    t.check(mid.pressed("l") and not mid.pressed("r"), "겹침 자리는 하나만")

    -- contains는 슬롭 포함
    t.check(pad.contains(330, 447) == true, "contains: 슬롭 포함")
    t.check(pad.contains(330, 460) == false, "contains: 슬롭 밖")

    pad.dispose()
    mid.dispose()
end

return M
