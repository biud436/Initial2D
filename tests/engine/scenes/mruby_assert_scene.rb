# mruby 엔진 검증 씬 (픽셀 검증용, tests/run_engine_tests.py 가 구동)
# assert_scene.lua 를 한 줄씩 옮긴 것이다. 같은 그림을 그려야 하므로 러너는
# Lua 씬과 **같은 골든**(assert_scene_f35)에 견준다. 두 바인딩이 같은 엔진
# 호출로 이어진다는 증거다.

def init
  # [A] BMFont 텍스트: 단색 배경판 위에 흰 글리프 (hangul.fnt: lineHeight=32 -> scale=1)
  @backdrop = Sprite.load("./resources/tiles/tile1.png", "backdrop", 0, 0, 48, 48, 1)
  @backdrop.set_position(32, 150)
  @backdrop.scale = 8

  @font_ready = Graphics.prepare_font("./resources/fonts/hangul.fnt")
  puts "fontReady:#{@font_ready}"

  # [B] 프레임 애니메이션: tileset 상단 행 4프레임 (16x16, scale 4)
  @anim = Sprite.load("./resources/tiles/tileset16-8x13.png", "anim", 0, 0, 16, 16, 4)
  @anim.set_position(500, 200)
  @anim.scale = 4
  @anim.loop = true
  @anim.set_frames(0, 4)
  @anim.frame_delay = 60.0

  # [C] 회전: 45도 (원점 기준 회전)
  @rot = Sprite.load("./resources/tiles/tile1.png", "rot", 0, 0, 48, 48, 1)
  @rot.set_position(600, 500)
  @rot.angle = 45.0

  # [D] 반투명: opacity 128
  @half = Sprite.load("./resources/tiles/tile1.png", "half", 0, 0, 48, 48, 1)
  @half.set_position(500, 700)
  @half.opacity = 128

  # [E] 오디오: BGM + SE
  Audio.play_music("./resources/audio/bless.ogg", "bgm", -1)
  Audio.play_sound("./resources/audio/bless.ogg", "se", 0)
  puts "volume:#{Audio.volume}"
end

def update(elapsed)
  @backdrop.update(0)
  @anim.update(elapsed)
  @rot.update(0)
  @half.update(0)

  # [F] 입력 API 호출 검증 (크래시 없이 동작해야 함)
  _dummy = Input.key_down?(:z) || Input.any_key_down? || Input.mouse_press?(:left)
  _mx = Input.mouse_x
  _my = Input.mouse_y
end

def render
  @backdrop.draw
  @anim.draw
  @rot.draw
  @half.draw

  Graphics.draw_text(60, 180, "한글 폰트 렌더링") if @font_ready

  # [G] 프리미티브: 빨간 점 블록
  Graphics.set_color(255, 0, 0, 255)
  8.times do |i|
    8.times do |j|
      Graphics.draw_point(700 + i, 60 + j)
    end
  end
end

def destroy
end
