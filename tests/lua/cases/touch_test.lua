-- touch_test.lua : 포인터 통합(scripts/ui/touch.lua) 검증 (T1)
--
-- 터치 API가 있으면 손가락들을, 없으면 마우스를 포인터 목록으로 만든다.
-- 가짜 Input 표면으로 두 경우를 다 검증한다.

local M = {}

local function mouseInput(down, press, up, x, y)
    return {
        IsMouseDown = function(btn) return btn == 0 and down end,
        IsMousePress = function(btn) return btn == 0 and press end,
        IsMouseUp = function(btn) return btn == 0 and up end,
        GetMouseX = function() return x end,
        GetMouseY = function() return y end,
    }
end

function M.run(t)
    local Touch = require("scripts/ui/touch")
    t.check_type(Touch.pointers, "function", "Touch.pointers 존재")

    -- 터치 API 없는 표면 (테스트의 가짜 Input, 옛 빌드): 마우스만
    local ps = Touch.pointers(mouseInput(true, false, false, 10, 20))
    t.check_eq(#ps, 1, "마우스만: 포인터 하나")
    t.check(ps[1].id == "mouse" and ps[1].x == 10 and ps[1].y == 20, "마우스 좌표")
    t.check(ps[1].down and ps[1].held and not ps[1].up, "마우스 down 틱")

    ps = Touch.pointers(mouseInput(false, true, false, 10, 20))
    t.check(not ps[1].down and ps[1].held, "마우스 press 틱")

    ps = Touch.pointers(mouseInput(false, false, true, 10, 20))
    t.check(ps[1].up and not ps[1].held, "마우스 up 틱")

    ps = Touch.pointers(mouseInput(false, false, false, 10, 20))
    t.check_eq(#ps, 0, "안 눌렸으면 포인터 없음")

    -- 터치 API 있는 표면: 손가락들 + 마우스 합집합
    local input = mouseInput(true, false, false, 10, 20)
    local touches = {
        { 7, 100, 200, "down" },
        { 8, 300, 400, "press" },
        { 9, 500, 600, "up" },
    }
    input.GetTouchCount = function() return #touches end
    input.GetTouch = function(i)
        local touch = touches[i]
        if touch == nil then return nil end
        return touch[1], touch[2], touch[3], touch[4]
    end

    ps = Touch.pointers(input)
    t.check_eq(#ps, 4, "손가락 셋과 마우스")
    t.check(ps[1].id == 7 and ps[1].down and ps[1].held and not ps[1].up,
        "손가락 down: down이고 held")
    t.check(ps[2].id == 8 and not ps[2].down and ps[2].held, "손가락 press: held만")
    t.check(ps[3].id == 9 and ps[3].up and not ps[3].held, "손가락 up: held 아님")
    t.check_eq(ps[4].id, "mouse", "마우스가 마지막에 온다")
end

return M
