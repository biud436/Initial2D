# input_replay_test.rb : 입력 시퀀스 재생기의 상태 전이 의미 검증. input_replay_test.lua 의 Ruby 판.
# 엔진의 4-상태 머신(KB_DOWN, KB_PRESS, KB_UP)과 동일해야 한다.

require "scripts/ruby/rbtests/input_replay"

T.run_case("input_replay") do |t|
  r = InputReplay.new([
    { at: 2, mouse: { x: 100, y: 200 } },
    { at: 3, press: "SPACE" },
    { at: 5, release: "SPACE" },
    { at: 4, click: 0 },
    { at: 6, unclick: 0 },
    { at: 7, wheel: -1 },
  ])
  space = InputReplay::KEYS["SPACE"]

  t.check_eq(space, 32, "키 이름 테이블 (SPACE=32)")
  t.check_eq(InputReplay::KEYS["Z"], 90, "키 이름 테이블 (Z=90)")

  # 프레임 1: 아무 일 없음
  r.tick
  t.check(!r.api.key_down?(space) && !r.api.key_press?(space) &&
          !r.api.key_up?(space), "프레임 1: 입력 없음")

  # 프레임 2: 마우스 이동
  r.tick
  t.check_eq(r.api.mouse_x, 100, "프레임 2: 마우스 X")
  t.check_eq(r.api.mouse_y, 200, "프레임 2: 마우스 Y")

  # 프레임 3: 스페이스 눌림 시작 → Down만 참
  r.tick
  t.check(r.api.key_down?(space), "프레임 3: IsKeyDown (rising edge)")
  t.check(!r.api.key_press?(space), "프레임 3: IsKeyPress 아님")
  t.check(r.api.any_key_down?, "프레임 3: IsAnyKeyDown")

  # 프레임 4: 계속 눌림 → Press만 참. 마우스 클릭 시작
  r.tick
  t.check(!r.api.key_down?(space), "프레임 4: IsKeyDown은 한 프레임만")
  t.check(r.api.key_press?(space), "프레임 4: IsKeyPress (held)")
  t.check(r.api.mouse_down?(0), "프레임 4: IsMouseDown (rising edge)")

  # 프레임 5: 떼어짐 → Up만 참. 마우스는 held
  r.tick
  t.check(r.api.key_up?(space), "프레임 5: IsKeyUp (falling edge)")
  t.check(!r.api.key_down?(space) && !r.api.key_press?(space),
          "프레임 5: Down/Press 아님")
  t.check(r.api.mouse_press?(0), "프레임 5: IsMousePress (held)")

  # 프레임 6: 전부 해제
  r.tick
  t.check(!r.api.key_up?(space), "프레임 6: IsKeyUp도 한 프레임만")
  t.check(r.api.mouse_up?(0), "프레임 6: IsMouseUp (falling edge)")
  t.check(!r.finished?, "프레임 6: 시나리오 아직 안 끝남")

  # 프레임 7: 휠
  r.tick
  t.check_eq(r.api.mouse_z, -1, "프레임 7: 휠 값")
  t.check(r.finished?, "프레임 7: 시나리오 종료 판정")

  # ---- 대화형 예약 (8단계: 화면을 보고 다음 입력을 정하는 시나리오) ------
  live = InputReplay.new([])
  z = 90

  live.tap("Z")
  live.tick
  t.check(live.api.key_down?(z), "tap: 다음 tick에 눌린다")
  live.tick
  t.check(live.api.key_up?(z), "tap: 그 다음 tick에 떼어진다")
  live.tick
  t.check(!live.api.key_down?(z) && !live.api.key_press?(z), "tap: 한 tick뿐")

  live.press("LEFT")
  live.tick
  t.check(live.api.key_down?(37), "press: 눌리기 시작")
  live.tick
  live.tick
  t.check(live.api.key_press?(37), "press: 뗄 때까지 눌린 채로 남는다")
  live.release("LEFT")
  live.tick
  t.check(live.api.key_up?(37), "release: 떼어진다")

  live.schedule({ press: "SPACE" }, 3)
  live.tick
  live.tick
  t.check(!live.api.key_down?(32), "schedule: 아직 아니다")
  live.tick
  t.check(live.api.key_down?(32), "schedule: 지정한 tick 뒤에 들어온다")

  # install/restore가 전역 Input을 교체하고 복구하는지
  original = Input
  r.install
  t.check(Input.equal?(r.api), "install: 전역 Input 교체")
  r.restore
  t.check(Input.equal?(original), "restore: 전역 Input 복구")

  # 멀티터치 재생 (T1): down → press → up 한 틱 → 사라짐
  tr = InputReplay.new([])
  t.check_eq(tr.api.touch_count, 0, "터치: 처음엔 없다")
  tr.schedule({ touchdown: { id: 1, x: 80, y: 360 } }, 1)
  tr.tick
  t.check_eq(tr.api.touch_count, 1, "터치: 손가락 하나")
  id, x, y, phase = tr.api.touch(0)
  t.check(id == 1 && x == 80 && y == 360 && phase == :down,
          "터치: 첫 틱은 down", phase.inspect)
  tr.tick
  _, _, _, p2 = tr.api.touch(0)
  t.check_eq(p2, :press, "터치: 다음 틱은 press")

  # 두 번째 손가락과 끌기
  tr.schedule({ touchdown: { id: 2, x: 300, y: 400 } }, 1)
  tr.schedule({ touchmove: { id: 1, x: 120, y: 360 } }, 1)
  tr.tick
  t.check_eq(tr.api.touch_count, 2, "터치: 두 손가락")
  i1, x1 = tr.api.touch(0)
  i2, _, _, ph2 = tr.api.touch(1)
  t.check(i1 == 1 && x1 == 120, "터치: 끌기가 좌표를 옮긴다", x1.inspect)
  t.check(i2 == 2 && ph2 == :down, "터치: 새 손가락은 down")

  # 뗌: up으로 한 틱 보이고 사라진다
  tr.schedule({ touchup: { id: 1 } }, 1)
  tr.tick
  u1, _, _, up1 = tr.api.touch(0)
  t.check(u1 == 1 && up1 == :up, "터치: 뗀 틱은 up", up1.inspect)
  tr.tick
  t.check_eq(tr.api.touch_count, 1, "터치: up 다음 틱에 사라진다")
  only = tr.api.touch(0)[0]
  t.check_eq(only, 2, "터치: 남은 것은 손가락 2")

  # ---- Ruby 판 추가: Ruby Input 표면과 같게 --------------------------------------
  # 키 이름은 String, Symbol, 소문자, 정수 모두, 없는 이름은 엔진처럼 ArgumentError
  k = InputReplay.new([{ at: 1, press: :z }, { at: 1, press: "x" }, { at: 1, press: 67 },
                       { at: 1, press: :enter }, { at: 1, press: "0" }])
  k.tick
  t.check(k.api.key_down?(:z) && k.api.key_down?(Keys::Z) && k.api.key_down?("Z"), "키: Symbol, 정수, 문자열")
  t.check(k.api.key_down?(:x) && k.api.key_down?(:c), "키: 소문자 이름과 정수 이벤트")
  t.check(k.api.key_down?(:return) && k.api.key_down?(Keys::ENTER), "키: Keys 에만 있는 이름 (:enter)")
  t.check(k.api.key_down?(:"0") && k.api.key_down?(Keys::DIGIT0), "키: 숫자 이름")
  t.check(k.api.trigger?(:z) && !k.api.press?(:z) && !k.api.release?(:z), "trigger?/press?/release? 별명")
  bad = false
  begin
    k.api.key_down?(:no_such_key)
  rescue ArgumentError
    bad = true
  end
  t.check(bad, "모르는 키 이름은 ArgumentError")

  # 마우스: 좌표는 엔진처럼 Float, 버튼은 0/1/2 와 :left/:right/:middle
  m = InputReplay.new([{ at: 1, mouse: { x: 7, y: 9 }, click: :left }, { at: 1, click: 1 },
                       { at: 2, unclick: 0 }])
  m.tick
  t.check_type(m.api.mouse_x, Float, "mouse_x 는 Float")
  t.check(m.api.mouse_down?(:left) && m.api.mouse_down?(0) && m.api.mouse_down?(:right), "마우스 버튼 이름")
  t.check(!m.api.mouse_down?(:middle), ":middle 은 안 눌림")
  t.check(m.api.any_mouse_down?, "any_mouse_down?")
  m.tick
  t.check(m.api.mouse_up?(:left) && m.api.mouse_press?(:right) && !m.api.any_mouse_down?, "마우스 뗌과 누른 채")
  m.api.mouse_z = 3
  t.check_eq(m.api.mouse_z, 3, "mouse_z=")

  # touches 와 범위 밖 touch
  t.check_eq(tr.api.touches, [[2, 300.0, 400.0, :press]], "touches 는 [id, x, y, phase] 배열")
  t.check_eq(tr.api.touch(5), nil, "범위 밖 touch 는 nil")

  # 이벤트 at 이 없으면 오류 (Lua 의 assert)
  bad_at = false
  begin
    InputReplay.new([{ press: "Z" }])
  rescue ArgumentError
    bad_at = true
  end
  t.check(bad_at, "at 없는 이벤트는 ArgumentError")

  # install 중에는 최상위 Input 을 읽는 코드(Touch.pointers 등)가 가짜를 본다
  require "scripts/ruby/ui/touch"
  s = InputReplay.new([{ at: 1, touchdown: { id: 4, x: 10, y: 20 } }])
  s.install
  begin
    s.tick
    ps = Ui::Touch.pointers(Input)
    t.check(ps.size == 1 && ps[0][:id] == 4 && ps[0][:down], "install 중 Touch.pointers(Input) 가 가짜 손가락을 본다")
  ensure
    s.restore
  end
  t.check(Input.equal?(original), "restore 뒤 원래 Input")
  t.check_eq(s.frame, 1, "frame 은 tick 수")
end
