# rpg_message_test.rb : 대화창(scripts/ruby/rpg/message.rb) 검증. rpg_message_test.lua 의 Ruby 판.
#
# 타자 효과, 쪽 나눔, 얼굴, 그리고 실행기(interpreter.lua)와의 연결을 본다.
# 폭 측정은 가짜(한 글자 10픽셀)라 줄바꿈 위치가 글자 수로 계산된다.
#
# 선택 결과는 Ruby 판에서 0부터다 (라벨의 "n번"은 n번째 항목).

require "scripts/ruby/rpg/window"
require "scripts/ruby/rpg/message"
require "scripts/ruby/rpg/text"
require "scripts/ruby/rpg/specs"

# 그린 것을 기록하는 가짜 스프라이트 (Sprite 의 표면만 흉내낸다). log 가 nil 이면 기록하지 않는다.
class MessageTestImage
  attr_reader :path
  attr_accessor :loop, :scale, :opacity

  def initialize(log, path)
    @log = log
    @path = path
    @rect = []
    @pos = []
  end

  def set_rect(rx, ry, rw, rh)
    @rect = [rx, ry, rw, rh]
  end

  def set_position(px, py)
    @pos = [px, py]
  end

  def update(_elapsed); end

  def draw
    return if @log.nil?
    @log.push({ path: @path, sx: @rect[0], sy: @rect[1], x: @pos[0], y: @pos[1] })
  end

  def dispose; end
  def release; end
end

# Ruby 에는 아직 이벤트 실행기(interpreter)가 없다 (S2 범위 밖). interpreter.lua 의
# message / choice 경로만 Fiber 로 옮긴 최소 실행기다. 항구(port) 계약은 그대로다:
# port.show_message(text, opts) 뒤 port.busy? 가 거짓이 될 때까지 기다리고,
# port.show_choice(items, opts) 뒤에는 port.result 를 스크립트에 돌려준다.
# 한 프레임에 한 번만 재개한다는 규칙도 같다.
class MessageTestInterpreter
  attr_reader :errors

  def initialize(message_port:)
    @port = message_port
    @running = nil
    @errors = []
    @ctx = make_ctx
  end

  # 이벤트 스크립트가 부르는 API. 전부 Fiber.yield 로 요청을 넘긴다.
  def make_ctx
    ctx = {}
    ctx[:message] = ->(text, opts = nil) { Fiber.yield({ message: text.to_s, message_opts: opts }) }
    ctx[:choice] = ->(items, opts = nil) { Fiber.yield({ choice: items, choice_opts: opts }) }
    ctx
  end

  def start(event)
    return false if event.nil? || event[:script].nil?
    return false unless @running.nil?
    entry = { event: event, fiber: Fiber.new { |ev, ctx| event[:script].call(ev, ctx) },
              wait: nil, started: false, dead: false }
    step(entry)
    @running = entry unless entry[:dead]
    true
  end

  def busy?
    !@running.nil?
  end

  def begin_wait(request)
    return { kind: :frames, frames: 0 } if request.nil?
    if request[:message]
      @port.show_message(request[:message], request[:message_opts] || {})
      return { kind: :message }
    end
    if request[:choice]
      @port.show_choice(request[:choice], request[:choice_opts] || {})
      return { kind: :choice }
    end
    { kind: :frames, frames: 0 }
  end

  def poll_wait(wait)
    return [true, nil] if wait.nil?
    case wait[:kind]
    when :frames
      return [true, nil] if wait[:frames] <= 0
      wait[:frames] -= 1
      [false, nil]
    when :message
      [!@port.busy?, nil]
    when :choice
      return [false, nil] if @port.busy?
      [true, @port.result]
    else
      [true, nil]
    end
  end

  def step(entry)
    request = nil
    begin
      if !entry[:started]
        entry[:started] = true
        request = entry[:fiber].resume(entry[:event], @ctx)
      else
        request = entry[:fiber].resume(entry[:resume_value])
        entry[:resume_value] = nil
      end
    rescue Exception => e
      @errors.push("이벤트 '#{entry[:event][:id]}' 실행 오류: #{e.message}")
      entry[:dead] = true
      return
    end
    unless entry[:fiber].alive?
      entry[:dead] = true
      return
    end
    entry[:wait] = begin_wait(request)
  end

  def advance(entry)
    return if entry[:dead]
    done, value = poll_wait(entry[:wait])
    return unless done
    entry[:wait] = nil
    entry[:resume_value] = value
    step(entry)
  end

  def update
    return if @running.nil?
    advance(@running)
    @running = nil if @running[:dead]
  end
