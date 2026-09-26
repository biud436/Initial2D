# message.rb : 대화창 (7단계, docs/plans/07-rpg-dialogue.md). scripts/lua/rpg/message.lua 의 Ruby 판.
#
# 화면 아래 고정 위치의 창에 대사를 한 글자씩 출력한다. 결정키를 누르면 남은
# 글자를 즉시 다 보여 주고, 한 번 더 누르면 다음 쪽으로 넘어가거나 닫힌다.
#
# 6단계 실행기(interpreter.lua)가 요구하는 항구(port)의 구현체다. 실행기는
# show_message / show_choice / busy? / result 네 가지만 알고, 그것들이 창인지
# print 스텁인지는 모른다. 그래서 선택지 창도 여기서 함께 들고 있는다.
# 실행기 쪽에서 보면 대화 하나로 보여야 하기 때문이다.
#
# 시간은 프레임으로 잰다 (실행기와 같은 고정 스텝 규칙). 폭 측정과 글자 그리기는
# 주입받으므로, 엔진 없이도 배치와 쪽 나눔을 단위 테스트할 수 있다.
#
# Lua 와 다른 점: 선택 결과(result, cancel_index, index)는 Choice 와 같이 0부터다.
# page 는 Lua 와 같은 "n번째 쪽"(1부터, 0이면 쪽 없음)이다. 여러 값을 돌려주던
# text_rect / pause_arrow_rect 는 배열 [x, y, w, h]. 얼굴은 { file:, index: } Hash.
#
# 사용:
#   dlg = Rpg::Dialogue.new(skin: skin)
#   interp = Interpreter.new(message_port: dlg.port, ...)
#   dlg.update(input, interp.busy?)   # 매 프레임
#   dlg.draw

require "scripts/ruby/rpg/window"
require "scripts/ruby/rpg/choice"
require "scripts/ruby/rpg/text"
require "scripts/ruby/rpg/specs"
require "scripts/ruby/image"

