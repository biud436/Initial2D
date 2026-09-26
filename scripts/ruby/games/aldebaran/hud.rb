# 알데바란, HUD (기획서 8.2절): HP/MP/EXP 막대, 레벨, 목숨, 골드.
#
# 막대는 hud.png의 채움 띠를 원하는 폭만큼 잘라 그린다. 엔진의 스프라이트는
# 만들 때의 크기를 소스 사각형 크기로 쓰므로(window.rb의 Skin과 같은 이유)
# 폭마다 스프라이트를 하나씩 캐시한다. 텍스처는 한 장을 공유한다.

require "scripts/ruby/image"

module Aldebaran
  class Hud
    PATH = "./resources/aldebaran/hud.png"
    # hud.png의 띠와 아이콘 좌표 (tools/generate_aldebaran_assets.py의 make_hud)
    STRIP_Y = { hp: 0, mp: 8, exp: 16, bg: 24 }
    ICON = { star: { x: 66, y: 0 }, star_empty: { x: 66, y: 12 }, coin: { x: 66, y: 24 } }

    BAR_W = 64
    BAR_H = 6
    ICON_SIZE = 10

    def initialize(image_factory: nil)
      @factory = image_factory || Image::FACTORY
      @cache = {}
    end

    def image(w, h)
      key = "#{w}x#{h}"
      unless @cache[key]
        img = @factory.call(PATH, 0, 0, w, h, 1, "AldebaranHud")
        img.loop = false
        @cache[key] = img
      end
      @cache[key]
    end

    def piece(sx, sy, w, h, x, y, opacity = nil)
      img = image(w, h)
      img.set_rect(sx, sy, w, h)
      img.set_position(x, y)
      img.opacity = opacity || 255
      img.update(0)
      img.draw
    end

    # 막대 하나: 바탕 위에 비율만큼의 채움 (0이 아니면 최소 1px)
    def bar(x, y, kind, ratio)
      piece(0, STRIP_Y[:bg], BAR_W, BAR_H, x, y)
      w = ([0, [1, ratio].min].max * BAR_W).floor
      w = 1 if w == 0 && ratio > 0
      piece(0, STRIP_Y[kind], w, BAR_H, x, y) if w > 0
    end

    # 아이콘 하나 (목숨 별, 동전)
    def icon(x, y, name)
      r = ICON[name]
      piece(r[:x], r[:y], ICON_SIZE, ICON_SIZE, x, y)
    end

    # 스킬 슬롯 하나. 익히지 않았으면 테두리만 그리고, 쿨타임 중이면 남은 비율만큼
    # 위에서부터 어둡게 덮는다. ratio는 남은 쿨타임의 비율(1이면 방금 썼다), ready는 지금 쓸 수 있는가.
    def skill_slot(x, y, size, learned, ratio, ready)
      # 테두리 (막대의 바탕 띠를 잘라 쓴다)
      size.times do |i|
        piece(0, STRIP_Y[:bg], 1, 1, x + i, y)
        piece(0, STRIP_Y[:bg], 1, 1, x + i, y + size - 1)
        piece(0, STRIP_Y[:bg], 1, 1, x, y + i)
        piece(0, STRIP_Y[:bg], 1, 1, x + size - 1, y + i)
      end
      return unless learned

      # 안쪽: 쓸 수 있으면 노랑(EXP 띠), 아니면 파랑(MP 띠)
      kind = ready ? :exp : :mp
      inner = size - 2
      inner.times do |i|
        piece(0, STRIP_Y[kind], inner, 1, x + 1, y + 1 + i)
      end
      # 쿨타임: 위에서부터 어둡게 덮는다
      if ratio && ratio > 0
        h = (inner * [1, ratio].min).floor
        h.times do |i|
          piece(0, STRIP_Y[:bg], inner, 1, x + 1, y + 1 + i)
        end
      end
    end

    def dispose
      # 텍스처 한 장을 공유한다. 텍스처 해제(release)는 한 번만 하고, 나머지는 스프라이트만 해제한다(dispose)
      first = true
      @cache.each_value do |img|
        if first && img.respond_to?(:release)
          img.release
        else
          img.dispose
        end
        first = false
      end
      @cache = {}
    end
  end
end
