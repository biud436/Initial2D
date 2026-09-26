# input_test.rb : Input 모듈. 키 이름 해석(Symbol), 마우스 버튼 이름, 터치 빈 상태.
# 헤드리스라 실제 입력은 없다. 값의 형과 이름 해석 규칙을 본다.

T.run_case("input") do |t|
  t.check_eq(Input.key_down?(Keys::Z), false, "정수 키로 key_down?")
  t.check_eq(Input.key_down?(:z), false, "Symbol 키로 key_down? (:z)")
  t.check_eq(Input.key_press?(:space), false, "Symbol 키 (:space)")
  t.check_eq(Input.key_up?("escape"), false, "문자열 키 (\"escape\")")
  t.check_eq(Input.trigger?(:"0"), false, "숫자 Symbol 은 DIGIT 로 (:\"0\")")
  t.check_eq(Input.press?(:enter), false, "press? 별명")
  t.check_eq(Input.release?(:left), false, "release? 별명")
  t.check_eq(Input.any_key_down?, false, "any_key_down?")

  bad = false
  begin
    Input.key_down?(:no_such_key)
  rescue ArgumentError
    bad = true
  end
  t.check(bad, "모르는 키 이름은 ArgumentError")

  bad_type = false
  begin
    Input.key_down?(1.5.to_s.to_sym) # :"1.5" 는 Keys 에 없다
  rescue ArgumentError
    bad_type = true
  end
  t.check(bad_type, "이상한 Symbol 도 ArgumentError")

  t.check_type(Input.mouse_x, Float, "mouse_x 는 Float")
  t.check_type(Input.mouse_y, Float, "mouse_y 는 Float")
  t.check_eq(Input.mouse_down?(0), false, "정수 버튼")
  t.check_eq(Input.mouse_down?(:left), false, ":left")
  t.check_eq(Input.mouse_press?(:right), false, ":right")
  t.check_eq(Input.mouse_up?(:middle), false, ":middle")
  t.check_eq(Input.any_mouse_down?, false, "any_mouse_down?")

  Input.mouse_z = 1
  t.check_type(Input.mouse_z, Integer, "mouse_z 는 Integer")

  t.check_eq(Input.touch_count, 0, "헤드리스에는 손가락이 없다")
  t.check_eq(Input.touch(0), nil, "범위 밖 touch 는 nil")
  t.check_eq(Input.touches, [], "touches 는 빈 배열")
end
