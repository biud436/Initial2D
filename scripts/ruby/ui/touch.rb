# touch.rb : 터치와 마우스를 포인터 목록 하나로 합친다 (범용 UI 모듈, T1).
# scripts/lua/ui/touch.lua 의 Ruby 판.
#
# 엔진에 멀티터치 API(Input.touch_count/touch)가 있으면 손가락들을,
# 마우스(눌려 있거나 이번 틱에 떨어진 경우)를 포인터로 만들어 한 목록에 담는다.
# 터치 API가 없는 표면(옛 빌드, 테스트의 가짜 Input)에서는 자연히 마우스만 남아
# 기존 단일 터치 동작과 같다.
#
# SDL은 첫 손가락을 마우스로도 흉내내므로 같은 손가락이 터치와 마우스로 두 번
# 보일 수 있다. 방향과 버튼 판정은 합집합이라 중복은 무해하고, 포인터를 잡는
# (소유권) 쪽은 id로 잡으므로 중복이 상태를 흔들지 않는다.
#
# 포인터: { id:, x:, y:, down:, held:, up: }  (마우스의 id 는 :mouse)
#   down: 이번 틱에 눌리기 시작    held: 눌려 있음 (down인 틱 포함)
#   up:   이번 틱에 떨어짐 (이 틱을 끝으로 목록에서 사라진다)

module Ui
  module Touch
    # input(엔진 Input과 같은 표면)에서 이번 틱의 포인터 목록을 만든다.
    # touch(i) 는 0 부터이고 [id, x, y, :down | :press | :up] 또는 nil 을 돌려준다.
    def self.pointers(input)
      list = []

      if input.respond_to?(:touch_count)
        n = input.touch_count
        (0...n).each do |i|
          touch = input.touch(i)
          next if touch.nil?
          id, x, y, phase = touch
          next if id.nil?
          list.push({
            id: id, x: x, y: y,
            down: phase == :down,
            held: phase != :up,
            up: phase == :up,
          })
        end
      end

      down = input.mouse_down?(0)
      held = down || input.mouse_press?(0)
      up = input.mouse_up?(0)
      if held || up
        list.push({
          id: :mouse, x: input.mouse_x, y: input.mouse_y,
          down: down, held: held, up: up,
        })
      end

      list
    end
  end
end
