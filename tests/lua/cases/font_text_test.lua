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

    -- 커닝 블록이 없는 .fnt (BMFont 규격에서 선택 사항이며, 커닝 쌍이 없는
    -- 폰트에는 아예 없다). 파서가 널 검사 없이 참조해서 게임이 죽던 자리다
    -- (2026-08-17, tools/generate_bmfont.py로 만든 폰트를 열다가 발견).
    local minimal = [[<?xml version="1.0"?>
<font>
  <info face="t" size="8" bold="0" italic="0" charset="" unicode="1" stretchH="100" smooth="1" aa="1" padding="0,0,0,0" spacing="1,1" outline="0"/>
  <common lineHeight="8" base="7" scaleW="64" scaleH="64" pages="1" packed="0" alphaChnl="0" redChnl="0" greenChnl="0" blueChnl="0"/>
  <pages>
    <page id="0" file="hangul_0.png" />
  </pages>
  <chars count="1">
    <char id="65" x="0" y="0" width="4" height="6" xoffset="0" yoffset="1" xadvance="5" page="0" chnl="15" />
  </chars>
</font>
]]
    local f = assert(io.open("./no_kernings.fnt", "w"))
    f:write(minimal)
    f:close()
    t.check_eq(PreparaFont("./no_kernings.fnt"), true, "커닝 블록 없는 폰트도 열린다")
    t.check(GetTextWidth("A") > 0, "그 폰트로 폭 측정이 된다")

    -- 필수 블록이 빠진 파일은 죽지 않고 false를 돌려준다
    local broken = assert(io.open("./no_chars.fnt", "w"))
    broken:write(minimal:gsub('<chars count="1">.-</chars>', ""))
    broken:close()
    t.check_eq(PreparaFont("./no_chars.fnt"), false, "chars 없는 폰트는 거부한다")

    os.remove("./no_kernings.fnt")
    os.remove("./no_chars.fnt")

    -- 다음 케이스를 위해 원래 폰트로 되돌린다
    t.check_eq(PreparaFont("./resources/fonts/hangul.fnt"), true, "원래 폰트 복구")
end

return M
