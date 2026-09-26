# input_replay.rb : 입력 시퀀스 재생기 (검수 인프라, docs/plans/09-testing.md 3.4절).
# tests/lua/input_replay.lua 의 Ruby 판.
#
# 엔진 Input 모듈과 같은 표면(Ruby 이름)을 갖는 가짜 Input을 만들어, 프레임 번호에
# 맞춰 정해진 입력을 재생한다. 고정 타임스텝(16ms) 덕분에 같은 시나리오는 항상
# 같은 결과를 낸다. 상태 전이 의미는 엔진의 4-상태 머신과 동일하다:
#   key_down?  = 이번 프레임에 눌리기 시작 (rising edge)
#   key_press? = 계속 눌려 있음
#   key_up?    = 이번 프레임에 떼어짐 (falling edge)
#
# 시나리오 형식 (Symbol 키 Hash 의 배열):
#   [
#     { at: 10, press: "SPACE" },                 # 프레임 10부터 키가 눌림
#     { at: 15, release: "SPACE" },               # 프레임 15에 떼어짐
#     { at: 20, mouse: { x: 100, y: 200 } },      # 마우스 이동
#     { at: 21, click: 0 },                       # 마우스 버튼 0 누름 (:left 도 된다)
#     { at: 23, unclick: 0 },
#     { at: 30, wheel: -1 },
#     { at: 40, touchdown: { id: 1, x: 80, y: 360 } },   # 손가락 1 누름
#     { at: 45, touchmove: { id: 1, x: 120, y: 360 } },  # 끌기
#     { at: 50, touchup: { id: 1 } },             # 뗌 (그 틱에 phase :up 으로 보인다)
#   ]
# 키는 이름("SPACE", "z", :space) 또는 VK 정수(32) 모두 허용한다. 이름은 KEYS 표를
# 먼저 보고, 없으면 엔진의 Keys 모듈(Keys::ENTER, Keys::F1 ...)에서 찾는다.
# 터치는 엔진의 멀티터치 API(touch_count/touch)와 같은 의미로 재생된다:
# 누른 첫 틱은 :down, 이후 :press, 뗀 틱은 :up 으로 한 틱 보인 뒤 사라진다.
#
# 사용법 (씬의 update 첫 줄에서 tick을 호출한다):
#   require "scripts/ruby/rbtests/input_replay"
#   r = InputReplay.new(scenario)
#   r.install              # 최상위 상수 Input 을 교체
#   def update(e) r.tick ... end
#   r.restore              # 원래 Input 복구

