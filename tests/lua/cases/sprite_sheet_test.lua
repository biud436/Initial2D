-- sprite_sheet_test.lua : Sprite.SetSheetGrid와 Dispose, GetRect 검증
-- (1단계, docs/plans/01-engine-core.md — R2K3 CharSet 3x4의 선행 조건)

local M = {}

function M.run(t)
    t.check(TextureManager.Load("./resources/tiles/tileset16-8x13.png", "test_sheet"),
        "테스트 텍스처 로드")

    -- 프레임 24x32, 최대 12프레임
    local sp = Sprite.Create(0, 0, 24, 32, 12, "test_sheet")
    t.check(sp ~= 0, "스프라이트 생성")

    -- 기본 4x4 분할: 프레임 5 = (열 1, 행 1)
    Sprite.SetCurrentFrame(sp, 5)
    local r = Sprite.GetRect(sp)
    t.check_type(r, "table", "GetRect가 테이블을 돌려준다 (settable 버그 수정 검증)")
    t.check_eq(r.x, 24, "기본 4x4: 프레임 5의 x")
    t.check_eq(r.y, 32, "기본 4x4: 프레임 5의 y")

    -- 3x4 분할 (R2K3 CharSet 규격): 프레임 4 = (열 1, 행 1)
    Sprite.SetSheetGrid(sp, 3, 4)
    Sprite.SetCurrentFrame(sp, 4)
    r = Sprite.GetRect(sp)
    t.check_eq(r.x, 24, "3x4: 프레임 4의 x")
    t.check_eq(r.y, 32, "3x4: 프레임 4의 y")

    -- 프레임 3은 3열 분할에서 둘째 행 첫 칸 (4열 분할이면 첫 행 넷째 칸이었을 것)
    Sprite.SetCurrentFrame(sp, 3)
    r = Sprite.GetRect(sp)
    t.check_eq(r.x, 0, "3x4: 프레임 3은 둘째 행으로 접힌다 (x)")
    t.check_eq(r.y, 32, "3x4: 프레임 3은 둘째 행으로 접힌다 (y)")

    -- 잘못된 분할 값은 무시된다
    Sprite.SetSheetGrid(sp, 0, -1)
    r = Sprite.GetRect(sp)
    t.check_eq(r.y, 32, "0 이하의 분할 값은 무시")

    -- 해제 (누수 방지 API)
    t.check_type(Sprite.Dispose, "function", "Dispose 바인딩 존재")
    Sprite.Dispose(sp)
    t.check(true, "Dispose 호출 후 정상 진행")

    TextureManager.Remove("test_sheet")
end

return M
