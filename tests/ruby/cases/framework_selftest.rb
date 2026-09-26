# framework_selftest.rb : 테스트 프레임워크 자체가 동작하는지 확인한다.

T.run_case("framework_selftest") do |t|
  t.check(1 + 1 == 2, "check 가 참을 통과시킨다")
  t.check_eq("가" + "나", "가나", "check_eq 문자열 비교 (UTF-8)")
  t.check_type(:sym, Symbol, "check_type 클래스 판별")

  # 예외 집계 확인: 의도적 예외를 스스로 잡아 본다
  caught = false
  begin
    raise ArgumentError, "의도적 오류"
  rescue ArgumentError => e
    caught = e.message == "의도적 오류"
  end
  t.check(caught, "rescue 가 예외를 잡는다")
end
