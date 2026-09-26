# rpg_text_test.rb : UTF-8 글자 분할과 자동 줄바꿈 검증 (scripts/ruby/rpg/text.rb)
# rpg_text_test.lua 의 Ruby 판.
#
# 폭 측정을 주입받는 구조라 가짜 자로 잰다. 한글은 3바이트라 바이트 길이와
# 글자 수가 다르고, 그 차이에서 나오는 실수를 여기서 잡는다.

require "scripts/ruby/rpg/text"

T.run_case("rpg_text") do |t|
  text = Rpg::Text

  # 가짜 자: 한글은 20px, 그 밖의 글자는 10px
  fake_measure = lambda do |s|
    w = 0
    s.chars.each { |ch| w += ch.bytesize > 1 ? 20 : 10 }
    w
  end

  join = lambda { |lines| lines.join("|") }

  # ---- [1] 글자 분할 ------------------------------------------------------
  t.check_eq(text.chars("가나다").size, 3, "한글 3글자")
  t.check_eq("가나다".bytesize, 9, "같은 문자열의 바이트는 9 (분할이 필요한 이유)")
  t.check_eq(text.length("가나다"), 3, "length는 글자 수")
  t.check_eq(text.length("abc가나"), 5, "영문과 한글이 섞여도 글자 수")
  t.check_eq(text.length(""), 0, "빈 문자열")
  cs = text.chars("a가!")
  t.check(cs[0] == "a" && cs[1] == "가" && cs[2] == "!", "글자 순서 유지")

  # ---- [2] 앞에서 n글자 (타자 효과) ---------------------------------------
  t.check_eq(text.sub("안녕하세요", 2), "안녕", "앞 2글자")
  t.check_eq(text.sub("안녕하세요", 0), "", "0글자는 빈 문자열")
  t.check_eq(text.sub("안녕하세요", 99), "안녕하세요", "글자 수보다 크면 전체")
  t.check_eq(text.sub("abc", 2), "ab", "영문도 같다")
  # Ruby 판에서 더한 검사: 타자 효과는 실수 글자 수를 넘긴다 (Lua 판은 n 이하까지 담는다)
  t.check_eq(text.sub("안녕하세요", 2.5), "안녕", "실수 글자 수는 내림")

  # ---- [3] 줄바꿈: 폭에 맞춰 끊는다 ---------------------------------------
  # 한글 20px 기준, 폭 100이면 한 줄에 5글자
  lines = text.wrap("가나다라마바사아", 100, fake_measure)
  t.check_eq(lines.size, 2, "8글자가 두 줄로")
  t.check_eq(lines[0], "가나다라마", "첫 줄은 5글자")
  t.check_eq(lines[1], "바사아", "나머지가 둘째 줄")

  # 폭 안에 들어가면 그대로 한 줄
  lines = text.wrap("가나다", 100, fake_measure)
  t.check_eq(lines.size, 1, "짧은 문장은 한 줄")
  t.check_eq(lines[0], "가나다", "내용 그대로")

  # ---- [4] 띄어쓰기에서 끊는다 --------------------------------------------
  # "가나 다라마바" : 폭 100(5글자)이면 "가나"에서 끊어야 낱말이 안 잘린다
  lines = text.wrap("가나 다라마바", 100, fake_measure)
  t.check_eq(lines.size, 2, "두 줄")
  t.check_eq(lines[0], "가나", "띄어쓰기에서 끊는다")
  t.check_eq(lines[1], "다라마바", "다음 줄의 앞 공백은 버린다")

  # 낱말 하나가 폭보다 길면 글자에서 끊는다
  lines = text.wrap("가나다라마바사", 60, fake_measure)
  t.check_eq(lines[0], "가나다", "낱말이 길면 글자에서 끊는다")
  t.check(lines.size >= 3, "계속 끊어 나간다", lines.size.to_s)

  # 모든 줄이 폭을 넘지 않는다 (계약)
  long = "어서 오시게. 처음 보는 얼굴이군. 천천히 둘러보다 가시게나."
  lines = text.wrap(long, 200, fake_measure)
  over = 0
  lines.each do |line|
    over += 1 if fake_measure.call(line) > 200
  end
  t.check_eq(over, 0, "모든 줄이 폭 안에 들어간다")
  t.check(lines.size > 1, "긴 문장은 여러 줄", lines.size.to_s)

  # 나눈 줄을 이으면 원문의 글자가 보존된다 (공백 제외)
  spaces = [" ", "\t", "\n", "\r", "\v", "\f"]
  squeeze = lambda { |s| s.chars.reject { |ch| spaces.include?(ch) }.join }
  t.check_eq(squeeze.call(lines.join), squeeze.call(long), "글자가 사라지지 않는다")

  # Ruby 판에서 더한 검사: Lua 판과 같은 곳에서 끊는다 (Lua 판의 결과를 그대로 적었다)
  t.check_eq(join.call(lines), "어서 오시게. 처음|보는 얼굴이군.|천천히 둘러보다|가시게나.",
             "Lua 판과 같은 줄바꿈: 긴 문장")
  t.check_eq(join.call(text.wrap("ab cd ef gh", 50, fake_measure)), "ab|cd|ef gh",
             "Lua 판과 같은 줄바꿈: 영문")
  t.check_eq(join.call(text.wrap("a  b   c d", 30, fake_measure)), "a |b |c d",
             "Lua 판과 같은 줄바꿈: 겹친 공백")
  t.check_eq(join.call(text.wrap("가나 다라 마바사아자차카 타 ", 80, fake_measure)),
             "가나|다라|마바사아|자차카|타 ", "Lua 판과 같은 줄바꿈: 긴 낱말과 끝 공백")
  t.check_eq(join.call(text.wrap(" 가 나 다  라마바사 ", 60, fake_measure)),
             " 가|나 다|라마바|사 ", "Lua 판과 같은 줄바꿈: 앞 공백")

  # ---- [5] 개행 유지 ------------------------------------------------------
  lines = text.wrap("가나\n다라", 100, fake_measure)
  t.check_eq(join.call(lines), "가나|다라", "원문 개행은 그대로 나뉜다")
  lines = text.wrap("가나\n\n다라", 100, fake_measure)
  t.check_eq(join.call(lines), "가나||다라", "빈 줄도 유지된다")

  # ---- [6] 경계 ------------------------------------------------------------
  t.check_eq(join.call(text.wrap("", 100, fake_measure)), "", "빈 문자열은 빈 줄 하나")
  t.check_eq(text.wrap("", 100, fake_measure).size, 1, "빈 문자열의 줄 수는 1")
  lines = text.wrap("가나다", 0, fake_measure)
  t.check_eq(lines[0], "가나다", "폭 0이면 나누지 않는다 (무한 루프 방지)")
  no_measure = begin
    text.wrap("가", 100, nil)
    false
  rescue ArgumentError
    true
  end
  t.check(no_measure, "측정 함수 없이 부르면 오류")
  not_callable = begin
    text.wrap("가", 100, 42)
    false
  rescue ArgumentError
    true
  end
  t.check(not_callable, "부를 수 없는 측정 값도 오류")

  # 한 글자가 폭보다 넓어도 그 글자는 남는다 (빈 줄이 무한히 생기지 않는다)
  lines = text.wrap("가나", 5, fake_measure)
  t.check_eq(lines.size, 2, "한 글자씩 나뉜다")
  t.check_eq(lines[0], "가", "첫 글자")

  # 한글 조사 고르기 (받침이 있으면 앞엣것)
  t.check_eq(text.particle("폭주", "을", "를"), "를", "받침 없는 말")
  t.check_eq(text.particle("도약", "을", "를"), "을", "받침 있는 말")
  t.check_eq(text.particle("검기 방출", "을", "를"), "을", "마지막 글자로 고른다")
  t.check_eq(text.particle("Karto", "을", "를"), "를", "한글이 아니면 뒤엣것")
  t.check_eq(text.particle("", "을", "를"), "를", "빈 문자열도 죽지 않는다")
  t.check_eq(text.with("도약", "을", "를"), "도약을", "붙여서 돌려준다")
  t.check_eq(text.with("폭주", "이", "가"), "폭주가", "다른 조사 짝도 된다")
end