end

T.run_case("rpg_message") do |t|
  text = Rpg::Text
  char_w = 10

  fake_image_factory = lambda do |log|
    ->(path, _x, _y, _w, _h, _frames, _id) { MessageTestImage.new(log, path) }
  end

  fake_measure = ->(s) { text.length(s) * char_w }

  # 창 폭 200 = 글자 18개 (여백 16을 빼면 184 → 18글자), 한 쪽에 두 줄인 대화창
  new_dialogue = lambda do |opts|
    opts ||= {}
    draw_log = opts[:draw_log] || []
    skin = Rpg::Skin.new(path: "skin.png", scale: 1, image_factory: fake_image_factory.call(draw_log))
    drawn = []
    dlg = Rpg::Dialogue.new(
      skin: skin, measure: fake_measure,
      draw_text: ->(x, y, s) { drawn.push({ x: x, y: y, text: s }) },
      image_factory: fake_image_factory.call(draw_log),
      x: 0, y: 100, width: opts[:width] || 200, height: opts[:height] || 56,
      lines: opts[:lines] || 2, line_height: 20,
      speed: opts[:speed] || 2, text_se_interval: opts[:text_se_interval] || 0,
      se: opts[:se], open_frames: 0
    )
    [dlg, drawn]
  end

  # 창이 다 열릴 때까지 + n 프레임 굴린다
  pump = lambda do |dlg, n, input = nil|
    n.times { dlg.update(input, true) }
  end

  # ---- [1] 쪽 나눔: 폭에 맞춰 줄로, 줄 수에 맞춰 쪽으로 ------------------
  dlg, _drawn = new_dialogue.call(nil)
  pages = dlg.paginate("가나다라마바사아자차카타파하거너더러머버서어저처", 100)
  t.check_eq(pages[0].size, 2, "한 쪽은 두 줄 (lines = 2)")
  t.check_eq(text.length(pages[0][0]), 10, "한 줄은 폭 100 / 글자폭 10 = 10글자")
  t.check(pages.size >= 2, "넘치는 줄은 다음 쪽으로", "#pages=#{pages.size}")

  # ---- [2] 타자 효과: 프레임마다 speed 글자씩 -----------------------------
  dlg.show_message("가나다라마")
  t.check(dlg.busy?, "대사를 띄우면 실행기는 기다린다")
  t.check_eq(dlg.revealed, 0, "처음에는 한 글자도 안 나왔다")

  dlg.update({}, true)
  t.check_eq(dlg.revealed, 2, "프레임당 2글자")
  t.check_eq(dlg.visible_lines[0], "가나", "보이는 글자는 앞에서부터")
  dlg.update({}, true)
  t.check_eq(dlg.visible_lines[0], "가나다라", "계속 이어진다")
  dlg.update({}, true)
  t.check(dlg.revealed?, "다 나오면 멈춘다")
  t.check_eq(dlg.revealed, 5, "글자 수를 넘어가지 않는다")

  # ---- [3] 결정키: 먼저 전부 표시, 그다음 닫기 ---------------------------
  dlg.show_message("가나다라마바사")
  dlg.update({ confirm: true }, true)
  t.check(dlg.revealed?, "출력 중 결정키는 남은 글자를 즉시 보여 준다")
  t.check(dlg.busy?, "그 누름으로 창이 닫히지는 않는다")
  dlg.update({ confirm: true }, true)
  t.check(!dlg.busy?, "다 나온 뒤의 결정키가 대사를 끝낸다")

  # ---- [4] 여러 쪽: 결정키로 넘긴다 --------------------------------------
  long = "가" * 60     # 18글자 x 2줄 = 한 쪽에 36글자
  dlg.show_message(long)
  t.check(dlg.pages.size >= 2, "긴 대사는 여러 쪽", "#pages=#{dlg.pages.size}")
  dlg.update({ confirm: true }, true)      # 전부 표시
  dlg.update({ confirm: true }, true)      # 다음 쪽
  t.check_eq(dlg.page, 2, "결정키로 다음 쪽")
  t.check_eq(dlg.revealed, 0, "새 쪽은 다시 처음부터 출력한다")
  t.check(dlg.busy?, "쪽이 남아 있으면 계속 기다린다")
  dlg.update({ confirm: true }, true)
  dlg.update({ confirm: true }, true)
  t.check(!dlg.busy?, "마지막 쪽에서 결정키를 누르면 끝난다")

  # ---- [5] 얼굴: 글자 영역이 그만큼 밀린다 -------------------------------
  tx0, = dlg.text_rect
  dlg.show_message("얼굴 있는 대사", { face: { file: "faces.png", index: 3 } })
  tx1, _ty1, tw1 = dlg.text_rect
  t.check_eq(tx1 - tx0, 48 + 8, "얼굴(48) + 여백만큼 글자가 오른쪽으로")
  t.check(tw1 < 200 - 16, "글자 영역 폭도 그만큼 줄어든다")

  # 얼굴 그림은 시트에서 3번 칸(48x48)을 잘라 쓴다
  face_log = []
  faced, _drawn = new_dialogue.call({ draw_log: face_log })
  faced.show_message("얼굴", { face: { file: "faces.png", index: 3 } })
  faced.update({}, true)
  faced.draw
  face = nil
  face_log.each do |entry|
    face = entry if entry[:path] == "faces.png"
  end
  t.check(!face.nil?, "얼굴 그림을 그렸다")
  unless face.nil?
    t.check(face[:sx] == 144 && face[:sy] == 0, "3번 얼굴은 시트 (144,0)",
            "#{face[:sx]},#{face[:sy]}")
  end

  # ---- [6] 이름 창 --------------------------------------------------------
  named, _drawn = new_dialogue.call(nil)
  named.show_message("안녕하신가", { name: "촌장" })
  t.check(!named.name_window.nil?, "이름을 주면 작은 창이 생긴다")
  t.check_eq(named.name_window.width, 2 * char_w + 16, "이름 창 폭은 이름 길이에서")
  t.check(named.name_window.y < named.window.y, "이름 창은 대화창 위에 붙는다")
  named.show_message("이번엔 이름 없이")
  t.check(named.name_window.nil?, "이름이 없으면 이름 창도 없다")

  # ---- [7] 선택지 연동 ----------------------------------------------------
  dlg2, _drawn = new_dialogue.call(nil)
  dlg2.show_message("고르시오")
  dlg2.update({ confirm: true }, true)
  dlg2.update({ confirm: true }, true)
  t.check(!dlg2.busy?, "대사가 끝났다")
  dlg2.show_choice(["네", "아니요"])
  t.check(dlg2.busy?, "선택 중에도 실행기는 기다린다")
  dlg2.update({ down: true }, true)
  dlg2.update({ confirm: true }, true)
  t.check(!dlg2.busy?, "고르면 끝난다")
  t.check_eq(dlg2.result, 1, "고른 번호를 돌려준다")

  # ---- [8] 창 닫기: 스크립트가 끝나야 닫힌다 ------------------------------
  closing, _drawn = new_dialogue.call(nil)
  closing.window.open_frames = 4
  closing.show_message("가")
  pump.call(closing, 6)
  t.check(closing.window.open?, "대사 중에는 열려 있다")
  closing.update({ confirm: true }, true)
  t.check(!closing.busy?, "대사는 끝났다")
  closing.update({}, true)
  t.check(closing.window.target == 1, "스크립트가 도는 동안에는 열어 둔다 (다음 대사)")
  6.times { closing.update({}, false) }
  t.check(closing.window.closed?, "스크립트까지 끝나면 창이 닫힌다")
  t.check_eq(closing.page, 0, "닫힌 뒤에는 지난 대사를 버린다")

  # ---- [8.5] 다음을 기다릴 때 스킨의 화살표가 깜빡인다 --------------------
  arrow_log = []
  waiting, _drawn = new_dialogue.call({ draw_log: arrow_log, speed: 0 })
  waiting.show_message("가나다")
  waiting.update({}, true)
  waiting.draw
  arrow_down = Rpg::Specs::WINDOW[:arrow_down]
  drew_arrow = lambda do |log|
    log.any? { |entry| entry[:sx] == arrow_down[:x] && entry[:sy] == arrow_down[:y] }
  end
  t.check(drew_arrow.call(arrow_log), "다 나온 뒤에는 대기 화살표를 그린다")

  # 깜빡임의 꺼진 구간에서는 그리지 않는다
  Rpg::Dialogue::ARROW_BLINK_FRAMES.times { waiting.update({}, true) }
  off_log = []
  waiting.skin.cache = {}                       # 새 기록으로 갈아 끼운다
  waiting.skin.image_factory = fake_image_factory.call(off_log)
  waiting.draw
  t.check(!drew_arrow.call(off_log), "깜빡임의 꺼진 구간에서는 화살표를 그리지 않는다")

  # ---- [9] 효과음 --------------------------------------------------------
  beeps = { text: 0, decision: 0 }
  noisy, _drawn = new_dialogue.call({
    text_se_interval: 2,
    se: {
      text: -> { beeps[:text] += 1 },
      decision: -> { beeps[:decision] += 1 },
    },
  })
  noisy.show_message("가나다라")
  noisy.update({}, true)
  noisy.update({}, true)
  t.check_eq(beeps[:text], 2, "두 글자마다 글자 출력음")
  noisy.update({ confirm: true }, true)
  t.check_eq(beeps[:decision], 1, "결정음은 대사를 넘길 때")

  # ---- [10] 실행기와 실제로 연결한다 --------------------------------------
  dlg3, _drawn = new_dialogue.call({ speed: 0 })     # speed 0 = 즉시 전부 표시
  port = dlg3.port
  t.check(port.respond_to?(:show_message) && port.respond_to?(:show_choice) &&
          port.respond_to?(:busy?) && port.respond_to?(:result),
          "항구는 show_message / show_choice / busy? / result 넷을 낸다")
  interp = MessageTestInterpreter.new(message_port: port)
  picked = nil
  interp.start({
    id: "npc", trigger: :action,
    script: lambda do |_ev, ctx|
      ctx[:message].call("어서 오시게.", { name: "촌장", face: { file: "f.png", index: 1 } })
      picked = ctx[:choice].call(["네", "아니요"])
      ctx[:message].call("그렇군.")
    end,
  })

  t.check(interp.busy?, "스크립트가 돌기 시작했다")
  t.check_eq(dlg3.name, "촌장", "ctx.message의 opts가 대화창까지 전달된다")
  t.check(!dlg3.face.nil? && dlg3.face[:file] == "f.png", "얼굴 지정도 전달된다")

  dlg3.update({}, interp.busy?)
  dlg3.update({ confirm: true }, interp.busy?)   # 첫 대사 넘기기
  interp.update
  t.check(dlg3.choice.active?, "대사를 넘기면 선택지가 뜬다")

  dlg3.update({ down: true }, interp.busy?)
  dlg3.update({ confirm: true }, interp.busy?)
  interp.update
  t.check_eq(picked, 1, "고른 번호가 스크립트로 돌아간다")
  t.check_eq(dlg3.visible_lines[0], "그렇군.", "다음 대사가 이어진다")

  dlg3.update({ confirm: true }, interp.busy?)
  interp.update
  t.check(!interp.busy?, "마지막 대사를 넘기면 스크립트가 끝난다")
  t.check_eq(interp.errors, [], "스크립트 오류 없음")
end
