# mruby 플래피 인수 씬 (tests/run_engine_tests.py 가 구동, S1)
# scripts/ruby/games/flappy.rb 를 그대로 열고 INITIAL2D_AUTOPLAY 로 자동 시연시킨다.
# 상태 전이와 점수를 stdout 으로 알리고, 정한 틱 수가 지나면 스스로 끝낸다
# (헤드리스에서는 프레임이 틱보다 빨리 돌아 INITIAL2D_EXIT_AFTER 로는 시간을 잴 수 없다).

require "scripts/ruby/games/flappy"

TICK_BUDGET = 900 # 60Hz 기준 15초. 자동 시연은 약 290틱에 첫 파이프를 지난다

def init
  $font_ready = Graphics.prepare_font("./resources/fonts/hangul.fnt")
  # 파이프 간격은 난수다. 물리는 고정 스텝이라 씨앗을 고정하면 매번 같은 판이 된다.
  # 씨앗 1은 900틱 안에 5점을 내고 한 번 죽어 다시 시작한다 (씨앗 1..6 모두 1점 이상).
  srand(Integer(System.env("INITIAL2D_FLAPPY_SEED") || 1))
  FlappyScene.init
  @ticks = 0
  @last_state = nil
  @last_score = nil
  @done = false
end

def update(elapsed)
  return if @done
  FlappyScene.update(elapsed)
  @ticks += 1

  if FlappyScene.state != @last_state
    @last_state = FlappyScene.state
    puts "flappy:state:#{@last_state}"
  end
  if FlappyScene.score != @last_score
    @last_score = FlappyScene.score
    puts "flappy:score:#{@last_score}"
  end

  if @ticks >= TICK_BUDGET
    @done = true
    puts "flappyFinal state=#{FlappyScene.state} score=#{FlappyScene.score} best=#{FlappyScene.best} ticks=#{@ticks}"
    System.exit
  end
end

def render
  FlappyScene.render
end

def destroy
  FlappyScene.destroy
end
