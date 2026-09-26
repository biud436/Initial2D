# manifest.rb : 실행할 mruby 테스트 케이스 목록.
# 경로는 워크 디렉터리 기준이다 (tests/ruby/ 가 scripts/ruby/rbtests/ 로 복사된다).
# 새 케이스를 추가하면 여기 명시한다 (Lua 쪽 manifest.lua 와 같은 이유로 자동 스캔하지 않는다).
# S2(알데바란 포팅)의 케이스는 Lua 의 tests/lua/cases/ 와 이름을 맞춘다.

MRUBY_TEST_MANIFEST = [
  # S1: 바인딩
  "scripts/ruby/rbtests/cases/framework_selftest.rb",
  "scripts/ruby/rbtests/cases/api_surface_test.rb",
  "scripts/ruby/rbtests/cases/graphics_test.rb",
  "scripts/ruby/rbtests/cases/input_test.rb",
  "scripts/ruby/rbtests/cases/json_test.rb",
  "scripts/ruby/rbtests/cases/sprite_test.rb",
  "scripts/ruby/rbtests/cases/tilemap_test.rb",
  "scripts/ruby/rbtests/cases/audio_test.rb",
  "scripts/ruby/rbtests/cases/require_test.rb",
  "scripts/ruby/rbtests/cases/fontex_test.rb",
  # S2: 공용 모듈
  "scripts/ruby/rbtests/cases/rpg_rng_test.rb",
  "scripts/ruby/rbtests/cases/bgm_test.rb",
  "scripts/ruby/rbtests/cases/rpg_assets_test.rb",
  "scripts/ruby/rbtests/cases/rpg_specs_test.rb",
  "scripts/ruby/rbtests/cases/rpg_text_test.rb",
  "scripts/ruby/rbtests/cases/rpg_window_test.rb",
  "scripts/ruby/rbtests/cases/rpg_choice_test.rb",
  "scripts/ruby/rbtests/cases/rpg_message_test.rb",
  "scripts/ruby/rbtests/cases/touch_test.rb",
  "scripts/ruby/rbtests/cases/layout_test.rb",
  "scripts/ruby/rbtests/cases/vpad_test.rb",
  "scripts/ruby/rbtests/cases/buttons_test.rb",
  "scripts/ruby/rbtests/cases/input_replay_test.rb",
  # S2: 알데바란
  "scripts/ruby/rbtests/cases/aldebaran_player_test.rb",
  "scripts/ruby/rbtests/cases/aldebaran_combat_test.rb",
  "scripts/ruby/rbtests/cases/aldebaran_monster_test.rb",
  "scripts/ruby/rbtests/cases/aldebaran_monsters_data_test.rb",
  "scripts/ruby/rbtests/cases/aldebaran_climate_test.rb",
  # R1: 씬 로더
  "scripts/ruby/rbtests/cases/scene_loader_test.rb",
]
