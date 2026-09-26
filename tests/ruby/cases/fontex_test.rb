# fontex_test.rb : FontEx 클래스. 비-Windows 에서는 무동작 스텁이라 API 형태만 본다.

T.run_case("fontex") do |t|
  font = FontEx.new("나눔고딕", 32, 400, 440)
  t.check_type(font, FontEx, "FontEx.new")
  font.text = "2020년입니다"
  font.set_position(10, 20)
  font.set_text_color(255, 128, 0)
  font.opacity = 200
  font.angle = 15.0
  t.check_type(font.text_width("가나다"), Integer, "text_width 는 Integer")
  font.update(16.0)
  font.draw
  t.check(true, "속성 설정과 update / draw 호출")

  font.dispose
  t.check_eq(font.disposed?, true, "dispose 뒤 disposed?")
  after = false
  begin
    font.draw
  rescue RuntimeError
    after = true
  end
  t.check(after, "dispose 뒤 draw 는 RuntimeError")
end
