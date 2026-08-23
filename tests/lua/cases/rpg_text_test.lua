-- rpg_text_test.lua : UTF-8 글자 분할과 자동 줄바꿈 검증 (scripts/rpg/text.lua)
--
-- 폭 측정을 주입받는 구조라 가짜 자로 잰다. 한글은 3바이트라 바이트 길이와
-- 글자 수가 다르고, 그 차이에서 나오는 실수를 여기서 잡는다.

local M = {}

-- 가짜 자: 한글은 20px, 그 밖의 글자는 10px
local function fakeMeasure(s)
	local w = 0
	for c in s:gmatch("[\0-\127\194-\244][\128-\191]*") do
		w = w + (#c > 1 and 20 or 10)
	end
	return w
end

local function join(lines)
	return table.concat(lines, "|")
end

function M.run(t)
	local Text = require("scripts/rpg/text")

	-- ---- [1] 글자 분할 ------------------------------------------------------
	t.check_eq(#Text.chars("가나다"), 3, "한글 3글자")
	t.check_eq(#("가나다"), 9, "같은 문자열의 바이트는 9 (분할이 필요한 이유)")
	t.check_eq(Text.length("가나다"), 3, "length는 글자 수")
	t.check_eq(Text.length("abc가나"), 5, "영문과 한글이 섞여도 글자 수")
	t.check_eq(Text.length(""), 0, "빈 문자열")
	local cs = Text.chars("a가!")
	t.check(cs[1] == "a" and cs[2] == "가" and cs[3] == "!", "글자 순서 유지")

	-- ---- [2] 앞에서 n글자 (타자 효과) ---------------------------------------
	t.check_eq(Text.sub("안녕하세요", 2), "안녕", "앞 2글자")
	t.check_eq(Text.sub("안녕하세요", 0), "", "0글자는 빈 문자열")
	t.check_eq(Text.sub("안녕하세요", 99), "안녕하세요", "글자 수보다 크면 전체")
	t.check_eq(Text.sub("abc", 2), "ab", "영문도 같다")

	-- ---- [3] 줄바꿈: 폭에 맞춰 끊는다 ---------------------------------------
	-- 한글 20px 기준, 폭 100이면 한 줄에 5글자
	local lines = Text.wrap("가나다라마바사아", 100, fakeMeasure)
	t.check_eq(#lines, 2, "8글자가 두 줄로")
	t.check_eq(lines[1], "가나다라마", "첫 줄은 5글자")
	t.check_eq(lines[2], "바사아", "나머지가 둘째 줄")

	-- 폭 안에 들어가면 그대로 한 줄
	lines = Text.wrap("가나다", 100, fakeMeasure)
	t.check_eq(#lines, 1, "짧은 문장은 한 줄")
	t.check_eq(lines[1], "가나다", "내용 그대로")

	-- ---- [4] 띄어쓰기에서 끊는다 --------------------------------------------
	-- "가나 다라마바" : 폭 100(5글자)이면 "가나"에서 끊어야 낱말이 안 잘린다
	lines = Text.wrap("가나 다라마바", 100, fakeMeasure)
	t.check_eq(#lines, 2, "두 줄")
	t.check_eq(lines[1], "가나", "띄어쓰기에서 끊는다")
	t.check_eq(lines[2], "다라마바", "다음 줄의 앞 공백은 버린다")

	-- 낱말 하나가 폭보다 길면 글자에서 끊는다
	lines = Text.wrap("가나다라마바사", 60, fakeMeasure)
	t.check_eq(lines[1], "가나다", "낱말이 길면 글자에서 끊는다")
	t.check(#lines >= 3, "계속 끊어 나간다", tostring(#lines))

	-- 모든 줄이 폭을 넘지 않는다 (계약)
	local long = "어서 오시게. 처음 보는 얼굴이군. 천천히 둘러보다 가시게나."
	lines = Text.wrap(long, 200, fakeMeasure)
	local over = 0
	for _, line in ipairs(lines) do
		if fakeMeasure(line) > 200 then over = over + 1 end
	end
	t.check_eq(over, 0, "모든 줄이 폭 안에 들어간다")
	t.check(#lines > 1, "긴 문장은 여러 줄", tostring(#lines))

	-- 나눈 줄을 이으면 원문의 글자가 보존된다 (공백 제외)
	local function squeeze(s) return (s:gsub("%s", "")) end
	t.check_eq(squeeze(table.concat(lines)), squeeze(long), "글자가 사라지지 않는다")

	-- ---- [5] 개행 유지 ------------------------------------------------------
	lines = Text.wrap("가나\n다라", 100, fakeMeasure)
	t.check_eq(join(lines), "가나|다라", "원문 개행은 그대로 나뉜다")
	lines = Text.wrap("가나\n\n다라", 100, fakeMeasure)
	t.check_eq(join(lines), "가나||다라", "빈 줄도 유지된다")

	-- ---- [6] 경계 ------------------------------------------------------------
	t.check_eq(join(Text.wrap("", 100, fakeMeasure)), "", "빈 문자열은 빈 줄 하나")
	lines = Text.wrap("가나다", 0, fakeMeasure)
	t.check_eq(lines[1], "가나다", "폭 0이면 나누지 않는다 (무한 루프 방지)")
	t.check(pcall(Text.wrap, "가", 100) == false, "측정 함수 없이 부르면 오류")

	-- 한 글자가 폭보다 넓어도 그 글자는 남는다 (빈 줄이 무한히 생기지 않는다)
	lines = Text.wrap("가나", 5, fakeMeasure)
	t.check_eq(#lines, 2, "한 글자씩 나뉜다")
	t.check_eq(lines[1], "가", "첫 글자")

	-- 한글 조사 고르기 (받침이 있으면 앞엣것)
	t.check_eq(Text.particle("폭주", "을", "를"), "를", "받침 없는 말")
	t.check_eq(Text.particle("도약", "을", "를"), "을", "받침 있는 말")
	t.check_eq(Text.particle("검기 방출", "을", "를"), "을", "마지막 글자로 고른다")
	t.check_eq(Text.particle("Karto", "을", "를"), "를", "한글이 아니면 뒤엣것")
	t.check_eq(Text.particle("", "을", "를"), "를", "빈 문자열도 죽지 않는다")
	t.check_eq(Text.with("도약", "을", "를"), "도약을", "붙여서 돌려준다")
	t.check_eq(Text.with("폭주", "이", "가"), "폭주가", "다른 조사 짝도 된다")
end

return M
