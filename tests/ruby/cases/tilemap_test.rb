# tilemap_test.rb : Tilemap 클래스 검증. Lua 의 tilemap_test.lua 에 대응한다.
# 포맷 계약 픽스처(tests/fixtures/maps/sample_v1.json, 4x3 2레이어)로 값을 통제한다.
# 픽스처는 러너가 워크 디렉터리의 ./fixtures/ 로 복사한다.
# **레이어는 0 기준이다** (Ruby 배열 관례. Lua 바인딩은 1 기준).

TILEMAP_FIXTURE = "./fixtures/maps/sample_v1.json"

T.run_case("tilemap") do |t|
  text = File.read(TILEMAP_FIXTURE)
  t.check(text.is_a?(String) && !text.empty?, "픽스처 존재 (#{TILEMAP_FIXTURE})")

  small = Tilemap.new(TILEMAP_FIXTURE)
  t.check_type(small, Tilemap, "픽스처 맵 로드")
  t.check_eq(small.size, [4, 3, 16, 16, 2], "size -> [w, h, tw, th, layers]")
  t.check_eq([small.width, small.height], [4, 3], "width / height")
  t.check_eq([small.tile_width, small.tile_height], [16, 16], "tile_width / tile_height")
  t.check_eq(small.layer_count, 2, "layer_count")

  # 행 우선 인덱싱: data[y*W + x], x, y, layer 모두 0 기준
  t.check_eq(small.tile_id(0, 0, 0), 1, "tile_id (0,0)")
  t.check_eq(small.tile_id(3, 0, 0), 4, "tile_id 행 끝 (3,0)")
  t.check_eq(small.tile_id(0, 1, 0), 5, "tile_id 다음 행 (0,1)")
  t.check_eq(small.tile_id(3, 2, 0), 12, "tile_id 마지막 (3,2)")
  t.check_eq(small.tile_id(1, 1, 1), 5, "tile_id deco 레이어 (index 1)")
  t.check_eq(small.tile_id(0, 0, 1), 0, "deco 빈 칸은 0")

  # 범위 밖 계약: gid 0
  t.check_eq(small.tile_id(-1, 0, 0), 0, "x 음수는 0")
  t.check_eq(small.tile_id(4, 0, 0), 0, "x 초과는 0")
  t.check_eq(small.tile_id(0, 3, 0), 0, "y 초과는 0")
  t.check_eq(small.tile_id(0, 0, 2), 0, "없는 레이어는 0")

  # set_tile_id
  t.check_eq(small.set_tile_id(2, 1, 0, 99), true, "set_tile_id 성공")
  t.check_eq(small.tile_id(2, 1, 0), 99, "set_tile_id 반영")
  t.check_eq(small.set_tile_id(-1, 0, 0, 5), false, "범위 밖 set_tile_id 거부")
  t.check_eq(small.set_tile_id(0, 0, 2, 5), false, "없는 레이어 set_tile_id 거부")
  t.check_eq(small.set_tile_id(0, 0, 0, -3), false, "음수 gid 거부")

  # passable?: collision [0,0,0,1 / 0,1,0,0 / 1,0,0,0]
  t.check_eq(small.passable?(0, 0), true, "통행 가능 (0,0)")
  t.check_eq(small.passable?(3, 0), false, "통행 불가 (3,0)")
  t.check_eq(small.passable?(1, 1), false, "통행 불가 (1,1)")
  t.check_eq(small.passable?(0, 2), false, "통행 불가 (0,2)")
  t.check_eq(small.passable?(1, 2), true, "통행 가능 (1,2)")
  t.check_eq(small.passable?(-1, 0), false, "범위 밖은 통행 불가")

  # 그리기 스모크
  small.draw(0, 1, 0, 0)
  small.draw(0, 1, -8, -8)
  small.draw(0, 1)
  small.draw(1, 0) # 빈 범위는 무시
  t.check(true, "draw 스모크 (컬링 포함) 오류 없음")

  small.dispose
  t.check_eq(small.disposed?, true, "dispose 뒤 disposed?")
  after = false
  begin
    small.width
  rescue RuntimeError
    after = true
  end
  t.check(after, "dispose 뒤 사용은 RuntimeError")

  # 오류 계약
  missing = nil
  begin
    Tilemap.new("./no_such_map.json")
  rescue RuntimeError => e
    missing = e.message
  end
  t.check(missing.is_a?(String) && !missing.empty?, "없는 파일: RuntimeError + 메시지", missing)
  t.check_eq(Tilemap.load("./no_such_map.json"), nil, "Tilemap.load 는 실패하면 nil")

  File.open("./tilemap_bad_size.json", "w") { |f| f.write(text.sub('"width": 4', '"width": 5')) }
  t.check_eq(Tilemap.load("./tilemap_bad_size.json"), nil, "데이터 크기 불일치는 nil")

  File.open("./tilemap_v2.json", "w") { |f| f.write(text.sub('"version": 1', '"version": 2')) }
  v2 = Tilemap.load("./tilemap_v2.json")
  t.check(!v2.nil?, "포맷 v2도 열린다")
  t.check_eq(v2.tile_id(3, 2, 0), 12, "v2의 타일 값도 v1과 같다") if v2

  File.open("./tilemap_bad_ver.json", "w") { |f| f.write(text.sub('"version": 1', '"version": 99')) }
  t.check_eq(Tilemap.load("./tilemap_bad_ver.json"), nil, "지원하지 않는 버전은 nil")

  # 타입이 틀린 값은 jsoncpp 가 C++ 예외(Json::LogicError)를 던진다. 바인딩 경계(MRUBY_GUARD)에서
  # RuntimeError 가 되어 rescue 로 잡히고, 메시지는 "타입: 메시지" 다
  File.open("./tilemap_bad_type.json", "w") { |f| f.write(text.sub('"version": 1', '"version": "x"')) }
  cpp = nil
  begin
    Tilemap.new("./tilemap_bad_type.json")
  rescue RuntimeError => e
    cpp = e.message
  end
  t.check_eq(cpp, "Json::LogicError: Value is not convertible to Int.", "C++ 예외는 RuntimeError (타입: 메시지)")
  t.check_eq(Tilemap.load("./tilemap_bad_type.json"), nil, "C++ 예외가 난 맵도 Tilemap.load 는 nil")

  File.delete("./tilemap_bad_size.json")
  File.delete("./tilemap_v2.json")
  File.delete("./tilemap_bad_ver.json")
  File.delete("./tilemap_bad_type.json")

  # 커밋된 샘플 맵
  sample = Tilemap.load("./resources/maps/sample.json")
  t.check(!sample.nil?, "샘플 맵 로드 성공")
  t.check_eq(sample.size, [80, 70, 16, 16, 2], "샘플 맵 크기 80x70, 16px, 2레이어") if sample
end
