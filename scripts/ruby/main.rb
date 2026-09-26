# Initial2D, mruby 게임 진입점 (S1, docs/plans/s1-mruby-binding.md)
#
# scripts/lua/main.lua 에 대응한다. Lua 스크립트는 scripts/lua/ 에, Ruby 스크립트는 이 폴더
# (scripts/ruby/) 에 둔다. 이 파일은 mruby 를 골랐을 때 읽힌다.
#   INITIAL2D_SCRIPT=mruby ./build/Initial2D
# (또는 game.json 의 "script": "mruby", 또는 main.lua 가 없을 때. ScriptRuntime.h)
#
# 씬 계약: init / update(elapsed_ms) / render / destroy
# 씬 전환: 씬 안에서 switch_scene("이름") 호출. 실제 전환은 다음 update 직전에 수행.
#
# 지금 Ruby 로 쓰인 씬은 플래피 하나다. 다른 데모(알데바란, 마을)는 Lua 다.
# INITIAL2D_SCENE=flappy 처럼 이름을 주면 그 씬으로 바로 연다.

require "scripts/ruby/games/flappy"

SCENES = {
  "flappy" => FlappyScene,
}
START_SCENE = "flappy"

$scene = nil
$pending_scene = nil

# 전역: 씬에서 호출하는 씬 전환 요청
def switch_scene(name)
  $pending_scene = name if SCENES.key?(name)
end

def init
  # 폰트는 씬 공용 자원이라 여기서 한 번만 준비한다
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
end
