-- font_text_test.lua : 폰트 로드와 GetTextWidth 검증 (1단계, docs/plans/01-engine-core.md)
-- '힣'(U+D7A3)은 글리프 테이블 경계의 마지막 인덱스라 반드시 포함한다.

local M = {}

function M.run(t)
    local ok = PreparaFont("./resources/fonts/hangul.fnt")
    t.check(ok == true, "hangul.fnt 로드")

    t.check_type(GetTextWidth, "function", "GetTextWidth 바인딩 존재")

    local w1 = GetTextWidth("안녕")
    local w2 = GetTextWidth("안녕하세요")
    t.check(w1 > 0, "한글 폭 측정이 양수", "w=" .. tostring(w1))
    t.check(w2 > w1, "긴 문자열이 더 넓다", w2 .. " > " .. w1)

    -- 글리프 테이블 경계 검증.
    -- hangul.fnt(2453자)의 실측: 첫 글리프 '가'(U+AC00), 마지막 글리프 '힝'(55197).
    -- '힣'(U+D7A3 = 55203)은 이 폰트에 없지만 테이블의 마지막 인덱스라,
    -- "0을 반환하되 경계 밖을 읽지 않아야" 한다 (수정 전에는 배열 밖 읽기였음).
    t.check(GetTextWidth("가") > 0, "'가'(U+AC00, 첫 글리프) 폭")
    t.check(GetTextWidth("힝") > 0, "'힝'(55197, 폰트의 마지막 글리프) 폭")
    t.check_eq(GetTextWidth("힣"), 0, "'힣'(U+D7A3, 폰트에 없음) 폭은 0")
    t.check(GetTextWidth("가힣힝") > GetTextWidth("가힝") - 1,
        "없는 글리프가 섞여도 나머지는 정상 측정")

    t.check_eq(GetTextWidth(""), 0, "빈 문자열 폭은 0")

    -- 측정은 그리기와 같은 자로 재야 한다: DrawText의 반환 폭과 일치
    local drawn = DrawText(0, -100, "안녕")
    t.check_eq(w1, drawn, "GetTextWidth와 DrawText 반환 폭 일치")

    -- 개행: 두 줄 중 넓은 쪽이 전체 폭
    local wide = GetTextWidth("안녕하세요")
    local multi = GetTextWidth("안녕하세요\n가")
    t.check_eq(multi, wide, "개행 시 가장 넓은 줄의 폭")
end

return M
