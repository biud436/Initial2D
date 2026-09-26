# 씬 로더 픽스처 씬, Ruby 판 (tests/run_engine_tests.py 가 구동, R1)
#
# scene_loader_scene.lua 를 한 줄씩 옮긴 것이다. 같은 픽스처를 Ruby 씬 로더로 열고 같은 형식의
# 줄을 stdout 으로 알리며, 러너는 화면을 Lua 씬과 **같은 골든**(scene_loader)에 견준다.

require "scripts/ruby/scene_loader"

$scene = nil
$ticks = 0

def init
  $scene = SceneLoader.open("fixtures/scenes/sample_v1.json")
  puts "scene:name:#{$scene.name}"
  puts "scene:order:#{$scene.objects.map(&:id).join(',')}"
  puts "scene:editorOnly:#{$scene.source['editorOnly'] && $scene.source['editorOnly']['note']}"
  puts "scene:tileEditorOnly:#{$scene.find('tile').spec['editorOnly']['locked']}"
  tile = $scene.find("tile")
  puts "scene:tile:#{tile.x},#{tile.y} frame #{tile.frame_width}x#{tile.frame_height}"
  puts "scene:map:layers #{$scene.find('map').layer_count}"
  puts "scene:anim:frame #{$scene.find('anim').sprite.current_frame}"
end

def update(elapsed)
  $scene = $scene.tick(elapsed)
  $ticks += 1
  puts "scene:tick#{$ticks}:tile.x=#{$scene.find('tile').x}" if $ticks <= 3
end

def render
  $scene.draw
end

def destroy
  puts "scene:final:tile.x=#{$scene.find('tile').x}"
  $scene.close
  puts "scene:closed:#{$scene.closed?}"
end
