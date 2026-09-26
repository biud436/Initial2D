# sprite_test.rb : Sprite 클래스. 시트 분할, 소스 사각형, 속성 왕복, dispose 와 GC.
# Lua 의 sprite_sheet_test.lua 에 대응한다.

T.run_case("sprite") do |t|
  t.check(TextureManager.load("./resources/tiles/tileset16-8x13.png", "test_sheet"), "테스트 텍스처 로드")
  t.check_eq(TextureManager.valid?("test_sheet"), true, "TextureManager.valid?")

  # 프레임 24x32, 최대 12 프레임
  sp = Sprite.new(0, 0, 24, 32, 12, "test_sheet")
  t.check_type(sp, Sprite, "Sprite.new 가 Sprite 를 돌려준다")
  t.check_eq(sp.disposed?, false, "만든 직후 disposed? 는 false")

  # 기본 4x4 분할: 프레임 5 = (열 1, 행 1)
  sp.current_frame = 5
  r = sp.rect
  t.check_type(r, Hash, "rect 는 Hash")
  t.check_eq(r[:x], 24, "기본 4x4: 프레임 5의 x")
  t.check_eq(r[:y], 32, "기본 4x4: 프레임 5의 y")
  t.check_eq(r[:width], 24, "rect[:width] 는 폭 (오른쪽 좌표가 아니다)")
  t.check_eq(r[:height], 32, "rect[:height] 는 높이")
  t.check_eq(r[:right], 48, "rect[:right] 는 오른쪽 좌표")
  t.check_eq(r[:bottom], 64, "rect[:bottom] 는 아래 좌표")

  # 3x4 분할 (R2K3 CharSet 규격): 프레임 4 = (열 1, 행 1)
  sp.set_sheet_grid(3, 4)
  sp.current_frame = 4
  r = sp.rect
  t.check_eq([r[:x], r[:y]], [24, 32], "3x4: 프레임 4의 (x, y)")
  sp.current_frame = 3
  r = sp.rect
  t.check_eq([r[:x], r[:y]], [0, 32], "3x4: 프레임 3은 둘째 행으로 접힌다")
  sp.set_sheet_grid(0, -1)
  t.check_eq(sp.rect[:y], 32, "0 이하의 분할 값은 무시")

  # 소스 사각형 직접 지정
  sp.set_rect(40, 8, 16, 8)
  r = sp.rect
  t.check_eq([r[:x], r[:y], r[:width], r[:height]], [40, 8, 16, 8], "set_rect(x, y, w, h)")
  t.check_eq([r[:right], r[:bottom]], [56, 16], "오른쪽/아래 = x + w, y + h")
  sp.set_rect(x: 96, y: 32, width: 8, height: 8)
  r = sp.rect
  t.check_eq([r[:x], r[:y]], [96, 32], "Hash 형태 set_rect")
  bad_args = false
  begin
    sp.set_rect(1, 2)
  rescue ArgumentError
    bad_args = true
  end
  t.check(bad_args, "set_rect 인자 수가 틀리면 ArgumentError")

  # 속성 왕복
  sp.set_position(12.5, 7)
  t.check_eq(sp.position, [12.5, 7.0], "set_position / position")
  sp.x = 3
  sp.y = 4
  t.check_eq([sp.x, sp.y], [3.0, 4.0], "x= / y=")
  sp.position = [8, 9]
  t.check_eq(sp.position, [8.0, 9.0], "position=")
  t.check_eq([sp.width, sp.height], [24, 32], "width / height")
  sp.scale = 2.5
  t.check_eq(sp.scale, 2.5, "scale")
  sp.angle = 90.0
  t.check((sp.angle - 90.0).abs < 0.01, "angle", sp.angle)
  t.check((sp.radians - 3.14159 / 2).abs < 0.01, "radians 는 angle 에서 온다", sp.radians)
  sp.opacity = 128
  t.check_eq(sp.opacity, 128, "opacity")
  sp.visible = false
  t.check_eq(sp.visible?, false, "visible")
  sp.visible = true
  sp.frame_delay = 60.0
  t.check_eq(sp.frame_delay, 60.0, "frame_delay")
  # 엔진의 setFrames 는 둘째 인자를 "끝의 다음"으로 받는다 (Sprite.cpp: endFrame = endNum - 1,
  # 최대 프레임 수로 클램프). Lua 의 flappy 가 3프레임 새에 setFrames(0, 3) 을 주는 이유다.
  sp.set_frames(1, 3)
  t.check_eq([sp.start_frame, sp.end_frame], [1, 2], "set_frames(first, last_exclusive) / start_frame / end_frame")
  sp.set_frames(0, 99)
  t.check_eq(sp.end_frame, 11, "끝은 최대 프레임 수(12)로 클램프된다")
  sp.loop = true
  sp.anim_complete = false
  t.check_eq(sp.anim_complete?, false, "anim_complete")
  sp.update(16.0)
  sp.draw
  t.check(true, "update / draw 호출")

  # dispose: 그 뒤의 사용은 RuntimeError
  sp.dispose
  t.check_eq(sp.disposed?, true, "dispose 뒤 disposed?")
  sp.dispose
  t.check(true, "두 번 dispose 해도 안전")
  after = false
  begin
    sp.draw
  rescue RuntimeError
    after = true
  end
  t.check(after, "dispose 뒤 draw 는 RuntimeError")

  # Sprite.load (프렐류드): 텍스처를 읽고 만든다
  loaded = Sprite.load("./resources/tiles/tile1.png", "test_tile1", 5, 6, 48, 48)
  t.check_type(loaded, Sprite, "Sprite.load 가 Sprite 를 돌려준다")
  t.check_eq(loaded.position, [5.0, 6.0], "Sprite.load 의 위치 인자")
  t.check_eq(TextureManager.valid?("test_tile1"), true, "Sprite.load 가 텍스처를 읽는다")
  load_fail = false
  begin
    Sprite.load("./resources/no_such.png", "nope", 0, 0, 1, 1)
  rescue RuntimeError
    load_fail = true
  end
  t.check(load_fail, "없는 그림은 RuntimeError")

  # GC 가 거두어도 죽지 않는다 (dfree 가 C++ Sprite 를 지운다)
  200.times { Sprite.new(0, 0, 8, 8, 1, "test_sheet") }
  GC.start if Object.const_defined?(:GC)
  t.check(true, "버려진 Sprite 200개를 GC 가 거둔다")

  TextureManager.remove("test_sheet")
  TextureManager.remove("test_tile1")
  t.check_eq(TextureManager.valid?("test_sheet"), false, "remove 뒤 valid? 는 false")
end
