# rpg_choice_test.rb : 선택지 창(scripts/ruby/rpg/choice.rb) 검증. rpg_choice_test.lua 의 Ruby 판.
#
# 창 크기가 글자 폭에서 나오므로 폭 측정 함수를 가짜로 주입해 값을 통제한다
# (한 글자 = 10픽셀). 그리기는 가짜 Image로 기록만 남긴다.
#
# 항목 번호는 Ruby 판에서 0부터다. 라벨의 "n번"은 n번째 항목이라는 뜻이고,
# 검사하는 값은 그보다 하나 작다 (Lua 판은 1부터였다).

require "scripts/ruby/rpg/window"
require "scripts/ruby/rpg/choice"
require "scripts/ruby/rpg/text"

# 아무것도 하지 않는 가짜 스프라이트 (Sprite 의 표면만 흉내낸다)
class ChoiceTestImage
  attr_accessor :loop, :scale, :opacity

  def set_rect(*_args); end
  def set_position(*_args); end
  def update(*_args); end
  def draw; end
  def dispose; end
  def release; end
end

T.run_case("rpg_choice") do |t|
  char_w = 10

  fake_image_factory = -> { ->(_path, _x, _y, _w, _h, _frames, _id) { ChoiceTestImage.new } }

  # 한 글자 10픽셀 (UTF-8 글자 수로 센다. 한글은 3바이트다)
  fake_measure = ->(text) { Rpg::Text.length(text) * char_w }

  new_choice = lambda do |opts|
    opts ||= {}
    skin = Rpg::Skin.new(path: "fake.png", scale: 1, image_factory: fake_image_factory.call)
    drawn = []
    choice = Rpg::Choice.new(
      skin: skin, measure: fake_measure,
      draw_text: ->(x, y, text) { drawn.push({ x: x, y: y, text: text }) },
      line_height: opts[:line_height] || 20,
      max_visible: opts[:max_visible],
      open_frames: 0
    )
    [choice, drawn]
  end

  # ---- [1] 창 크기는 가장 긴 항목에서 나온다 -----------------------------
  choice, _drawn = new_choice.call(nil)
  choice.show(["네", "아니요, 처음입니다"], { x: 100, y: 50 })
  t.check(choice.active?, "항목을 열면 선택 중")
  t.check_eq(choice.window.width, 10 * char_w + 16 + choice.ink_margin,
             "폭 = 가장 긴 항목(10글자) + 여백")
  t.check_eq(choice.window.height, 2 * 20 + 16, "높이 = 항목 수 x 줄 높이 + 여백")
  t.check_eq(choice.index, 0, "커서는 첫 항목에서 시작")
  t.check_eq(choice.result, nil, "고르기 전에는 결과가 없다")

  # ---- [2] 위아래 이동은 양끝에서 돈다 ------------------------------------
  choice.update({ down: true })
  t.check_eq(choice.index, 1, "아래로 이동")
  choice.update({ down: true })
  t.check_eq(choice.index, 0, "마지막에서 아래로 가면 처음으로")
  choice.update({ up: true })
  t.check_eq(choice.index, 1, "처음에서 위로 가면 마지막으로")

  # ---- [3] 결정 -----------------------------------------------------------
  choice.update({ confirm: true })
  t.check(!choice.active?, "결정키를 누르면 선택이 끝난다")
  t.check_eq(choice.result, 1, "고른 항목 번호를 돌려준다")

  # ---- [4] 취소: cancelIndex가 있을 때만 -----------------------------------
  choice.show(["산다", "안 산다"], { x: 0, y: 0 })
  choice.update({ cancel: true })
  t.check(choice.active?, "cancelIndex가 없으면 취소키를 무시한다")

  choice.show(["산다", "안 산다"], { x: 0, y: 0, cancel_index: 1 })
  choice.update({ cancel: true })
  t.check(!choice.active?, "cancelIndex가 있으면 취소로 빠져나간다")
  t.check_eq(choice.result, 1, "취소는 지정한 번호를 돌려준다")

  # ---- [5] 메시지 창 기준 배치 (오른쪽 위에 붙는다) -----------------------
  choice.show(["예", "아니오"], { anchor: { x: 8, y: 300, w: 360 } })
  w, h = choice.window.width, choice.window.height
  t.check_eq(choice.window.x, 8 + 360 - w, "선택지 창은 메시지 창 오른쪽 끝에 맞춘다")
  t.check_eq(choice.window.y, 300 - h, "메시지 창 바로 위에 놓인다")

  # ---- [6] 항목이 많으면 스크롤한다 ---------------------------------------
  many, _drawn = new_choice.call({ max_visible: 3 })
  many.show(["하나", "둘", "셋", "넷", "다섯"], { x: 0, y: 0 })
  t.check_eq(many.window.height, 3 * 20 + 16, "보이는 항목 수만큼만 창이 커진다")
  first, last = many.visible_range
  t.check(first == 0 && last == 2, "처음에는 1~3번이 보인다", "#{first}..#{last}")

  many.update({ down: true })
  many.update({ down: true })
  first, last = many.visible_range
  t.check(first == 0 && last == 2 && many.index == 2, "3번까지는 스크롤하지 않는다")
  many.update({ down: true })
  first, last = many.visible_range
  t.check(first == 1 && last == 3 && many.index == 3, "4번으로 가면 한 칸 스크롤",
          "#{first}..#{last}")
  many.update({ down: true })
  many.update({ down: true })   # 5 → 1 로 되돌아온다
  first, last = many.visible_range
  t.check(many.index == 0 && first == 0, "처음으로 돌아오면 스크롤도 되돌아온다",
          "#{first}..#{last}")

  # ---- [7] 그리기: 보이는 항목만 그린다 ------------------------------------
  drawable, drawn = new_choice.call({ max_visible: 2 })
  drawable.show(["가", "나", "다"], { x: 10, y: 10 })
  drawable.update(nil)
  drawable.draw
  t.check_eq(drawn.size, 2, "보이는 두 항목만 글자를 그린다")
  t.check_eq(drawn[0][:text], "가", "첫 항목")
  t.check(drawn[1][:y] - drawn[0][:y] == 20, "항목 간격은 줄 높이")

  # ---- [8] 효과음은 있을 때만 부른다 --------------------------------------
  beeps = { cursor: 0, decision: 0 }
  se = {
    cursor: -> { beeps[:cursor] += 1 },
    decision: -> { beeps[:decision] += 1 },
  }
  noisy = Rpg::Choice.new(
    skin: Rpg::Skin.new(path: "fake.png", image_factory: fake_image_factory.call),
    measure: fake_measure, draw_text: ->(_x, _y, _text) {}, se: se, open_frames: 0
  )
  noisy.show(["가", "나"], { x: 0, y: 0 })
  noisy.update({ down: true })
  noisy.update({ confirm: true })
  t.check_eq(beeps[:cursor], 1, "커서 이동 효과음")
  t.check_eq(beeps[:decision], 1, "결정 효과음")

  # ---- [9] 좌표로 항목 집기 (터치 조작, 8단계) ---------------------------
  touch, _drawn = new_choice.call({ line_height: 20, max_visible: 2 })
  touch.show(["가", "나", "다"], { x: 40, y: 60 })
  touch.update(nil)
  cx, cy, cw = touch.window.content_rect

  t.check_eq(touch.index_at(cx + 2, cy + 2), 0, "첫 줄 안을 누르면 1번")
  t.check_eq(touch.index_at(cx + 2, cy + 25), 1, "둘째 줄은 2번")
  t.check_eq(touch.index_at(cx - 5, cy + 2), nil, "창 왼쪽 밖은 없음")
  t.check_eq(touch.index_at(cx + cw + 5, cy + 2), nil, "창 오른쪽 밖은 없음")
  t.check_eq(touch.index_at(cx + 2, cy - 5), nil, "내용 위쪽 밖은 없음")
  t.check_eq(touch.index_at(cx + 2, cy + 45), nil, "보이지 않는 셋째 줄은 없음")

  touch.update({ down: true })   # 커서를 2번으로 옮겨 스크롤 없이 확인
  touch.update({ down: true })   # 3번 → 한 칸 스크롤 (보이는 범위 2..3)
  first, _last = touch.visible_range
  t.check_eq(first, 1, "스크롤된 상태")
  t.check_eq(touch.index_at(cx + 2, cy + 2), 1, "스크롤 뒤 첫 줄은 2번")
  t.check_eq(touch.index_at(cx + 2, cy + 25), 2, "스크롤 뒤 둘째 줄은 3번")

  touch.update({ confirm: true })
  t.check_eq(touch.index_at(cx + 2, cy + 2), nil, "선택이 끝나면 집히지 않는다")

  # ---- [10] 인자 검사 (Lua 의 assert 는 ArgumentError) ---------------------
  no_skin = false
  begin
    Rpg::Choice.new(skin: nil, measure: fake_measure)
  rescue ArgumentError
    no_skin = true
  end
  t.check(no_skin, "skin 없이는 만들 수 없다")

  no_measure = false
  begin
    Rpg::Choice.new(skin: Rpg::Skin.new(image_factory: fake_image_factory.call), measure: nil)
  rescue ArgumentError
    no_measure = true
  end
  t.check(no_measure, "폭 측정 함수 없이는 만들 수 없다")

  empty_items = false
  begin
    choice.show([], { x: 0, y: 0 })
  rescue ArgumentError
    empty_items = true
  end
  t.check(empty_items, "빈 항목 목록은 열 수 없다")
end