class InputReplay
  # Win32 가상 키 코드 (엔진 전 플랫폼 공통 관례, src/platform/WinTypes.h)
  KEYS = {
    "BACKSPACE" => 8, "TAB" => 9, "RETURN" => 13, "SHIFT" => 16, "CONTROL" => 17, "MENU" => 18,
    "ESCAPE" => 27, "SPACE" => 32,
    "PRIOR" => 33, "NEXT" => 34, "END" => 35, "HOME" => 36,
    "LEFT" => 37, "UP" => 38, "RIGHT" => 39, "DOWN" => 40,
    "INSERT" => 45, "DELETE" => 46,
  }
  (0..25).each { |i| KEYS[(65 + i).chr] = 65 + i }  # A~Z
  (0..9).each { |i| KEYS[i.to_s] = 48 + i }         # 0~9

  MOUSE_BUTTONS = { "left" => 0, "right" => 1, "middle" => 2 }

  # 키 이름(String, Symbol) 또는 정수를 VK 정수로 바꾼다. 모르는 이름은 ArgumentError.
  def self.resolve_key(key)
    return key.to_i if key.is_a?(Numeric)
    name = key.to_s.upcase
    vk = KEYS[name]
    return vk unless vk.nil?
    # 엔진 Input 과 같은 규칙으로 Keys 모듈에서 찾는다 (한 글자 숫자는 DIGIT 으로)
    name = "DIGIT" + name if name.size == 1 && name >= "0" && name <= "9"
    if Object.const_defined?(:Keys)
      begin
        return Keys.const_get(name) if Keys.const_defined?(name)
      rescue NameError
        # 상수 이름이 될 수 없는 문자열 (아래에서 오류)
      end
    end
    raise ArgumentError, "input_replay: 알 수 없는 키 이름 " + key.to_s
  end

  # 마우스 버튼: 0, 1, 2 또는 :left, :right, :middle
  def self.resolve_button(btn)
    return btn.to_i if btn.is_a?(Numeric)
    b = MOUSE_BUTTONS[btn.to_s]
    raise ArgumentError, "input_replay: 알 수 없는 마우스 버튼 " + btn.to_s if b.nil?
    b
  end

  # 엔진 Input 과 같은 표면(Ruby 이름)의 가짜. 상태는 재생기(InputReplay)가 들고 있다.
  class FakeInput
    def initialize(replay)
      @r = replay
    end

    def key_down?(key)
      vk = InputReplay.resolve_key(key)
      @r.key_down[vk] == true && @r.key_prev[vk] != true
    end

    def key_press?(key)
      vk = InputReplay.resolve_key(key)
      @r.key_down[vk] == true && @r.key_prev[vk] == true
    end

    def key_up?(key)
      vk = InputReplay.resolve_key(key)
      @r.key_down[vk] != true && @r.key_prev[vk] == true
    end

    # RGSS 식 별명 (엔진 Input 과 같다)
    def trigger?(key)
      key_down?(key)
    end

    def press?(key)
      key_press?(key)
    end

    def release?(key)
      key_up?(key)
    end

    def any_key_down?
      @r.key_down.each do |vk, v|
        return true if v && @r.key_prev[vk] != true
      end
      false
    end

    def mouse_down?(btn)
      b = InputReplay.resolve_button(btn)
      @r.btn_down[b] == true && @r.btn_prev[b] != true
    end

    def mouse_press?(btn)
      b = InputReplay.resolve_button(btn)
      @r.btn_down[b] == true && @r.btn_prev[b] == true
    end

    def mouse_up?(btn)
      b = InputReplay.resolve_button(btn)
      @r.btn_down[b] != true && @r.btn_prev[b] == true
    end

    def any_mouse_down?
      @r.btn_down.each do |b, v|
        return true if v && @r.btn_prev[b] != true
      end
      false
    end

    # 엔진의 mouse_x, mouse_y 는 Float 이다. 가짜도 같게 돌려준다
    # (정수로 두면 게임 쪽 / 가 정수 나눗셈이 되어 실물과 달라진다).
    def mouse_x
      @r.mx.to_f
    end

    def mouse_y
      @r.my.to_f
    end

    def mouse_z
      @r.wheel_value
    end

    def mouse_z=(v)
      @r.wheel_value = v.to_i
    end

    # 멀티터치 (T1). 엔진과 같은 의미: 이번 틱의 손가락 목록에 뗀 손가락이
    # :up 으로 한 틱 남는다. 순서는 id 정렬로 고정한다 (결정성).
    def touch_count
      @r.touch_list.size
    end

    # i 는 0 부터. [id, x, y, :down | :press | :up] 또는 범위 밖이면 nil
    def touch(i)
      @r.touch_list[i]
    end

    def touches
      @r.touch_list
    end

    def inspect
      "#<InputReplay::FakeInput frame=#{@r.frame}>"
    end
  end

  attr_reader :frame, :api, :events, :saved
  attr_reader :key_down, :key_prev, :btn_down, :btn_prev, :touch_now, :touch_prev
  attr_reader :mx, :my
  attr_accessor :wheel_value

  def initialize(scenario = nil)
    @frame = 0
    @key_down = {}
    @key_prev = {}
    @btn_down = {}
    @btn_prev = {}
    @touch_now = {}  # id => { x:, y: }
    @touch_prev = {}
    @mx = 0
    @my = 0
    @wheel_value = 0
    @saved = nil

    # 프레임 => 이벤트 목록 색인
    @events = {}
    (scenario || []).each do |ev|
      unless ev[:at].is_a?(Numeric)
        raise ArgumentError, "input_replay: 이벤트에 at(프레임)이 필요함"
      end
      (@events[ev[:at]] ||= []).push(ev)
    end

    # 엔진 Input 과 같은 표면의 가짜 객체
    @api = FakeInput.new(self)
  end

  # 이번 틱의 손가락 목록 [[id, x, y, phase], ...] (id 정렬). 좌표는 엔진처럼 Float.
  def touch_list
    list = []
    @touch_now.each do |id, p|
      list.push([id, p[:x].to_f, p[:y].to_f, @touch_prev.key?(id) ? :press : :down])
    end
    @touch_prev.each do |id, p|
      list.push([id, p[:x].to_f, p[:y].to_f, :up]) unless @touch_now.key?(id)
    end
    list.sort_by { |t| t[0] }
  end

  # 매 프레임 호출한다. 이전 상태를 스냅샷한 뒤 이번 프레임의 이벤트를 적용한다.
  def tick
    @key_prev = @key_down.dup
    @btn_prev = @btn_down.dup
    @touch_prev = {}
    @touch_now.each { |id, p| @touch_prev[id] = { x: p[:x], y: p[:y] } }

    @frame += 1
    list = @events[@frame]
    return if list.nil?
    list.each do |ev|
      @key_down[InputReplay.resolve_key(ev[:press])] = true if ev[:press]
      @key_down.delete(InputReplay.resolve_key(ev[:release])) if ev[:release]
      @btn_down[InputReplay.resolve_button(ev[:click])] = true if ev[:click]
      @btn_down.delete(InputReplay.resolve_button(ev[:unclick])) if ev[:unclick]
      if ev[:mouse]
        @mx = ev[:mouse][:x]
        @my = ev[:mouse][:y]
      end
      @wheel_value = ev[:wheel] if ev[:wheel]
      if ev[:touchdown]
        @touch_now[ev[:touchdown][:id]] = { x: ev[:touchdown][:x], y: ev[:touchdown][:y] }
      end
      if ev[:touchmove] && @touch_now.key?(ev[:touchmove][:id])
        @touch_now[ev[:touchmove][:id]] = { x: ev[:touchmove][:x], y: ev[:touchmove][:y] }
      end
      @touch_now.delete(ev[:touchup][:id]) if ev[:touchup]
    end
  end

  # 다음 tick에 적용될 이벤트를 지금 예약한다.
  # 시나리오를 미리 다 적어 두는 대신, 화면 상태를 보고 다음 입력을 정하는
  # 대화형 시나리오(8단계의 데모 인수 테스트)에서 쓴다.
  def schedule(ev, delay = nil)
    at = @frame + (delay || 1)
    (@events[at] ||= []).push(ev)
    self
  end

  # 다음 tick부터 키를 누른 채로 둔다 (뗄 때까지 계속 눌려 있다)
  def press(key)
    schedule({ press: key })
  end

  # 다음 tick에 키를 뗀다
  def release(key)
    schedule({ release: key })
  end

  # 한 tick만 눌렀다 뗀다 (결정키처럼 엣지로 쓰는 입력)
  def tap(key)
    schedule({ press: key }, 1)
    schedule({ release: key }, 2)
  end

  # 남은 이벤트가 없으면 true (시나리오 종료 판정용)
  def finished?
    @events.each_key do |at|
      return false if at > @frame
    end
    true
  end

  # 최상위 상수 Input 을 가짜로 바꾼다 (Lua 의 _G.Input = self.api)
  def install
    @saved = ::Input
    Object.send(:remove_const, :Input)
    Object.const_set(:Input, @api)
  end

  def restore
    return if @saved.nil?
    Object.send(:remove_const, :Input)
    Object.const_set(:Input, @saved)
    @saved = nil
  end
end
