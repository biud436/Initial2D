-- input_replay_test.lua : 입력 시퀀스 재생기의 상태 전이 의미 검증.
-- 엔진의 4-상태 머신(KB_DOWN, KB_PRESS, KB_UP)과 동일해야 한다.

local replay = require("scripts/luatests/input_replay")

local M = {}

function M.run(t)
    local r = replay.new({
        { at = 2, mouse = { x = 100, y = 200 } },
        { at = 3, press = "SPACE" },
        { at = 5, release = "SPACE" },
        { at = 4, click = 0 },
        { at = 6, unclick = 0 },
        { at = 7, wheel = -1 },
    })
    local SPACE = replay.KEYS.SPACE

    t.check_eq(SPACE, 32, "키 이름 테이블 (SPACE=32)")
    t.check_eq(replay.KEYS.Z, 90, "키 이름 테이블 (Z=90)")

    -- 프레임 1: 아무 일 없음
    r:tick()
    t.check(not r.api.IsKeyDown(SPACE) and not r.api.IsKeyPress(SPACE)
        and not r.api.IsKeyUp(SPACE), "프레임 1: 입력 없음")

    -- 프레임 2: 마우스 이동
    r:tick()
    t.check_eq(r.api.GetMouseX(), 100, "프레임 2: 마우스 X")
    t.check_eq(r.api.GetMouseY(), 200, "프레임 2: 마우스 Y")

    -- 프레임 3: 스페이스 눌림 시작 → Down만 참
    r:tick()
    t.check(r.api.IsKeyDown(SPACE), "프레임 3: IsKeyDown (rising edge)")
    t.check(not r.api.IsKeyPress(SPACE), "프레임 3: IsKeyPress 아님")
    t.check(r.api.IsAnyKeyDown(), "프레임 3: IsAnyKeyDown")

    -- 프레임 4: 계속 눌림 → Press만 참. 마우스 클릭 시작
    r:tick()
    t.check(not r.api.IsKeyDown(SPACE), "프레임 4: IsKeyDown은 한 프레임만")
    t.check(r.api.IsKeyPress(SPACE), "프레임 4: IsKeyPress (held)")
    t.check(r.api.IsMouseDown(0), "프레임 4: IsMouseDown (rising edge)")

    -- 프레임 5: 떼어짐 → Up만 참. 마우스는 held
    r:tick()
    t.check(r.api.IsKeyUp(SPACE), "프레임 5: IsKeyUp (falling edge)")
    t.check(not r.api.IsKeyDown(SPACE) and not r.api.IsKeyPress(SPACE),
        "프레임 5: Down/Press 아님")
    t.check(r.api.IsMousePress(0), "프레임 5: IsMousePress (held)")

    -- 프레임 6: 전부 해제
    r:tick()
    t.check(not r.api.IsKeyUp(SPACE), "프레임 6: IsKeyUp도 한 프레임만")
    t.check(r.api.IsMouseUp(0), "프레임 6: IsMouseUp (falling edge)")
    t.check(not r:finished(), "프레임 6: 시나리오 아직 안 끝남")

    -- 프레임 7: 휠
    r:tick()
    t.check_eq(r.api.GetMouseZ(), -1, "프레임 7: 휠 값")
    t.check(r:finished(), "프레임 7: 시나리오 종료 판정")

    -- install/restore가 전역 Input을 교체하고 복구하는지
    local original = _G.Input
    r:install()
    t.check(_G.Input == r.api, "install: 전역 Input 교체")
    r:restore()
    t.check(_G.Input == original, "restore: 전역 Input 복구")
end

return M
