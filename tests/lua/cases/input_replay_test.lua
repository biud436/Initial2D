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

    -- ---- 대화형 예약 (8단계: 화면을 보고 다음 입력을 정하는 시나리오) ------
    local live = require("scripts/luatests/input_replay").new({})
    local Z = 90

    live:tap("Z")
    live:tick()
    t.check(live.api.IsKeyDown(Z), "tap: 다음 tick에 눌린다")
    live:tick()
    t.check(live.api.IsKeyUp(Z), "tap: 그 다음 tick에 떼어진다")
    live:tick()
    t.check(not live.api.IsKeyDown(Z) and not live.api.IsKeyPress(Z), "tap: 한 tick뿐")

    live:press("LEFT")
    live:tick()
    t.check(live.api.IsKeyDown(37), "press: 눌리기 시작")
    live:tick()
    live:tick()
    t.check(live.api.IsKeyPress(37), "press: 뗄 때까지 눌린 채로 남는다")
    live:release("LEFT")
    live:tick()
    t.check(live.api.IsKeyUp(37), "release: 떼어진다")

    live:schedule({ press = "SPACE" }, 3)
    live:tick(); live:tick()
    t.check(not live.api.IsKeyDown(32), "schedule: 아직 아니다")
    live:tick()
    t.check(live.api.IsKeyDown(32), "schedule: 지정한 tick 뒤에 들어온다")

    -- install/restore가 전역 Input을 교체하고 복구하는지
    local original = _G.Input
    r:install()
    t.check(_G.Input == r.api, "install: 전역 Input 교체")
    r:restore()
    t.check(_G.Input == original, "restore: 전역 Input 복구")

    -- 멀티터치 재생 (T1): down → press → up 한 틱 → 사라짐
    local tr = replay.new({})
    t.check_eq(tr.api.GetTouchCount(), 0, "터치: 처음엔 없다")
    tr:schedule({ touchdown = { id = 1, x = 80, y = 360 } }, 1)
    tr:tick()
    t.check_eq(tr.api.GetTouchCount(), 1, "터치: 손가락 하나")
    local id, x, y, phase = tr.api.GetTouch(1)
    t.check(id == 1 and x == 80 and y == 360 and phase == "down",
        "터치: 첫 틱은 down", tostring(phase))
    tr:tick()
    local _, _, _, p2 = tr.api.GetTouch(1)
    t.check_eq(p2, "press", "터치: 다음 틱은 press")

    -- 두 번째 손가락과 끌기
    tr:schedule({ touchdown = { id = 2, x = 300, y = 400 } }, 1)
    tr:schedule({ touchmove = { id = 1, x = 120, y = 360 } }, 1)
    tr:tick()
    t.check_eq(tr.api.GetTouchCount(), 2, "터치: 두 손가락")
    local i1, x1 = tr.api.GetTouch(1)
    local i2, _, _, ph2 = tr.api.GetTouch(2)
    t.check(i1 == 1 and x1 == 120, "터치: 끌기가 좌표를 옮긴다", tostring(x1))
    t.check(i2 == 2 and ph2 == "down", "터치: 새 손가락은 down")

    -- 뗌: up으로 한 틱 보이고 사라진다
    tr:schedule({ touchup = { id = 1 } }, 1)
    tr:tick()
    local u1, _, _, up1 = tr.api.GetTouch(1)
    t.check(u1 == 1 and up1 == "up", "터치: 뗀 틱은 up", tostring(up1))
    tr:tick()
    t.check_eq(tr.api.GetTouchCount(), 1, "터치: up 다음 틱에 사라진다")
    local only = tr.api.GetTouch(1)
    t.check_eq(only, 2, "터치: 남은 것은 손가락 2")
end

return M
