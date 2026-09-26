# touch_test.rb : 포인터 통합(scripts/ruby/ui/touch.rb) 검증 (T1). touch_test.lua 의 Ruby 판.
#
# 터치 API가 있으면 손가락들을, 없으면 마우스를 포인터 목록으로 만든다.
# 가짜 Input 표면으로 두 경우를 다 검증한다.

require "scripts/ruby/ui/touch"

T.run_case("touch") do |t|
  # 마우스만 있는 가짜 Input (Ruby Input 표면의 마우스 부분)
  mouse_input = lambda do |down, press, up, x, y|
    o = Object.new
    o.define_singleton_method(:mouse_down?) { |btn| btn == 0 && down }
    o.define_singleton_method(:mouse_press?) { |btn| btn == 0 && press }
    o.define_singleton_method(:mouse_up?) { |btn| btn == 0 && up }
    o.define_singleton_method(:mouse_x) { x }
    o.define_singleton_method(:mouse_y) { y }
    o
  end

  touch = Ui::Touch
  t.check(touch.respond_to?(:pointers), "Touch.pointers 존재")

  # 터치 API 없는 표면 (테스트의 가짜 Input, 옛 빌드): 마우스만
  ps = touch.pointers(mouse_input.call(true, false, false, 10, 20))
  t.check_eq(ps.size, 1, "마우스만: 포인터 하나")
  t.check(ps[0][:id] == :mouse && ps[0][:x] == 10 && ps[0][:y] == 20, "마우스 좌표")
  t.check(ps[0][:down] && ps[0][:held] && !ps[0][:up], "마우스 down 틱")

  ps = touch.pointers(mouse_input.call(false, true, false, 10, 20))
  t.check(!ps[0][:down] && ps[0][:held], "마우스 press 틱")

  ps = touch.pointers(mouse_input.call(false, false, true, 10, 20))
  t.check(ps[0][:up] && !ps[0][:held], "마우스 up 틱")

  ps = touch.pointers(mouse_input.call(false, false, false, 10, 20))
  t.check_eq(ps.size, 0, "안 눌렸으면 포인터 없음")

  # 터치 API 있는 표면: 손가락들 + 마우스 합집합
  input = mouse_input.call(true, false, false, 10, 20)
  touches = [
    [7, 100, 200, :down],
    [8, 300, 400, :press],
    [9, 500, 600, :up],
  ]
  input.define_singleton_method(:touch_count) { touches.size }
  input.define_singleton_method(:touch) { |i| touches[i] } # 0 부터, 범위 밖은 nil

  ps = touch.pointers(input)
  t.check_eq(ps.size, 4, "손가락 셋과 마우스")
  t.check(ps[0][:id] == 7 && ps[0][:down] && ps[0][:held] && !ps[0][:up],
          "손가락 down: down이고 held")
  t.check(ps[1][:id] == 8 && !ps[1][:down] && ps[1][:held], "손가락 press: held만")
  t.check(ps[2][:id] == 9 && ps[2][:up] && !ps[2][:held], "손가락 up: held 아님")
  t.check_eq(ps[3][:id], :mouse, "마우스가 마지막에 온다")

  # Ruby 판 추가: 손가락 좌표가 그대로 옮겨지고, 범위 밖 touch(i) 의 nil 은 건너뛴다
  t.check(ps[1][:x] == 300 && ps[1][:y] == 400, "손가락 좌표")
  input.define_singleton_method(:touch_count) { touches.size + 1 }
  ps = touch.pointers(input)
  t.check_eq(ps.size, 4, "nil 인 touch(i) 는 건너뛴다")

  # Ruby 판 추가: 엔진 Input 자체도 받는다 (헤드리스라 손가락과 마우스가 없다)
  t.check_eq(touch.pointers(Input), [], "엔진 Input: 헤드리스는 빈 목록")
end
