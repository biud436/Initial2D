# Initial2D, mruby 게임 진입점 (docs/plans/s2-ruby-aldebaran.md)
#
# 이 파일은 스크립트 언어로 mruby를 선택했을 때 읽힌다.
#   INITIAL2D_SCRIPT=mruby ./build/Initial2D
# (또는 game.json의 "script": "mruby", 또는 main.lua가 없을 때. ScriptRuntime.h)
#
# 이 저장소의 게임은 「알데바란」이다. 실행하면 타이틀이 표시되고, 시작하면
# 첫 스테이지 「검은 안개의 숲」이 시작된다 (scripts/ruby/games/aldebaran/).
#
# 씬 계약: init / update(elapsed_ms) / render / destroy
# 씬 전환: 씬 안에서 switch_scene("이름")을 호출한다. 실제 전환은 다음 update 직전에 수행한다.
# INITIAL2D_AUTOPLAY 환경 변수를 설정하면 자동 시연 모드로 동작한다 (테스트/CI용).
#
# 플래피는 엔진이 장르에 중립이라는 것을 보이는 데모이며 게임의 흐름에 들어 있지 않다.
# INITIAL2D_SCENE=flappy처럼 이름을 주면 그 씬으로 바로 시작한다.

require "scripts/ruby/bgm"
require "scripts/ruby/games/aldebaran/title"
require "scripts/ruby/games/aldebaran/game"
require "scripts/ruby/games/flappy"

SCENES = {
  "aldebaran_title" => AldebaranTitleScene,
  "aldebaran" => AldebaranScene,
  # 엔진 데모 (게임 흐름 밖, INITIAL2D_SCENE으로만 시작한다)
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

  # 폰트는 씬 공용 자원이라 여기서 한 번만 준비한다. BGM은 씬이 직접 선택한다
  # (scripts/ruby/bgm.rb가 재생 중인 곡을 기억하고 있어, 곡이 같으면 다시 재생하지 않는다).
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
