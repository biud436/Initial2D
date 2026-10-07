# 입력 경로 검증 씬 (tests/run_engine_tests.py 의 test_input_events_mruby 가 구동)
#
# 러너가 INITIAL2D_TEST_EVENTS 로 SDL 마우스 이벤트 다섯 개를 넣는다. 이 씬은 입력이 있는 틱마다
# input_events_scene.lua 와 같은 줄을 찍고, 다섯 번째 뒤에 mouse_z= 를 확인한 다음 끝낸다.

$tick = 0
$seen = 0
$set_tick = nil

def init
end

def update(elapsed)
  $tick += 1
  any_mouse = Input.any_mouse_down?
  left = Input.mouse_down?(:left)
  any_key = Input.any_key_down?
  wheel = Input.mouse_z
  if any_mouse || left || any_key || wheel != 0
    $seen += 1
    puts "input:any_mouse=#{any_mouse} left=#{left} any_key=#{any_key} wheel=#{wheel}"
    return
  end

  if $set_tick.nil? && $seen >= 5
    $set_tick = $tick
    Input.mouse_z = 7
    puts "input:set_wheel=#{Input.mouse_z}"
  elsif !$set_tick.nil? && $tick == $set_tick + 1
    puts "input:after_set_wheel=#{Input.mouse_z}"
    System.exit
  end
end

def render
end

def destroy
end
