# buttons.rb : 화면 위 동작 버튼 (터치 조작, 범용 UI 모듈, 9단계, T1에서 멀티터치).
# scripts/lua/ui/buttons.lua 의 Ruby 판.
#
# 가상 패드(vpad.rb)가 방향을 맡고, 이쪽이 동작을 맡는다. 8단계까지는
# "패드 밖 아무 데나 탭 = 결정"이었는데, 걸으려다 대화가 넘어가고 대화를 넘기려다
# 걷는 일이 잦았다 (기획서 docs/design/port-town.md 6.3절).
#
# 포인터는 touch.rb 가 합쳐 준다: 멀티터치 API가 있으면 손가락들을, 없으면
# 마우스를 쓴다. 손가락마다 따로 판정하므로 패드로 달리면서 버튼을 누를 수
# 있고, 두 버튼을 동시에 누를 수도 있다 (T1).
#
# 판정 반경은 표시 반경의 1.25배다 (히트 슬롭, 작은 버튼도 누르기 쉽게).
# 슬롭끼리 겹치는 자리는 중심이 더 가까운 버튼 하나만 먹는다.
#
# 사용:
#   require "scripts/ruby/ui/buttons"
#   pad = Ui::Buttons.new(
#     draw_text: ->(x, y, text) { Graphics.draw_text(x, y, text) },
#     measure: ->(text) { Graphics.text_width(text) },
#     items: [
#       { id: :confirm, label: "결정", x: 300, y: 380, size: 56 },
#       { id: :cancel,  label: "취소", x: 240, y: 396, size: 44 },
#     ],
#   )
#   pad.update                   # 매 프레임, Input 갱신 뒤
#   if pad.pressed?(:confirm) then ... end   # 이번 프레임에 눌렸는가 (엣지)
#   pad.contains?(mx, my)        # 버튼 위 터치인가 (다른 탭 처리에서 제외할 때)
#   pad.draw
#   pad.dispose

require "scripts/ruby/image"
require "scripts/ruby/ui/touch"

module Ui
  class Buttons
    SHEET = "./resources/ui/actionbtn.png"
    FRAME_SIZE = 96   # tools/generate_ui_assets.py의 make_action_button과 같은 값
    LABEL_LINE = 16   # 라벨 세로 중앙 보정 (16px 폰트 기준)
    HIT_SCALE = 1.25  # 판정 반경 / 표시 반경

    # 점이 원 안에 있는가 (순수 함수, 단위 테스트가 그대로 부른다).
    # hit_scale을 주면 판정 반경을 그만큼 키운다 (기본 1 = 표시 반경).
    # item 은 { x:, y:, size: } 를 가진 Hash.
    def self.hit(item, x, y, hit_scale = nil)
      r = item[:size].to_f / 2 * (hit_scale || 1)
      half = item[:size].to_f / 2
      cx = item[:x] + half
      cy = item[:y] + half
      dx = x - cx
      dy = y - cy
      dx * dx + dy * dy <= r * r
    end

    # Ruby 식 술어 이름 (hit 와 같다)
    def self.hit?(item, x, y, hit_scale = nil)
      hit(item, x, y, hit_scale)
    end

    # 포인터가 먹는 버튼 하나를 고른다 (순수 함수). 슬롭이 겹치면 중심이 가까운 쪽.
    def self.pick(items, x, y, hit_scale = nil)
      best = nil
      best_d2 = nil
      items.each do |item|
        half = item[:size].to_f / 2
        r = half * (hit_scale || 1)
        dx = x - (item[:x] + half)
        dy = y - (item[:y] + half)
        d2 = dx * dx + dy * dy
        if d2 <= r * r && (best_d2.nil? || d2 < best_d2)
          best = item
          best_d2 = d2
        end
      end
      best
    end

    # 버튼 상태 목록. 각 원소는 { id:, label:, x:, y:, size:, img:, held:, edge: }
    attr_reader :items

    # opts (Hash 하나 또는 키워드):
    #   items:          [{ id:, label:, x:, y:, size: }, ...] (필수, 하나 이상)
    #   draw_text:      Proc (x, y, text) (기본 Graphics.draw_text)
    #   measure:        Proc (text) -> 폭 (기본 Graphics.text_width)
    #   input:          엔진 Input과 같은 표면 (기본 전역 Input)
    #   image_factory:  Image 생성자 (기본 Image::FACTORY, 테스트가 가짜를 넣는다)
    def initialize(opts = nil, **kw)
      opts = (opts || {}).merge(kw)
      defs = opts[:items]
      unless defs.is_a?(Array) && defs.size > 0
        raise ArgumentError, "buttons: items가 필요하다"
      end

      @input = opts[:input] || ::Input
      @draw_text = opts[:draw_text] || ->(x, y, text) { Graphics.draw_text(x, y, text) }
      @measure = opts[:measure] || ->(text) { Graphics.text_width(text) }
      factory = opts[:image_factory] || Image::FACTORY

      @items = []
      defs.each_with_index do |spec, idx|
        i = idx + 1
        size = spec[:size] || 56
        img = factory.call(SHEET, spec[:x], spec[:y], FRAME_SIZE, FRAME_SIZE, 2,
                           "UIButton:" + (spec[:id] || i).to_s)
        img.loop = false
        img.scale = size.to_f / FRAME_SIZE
        img.set_position(spec[:x], spec[:y])
        @items.push({
          id: spec[:id] || ("btn" + i.to_s).to_sym, label: spec[:label],
          x: spec[:x], y: spec[:y], size: size, img: img,
          held: false, edge: false,
        })
      end
    end

    # 매 프레임. 눌림 상태와 이번 프레임의 엣지를 갱신한다.
    # pointers를 넘기면 그것을 쓰고(단위 테스트), 없으면 input에서 만든다.
    def update(pointers = nil)
      pointers = Ui::Touch.pointers(@input) if pointers.nil?

      @items.each do |item|
        item[:edge] = false
        item[:held] = false
      end
      pointers.each do |p|
        next unless p[:held]
        best = Buttons.pick(@items, p[:x], p[:y], HIT_SCALE)
        unless best.nil?
          best[:edge] = best[:edge] || (p[:down] ? true : false)
          best[:held] = true
        end
      end
      @items.each do |item|
        frame = item[:held] ? 1 : 0
        item[:img].set_frames(frame, frame)
        item[:img].set_position(item[:x], item[:y])
        item[:img].update(0)
      end
    end

    # 이번 프레임에 눌렸는가 (엣지). 대화창과 선택지가 보는 값이다. Lua 의 pressed(id)
    def pressed?(id)
      @items.each do |item|
        return item[:edge] if item[:id] == id
      end
      false
    end

    # Lua 이름 그대로 (pressed? 와 같다)
    def pressed(id)
      pressed?(id)
    end

    # 버튼 판정 영역(슬롭 포함) 위인가 (다른 탭 처리에서 제외할 때)
    def contains?(x, y)
      @items.each do |item|
        return true if Buttons.hit(item, x, y, HIT_SCALE)
      end
      false
    end

    def draw
      @items.each do |item|
        item[:img].draw
        if !item[:label].nil? && !@draw_text.nil? && !@measure.nil?
          w = @measure.call(item[:label])
          @draw_text.call(item[:x] + (item[:size] - w).to_f / 2,
                          item[:y] + (item[:size] - LABEL_LINE).to_f / 2 - 2, item[:label])
        end
      end
    end

    # Lua 의 img.dispose() 는 텍스처까지 놓는다. Ruby 에서는 release 가 그 일을 한다.
    def dispose
      @items.each do |item|
        item[:img].release
      end
      @items = []
    end
  end
end
