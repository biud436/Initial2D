# graphics_test.rb : Graphics 모듈. 폰트 로드, 글자 폭, 창 크기, 렌더 배율.
# Lua 의 font_text_test.lua 와 resolution 검증에 대응한다.

T.run_case("graphics") do |t|
  t.check(Graphics.width > 0 && Graphics.height > 0, "창 크기가 양수",
          "#{Graphics.width}x#{Graphics.height}")
  t.check_type(Graphics.frame_count, Integer, "frame_count 는 Integer")

  ok = Graphics.prepare_font("./resources/fonts/hangul.fnt")
  t.check_eq(ok, true, "hangul.fnt 로드")

  w1 = Graphics.text_width("안녕")
  w2 = Graphics.text_width("안녕하세요")
  t.check(w1 > 0, "한글 폭 측정이 양수", "w=#{w1}")
  t.check(w2 > w1, "긴 문자열이 더 넓다", "#{w2} > #{w1}")

  # 글리프 테이블 경계 (font_text_test.lua 와 같은 근거)
  t.check(Graphics.text_width("가") > 0, "'가'(U+AC00, 첫 글리프) 폭")
  t.check(Graphics.text_width("힝") > 0, "'힝'(55197, 폰트의 마지막 글리프) 폭")
  t.check_eq(Graphics.text_width("힣"), 0, "'힣'(U+D7A3, 폰트에 없음) 폭은 0")
  t.check_eq(Graphics.text_width(""), 0, "빈 문자열 폭은 0")

  drawn = Graphics.draw_text(0, -100, "안녕")
  t.check_eq(drawn, w1, "text_width 와 draw_text 반환 폭 일치")

  # 렌더 배율: 창은 그대로, 논리 해상도만 1/n
  base_w = Graphics.width
  Graphics.render_scale = 2
  t.check_eq(Graphics.render_scale, 2, "render_scale= 반영")
  t.check_eq(Graphics.width, base_w / 2, "배율 2 에서 논리 폭은 절반")
  Graphics.render_scale = 0
  t.check_eq(Graphics.render_scale, 1, "배율 하한 클램프 (0 -> 1)")
  t.check_eq(Graphics.width, base_w, "배율을 되돌리면 원래 폭")

  # 프리미티브: 호출만 되면 된다 (픽셀은 mruby_assert_scene 이 본다)
  Graphics.set_color(255, 0, 0)
  Graphics.set_color(255, 0, 0, 255)
  Graphics.draw_point(1, 1)
  t.check(true, "set_color / draw_point 호출")
end
