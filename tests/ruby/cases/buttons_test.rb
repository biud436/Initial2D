# buttons_test.rb : 동작 버튼(scripts/ruby/ui/buttons.rb)의 판정 로직 검증 (T1). buttons_test.lua 의 Ruby 판.
#
# 히트 슬롭(판정 반경 1.25배), 슬롭 겹침의 승자 결정, 그리고 멀티터치로
# 두 버튼이 동시에 눌리는 것을 가짜 포인터와 가짜 Image로 검증한다.

require "scripts/ruby/ui/buttons"

T.run_case("buttons") do |t|
  # 가짜 Image: Image.create 가 돌려주는 Sprite 의 표면(쓰는 것만)을 흉내내고 호출을 기록한다
  fake_images = []
  fake_image = lambda do |*args|
    img = Object.new
    log = { args: args, frames: nil, scale: nil, position: nil, draws: 0, released: false }
    img.define_singleton_method(:log) { log }
    img.define_singleton_method(:loop=) { |_v| }
    img.define_singleton_method(:scale=) { |v| log[:scale] = v }
    img.define_singleton_method(:set_position) { |x, y| log[:position] = [x, y] }
    img.define_singleton_method(:set_frames) { |a, b| log[:frames] = [a, b] }
    img.define_singleton_method(:current_frame=) { |_f| }
    img.define_singleton_method(:update) { |_e| }
    img.define_singleton_method(:draw) { log[:draws] += 1 }
    img.define_singleton_method(:dispose) { }
    img.define_singleton_method(:release) { log[:released] = true }
    fake_images.push(img)
    img
  end

  pt = lambda do |id, x, y, phase|
    { id: id, x: x, y: y, down: phase == :down, held: phase != :up, up: phase == :up }
  end

  buttons = Ui::Buttons
  t.check(buttons.respond_to?(:hit), "Buttons.hit 존재")
  t.check(buttons.respond_to?(:pick), "Buttons.pick 존재")

  # 히트 슬롭: 표시 반경 밖이라도 1.25배 안이면 맞는다
  item = { x: 100, y: 100, size: 40 } # 중심 (120, 120), 반경 20
  t.check(buttons.hit(item, 120, 141) == false, "표시 반경 밖")
  t.check(buttons.hit(item, 120, 141, 1.25) == true, "슬롭 반경 안")
  t.check(buttons.hit(item, 120, 146, 1.25) == false, "슬롭 반경 밖")
  # Ruby 판 추가: 홀수 크기도 실수 반경 (정수 나눗셈이면 중심이 반 픽셀 어긋난다)
  t.check(buttons.hit({ x: 0, y: 0, size: 41 }, 20.5, 41.0) == true, "홀수 크기: 중심 20.5, 반경 20.5 경계 포함")
  t.check(buttons.hit({ x: 0, y: 0, size: 41 }, 20.5, 41.1) == false, "홀수 크기: 경계 밖")
  t.check(buttons.hit?(item, 120, 141, 1.25) == true, "hit? 는 hit 와 같다")

  # 승자 결정: 겹치는 자리는 중심이 가까운 버튼이 먹는다
  a = { id: :a, x: 0, y: 0, size: 40 }  # 중심 (20, 20)
  b = { id: :b, x: 44, y: 0, size: 40 } # 중심 (64, 20)
  picked = buttons.pick([a, b], 40, 20, 1.25) # a까지 20, b까지 24
  t.check_eq(picked.nil? ? nil : picked[:id], :a, "겹침: 가까운 쪽이 이긴다")
  picked = buttons.pick([a, b], 46, 20, 1.25) # a까지 26 > 25 (슬롭 밖), b까지 18
  t.check_eq(picked.nil? ? nil : picked[:id], :b, "겹침: 반대쪽")
  t.check_eq(buttons.pick([a, b], 200, 200, 1.25), nil, "빈 곳은 nil")

  # 멀티터치: 두 손가락이 두 버튼을 동시에 누른다
  pad = buttons.new(
    image_factory: fake_image,
    items: [
      { id: :jump, x: 300, y: 380, size: 60 },   # 중심 (330, 410)
      { id: :attack, x: 220, y: 380, size: 60 }, # 중심 (250, 410)
    ],
  )
  pad.update([pt.call(1, 330, 410, :down), pt.call(2, 250, 410, :down)])
  t.check(pad.pressed?(:jump) && pad.pressed?(:attack), "동시 두 버튼 엣지")

  # 엣지는 down 틱에만, held는 누르는 동안 계속
  pad.update([pt.call(1, 330, 410, :press), pt.call(2, 250, 410, :press)])
  t.check(!pad.pressed?(:jump) && !pad.pressed?(:attack), "press 틱은 엣지 아님")
  t.check(pad.items[0][:held] && pad.items[1][:held], "press 틱에도 held")

  # 뗀 손가락은 누르지 못한다
  pad.update([pt.call(1, 330, 410, :up), pt.call(2, 250, 410, :press)])
  t.check(!pad.items[0][:held] && pad.items[1][:held], "up은 held 아님")

  # 한 포인터는 버튼 하나만 먹는다 (두 버튼 사이 겹침 자리)
  mid = buttons.new({
    image_factory: fake_image,
    items: [
      { id: :l, x: 0, y: 0, size: 40 },
      { id: :r, x: 44, y: 0, size: 40 },
    ],
  })
  mid.update([pt.call(1, 40, 20, :down)])
  t.check(mid.pressed?(:l) && !mid.pressed?(:r), "겹침 자리는 하나만")

  # contains는 슬롭 포함
  t.check(pad.contains?(330, 447) == true, "contains: 슬롭 포함")
  t.check(pad.contains?(330, 460) == false, "contains: 슬롭 밖")

  # ---- Ruby 판 추가 -----------------------------------------------------------
  # 생성: 시트, 프레임 크기, 텍스처 id, 스케일 (60 / 96 은 실수)
  jump_img = pad.items[0][:img]
  t.check_eq(jump_img.log[:args],
             ["./resources/ui/actionbtn.png", 300, 380, 96, 96, 2, "UIButton:jump"],
             "image_factory 에 Lua 와 같은 인자 (텍스처 id UIButton:jump)")
  t.check_eq(jump_img.log[:scale], 60.0 / 96, "스케일은 size / 96 (실수)")
  # update 가 눌림 프레임을 고른다 (마지막 update: jump 는 뗌, attack 은 누름)
  t.check_eq(jump_img.log[:frames], [0, 0], "뗀 버튼은 프레임 0")
  t.check_eq(pad.items[1][:img].log[:frames], [1, 1], "눌린 버튼은 프레임 1")
  t.check_eq(pad.pressed?(:nope), false, "없는 id 는 false")
  t.check_eq(pad.pressed(:attack), pad.pressed?(:attack), "pressed 는 pressed? 와 같다 (Lua 이름)")

  # 기본 id 와 size: id 가 없으면 :btn1, size 가 없으면 56
  anon = buttons.new(image_factory: fake_image, items: [{ x: 0, y: 0 }])
  t.check_eq(anon.items[0][:id], :btn1, "id 생략은 :btn1")
  t.check_eq(anon.items[0][:size], 56, "size 생략은 56")
  t.check_eq(anon.items[0][:img].log[:args][6], "UIButton:1", "id 생략 텍스처 id 는 UIButton:1")

  # draw: 주입한 measure 와 draw_text 로 라벨을 가운데 그린다
  drawn = []
  labeled = buttons.new(
    image_factory: fake_image,
    measure: ->(text) { text.size * 10 },
    draw_text: ->(x, y, text) { drawn.push([x, y, text]) },
    items: [{ id: :jump, label: "점프", x: 100, y: 200, size: 61 }],
  )
  labeled.draw
  # x = 100 + (61 - 20) / 2 = 120.5, y = 200 + (61 - 16) / 2 - 2 = 220.5 (Lua 는 실수 나눗셈)
  t.check_eq(drawn, [[120.5, 220.5, "점프"]], "라벨 위치 (실수 나눗셈)")
  t.check_eq(labeled.items[0][:img].log[:draws], 1, "draw 가 스프라이트를 그린다")

  # items 가 없으면 오류 (Lua 의 assert)
  raised = false
  begin
    buttons.new(image_factory: fake_image, items: [])
  rescue ArgumentError
    raised = true
  end
  t.check(raised, "items 없으면 ArgumentError")

  # 포인터를 넘기지 않으면 input 에서 만든다 (마우스 폴백)
  mouse = { down: true }
  fake_input = Object.new
  fake_input.define_singleton_method(:mouse_down?) { |btn| btn == 0 && mouse[:down] }
  fake_input.define_singleton_method(:mouse_press?) { |_btn| false }
  fake_input.define_singleton_method(:mouse_up?) { |_btn| false }
  fake_input.define_singleton_method(:mouse_x) { 330.0 }
  fake_input.define_singleton_method(:mouse_y) { 410.0 }
  mp = buttons.new(image_factory: fake_image, input: fake_input,
                   items: [{ id: :jump, x: 300, y: 380, size: 60 }])
  mp.update
  t.check(mp.pressed?(:jump), "input 의 마우스로 누른다")

  # dispose 는 텍스처까지 놓는다 (Lua 의 img.dispose 는 Ruby 에서 release)
  pad_imgs = pad.items.map { |it| it[:img] }
  pad.dispose
  mid.dispose
  t.check(pad_imgs.all? { |img| img.log[:released] }, "dispose 는 release 를 부른다")
  t.check_eq(pad.contains?(330, 410), false, "dispose 뒤에는 버튼이 없다")
  anon.dispose
  labeled.dispose
  mp.dispose

  # 실물 Image::FACTORY (기본값): 텍스처를 읽고 release 로 놓는다
  real = buttons.new(items: [{ id: :jump, label: "점프", x: 10, y: 20, size: 48 }])
  real_img = real.items[0][:img]
  t.check(real_img.is_a?(Sprite) && TextureManager.valid?("UIButton:jump"), "기본 팩토리는 Sprite 와 텍스처")
  t.check_eq(real_img.scale, 0.5, "실물 스프라이트 scale 0.5")
  real.update([pt.call(1, 34, 44, :down)])
  t.check(real.pressed?(:jump) && real_img.start_frame == 1, "실물: 누르면 프레임 1")
  real.draw
  real.dispose
  t.check(real_img.disposed? && !TextureManager.valid?("UIButton:jump"), "실물: dispose 가 텍스처까지 놓는다")
end
