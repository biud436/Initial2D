-- vpad_test.lua : 가상 D-패드 모듈(scripts/ui/vpad.lua)의 순수 로직 검증
-- 방향 판정은 순수 함수라 엔진 입력 없이 검증한다. 화면 표시는 데모 씬에서 눈으로 확인.

local M = {}

function M.run(t)
    t.check_type(GetPlatform, "function", "GetPlatform 존재")
    local p = GetPlatform()
    t.check(type(p) == "string" and p == p:lower() and #p > 0, "GetPlatform은 소문자 문자열", tostring(p))

    local VirtualPad = require("scripts/ui/vpad")
    t.check_type(VirtualPad.new, "function", "VirtualPad.new 존재")
    t.check_type(VirtualPad.direction, "function", "VirtualPad.direction 존재")
    t.check_type(VirtualPad.shouldShow, "function", "VirtualPad.shouldShow 존재")

    local R, D = 76.8, 16   -- size 160 기준 반경과 데드존
    local dir = VirtualPad.direction

    -- 4방향 (y는 아래가 양수)
    t.check_eq(dir(0, -50, R, D), "up", "위")
    t.check_eq(dir(0, 50, R, D), "down", "아래")
    t.check_eq(dir(-50, 0, R, D), "left", "왼쪽")
    t.check_eq(dir(50, 0, R, D), "right", "오른쪽")

    -- 대각선 경계: |dx| > |dy| 이면 좌우, 아니면 상하
    t.check_eq(dir(40, -30, R, D), "right", "대각선 (dx 우세) → 오른쪽")
    t.check_eq(dir(30, -40, R, D), "up", "대각선 (dy 우세) → 위")
    t.check_eq(dir(-30, 30, R, D), "down", "정확한 대각선은 상하 우선")

    -- 데드존과 반경 밖
    t.check_eq(dir(5, 5, R, D), nil, "데드존 안은 nil")
    t.check_eq(dir(0, 0, R, D), nil, "중심은 nil")
    t.check_eq(dir(100, 0, R, D), nil, "반경 밖은 nil")
    t.check_eq(dir(0, -R, R, D), "up", "반경 경계(포함)는 방향")

    -- 표시 규칙: 데스크톱에서는 기본 숨김, INITIAL2D_VPAD가 있으면 표시
    if p ~= "android" and p ~= "ios" then
        local forced = os.getenv("INITIAL2D_VPAD") ~= nil
        t.check_eq(VirtualPad.shouldShow(), forced, "데스크톱: 환경 변수 없이는 숨김")
    else
        t.check_eq(VirtualPad.shouldShow(), true, "터치 플랫폼: 표시")
    end
end

return M
