# choice.rb : 선택지 창 (docs/plans/07-rpg-dialogue.md).
#
# 항목을 세로로 나열하고 스킨 커서로 하나를 표시한다. 위아래로 이동하고 결정키로
# 선택하며, 취소키는 지정한 항목(cancel_index)을 결과로 하여 종료한다. 결과는 번호다.
# 항목이 많으면 보이는 만큼만 그리고 스킨의 화살표로 더 있음을 알린다.
#
# 창 폭은 글자 폭으로 정해지므로 폭 측정 함수를 주입받는다.
#
# 항목 번호(index, result, cancel_index, index_at, visible_range)는 0부터 센다.
# 입력과 옵션은 Symbol 키 Hash, 콜백은 Proc이다.
#
# 사용:
#   choice = Rpg::Choice.new(skin: skin, measure: ->(s) { Graphics.text_width(s) })
#   choice.show(["네", "아니요"], cancel_index: 1)
#   choice.update({ up: ..., down: ..., confirm: ..., cancel: ... })
#   choice.draw
#   pick = choice.result unless choice.active?

require "scripts/ruby/rpg/window"

module Rpg
  class Choice
    CURSOR_BLINK_FRAMES = 20   # 커서 두 장을 번갈아 보여 주는 주기 (R2K3식 깜빡임)

    attr_accessor :index, :top, :blink, :cancel_index
    attr_reader :skin, :measure, :draw_text, :line_height, :max_visible, :min_width,
                :padding, :ink_margin, :se, :open_frames, :items, :window, :value
    alias_method :options, :items   # items의 별칭

    # skin         Rpg::Skin (필수)
    # measure      Proc (measure.call(text) -> 픽셀 폭) (필수)
    # draw_text    Proc (draw_text.call(x, y, text)) (기본 Graphics.draw_text)
    # line_height  항목 한 줄 높이 (화면 픽셀)
    # max_visible  한 번에 보이는 항목 수 (기본 4)
    # min_width    창 최소 폭
    # se           { cursor: f, decision: f, cancel: f } 효과음 Proc (선택)
    def initialize(skin:, measure:, draw_text: nil, line_height: 20, max_visible: 4, min_width: 80,
                   padding: nil, ink_margin: nil, se: {}, open_frames: nil)
      raise ArgumentError, "choice: skin이 필요하다" if skin.nil?
      raise ArgumentError, "choice: 폭 측정 함수가 필요하다" unless measure.respond_to?(:call)

      @skin = skin
      @measure = measure
      @draw_text = draw_text || ->(x, y, text) { Graphics.draw_text(x, y, text) }
      @line_height = line_height || 20
      @max_visible = max_visible || 4
      @min_width = min_width || 80
      @padding = padding || (@skin.spec[:frame_corner] * @skin.scale)
      # 폭 측정값은 진행 폭(advance)의 합이라 획이 그보다 넓은 글자는 테두리에 닿을 수 있다.
      # 그만큼 창을 더 넓게 만든다.
      @ink_margin = ink_margin || (2 * @skin.scale)
      @se = se || {}
      @open_frames = open_frames

      @items = nil
      @index = 0
      @top = 0
      @window = nil
      @value = nil
      @blink = 0
    end

    # 항목을 표시하고 선택을 시작한다.
    # x, y          창 좌상단 (없으면 anchor 기준으로 배치한다)
    # anchor        { x:, y:, w: } 오른쪽 위 기준점 (보통 메시지 창의 사각형)
    # cancel_index  취소키를 눌렀을 때의 결과 (없으면 취소 불가)
    # index         커서의 처음 위치 (기본 0)
    def show(items, opts = {})
      raise ArgumentError, "choice: 항목이 필요하다" unless items.is_a?(Array) && !items.empty?
      opts ||= {}

      @items = items
      n = items.size
      @index = [[opts[:index] || 0, 0].max, n - 1].min
      @cancel_index = opts[:cancel_index]
      @value = nil
      @blink = 0

      visible = [@max_visible, n].min
      @top = [[0, @index - visible + 1].max, n - visible].min

      text_w = @min_width
      items.each do |item|
        text_w = [text_w, @measure.call(item.to_s)].max
      end
      w = text_w + @padding * 2 + @ink_margin
      h = visible * @line_height + @padding * 2

      x, y = opts[:x], opts[:y]
      anchor = opts[:anchor]
      if x.nil? && !anchor.nil?
        # 메시지 창 오른쪽 위에 배치한다 (R2K3의 선택지 위치)
        x = anchor[:x] + anchor[:w] - w
        y = anchor[:y] - h
      end

      @window = Window.new(
        skin: @skin, x: x || 0, y: y || 0, width: w, height: h,
        padding: @padding, open_frames: @open_frames
      )
      @window.open
      self
    end

    # 선택이 진행 중인가
    def active?
      !@items.nil?
    end

    def result
      @value
    end

    # 보이는 첫 항목 번호를 커서 위치에 맞춘다.
    def scroll_to_cursor
      visible = [@max_visible, @items.size].min
      if @index < @top
        @top = @index
      elsif @index > @top + visible - 1
        @top = @index - visible + 1
      end
    end

    # 매 프레임. input은 "이번 프레임에 눌렸다"는 엣지 값 { up:, down:, confirm:, cancel: }.
    def update(input)
      @window.update unless @window.nil?
      return if @items.nil?

      @blink += 1
      input ||= {}
      n = @items.size

      if input[:up]
        @index = (@index - 1) % n
        scroll_to_cursor
        @blink = 0
        play(@se[:cursor])
      elsif input[:down]
        @index = (@index + 1) % n
        scroll_to_cursor
        @blink = 0
        play(@se[:cursor])
      end

      if input[:confirm]
        @value = @index
        @items = nil
        play(@se[:decision])
        @window.close unless @window.nil?
      elsif input[:cancel] && !@cancel_index.nil?
        @value = @cancel_index
        @items = nil
        play(@se[:cancel] || @se[:decision])
        @window.close unless @window.nil?
      end
    end

    # 화면 좌표 위치에 있는 항목 번호 (없으면 nil). 터치로 항목을 직접 누를 때 쓴다.
    def index_at(x, y)
      win = @window
      return nil if @items.nil? || win.nil? || !win.open?

      cx, cy, cw = win.content_rect
      return nil if x < cx || x >= cx + cw

      first, last = visible_range
      row = ((y - cy).to_f / @line_height).floor
      return nil if row < 0 || row > last - first
      first + row
    end

    # 지금 화면에 보이는 항목 범위 [first, last]. 항목이 없으면 [0, -1].
    def visible_range
      return [0, -1] if @items.nil?
      visible = [@max_visible, @items.size].min
      [@top, [@top + visible - 1, @items.size - 1].min]
    end

    def draw
      win = @window
      return if win.nil? || win.openness <= 0

      win.draw
      return if !win.open? || @items.nil?

      cx, cy, cw = win.content_rect
      first, last = visible_range

      # 커서 먼저 (글자가 커서 위에 오게)
      row = @index - first
      @skin.draw_cursor(cx - @skin.scale, cy + row * @line_height,
                        cw + @skin.scale * 2, @line_height,
                        (@blink % (CURSOR_BLINK_FRAMES * 2)) >= CURSOR_BLINK_FRAMES)

      unless @draw_text.nil?
        (first..last).each do |i|
          @draw_text.call(cx, cy + (i - first) * @line_height, @items[i].to_s)
        end
      end

      # 위아래에 항목이 더 있으면 화살표를 그린다 (스킨의 스크롤 화살표를 그대로 쓴다)
      spec = @skin.spec
      s = @skin.scale
      wx, wy, ww, wh = win.rect
      ax = wx + ((ww - spec[:arrow_up][:w] * s).to_f / 2).floor
      if first > 0
        @skin.draw_rect(spec[:arrow_up], ax, wy)
      end
      if last < @items.size - 1
        @skin.draw_rect(spec[:arrow_down], ax, wy + wh - spec[:arrow_down][:h] * s)
      end
    end

    def dispose
      @window = nil
      @items = nil
    end

    private

    # 효과음 Proc이 있을 때만 호출한다
    def play(fn)
      fn.call if fn.respond_to?(:call)
    end
  end
end
