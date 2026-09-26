# window.rb : 스킨 창 (docs/plans/07-rpg-dialogue.md)
#
# RPG Maker 2003의 System 스킨(160x80 한 장)을 나인 슬라이스로 잘라 창을 조립한다.
# 조각 하나는 엔진의 Sprite#set_rect로 그리고, 어느 조각을 어디에 몇 번 그릴지는
# 이 모듈이 정한다.
#
# 엔진 제약 두 가지:
#   1. 스프라이트 스케일은 가로세로 같은 값 하나뿐이다. 그래서 변과 바탕은 늘이지 않고
#      반복해 채운다.
#   2. 소스 사각형의 크기는 스프라이트를 만들 때 고정된다. 그래서 자투리(반복하다 남는
#      부분)는 그 크기의 스프라이트를 따로 만들며, Skin이 크기별로 캐시한다.
#
# 좌표 단위: 조각 계산(Window.nine_patch, Window.slices)은 전부 스킨 픽셀이고, 화면에
# 그릴 때 scale을 곱한다. 창의 width/height는 화면 픽셀이며 scale의 배수로 내림한다.
#
# 구성: 스킨은 Rpg::Skin이고, 순수 기하 함수는 Rpg::Window의 클래스 메서드다. rect와
# content_rect는 배열 [x, y, w, h]를 돌려주고, 조각과 규격 사각형은 Symbol 키 Hash다.
#
# 사용:
#   require "scripts/ruby/rpg/window"
#   skin = Rpg::Skin.new(path: "./resources/ui/window.png", scale: 1)
#   win = Rpg::Window.new(skin: skin, x: 8, y: 300, width: 368, height: 76)
#   win.open ; win.update ; win.draw ; win.dispose

require "scripts/ruby/rpg/specs"
require "scripts/ruby/image"

