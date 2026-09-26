# 씬 로더 플래피 인수 씬, Ruby 판 (tests/run_engine_tests.py 가 구동, R1)
#
# resources/templates/main.rb 와 같은 진입점이다. 러너가 INITIAL2D_SCENE=flappy 와
# INITIAL2D_AUTOPLAY 를 주면 resources/scenes/flappy.json 이 Ruby 컴포넌트
# (scripts/ruby/components/flappy/)로 열리고, Director 가 상태 전이와 점수를 stdout 으로 알린 뒤
# 900틱에 스스로 끝낸다 (mruby_flappy_scene.rb 와 같은 검사).

require "scripts/ruby/scene_loader"

$scene = nil

def init
  game = begin
    Json.load("./game.json")
  rescue RuntimeError
    nil
  end
  game = {} unless game.is_a?(Hash)
  $scene = SceneLoader.open(System.env("INITIAL2D_SCENE") || game["startScene"] || "main")
end

def update(elapsed)
  $scene = $scene.tick(elapsed)
end

def render
  $scene.draw
end

def destroy
  $scene.close
end
