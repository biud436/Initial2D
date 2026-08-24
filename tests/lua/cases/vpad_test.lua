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

    -- 크기: 시트 원본(160px)보다 작게 만들어도 프레임 전체가 그려져야 한다.
    -- 엔진 Sprite는 스프라이트 크기를 소스 프레임 크기로 그대로 쓰므로, 표시
    -- 크기를 그대로 넘기면 시트의 일부만 잘려 나온다 (2026-08-16 Galaxy S24
    -- 실기에서 렌더 배율 2로 패드를 절반 크기로 만들었을 때 발견).
    local small = VirtualPad.new{ x = 10, y = 20, size = 80 }
    local rect = small.image.getRect()
    t.check_eq(rect.x, 0, "0번 프레임의 소스 x")
    t.check_eq(rect.y, 0, "0번 프레임의 소스 y")
    t.check_eq(small.image.getWidth(), 160, "소스 프레임 폭은 시트 원본 크기")
    t.check_eq(small.image.getHeight(), 160, "소스 프레임 높이는 시트 원본 크기")
    t.check_eq(small.scale, 0.5, "표시 크기는 스케일로 맞춘다")

    -- 방향 프레임도 시트 원본 격자로 잘린다 (5x1의 두 번째 칸 = x 160)
    small.image.setCurrentFrame(1)
    t.check_eq(small.image.getRect().x, 160, "위 방향 프레임의 소스 x")

    -- 히트 판정은 표시 크기 기준이다 (중심에서 반경 밖은 nil)
    t.check_eq(small.hitTest(10 + 40, 20 + 40), nil, "표시 크기 중심은 데드존")
    t.check_eq(small.hitTest(10 + 40, 20 + 10), "up", "표시 크기 기준 위쪽")
    t.check_eq(small.hitTest(10 + 40, 20 + 200), nil, "표시 크기 밖은 nil")
    small.dispose()

    -- 표시 규칙: 데스크톱에서는 기본 숨김, INITIAL2D_VPAD가 있으면 표시
    if p ~= "android" and p ~= "ios" then
        local forced = os.getenv("INITIAL2D_VPAD") ~= nil
        t.check_eq(VirtualPad.shouldShow(), forced, "데스크톱: 환경 변수 없이는 숨김")
    else
        t.check_eq(VirtualPad.shouldShow(), true, "터치 플랫폼: 표시")
    end

    -- ---- 조이스틱 소유권 (T1) -------------------------------------------------
    -- update(pointers)로 포인터 목록을 직접 넣어 검증한다.
    -- 패드: (10, 20) 크기 80 → 중심 (50, 60), 반경 38.4, 데드존 8

    local pad = VirtualPad.new{ x = 10, y = 20, size = 80 }
    local function pt(id, x, y, phase)
        return { id = id, x = x, y = y,
            down = phase == "down", held = phase ~= "up", up = phase == "up" }
    end

    -- 잡기: 패드 안에서 눌린 포인터
    pad.update({ pt(1, 70, 60, "down") })
    t.check_eq(pad.pressed(), "right", "잡기: 안에서 눌리면 방향")

    -- 조이스틱: 잡힌 동안 원 밖으로 끌어도 유지된다
    pad.update({ pt(1, 300, 60, "press") })
    t.check_eq(pad.pressed(), "right", "끌기: 반경 밖에서도 방향 유지")
    pad.update({ pt(1, 50, -100, "press") })
    t.check_eq(pad.pressed(), "up", "끌기: 방향은 계속 따라간다")

    -- 두 번째 손가락은 소유권을 뺏지 못한다
    pad.update({ pt(1, 70, 60, "press"), pt(2, 30, 60, "down") })
    t.check_eq(pad.pressed(), "right", "소유권: 두 번째 손가락 무시")

    -- 놓기: up이면 풀린다
    pad.update({ pt(1, 70, 60, "up") })
    t.check_eq(pad.pressed(), nil, "놓기: up이면 nil")

    -- 놓은 뒤에는 다른 포인터가 잡을 수 있다
    pad.update({ pt(2, 30, 60, "down") })
    t.check_eq(pad.pressed(), "left", "다시 잡기: 새 포인터")
    pad.update({})
    t.check_eq(pad.pressed(), nil, "포인터가 사라지면 풀린다")

    -- 밖에서 눌린 포인터는 잡히지 않는다 (밖에서 눌러 안으로 끌어도 무시)
    pad.update({ pt(3, 200, 60, "down") })
    t.check_eq(pad.pressed(), nil, "밖에서 누르면 무시")
    pad.update({ pt(3, 70, 60, "press") })
    t.check_eq(pad.pressed(), nil, "밖에서 눌러 안으로 끌어도 무시")
    pad.dispose()

    -- 마우스 폴백: 터치 API가 없는 표면(가짜 Input)에서는 마우스가 포인터가 된다
    local fake = { mx = 70, my = 60 }
    local fakeDown, fakePress, fakeUp = true, false, false
    fake.IsMouseDown = function(btn) return btn == 0 and fakeDown end
    fake.IsMousePress = function(btn) return btn == 0 and fakePress end
    fake.IsMouseUp = function(btn) return btn == 0 and fakeUp end
    fake.GetMouseX = function() return fake.mx end
    fake.GetMouseY = function() return fake.my end
    local mpad = VirtualPad.new{ x = 10, y = 20, size = 80, input = fake }
    mpad.update()
    t.check_eq(mpad.pressed(), "right", "마우스 폴백: down에 잡는다")
    fakeDown, fakePress = false, true
    fake.mx = 30
    mpad.update()
    t.check_eq(mpad.pressed(), "left", "마우스 폴백: 누른 채 이동")
    fakePress, fakeUp = false, true
    mpad.update()
    t.check_eq(mpad.pressed(), nil, "마우스 폴백: 떼면 풀린다")
    mpad.dispose()
end

return M
