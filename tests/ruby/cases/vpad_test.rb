# vpad_test.rb : 가상 D-패드 모듈(scripts/ruby/ui/vpad.rb)의 순수 로직 검증. vpad_test.lua 의 Ruby 판.
# 방향 판정은 순수 함수라 엔진 입력 없이 검증한다. 화면 표시는 데모 씬에서 눈으로 확인.

require "scripts/ruby/ui/vpad"

T.run_case("vpad") do |t|
  t.check(System.respond_to?(:platform), "GetPlatform 존재")
  plat = System.platform
  t.check(plat.is_a?(String) && plat == plat.downcase && plat.size > 0, "GetPlatform은 소문자 문자열", plat.inspect)

  virtual_pad = Ui::VirtualPad
  t.check(virtual_pad.respond_to?(:new), "VirtualPad.new 존재")
  t.check(virtual_pad.respond_to?(:direction), "VirtualPad.direction 존재")
  t.check(virtual_pad.respond_to?(:should_show?), "VirtualPad.shouldShow 존재")

  r = 76.8 # size 160 기준 반경과 데드존
  d = 16
  dir = ->(dx, dy, radius, deadzone) { virtual_pad.direction(dx, dy, radius, deadzone) }

  # 4방향 (y는 아래가 양수)
  t.check_eq(dir.call(0, -50, r, d), :up, "위")
  t.check_eq(dir.call(0, 50, r, d), :down, "아래")
  t.check_eq(dir.call(-50, 0, r, d), :left, "왼쪽")
  t.check_eq(dir.call(50, 0, r, d), :right, "오른쪽")

  # 대각선 경계: |dx| > |dy| 이면 좌우, 아니면 상하
  t.check_eq(dir.call(40, -30, r, d), :right, "대각선 (dx 우세) → 오른쪽")
  t.check_eq(dir.call(30, -40, r, d), :up, "대각선 (dy 우세) → 위")
  t.check_eq(dir.call(-30, 30, r, d), :down, "정확한 대각선은 상하 우선")

  # 데드존과 반경 밖
  t.check_eq(dir.call(5, 5, r, d), nil, "데드존 안은 nil")
  t.check_eq(dir.call(0, 0, r, d), nil, "중심은 nil")
  t.check_eq(dir.call(100, 0, r, d), nil, "반경 밖은 nil")
  t.check_eq(dir.call(0, -r, r, d), :up, "반경 경계(포함)는 방향")

  # 크기: 시트 원본(160px)보다 작게 만들어도 프레임 전체가 그려져야 한다.
  # 엔진 Sprite는 스프라이트 크기를 소스 프레임 크기로 그대로 쓰므로, 표시
  # 크기를 그대로 넘기면 시트의 일부만 잘려 나온다 (2026-08-16 Galaxy S24
  # 실기에서 렌더 배율 2로 패드를 절반 크기로 만들었을 때 발견).
  small = virtual_pad.new({ x: 10, y: 20, size: 80 })
  rect = small.image.rect
  t.check_eq(rect[:x], 0, "0번 프레임의 소스 x")
  t.check_eq(rect[:y], 0, "0번 프레임의 소스 y")
  t.check_eq(small.image.width, 160, "소스 프레임 폭은 시트 원본 크기")
  t.check_eq(small.image.height, 160, "소스 프레임 높이는 시트 원본 크기")
  t.check_eq(small.scale, 0.5, "표시 크기는 스케일로 맞춘다")
  # Ruby 판 추가: 정수끼리 나눗셈이 되면 0 이 된다. 스프라이트에 들어간 값도 본다
  t.check_eq(small.image.scale, 0.5, "스프라이트 scale 도 0.5 (정수 나눗셈 아님)")

  # 방향 프레임도 시트 원본 격자로 잘린다 (5x1의 두 번째 칸 = x 160)
  small.image.current_frame = 1
  t.check_eq(small.image.rect[:x], 160, "위 방향 프레임의 소스 x")

  # 히트 판정은 표시 크기 기준이다 (중심에서 반경 밖은 nil)
  t.check_eq(small.hit_test(10 + 40, 20 + 40), nil, "표시 크기 중심은 데드존")
  t.check_eq(small.hit_test(10 + 40, 20 + 10), :up, "표시 크기 기준 위쪽")
  t.check_eq(small.hit_test(10 + 40, 20 + 200), nil, "표시 크기 밖은 nil")
  # Ruby 판 추가: contains? 는 잡기 반경(표시 크기의 0.48) 기준
  t.check(small.contains?(50, 60) && small.contains?(50 + 38, 60) && !small.contains?(50 + 39, 60),
          "contains?: 잡기 반경 38.4 안팎")
  small.dispose
  t.check(small.image.disposed?, "dispose 는 스프라이트를 놓는다")
  t.check_eq(TextureManager.valid?("UIDpad"), false, "dispose 는 텍스처까지 놓는다 (Lua 의 img.dispose)")

  # 표시 규칙: 데스크톱에서는 기본 숨김, INITIAL2D_VPAD가 있으면 표시
  if plat != "android" && plat != "ios"
    forced = !System.env("INITIAL2D_VPAD").nil?
    t.check_eq(virtual_pad.should_show?, forced, "데스크톱: 환경 변수 없이는 숨김")
  else
    t.check_eq(virtual_pad.should_show?, true, "터치 플랫폼: 표시")
  end

  # ---- 조이스틱 소유권 (T1) -------------------------------------------------
  # update(pointers)로 포인터 목록을 직접 넣어 검증한다.
  # 패드: (10, 20) 크기 80 → 중심 (50, 60), 반경 38.4, 데드존 8

  pad = virtual_pad.new(x: 10, y: 20, size: 80)
  pt = lambda do |id, x, y, phase|
    { id: id, x: x, y: y, down: phase == :down, held: phase != :up, up: phase == :up }
  end

  # 잡기: 패드 안에서 눌린 포인터
  pad.update([pt.call(1, 70, 60, :down)])
  t.check_eq(pad.pressed, :right, "잡기: 안에서 눌리면 방향")
  # Ruby 판 추가: pressed?(dir) 와 이미지 프레임
  t.check(pad.pressed?(:right) && !pad.pressed?(:left), "pressed?(:right)")
  t.check_eq(pad.image.current_frame, 2, "오른쪽이면 프레임 2")

  # 조이스틱: 잡힌 동안 원 밖으로 끌어도 유지된다
  pad.update([pt.call(1, 300, 60, :press)])
  t.check_eq(pad.pressed, :right, "끌기: 반경 밖에서도 방향 유지")
  pad.update([pt.call(1, 50, -100, :press)])
  t.check_eq(pad.pressed, :up, "끌기: 방향은 계속 따라간다")

  # 두 번째 손가락은 소유권을 뺏지 못한다
  pad.update([pt.call(1, 70, 60, :press), pt.call(2, 30, 60, :down)])
  t.check_eq(pad.pressed, :right, "소유권: 두 번째 손가락 무시")

  # 놓기: up이면 풀린다
  pad.update([pt.call(1, 70, 60, :up)])
  t.check_eq(pad.pressed, nil, "놓기: up이면 nil")
  t.check_eq(pad.image.current_frame, 0, "놓으면 프레임 0")

  # 놓은 뒤에는 다른 포인터가 잡을 수 있다
  pad.update([pt.call(2, 30, 60, :down)])
  t.check_eq(pad.pressed, :left, "다시 잡기: 새 포인터")
  pad.update([])
  t.check_eq(pad.pressed, nil, "포인터가 사라지면 풀린다")

  # 밖에서 눌린 포인터는 잡히지 않는다 (밖에서 눌러 안으로 끌어도 무시)
  pad.update([pt.call(3, 200, 60, :down)])
  t.check_eq(pad.pressed, nil, "밖에서 누르면 무시")
  pad.update([pt.call(3, 70, 60, :press)])
  t.check_eq(pad.pressed, nil, "밖에서 눌러 안으로 끌어도 무시")

  # Ruby 판 추가: set_position 은 판정 중심과 스프라이트를 함께 옮긴다
  pad.set_position(110, 20)
  t.check(pad.x == 110 && pad.image.x == 110.0, "set_position 이 스프라이트도 옮긴다")
  t.check_eq(pad.hit_test(150, 30), :up, "set_position 뒤 판정 중심 (150, 60)")
  pad.dispose

  # 마우스 폴백: 터치 API가 없는 표면(가짜 Input)에서는 마우스가 포인터가 된다
  fake_state = { mx: 70, my: 60, down: true, press: false, up: false }
  fake = Object.new
  fake.define_singleton_method(:mouse_down?) { |btn| btn == 0 && fake_state[:down] }
  fake.define_singleton_method(:mouse_press?) { |btn| btn == 0 && fake_state[:press] }
  fake.define_singleton_method(:mouse_up?) { |btn| btn == 0 && fake_state[:up] }
  fake.define_singleton_method(:mouse_x) { fake_state[:mx] }
  fake.define_singleton_method(:mouse_y) { fake_state[:my] }
  mpad = virtual_pad.new(x: 10, y: 20, size: 80, input: fake)
  mpad.update
  t.check_eq(mpad.pressed, :right, "마우스 폴백: down에 잡는다")
  fake_state[:down] = false
  fake_state[:press] = true
  fake_state[:mx] = 30
  mpad.update
  t.check_eq(mpad.pressed, :left, "마우스 폴백: 누른 채 이동")
  fake_state[:press] = false
  fake_state[:up] = true
  mpad.update
  t.check_eq(mpad.pressed, nil, "마우스 폴백: 떼면 풀린다")
  mpad.dispose

  # Ruby 판 추가: Layout.controls 의 pad Hash 를 그대로 받는다
  lpad = virtual_pad.new({ x: 13, y: 301, size: 134 })
  t.check(lpad.x == 13 && lpad.y == 301 && lpad.size == 134, "pad Hash 를 그대로 받는다")
  lpad.update # 헤드리스 엔진 Input: 손가락도 마우스도 없다
  t.check_eq(lpad.pressed, nil, "엔진 Input 기본값: 입력 없으면 nil")
  lpad.dispose
end
