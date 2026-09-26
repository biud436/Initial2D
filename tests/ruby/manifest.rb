# manifest.rb : 실행할 mruby 테스트 케이스 목록.
# 경로는 워크 디렉터리 기준이다 (tests/ruby/ 가 scripts/ruby/rbtests/ 로 복사된다).
# 새 케이스를 추가하면 여기 명시한다 (Lua 쪽 manifest.lua 와 같은 이유로 자동 스캔하지 않는다).

MRUBY_TEST_MANIFEST = [
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
]
