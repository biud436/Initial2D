-- json_load_test.lua : Json.Load 바인딩 검증 (1단계, docs/plans/01-engine-core.md)
-- 테스트 데이터는 워크 디렉터리에 직접 만들어 외부 파일 의존을 없앤다.

local M = {}

local SAMPLE = [[{
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
}]]

function M.run(t)
    t.check_type(Json, "table", "Json 모듈 존재")
    t.check_type(Json.Load, "function", "Json.Load 존재")

    -- 테스트 파일 생성
    local f = assert(io.open("./json_test_data.json", "w"))
    f:write(SAMPLE)
    f:close()

    local data, err = Json.Load("./json_test_data.json")
    t.check(data ~= nil, "샘플 로드 성공", err)
    if data == nil then return end

    t.check_eq(data.name, "마을", "문자열 값 (UTF-8)")
    t.check_eq(data.id, 7, "정수 값")
    t.check_eq(data.scale, 1.5, "실수 값")
    t.check_eq(data.visible, true, "불리언 true")
    t.check_eq(data.hidden, false, "불리언 false")
    t.check_eq(data.empty, nil, "null은 nil")
    t.check_eq(math.type(data.id), "integer", "정수는 Lua integer로")

    t.check_eq(#data.layers, 2, "배열 길이")
    t.check_eq(data.layers[1].name, "ground", "중첩 객체 접근")
    t.check_eq(data.layers[1].data[3], 3, "중첩 배열 접근 (1부터 시작)")
    t.check_eq(#data.layers[2].data, 0, "빈 배열은 빈 테이블")

    -- 오류 계약: 없는 파일과 깨진 JSON은 nil + 메시지
    local missing, err1 = Json.Load("./no_such_file.json")
    t.check(missing == nil and type(err1) == "string", "없는 파일: nil + 오류 메시지")

    local bad = assert(io.open("./json_bad_data.json", "w"))
    bad:write("{ broken !!")
    bad:close()
    local parsed, err2 = Json.Load("./json_bad_data.json")
    t.check(parsed == nil and type(err2) == "string", "깨진 JSON: nil + 오류 메시지", err2)

    -- 백슬래시 경로도 NormalizePath로 열린다
    local viaBackslash = Json.Load(".\\json_test_data.json")
    t.check(viaBackslash ~= nil and viaBackslash.id == 7, "백슬래시 경로 정규화")

    -- 32비트를 넘는 정수는 64비트 integer, 64비트 부호 없는 범위의 큰 값은 실수 (게임 전체가 멈추지 않는다)
    local big = assert(io.open("./json_big_data.json", "w"))
    big:write('{"a": 2147483648, "b": -2147483649, "c": 9007199254740993, "d": 18446744073709551615}')
    big:close()
    local nums, err3 = Json.Load("./json_big_data.json")
    t.check(nums ~= nil, "32비트를 넘는 정수가 든 파일도 읽힌다", err3)
    if nums ~= nil then
        t.check_eq(nums.a, 2147483648, "2^31 은 integer")
        t.check_eq(math.type(nums.a), "integer", "2^31 의 타입")
        t.check_eq(nums.b, -2147483649, "-2^31-1 은 integer")
        t.check_eq(nums.c, 9007199254740993, "2^53+1 도 정확한 integer")
        t.check_eq(math.type(nums.d), "float", "int64 밖의 부호 없는 값은 실수")
    end

    os.remove("./json_test_data.json")
    os.remove("./json_bad_data.json")
    os.remove("./json_big_data.json")
end

return M