module Rpg
  class Window
    OPEN_FRAMES = 4         # 열기와 닫기 애니메이션 길이 (프레임)
    BG_BANDS = 4            # 바탕을 세로로 몇 개의 띠로 나눠 채울지 (background_fill 참조)

    # ---- 순수 기하 ------------------------------------------------------------

    # 소스 사각형을 반복해 목표 영역을 채운다. 마지막 자투리는 소스를 잘라 쓴다.
    # out          조각을 담을 배열 { sx:, sy:, sw:, sh:, dx:, dy: }
    # dx,dy,dw,dh  채울 영역 (창 좌상단 기준 스킨 픽셀)
    # sx,sy,sw,sh  소스 사각형 (스킨 이미지 기준)
    def self.tile_fill(out, dx, dy, dw, dh, sx, sy, sw, sh)
      return out if dw <= 0 || dh <= 0 || sw <= 0 || sh <= 0

      y = 0
      while y < dh
        h = [sh, dh - y].min
        x = 0
        while x < dw
          w = [sw, dw - x].min
          out.push({ sx: sx, sy: sy, sw: w, sh: h, dx: dx + x, dy: dy + y })
          x += w
        end
        y += h
      end
      out
    end

    # 나인 슬라이스: 모서리 4개는 그대로, 변은 반복, 가운데는 fill_center일 때만.
    # rect    스킨 안의 32x32 블록 (background/frame/cursor 중 하나) { x:, y:, w:, h: }
    # corner  모서리 크기 (보통 8)
    # w,h     만들 크기 (스킨 픽셀)
    def self.nine_patch(out, rect, corner, w, h, fill_center)
      c = corner
      rx, ry, rw, rh = rect[:x], rect[:y], rect[:w], rect[:h]

      # 모서리 두 개가 겹칠 만큼 작으면 그리지 않는다 (열리는 중의 아주 얇은 창).
      return out if w < c * 2 || h < c * 2

      inner_w, inner_h = rw - c * 2, rh - c * 2   # 소스의 변 조각 크기
      mid_w, mid_h = w - c * 2, h - c * 2         # 목표의 변 길이

      # 모서리
      out.push({ sx: rx, sy: ry, sw: c, sh: c, dx: 0, dy: 0 })
      out.push({ sx: rx + rw - c, sy: ry, sw: c, sh: c, dx: w - c, dy: 0 })
      out.push({ sx: rx, sy: ry + rh - c, sw: c, sh: c, dx: 0, dy: h - c })
      out.push({ sx: rx + rw - c, sy: ry + rh - c, sw: c, sh: c,
                 dx: w - c, dy: h - c })

      # 위아래 변
      tile_fill(out, c, 0, mid_w, c, rx + c, ry, inner_w, c)
      tile_fill(out, c, h - c, mid_w, c, rx + c, ry + rh - c, inner_w, c)
      # 좌우 변
      tile_fill(out, 0, c, c, mid_h, rx, ry + c, c, inner_h)
      tile_fill(out, w - c, c, c, mid_h, rx + rw - c, ry + c, c, inner_h)

      if fill_center
        tile_fill(out, c, c, mid_w, mid_h, rx + c, ry + c, inner_w, inner_h)
      end

      out
    end

    # 창 바탕. 스프라이트를 늘일 수 없으므로 바탕을 가로 띠 bands개로 나누고, 띠마다
    # 원본의 해당 부분을 반복해 채운다 (그라데이션이 끊기는 폭을 줄인다).
    def self.background_fill(out, w, h, spec, bands = nil)
      bg = spec[:background]
      bands ||= BG_BANDS
      bands = 1 if bands < 1 || bg[:h] % bands != 0
      band_h = bg[:h] / bands   # 정수 나눗셈

      top = 0
      (0..bands - 1).each do |i|
        bottom = (i == bands - 1) ? h : (h * (i + 1).to_f / bands).floor
        tile_fill(out, 0, top, w, bottom - top, bg[:x], bg[:y] + i * band_h, bg[:w], band_h)
        top = bottom
      end
      out
    end

    # 창 하나(바탕 + 테두리)의 조각 목록. 바탕은 창 전체를 덮는다 (테두리 안쪽이 반투명이다).
    def self.slices(w, h, spec = nil)
      spec ||= Specs::WINDOW
      out = []
      background_fill(out, w, h, spec)
      nine_patch(out, spec[:frame], spec[:frame_corner], w, h, false)
      out
    end

    # 선택 커서 조각 (가운데까지 채운다. 커서는 항목을 덮는 사각형이다).
    def self.cursor_slices(w, h, spec = nil, blink = false)
      spec ||= Specs::WINDOW
      rect = (blink && spec[:cursor2]) || spec[:cursor]
      nine_patch([], rect, spec[:cursor_corner] || spec[:frame_corner], w, h, true)
    end
  end

  # ---- 스킨 (엔진을 사용하는 부분) ------------------------------------------

  # 스킨 이미지 한 장과 크기별 스프라이트 캐시. 여러 창이 공유한다.
  class Skin
    attr_accessor :path, :spec, :scale, :image_factory, :texture_id, :cache, :opacity

    # path           스킨 이미지 경로
    # spec           규격 표 (기본 Specs::WINDOW)
    # scale          확대 배율 (기본 1)
    # image_factory  Image 생성 Proc (기본 Image::FACTORY, 테스트는 가짜를 넣는다)
    # texture_id     텍스처 id (기본 경로에서 만든다)
    def initialize(path: "./resources/ui/window.png", spec: nil, scale: 1, image_factory: nil,
                   texture_id: nil, opacity: 255)
      @path = path || "./resources/ui/window.png"
      @spec = spec || Specs::WINDOW
      @scale = scale || 1
      @image_factory = image_factory || Image::FACTORY
      @texture_id = texture_id || "winskin:#{@path}"
      @cache = {}     # "가로x세로" → Image (소스 크기별로 하나)
      @opacity = opacity || 255
    end

    # 소스 크기 (sw, sh)용 스프라이트. 엔진은 스프라이트 크기를 소스 사각형 크기로
    # 쓰므로 크기마다 하나씩 만들어 캐시한다.
    def image(sw, sh)
      key = "#{sw}x#{sh}"
      img = @cache[key]
      if img.nil?
        img = @image_factory.call(@path, 0, 0, sw, sh, 1, @texture_id)
        img.loop = false
        img.scale = @scale
        @cache[key] = img
      end
      img
    end

    # 조각 목록을 화면 (x, y)에 그린다. 조각 좌표는 스킨 픽셀이라 scale을 곱한다.
    def draw_pieces(pieces, x, y, opacity = nil)
      s = @scale
      pieces.each do |p|
        img = image(p[:sw], p[:sh])
        img.set_rect(p[:sx], p[:sy], p[:sw], p[:sh])
        img.set_position(x + p[:dx] * s, y + p[:dy] * s)
        img.opacity = opacity || @opacity
        img.update(0)
        img.draw
      end
    end

    # 스킨의 작은 조각 하나 (화살표 등)를 그대로 그린다.
    def draw_rect(rect, x, y, opacity = nil)
      img = image(rect[:w], rect[:h])
      img.set_rect(rect[:x], rect[:y], rect[:w], rect[:h])
      img.set_position(x, y)
      img.opacity = opacity || @opacity
      img.update(0)
      img.draw
    end

    # 선택 커서를 화면 사각형에 맞춰 그린다 (크기는 화면 픽셀).
    def draw_cursor(x, y, w, h, blink = false)
      s = @scale
      pieces = Window.cursor_slices((w.to_f / s).floor, (h.to_f / s).floor, @spec, blink)
      draw_pieces(pieces, x, y)
    end

    def dispose
      # 크기별 스프라이트는 텍스처 하나를 공유한다. 텍스처 해제(release)는 한 번만,
      # 나머지 스프라이트는 dispose로만 해제한다. 가짜 Image에 release가 없으면 dispose.
      imgs = @cache.values
      last = imgs.pop
      imgs.each { |img| img.dispose }
      unless last.nil?
        last.respond_to?(:release) ? last.release : last.dispose
      end
      @cache = {}
    end
  end

  # ---- 창 -------------------------------------------------------------------

  class Window
    attr_accessor :skin, :x, :y, :width, :height, :padding, :open_frames, :openness, :target, :visible

    # skin         Rpg::Skin (필수)
    # x, y         화면 좌상단 좌표
    # width, height  화면 픽셀 크기 (scale의 배수로 내림한다)
    # padding      안쪽 여백 (기본 모서리 크기 x 배율)
    # open_frames  열기와 닫기 프레임 수 (기본 4, 0이면 즉시)
    # open         true면 열린 채로 시작
    def initialize(skin:, x: 0, y: 0, width: 0, height: 0, padding: nil, open_frames: nil, open: false)
      raise ArgumentError, "window: skin이 필요하다" if skin.nil?

      @skin = skin
      s = @skin.scale
      @x = x || 0
      @y = y || 0
      # 화면 크기는 배율의 배수여야 스킨 픽셀로 되돌릴 때 어긋나지 않는다
      @width = [s * 2, ((width || 0).to_f / s).floor * s].max
      @height = [s * 2, ((height || 0).to_f / s).floor * s].max
      @padding = padding || (@skin.spec[:frame_corner] * s)
      @open_frames = open_frames || OPEN_FRAMES
      @openness = open ? 1 : 0
      @target = @openness
      @visible = true
    end

    def open
      @target = 1
      @openness = 1 if @open_frames <= 0
      self
    end

    def close
      @target = 0
      @openness = 0 if @open_frames <= 0
      self
    end

    # 완전히 열려 있는가 (내용은 이때만 그린다)
    def open?
      @openness >= 1
    end

    # 완전히 닫혔는가
    def closed?
      @openness <= 0
    end

    # 매 프레임 한 번. 열림 정도를 open_frames에 맞춰 한 단계 진행시킨다.
    def update
      if @open_frames <= 0
        @openness = @target
        return
      end
      step = 1.0 / @open_frames
      if @openness < @target
        @openness = [1, @openness + step].min
      elsif @openness > @target
        @openness = [0, @openness - step].max
      end
    end

    # 지금 프레임에 그릴 창의 화면 사각형 [x, y, w, h]. 열리는 중에는 세로 중앙에서 위아래로 커진다.
    def rect
      s = @skin.scale
      h = (@height * @openness.to_f / s).floor * s
      y = @y + ((@height - h).to_f / (2 * s)).floor * s
      [@x, y, @width, h]
    end

    # 내용(글자, 얼굴)을 그릴 안쪽 사각형 [x, y, w, h].
    def content_rect
      [@x + @padding, @y + @padding,
       @width - @padding * 2, @height - @padding * 2]
    end

    # 창틀만 그린다. 내용은 호출자가 content_rect에 그린다 (창은 내용에 관여하지 않는다).
    def draw
      return if !@visible || @openness <= 0
      s = @skin.scale
      x, y, w, h = rect
      pieces = Window.slices((w.to_f / s).floor, (h.to_f / s).floor, @skin.spec)
      @skin.draw_pieces(pieces, x, y)
    end

    def dispose
      # 스킨은 여러 창이 공유하므로 여기서 해제하지 않는다 (소유자가 해제한다).
      @skin = nil
    end
  end
end
