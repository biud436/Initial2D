# json_test.rb : Json.load / Json.parse 바인딩 검증. Lua 의 json_load_test.lua 에 대응한다.
# 테스트 데이터는 워크 디렉터리에 직접 만들어 외부 파일 의존을 없앤다.

JSON_SAMPLE = <<~JSON
  {
    "name": "마을",
    "id": 7,
    "tileWidth": 16,
    "scale": 1.5,
    "visible": true,
    "hidden": false,
    "empty": null,
    "layers": [
      { "name": "ground", "data": [1, 2, 3] },
      { "name": "deco", "data": [] }
    ]
  }
JSON

T.run_case("json") do |t|
  File.open("./json_test_data.json", "w") { |f| f.write(JSON_SAMPLE) }

  data = Json.load("./json_test_data.json")
  t.check_type(data, Hash, "객체는 Hash")
  t.check_eq(data["name"], "마을", "문자열 값 (UTF-8)")
  t.check_eq(data["id"], 7, "정수 값")
  t.check_type(data["id"], Integer, "정수는 Integer")
  t.check_eq(data["scale"], 1.5, "실수 값")
  t.check_type(data["scale"], Float, "실수는 Float")
  t.check_eq(data["visible"], true, "불리언 true")
  t.check_eq(data["hidden"], false, "불리언 false")
  t.check_eq(data["empty"], nil, "null 은 nil")
  t.check(data.key?("empty"), "null 키도 존재한다")

  t.check_eq(data["layers"].size, 2, "배열 길이")
  t.check_eq(data["layers"][0]["name"], "ground", "중첩 객체 접근")
  t.check_eq(data["layers"][0]["data"][2], 3, "중첩 배열 접근 (0 부터 시작)")
  t.check_eq(data["layers"][1]["data"], [], "빈 배열은 빈 Array")

  # 오류 계약: 없는 파일과 깨진 JSON 은 RuntimeError
  missing = nil
  begin
    Json.load("./no_such_file.json")
  rescue RuntimeError => e
    missing = e.message
  end
  t.check(missing.is_a?(String) && missing.include?("no_such_file"), "없는 파일: RuntimeError + 경로", missing)

  File.open("./json_bad_data.json", "w") { |f| f.write("{ broken !!") }
  broken = nil
  begin
    Json.load("./json_bad_data.json")
  rescue RuntimeError => e
    broken = e.message
  end
  t.check(broken.is_a?(String) && broken.include?("parse error"), "깨진 JSON: RuntimeError", broken)

  via_backslash = Json.load(".\\json_test_data.json")
  t.check(via_backslash.is_a?(Hash) && via_backslash["id"] == 7, "백슬래시 경로 정규화")

  parsed = Json.parse('{"a": [1, 2.5, null], "b": "가"}')
  t.check_eq(parsed, { "a" => [1, 2.5, nil], "b" => "가" }, "Json.parse 문자열")
  t.check_eq(Json.parse("[1, 2, 3]"), [1, 2, 3], "최상위 배열")

  parse_bad = false
  begin
    Json.parse("{ nope")
  rescue RuntimeError
    parse_bad = true
  end
  t.check(parse_bad, "깨진 문자열은 RuntimeError")

  # 32비트를 넘는 정수와 int64 밖의 부호 없는 값
  big = Json.parse('{"a": 2147483648, "b": -2147483649, "c": 9007199254740993, "d": 18446744073709551615}')
  t.check_eq(big["a"], 2147483648, "2^31 은 Integer")
  t.check_type(big["a"], Integer, "2^31 의 타입")
  t.check_eq(big["b"], -2147483649, "-2^31-1 은 Integer")
  t.check_eq(big["c"], 9007199254740993, "2^53+1 도 정확한 Integer")
  t.check_type(big["d"], Float, "int64 밖의 부호 없는 값은 Float")

  File.delete("./json_test_data.json")
  File.delete("./json_bad_data.json")
end