module Rpg
  class Dialogue
    ARROW_BLINK_FRAMES = 24    # 다음 쪽 대기 화살표 깜빡임 주기

    # 실행기에 넘기는 항구. Lua 판은 클로저 네 개를 담은 테이블이었다.
    # 실행기는 port.show_message(text, opts), port.show_choice(items, opts),
    # port.busy?, port.result 만 부른다.
    class Port
      def initialize(dialogue)
        @dialogue = dialogue
      end

      def show_message(text, opts = {})
        @dialogue.show_message(text, opts)
      end

      def show_choice(items, opts = {})
        @dialogue.show_choice(items, opts)
      end

      def busy?
        @dialogue.busy?
      end

      def result
        @dialogue.result
      end
    end

    attr_accessor :speed, :text_se_interval, :name, :face, :frame, :revealed, :page, :pages, :page_chars
    attr_reader :skin, :measure, :draw_text, :lines, :line_height, :se, :image_factory,
                :face_size, :ink_margin, :window, :name_window, :choice, :faces, :busy

    # skin          Rpg::Skin (필수)
    # measure       Proc (measure.call(text) -> 픽셀 폭) (기본 Graphics.text_width)
    # draw_text     Proc (draw_text.call(x, y, text)) (기본 Graphics.draw_text)
    # lines         한 쪽에 보일 줄 수 (기본 3)
    # line_height   줄 간격, 화면 픽셀 (기본 20. hangul16.fnt의 lineHeight 19)
    # speed         프레임당 출력 글자 수 (기본 2, 0이면 즉시 전부)
    # screen_w/h    화면 크기 (기본 Graphics.width/height)
    # x, y, width, height  직접 배치할 때
    # se            { text:, cursor:, decision:, cancel: } 효과음 Proc (선택)
    # image_factory 얼굴 그림용 Image 생성 Proc (기본 Image::FACTORY)
    def initialize(skin:, measure: nil, draw_text: nil, lines: 3, line_height: 20, speed: 2,
                   screen_w: nil, screen_h: nil, x: nil, y: nil, width: nil, height: nil,
                   se: {}, text_se_interval: 4, image_factory: nil, face_size: nil,
                   ink_margin: nil, margin: nil, padding: nil, open_frames: nil, max_choices: nil)
      raise ArgumentError, "message: skin이 필요하다" if skin.nil?

      @skin = skin
      s = @skin.scale

      @measure = measure || ->(text) { Graphics.text_width(text) }
      @draw_text = draw_text || ->(px, py, text) { Graphics.draw_text(px, py, text) }
      raise ArgumentError, "message: 폭 측정 함수가 필요하다" unless @measure.respond_to?(:call)

      @lines = lines || 3
      @line_height = line_height || 20
      @speed = speed || 2
      @se = se || {}
      @text_se_interval = text_se_interval || 4
      @image_factory = image_factory || Image::FACTORY
      @face_size = (face_size || Specs::FACESET[:size]) * s
      # 줄바꿈 여유 (choice.rb와 같은 이유. 측정 폭은 진행 폭의 합이다)
      @ink_margin = ink_margin || (2 * s)

      screen_w ||= Graphics.width
      screen_h ||= Graphics.height
      margin ||= 4 * s
      padding ||= @skin.spec[:frame_corner] * s

      width ||= screen_w - margin * 2
      height ||= @lines * @line_height + padding * 2
      x ||= margin
      y ||= screen_h - height - margin

      @window = Window.new(
        skin: @skin, x: x, y: y, width: width, height: height,
        padding: padding, open_frames: open_frames
      )
      @name_window = nil
      @choice = Choice.new(
        skin: @skin, measure: @measure, draw_text: @draw_text,
        line_height: @line_height, max_visible: max_choices || 4,
        padding: padding, se: @se, open_frames: open_frames
      )

      @faces = {}          # 경로 → Image
      @pages = []
      @page = 0
      @revealed = 0
      @busy = false
      @face = nil
      @name = nil
      @frame = 0
    end

    # ---- 쪽 나눔 --------------------------------------------------------------

    # 대사 한 덩어리를 창 폭에 맞춰 줄로 나누고, 다시 쪽으로 묶는다.
    # 순수 계산이라 단위 테스트가 그대로 부른다.
    def paginate(text, text_width)
      wrapped = Text.wrap(text, text_width, @measure)
      pages, page = [], []
      wrapped.each do |line|
        page.push(line)
        if page.size >= @lines
          pages.push(page)
          page = []
        end
      end
      pages.push(page) unless page.empty?
      pages.push([""]) if pages.empty?
      pages
    end

    # 글자를 그릴 영역 [x, y, w, h] (얼굴이 있으면 그만큼 오른쪽으로 밀린다)
    def text_rect
      cx, cy, cw, ch = @window.content_rect
      unless @face.nil?
        shift = @face_size + @window.padding
        return [cx + shift, cy, cw - shift, ch]
      end
      [cx, cy, cw, ch]
    end

    # ---- 표시 ----------------------------------------------------------------

    # 대사를 띄운다. 실행기가 부르는 진입점이기도 하다.
    # face  { file: 경로, index: 0..15 }
    # name  화자 이름 (작은 창으로 위에 붙는다)
    def show_message(text, opts = {})
      opts ||= {}
      @face = opts[:face]
      set_name(opts[:name])

      _, _, text_width = text_rect
      @pages = paginate(text.to_s, text_width - @ink_margin)
      start_page(1)
      @busy = true
      @window.open
      self
    end

    # n번째 쪽(1부터)을 처음부터 출력하기 시작한다. speed가 0이면 타자 효과 없이 바로 전부.
    def start_page(n)
      @page = n
      @page_chars = total_chars(@pages[n - 1] || [])
      @revealed = (@speed <= 0) ? @page_chars : 0
    end

    # 선택지를 띄운다 (대화창은 열린 채로 둔다. 방금 한 말이 보여야 한다).
    def show_choice(items, opts = {})
      opts ||= {}
      wx, wy, ww = @window.x, @window.y, @window.width
      @choice.show(items, {
        anchor: { x: wx, y: wy, w: ww },
        cancel_index: opts[:cancel_index],
        index: opts[:index],
      })
      @busy = true
      self
    end

    def set_name(name)
      @name = name
      if name.nil?
        @name_window = nil
        return
      end
      s = @skin.scale
      padding = @window.padding
      w = @measure.call(name.to_s) + padding * 2
      h = @line_height + padding * 2
      @name_window = Window.new(
        skin: @skin, x: @window.x, y: @window.y - h + s,
        width: w, height: h, padding: padding, open_frames: 0, open: true
      )
    end

    # 실행기가 보는 상태. 대사가 남아 있거나 선택 중이면 참.
    def busy?
      @busy || @choice.active?
    end

    # 마지막 선택 결과 (실행기가 choice 대기 뒤에 읽는다). 0부터.
    def result
      @choice.result
    end

    # 지금 쪽의 글자가 전부 나왔는가
    def revealed?
      @revealed >= (@page_chars || 0)
    end

    # 실행기에 넘길 항구. Lua 판은 클로저 테이블이었고, Ruby 는 위임 객체다.
    def port
      Port.new(self)
    end

    # ---- 프레임 --------------------------------------------------------------

    # 대사를 한 칸 진행시킨다 (결정키가 없을 때).
    def advance_reveal
      if @speed <= 0
        @revealed = @page_chars
        return
      end
      before = @revealed
      @revealed = [@page_chars, @revealed + @speed].min
      if @text_se_interval > 0 && @revealed > before &&
         (before.to_f / @text_se_interval).floor !=
         (@revealed.to_f / @text_se_interval).floor
        play(@se[:text])
      end
    end

    # 결정키를 눌렀을 때: 다 안 나왔으면 마저 보여 주고, 다 나왔으면 다음 쪽으로.
    def confirm
      unless revealed?
        @revealed = @page_chars
        return
      end
      play(@se[:decision])
      if @page < @pages.size
        start_page(@page + 1)
      else
        @busy = false
      end
    end

    # 매 프레임 한 번.
    # input        { confirm:, up:, down:, cancel: } 이번 프레임에 눌린 키
    # script_busy  실행기가 아직 도는 중인가. 거짓이고 할 일도 없으면 창을 닫는다.
    def update(input, script_busy)
      input ||= {}
      @frame += 1

      @window.update
      @name_window.update unless @name_window.nil?

      if @choice.active?
        # 선택 중에는 대화창은 그대로 두고 선택지만 움직인다
        @choice.update(input)
        @busy = false unless @choice.active?
        return
      end
      @choice.update(nil)

      if @busy
        if @window.open?
          if input[:confirm]
            confirm
          else
            advance_reveal
          end
        end
        return
      end

      unless script_busy
        @window.close
        @name_window.close unless @name_window.nil?
        if @window.closed?
          # 다 닫힌 뒤에는 지난 대사를 버린다. 다음에 열릴 때 옛 글자가
          # 한 프레임 비치는 것을 막는다.
          @pages, @page, @face = [], 0, nil
        end
      end
    end

    # ---- 그리기 --------------------------------------------------------------

    def face_image(file)
      img = @faces[file]
      if img.nil?
        size = Specs::FACESET[:size]
        img = @image_factory.call(file, 0, 0, size, size, 1, "face:#{file}")
        img.loop = false
        img.scale = @skin.scale
        @faces[file] = img
      end
      img
    end

    def draw_face
      return if @face.nil? || @face[:file].nil?
      cx, cy = @window.content_rect
      img = face_image(@face[:file])
      fx, fy, fw, fh = Specs.faceset_rect(@face[:index] || 0)
      img.set_rect(fx, fy, fw, fh)
      img.set_position(cx, cy)
      img.opacity = 255
      img.update(0)
      img.draw
    end

    # 지금 화면에 보이는 줄들 (타자 효과가 잘라 낸 상태). 테스트도 이걸 본다.
    def visible_lines
      page = current_page
      return [] if page.nil?
      out, left = [], @revealed
      page.each do |line|
        n = Text.length(line)
        if left >= n
          out.push(line)
          left -= n
        else
          out.push(Text.sub(line, left))
          left = 0
        end
      end
      out
    end

    def draw
      if !@name_window.nil? && !@name.nil?
        @name_window.draw
        if @name_window.open? && !@draw_text.nil?
          nx, ny = @name_window.content_rect
          @draw_text.call(nx, ny, @name)
        end
      end

      @window.draw

      # 대사는 창이 다 열려 있는 동안 계속 보인다 (선택지를 고르는 중에도, 닫히기
      # 직전까지도). 방금 무슨 말을 들었는지가 화면에 남아 있어야 한다.
      if @window.open? && !current_page.nil?
        draw_face
        tx, ty = text_rect
        unless @draw_text.nil?
          visible_lines.each_with_index do |line, i|
            @draw_text.call(tx, ty + i * @line_height, line) if line != ""
          end
        end
        draw_pause_arrow
      end

      @choice.draw
    end

    # 대기 화살표를 그릴 자리 [x, y, w, h] (창 아래 가운데). 테스트도 이 값으로 픽셀을 본다.
    def pause_arrow_rect
      s = @skin.scale
      arrow = @skin.spec[:arrow_down]
      wx, wy, ww, wh = @window.rect
      [wx + ((ww - arrow[:w] * s).to_f / 2).floor, wy + wh - arrow[:h] * s,
       arrow[:w] * s, arrow[:h] * s]
    end

    # 다음을 기다리는 동안 창 아래에서 깜빡이는 화살표 (스킨의 스크롤 화살표).
    def draw_pause_arrow
      return if !@busy || !revealed? || @choice.active?
      return if (@frame % (ARROW_BLINK_FRAMES * 2)) >= ARROW_BLINK_FRAMES
      x, y = pause_arrow_rect
      @skin.draw_rect(@skin.spec[:arrow_down], x, y)
    end

    def dispose
      # 얼굴 그림은 경로마다 제 텍스처를 가지므로 텍스처까지 놓는다 (Lua 의 Image.dispose)
      @faces.each_value do |img|
        img.respond_to?(:release) ? img.release : img.dispose
      end
      @faces = {}
      @choice.dispose
      @window = nil
      @name_window = nil
    end

    private

    # 지금 쪽 (page 는 1부터, 0이면 nil)
    def current_page
      return nil if @page < 1
      @pages[@page - 1]
    end

    # 한 쪽의 글자 수
    def total_chars(page)
      n = 0
      page.each { |line| n += Text.length(line) }
      n
    end

    # 효과음 Proc 이 있을 때만 부른다
    def play(fn)
      fn.call if fn.respond_to?(:call)
    end
  end
end
