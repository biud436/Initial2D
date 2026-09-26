# vpad.rb : 가상 패드 (터치 조작, 범용 UI 모듈). scripts/lua/ui/vpad.lua 의 Ruby 판.
#
# 키보드가 없는 플랫폼(Android 등)에서 방향 입력을 화면 위 패드로 받는다.
# 포인터는 touch.rb 가 합쳐 준다: 엔진에 멀티터치 API가 있으면 손가락들을,
# 없으면(테스트의 가짜 Input) 마우스를 쓴다. 조이스틱처럼 동작한다 (T1):
# 패드 안에서 눌린 포인터를 잡고, 잡힌 동안에는 손가락이 원 밖으로
# 미끄러져도 방향을 유지한다. 놓아야 풀린다.
#
# 사용:
#   require "scripts/ruby/ui/vpad"
#   pad = Ui::VirtualPad.new(x: 24, y: h - 184, size: 160) if Ui::VirtualPad.should_show?
#   pad.update                         # 매 프레임, Input 갱신 뒤
#   if pad.pressed?(:left) then ... end   # :up, :down, :left, :right
#   pad.contains?(mx, my)              # 패드 위 터치인지 (게임 쪽 탭 처리에서 제외할 때)
#   pad.draw                           # HUD 위에 마지막으로 그린다
#   pad.dispose
#
# size는 표시 크기다. 시트 원본(160px)과 달라도 되며, 논리 해상도가 작은
# 화면(렌더 배율 사용)에서는 배율로 나눈 값을 넘기면 손가락 크기가 유지된다.
#
# 스프라이트 시트 resources/ui/dpad.png: 가로 5프레임 (기본, 위, 오른쪽, 아래, 왼쪽)

require "scripts/ruby/image"
require "scripts/ruby/ui/touch"

module Ui
  class VirtualPad
    FRAME_OF = { up: 1, right: 2, down: 3, left: 4 }

    # 시트의 한 프레임 크기 (tools/generate_ui_assets.py의 make_dpad와 같은 값).
    # 엔진의 Sprite는 스프라이트 크기를 그대로 소스 프레임 크기로 쓰므로, 원하는
    # 표시 크기를 그냥 넘기면 프레임의 일부만 잘려 그려진다. 스프라이트는 원본
    # 크기로 만들고 표시 크기는 스케일로 맞춘다.
    FRAME_SIZE = 160

    # 표시 여부: 터치 플랫폼이거나 INITIAL2D_VPAD=1 (데스크톱에서 확인용)
    def self.should_show?
      if System.respond_to?(:env) && !System.env("INITIAL2D_VPAD").nil?
        return true
      end
      return false unless System.respond_to?(:platform)
      p = System.platform
      p == "android" || p == "ios"
    end

    # 순수 함수: 패드 중심 기준 상대 좌표(dx, dy)를 방향으로 바꾼다.
    # radius 밖이나 deadzone 안이면 nil. 45도 대각선을 경계로 4방향.
    def self.direction(dx, dy, radius, deadzone)
      d2 = dx * dx + dy * dy
      return nil if d2 > radius * radius || d2 < deadzone * deadzone
      if dx.abs > dy.abs
        dx > 0 ? :right : :left
      else
        dy > 0 ? :down : :up
      end
    end

    attr_accessor :x, :y
    attr_reader :size, :image, :scale

    # opts: { x:, y:, size:, opacity:, input:, image_factory: } (전부 생략 가능).
    # Layout.controls 의 pad Hash 를 그대로 넘겨도 되고 키워드로 줘도 된다.
    # image_factory 는 Lua 판에 없는 주입구다 (기본 Image::FACTORY, 테스트가 가짜를 넣을 때).
    def initialize(opts = nil, **kw)
      opts = (opts || {}).merge(kw)
      size = opts[:size] || 160
      @input = opts[:input] || ::Input
      @x = opts[:x] || 24
      @y = opts[:y] || (Graphics.height - size - 24)
      @size = size

      @radius = size * 0.48
      @deadzone = size * 0.10
      @current = nil
      @owner_id = nil # 패드를 잡은 포인터 (놓을 때까지 유지)
      factory = opts[:image_factory] || Image::FACTORY
      img = factory.call("./resources/ui/dpad.png", @x, @y,
                         FRAME_SIZE, FRAME_SIZE, 5, "UIDpad")
      img.set_sheet_grid(5, 1)
      img.loop = false
      img.set_frames(0, 0)
      img.current_frame = 0
      img.opacity = opts[:opacity] || 220
      img.scale = size.to_f / FRAME_SIZE # 위치는 좌상단 기준이라 스케일이 배치를 흔들지 않는다
      @image = img
      @scale = size.to_f / FRAME_SIZE
    end

    # 패드 중심 [cx, cy]
    def center
      [@x + @size.to_f / 2, @y + @size.to_f / 2]
    end

    def contains?(px, py)
      cx, cy = center
      dx = px - cx
      dy = py - cy
      dx * dx + dy * dy <= @radius * @radius
    end

    def hit_test(px, py)
      cx, cy = center
      VirtualPad.direction(px - cx, py - cy, @radius, @deadzone)
    end

    # 매 프레임. pointers를 넘기면 그것을 쓰고(단위 테스트), 없으면 input에서 만든다.
    def update(pointers = nil)
      pointers = Ui::Touch.pointers(@input) if pointers.nil?

      # 잡고 있던 포인터를 따라간다. 사라졌거나 떨어졌으면 놓는다.
      owner = nil
      unless @owner_id.nil?
        owner = pointers.find { |p| p[:id] == @owner_id }
        if owner.nil? || !owner[:held]
          @owner_id = nil
          owner = nil
        end
      end

      # 새로 잡기: 이번 틱에 패드 안에서 눌린 포인터
      if owner.nil?
        pointers.each do |p|
          if p[:down] && contains?(p[:x], p[:y])
            @owner_id = p[:id]
            owner = p
            break
          end
        end
      end

      if owner
        # 잡힌 동안은 반경 제한 없이 방향만 본다 (조이스틱: 밖으로 끌어도 유지)
        cx, cy = center
        @current = VirtualPad.direction(owner[:x] - cx, owner[:y] - cy,
                                        Float::INFINITY, @deadzone)
      else
        @current = nil
      end
      @image.current_frame = @current ? FRAME_OF[@current] : 0
      @image.update(0)
    end

    # Lua 의 isPressed(dir). dir 은 :up, :down, :left, :right
    def pressed?(dir)
      @current == dir
    end

    # 지금 방향 (:up, :down, :left, :right 또는 nil). Lua 의 pressed()
    def pressed
      @current
    end

    def set_position(x, y)
      @x = x
      @y = y
      @image.set_position(x, y)
    end

    def draw
      @image.draw
    end

    # Lua 의 img.dispose() 는 텍스처까지 놓는다. Ruby 에서는 release 가 그 일을 한다.
    def dispose
      @image.release
    end
  end
end
