# 기본 렌더링 검증 씬 (엔진 1) 의 Ruby 판. render_basics_scene.lua 와 같은 그림을 그리고
# 러너가 같은 검사와 같은 골든(render_basics)으로 확인한다.

TILE = "./resources/tiles/tile1.png" # 48x48 단색 (216, 145, 37)

def make_sprite(x, y, w, h, tex)
  s = Sprite.new(x, y, w, h, 1, tex)
  s.set_sheet_grid(1, 1)
  s.current_frame = 0
  s
end

def init
  TextureManager.load(TILE, "tile")
  tw, th = TextureManager.size("tile")
  puts "texsize:#{tw}x#{th}"
  puts "nosize:#{TextureManager.size("missing").inspect}"

  # 렌더 타깃: 32x16 투명 판 위에 왼쪽 빨강, 오른쪽 파랑
  puts "target:#{TextureManager.create_target("halves", 32, 16)}"
  puts "set:#{Graphics.set_render_target("halves")}"
  puts "current:#{Graphics.render_target}"
  Graphics.set_color(255, 0, 0, 255)
  Graphics.fill_rect(0, 0, 16, 16)
  Graphics.set_color(0, 0, 255, 255)
  Graphics.fill_rect(16, 0, 16, 16)
  Graphics.set_render_target(nil)
  puts "after:#{Graphics.render_target.inspect}"
  puts "notarget:#{Graphics.set_render_target("tile")}"
  tgw, tgh = TextureManager.size("halves")
  puts "targetsize:#{tgw}x#{tgh}"

  # [A] 색 입히기
  @tinted = make_sprite(32, 32, 48, 48, "tile")
  @tinted.set_color(255, 0, 0)
  puts "color:#{@tinted.color.join(",")}"

  # [B] 뒤집기
  @plain = make_sprite(32, 120, 32, 16, "halves")
  @plain.scale = 2
  @flipped = make_sprite(32, 170, 32, 16, "halves")
  @flipped.scale = 2
  @flipped.set_flip(true, false)
  puts "flip:#{@flipped.flip.join(",")}"

  # [C] 기준점과 회전
  @pivoted = make_sprite(400, 100, 48, 48, "tile")
  @pivoted.set_pivot(0.5, 0.5)
  @pivoted.angle = 45
  puts "pivot:#{@pivoted.pivot.join(",")}"

  # [D] 혼합 모드
  @added = make_sprite(500, 220, 48, 48, "tile")
  @added.blend_mode = :add
  @multiplied = make_sprite(600, 220, 48, 48, "tile")
  @multiplied.blend_mode = "multiply"
  puts "blend:#{@added.blend_mode},#{@multiplied.blend_mode},#{@tinted.blend_mode}"
  begin
    @added.blend_mode = :screen
    puts "badblend:true"
  rescue ArgumentError => e
    puts "badblend:false:#{e.message}"
  end

  # [E] 글자
  puts "fontReady:#{Graphics.prepare_font("./resources/fonts/hangul.fnt")}"
  puts "textsize:#{Graphics.text_size}"
  w32 = Graphics.text_width("가나다")
  Graphics.text_size = 64
  puts "textsize:#{Graphics.text_size}"
  w64 = Graphics.text_width("가나다")
  Graphics.text_size = 0
  puts "textwidth:#{w32}:#{w64}"

  @sprites = [@tinted, @plain, @flipped, @pivoted, @added, @multiplied]
  @sprites.each { |s| s.update(0) }
end

def update(elapsed)
  @sprites.each { |s| s.update(0) }
end

def render
  Graphics.set_color(100, 100, 100, 255)
  Graphics.fill_rect(490, 210, 180, 68)

  @sprites.each(&:draw)

  Graphics.set_text_color(255, 0, 0)
  Graphics.draw_text(32, 400, "가나다")
  Graphics.set_text_color(0, 0, 255, 255)
  Graphics.text_size = 64
  Graphics.draw_text(32, 460, "가나다")
  Graphics.text_size = 0
  Graphics.set_text_color(255, 255, 255)

  Graphics.set_color(0, 128, 0, 255)
  Graphics.fill_rect(600, 400, 64, 32)
  Graphics.draw_rect(600, 450, 64, 32)
  Graphics.draw_line(600, 500, 664, 500)
  Graphics.fill_circle(632, 580, 20)
  Graphics.draw_circle(712, 580, 20)
  Graphics.set_color(0, 0, 0, 128)
  Graphics.fill_rect(600, 640, 64, 32)

  # [G] 렌더 타깃을 그대로 두고 끝낸다
  Graphics.set_render_target("halves")
end

def destroy
end
