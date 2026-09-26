# Initial2D, mruby 게임 진입점 (S1, S2. docs/plans/s2-ruby-aldebaran.md)
#
# scripts/lua/main.lua 에 대응한다. Lua 스크립트는 scripts/lua/ 에, Ruby 스크립트는 이 폴더
# (scripts/ruby/) 에 둔다. 이 파일은 mruby 를 골랐을 때 읽힌다.
#   INITIAL2D_SCRIPT=mruby ./build/Initial2D
# (또는 game.json 의 "script": "mruby", 또는 main.lua 가 없을 때. ScriptRuntime.h)
#
# 이 저장소의 게임은 「알데바란」이다. 실행하면 타이틀이 뜨고, 시작하면
# 검은 안개의 숲이 열린다 (scripts/ruby/games/aldebaran/). Lua 판과 같은 게임이다.
#
# 씬 계약: init / update(elapsed_ms) / render / destroy
# 씬 전환: 씬 안에서 switch_scene("이름") 호출. 실제 전환은 다음 update 직전에 수행.
# INITIAL2D_AUTOPLAY 환경 변수를 설정하면 자동 시연 모드로 동작한다 (테스트/CI용).
#
# 플래피는 엔진이 장르에 중립이라는 것을 보이는 데모이며 게임의 흐름에 들어 있지 않다.
# INITIAL2D_SCENE=flappy 처럼 이름을 주면 그 씬으로 바로 연다.

require "scripts/ruby/bgm"
require "scripts/ruby/games/aldebaran/title"
require "scripts/ruby/games/aldebaran/game"
require "scripts/ruby/games/flappy"

SCENES = {
  "aldebaran_title" => AldebaranTitleScene,
  "aldebaran" => AldebaranScene,
  # 엔진 데모 (게임 흐름 밖, INITIAL2D_SCENE 으로만 연다)
  "flappy" => FlappyScene,
}
START_SCENE = "aldebaran_title"

$scene = nil
$pending_scene = nil

# 전역: 씬에서 호출하는 씬 전환 요청
def switch_scene(name)
  $pending_scene = name if SCENES.key?(name)
end

def init
  $autoplay = !System.env("INITIAL2D_AUTOPLAY").nil?

  # 폰트는 씬 공용 자원이라 여기서 한 번만 준비한다. BGM 은 씬이 스스로 고른다
  # (scripts/ruby/bgm.rb 가 "지금 걸린 곡"을 들고 있어, 곡이 같으면 다시 틀지 않는다).
  $font_ready = Graphics.prepare_font("./resources/fonts/hangul.fnt")

  name = System.env("INITIAL2D_SCENE")
  $scene = SCENES[name] || SCENES[START_SCENE]
  $scene.init
end

def update(elapsed)
  if $pending_scene
    $scene.destroy
    $scene = SCENES[$pending_scene]
    $pending_scene = nil
    $scene.init
  end

  $scene.update(elapsed)
end

def render
  $scene.render
end

def destroy
  $scene.destroy
  Bgm.stop
end
