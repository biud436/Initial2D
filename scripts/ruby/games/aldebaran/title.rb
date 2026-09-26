# 알데바란, 타이틀 씬 (docs/plans/aldebaran-3-content.md 2절).
#
# 배경 그림 한 장과 커서 메뉴 하나. 대화창 부품(창, 선택지, 메시지)을 재사용한다.
#
#   방향키 위아래: 항목 이동      Z / Enter / Space: 결정
#   터치: 항목을 직접 누른다      ESC / 뒤로가기: 게임 종료
#
# 배경은 tools/generate_aldebaran_assets.py로 다시 만든다 (제목 글자가 이미지에 포함되어 있다).

require "scripts/ruby/image"
require "scripts/ruby/rpg/window"
require "scripts/ruby/rpg/choice"
require "scripts/ruby/rpg/message"
require "scripts/ruby/rpg/assets"
require "scripts/ruby/bgm"

module AldebaranTitleScene
  BACKGROUND = "./resources/titles/aldebaran_title.png"
  BASE_FONT = "./resources/fonts/hangul.fnt"
  SE_CURSOR = "./resources/audio/ui_cursor.wav"
  SE_DECISION = "./resources/audio/ui_decision.wav"
  SE_TEXT = "./resources/audio/ui_text.wav"
  TITLE_BGM_SLOT = "./resources/audio/aldebaran_title.ogg" # 없으면 bless로
  TITLE_BGM_FALLBACK = "./resources/audio/bless.ogg"
  TITLE_BGM_VOLUME = 72

  SKIN_SCALE = 3
  LINE_HEIGHT = 48
  MENU_WIDTH = 280
  # 메뉴는 왼쪽 아래에 둔다. 가운데에 두면 배경의 숲과 별을 가린다.
  MENU_X = 84
  MENU_Y = 600
  AUTOPLAY_START_FRAME = 60

  ITEMS = ["시작", "조작 방법", "나가기"]
  # 선택지 번호 (0부터)
  START = 0
  HELP = 1
  LEAVE = 2

  HELP_TEXT = "왼쪽과 오른쪽 방향키로 걷고, 같은 방향을 빠르게 두 번 누르면 " \
    "대쉬합니다. Z나 스페이스로 뛰고, 공중에서 한 번 더 누르면 2단 점프입니다. " \
    "X를 이어 누르면 3단 베기, C는 버서커(MP 10)입니다. ESC나 P로 일시 정지. " \
    "터치 기기에서는 왼쪽 아래 패드로 걷고, 오른쪽 아래의 점프와 공격과 폭주 " \
    "버튼, 오른쪽 위의 정지 버튼을 씁니다."

  LEAVE_DELAY = 12

  class << self
    def play_se(path, id)
      -> { Audio.play_sound(path, id, 0) }
    end

    def open_menu(index)
      @choice.show(ITEMS, { x: MENU_X, y: MENU_Y, index: index })
    end

    # 씬 바깥(검증 시나리오)에서 상태를 읽는 접근자
    def status
      {
        items: ITEMS.size,
        index: @choice ? @choice.index : nil,
        menu_open: (@choice && @choice.active? && @choice.window && @choice.window.open?) || false,
        help_open: (@help && @help.busy?) || false,
        leaving: @leaving,
      }
    end

    def init
      @w = Graphics.width
      @h = Graphics.height
      @frame = 0
      @leaving = nil
      @leave_timer = 0

      Graphics.prepare_font(BASE_FONT) if $font_ready

      @bg = Image.create(BACKGROUND, 0, 0, @w, @h, 1, "AldebaranTitle")
      @bg.update(0)

      @skin = Rpg::Skin.new(path: Rpg::Assets.windowskin, scale: SKIN_SCALE)

      se = {
        cursor: play_se(SE_CURSOR, "uiCursor"),
        decision: play_se(SE_DECISION, "uiDecision"),
        text: play_se(SE_TEXT, "uiText"),
      }
      measure = ->(text) { Graphics.text_width(text) }
      draw_text = ->(x, y, text) { Graphics.draw_text(x, y, text) }

      @choice = Rpg::Choice.new(
        skin: @skin, measure: measure, draw_text: draw_text,
        line_height: LINE_HEIGHT, max_visible: ITEMS.size, min_width: MENU_WIDTH,
        se: se
      )
      @help = Rpg::Dialogue.new(
        skin: @skin, measure: measure, draw_text: draw_text,
        screen_w: @w, screen_h: @h, lines: 4, line_height: LINE_HEIGHT,
        speed: 3, se: se
      )

      open_menu(START)
      Bgm.play(Rpg::Assets.exists?(TITLE_BGM_SLOT) ? TITLE_BGM_SLOT : TITLE_BGM_FALLBACK,
               { volume: TITLE_BGM_VOLUME })
    end

    def poll_input
      {
        confirm: Input.key_down?(:z) || Input.key_down?(:return) || Input.key_down?(:space),
        up: Input.key_down?(:up),
        down: Input.key_down?(:down),
        cancel: Input.key_down?(:x),
      }
    end

    # 터치: 항목을 직접 누르면 커서를 옮기고 그대로 결정한다.
    def poll_touch(input)
      return input unless Input.mouse_down?(:left)
      mx = Input.mouse_x
      my = Input.mouse_y

      if @help.busy?
        input[:confirm] = true
        return input
      end

      index = @choice.index_at(mx, my)
      if index
        @choice.index = index
        input[:confirm] = true
      end
      input
    end

    def update(elapsed)
      @frame += 1

      if @leaving
        @leave_timer += 1
        @choice.update(nil)
        @help.update({}, false)
        if @leave_timer >= LEAVE_DELAY
          if @leaving == START
            # 새 회차다. 첫 스테이지부터, 이어받는 상태 없이 시작한다.
            if Object.const_defined?(:AldebaranScene)
              AldebaranScene.clear_carry
              AldebaranScene.set_stage("forest")
            end
            switch_scene("aldebaran")
          else
            System.exit # "나가기"
          end
        end
        return
      end

      input = poll_touch(poll_input)

      input[:confirm] = true if $autoplay && @frame == AUTOPLAY_START_FRAME

      if @help.busy?
        @help.update(input, false)
        open_menu(HELP) unless @help.busy?
        @choice.update(nil)
      else
        @help.update({}, false)
        @choice.update(input)

        unless @choice.active?
          picked = @choice.result
          if picked == HELP
            @help.show_message(HELP_TEXT)
          else
            @leaving = picked || LEAVE
            @leave_timer = 0
          end
        end
      end

      # 타이틀이 최상위 씬이다. ESC(안드로이드 뒤로가기)는 게임을 끝낸다.
      System.exit if Input.key_down?(:escape)
    end

    def render
      @bg.draw
      @choice.draw
      @help.draw
    end

    def destroy
      @bg.release if @bg
      @help.dispose if @help
      @choice.dispose if @choice
      @skin.dispose if @skin
      @bg = nil
      @help = nil
      @choice = nil
      @skin = nil
    end
  end
end
