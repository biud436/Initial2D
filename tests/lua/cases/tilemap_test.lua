-- tilemap_test.lua : Tilemap.* 바인딩 검증 (2단계, docs/plans/02-tilemap.md)
-- 포맷 계약 픽스처(tests/fixtures/maps/sample_v1.json, 4x3 2레이어)로 값을
-- 전부 통제하고, 커밋된 샘플 맵(resources/maps/sample.json)으로 실전 로드를
-- 확인한다. 픽스처는 러너가 워크 디렉터리의 ./fixtures/로 복사한다.

local M = {}

local FIXTURE = "./fixtures/maps/sample_v1.json"

local function readFile(path)
    local f = io.open(path, "r")
    if f == nil then return nil end
    local text = f:read("*a")
    f:close()
    return text
end

local function writeFile(path, text)
    local f = assert(io.open(path, "w"))
    f:write(text)
    f:close()
end

function M.run(t)
    t.check_type(Tilemap, "table", "Tilemap 모듈 존재")
    for _, name in ipairs({ "Load", "Dispose", "Draw", "GetSize",
                            "GetTileId", "SetTileId", "IsPassable" }) do
        t.check_type(Tilemap[name], "function", "Tilemap." .. name .. " 존재")
    end

    -- ---- 계약 픽스처: 값 전수 통제 (ground gid가 1..12 순번이라
    --      행 우선 인덱싱이 그대로 드러난다) --------------------------------
    local fixtureText = readFile(FIXTURE)
    t.check(fixtureText ~= nil, "픽스처 존재 (" .. FIXTURE .. ")")
    if fixtureText == nil then return end

    local small, err = Tilemap.Load(FIXTURE)
    t.check(small ~= nil, "픽스처 맵 로드 성공", err)
    if small == nil then return end

    local w, h, tw, th, layers = Tilemap.GetSize(small)
    t.check_eq(w, 4, "GetSize width")
    t.check_eq(h, 3, "GetSize height")
    t.check_eq(tw, 16, "GetSize tileWidth")
    t.check_eq(th, 16, "GetSize tileHeight")
    t.check_eq(layers, 2, "GetSize layerCount")

    -- 행 우선 인덱싱: data[y*W + x], x·y는 0 기준, layer는 1 기준
    t.check_eq(Tilemap.GetTileId(small, 0, 0, 1), 1, "GetTileId (0,0)")
    t.check_eq(Tilemap.GetTileId(small, 3, 0, 1), 4, "GetTileId 행 끝 (3,0)")
    t.check_eq(Tilemap.GetTileId(small, 0, 1, 1), 5, "GetTileId 다음 행 (0,1)")
    t.check_eq(Tilemap.GetTileId(small, 3, 2, 1), 12, "GetTileId 마지막 (3,2)")
    t.check_eq(Tilemap.GetTileId(small, 1, 1, 2), 5, "GetTileId deco 레이어")
    t.check_eq(Tilemap.GetTileId(small, 0, 0, 2), 0, "deco 빈 칸은 0")

    -- 범위 밖 계약: gid 0
    t.check_eq(Tilemap.GetTileId(small, -1, 0, 1), 0, "x 음수는 0")
    t.check_eq(Tilemap.GetTileId(small, 4, 0, 1), 0, "x 초과는 0")
    t.check_eq(Tilemap.GetTileId(small, 0, 3, 1), 0, "y 초과는 0")
    t.check_eq(Tilemap.GetTileId(small, 0, 0, 3), 0, "없는 레이어는 0")

    -- SetTileId
    t.check_eq(Tilemap.SetTileId(small, 2, 1, 1, 99), true, "SetTileId 성공")
    t.check_eq(Tilemap.GetTileId(small, 2, 1, 1), 99, "SetTileId 반영")
    t.check_eq(Tilemap.SetTileId(small, -1, 0, 1, 5), false, "범위 밖 SetTileId 거부")
    t.check_eq(Tilemap.SetTileId(small, 0, 0, 3, 5), false, "없는 레이어 SetTileId 거부")
    t.check_eq(Tilemap.SetTileId(small, 0, 0, 1, -3), false, "음수 gid 거부")

    -- IsPassable: collision [0,0,0,1 / 0,1,0,0 / 1,0,0,0]
    t.check_eq(Tilemap.IsPassable(small, 0, 0), true, "통행 가능 (0,0)")
    t.check_eq(Tilemap.IsPassable(small, 3, 0), false, "통행 불가 (3,0)")
    t.check_eq(Tilemap.IsPassable(small, 1, 1), false, "통행 불가 (1,1)")
    t.check_eq(Tilemap.IsPassable(small, 0, 2), false, "통행 불가 (0,2)")
    t.check_eq(Tilemap.IsPassable(small, 1, 2), true, "통행 가능 (1,2)")
    t.check_eq(Tilemap.IsPassable(small, -1, 0), false, "범위 밖은 통행 불가")
    t.check_eq(Tilemap.IsPassable(small, 4, 0), false, "범위 밖은 통행 불가 (x)")

    -- 그리기 스모크: 오류 없이 호출만 되면 된다 (픽셀 검증은 엔진 씬 테스트)
    Tilemap.Draw(small, 1, 2, 0, 0)
    Tilemap.Draw(small, 1, 2, -8, -8)
    Tilemap.Draw(small, 2, 1, 0, 0) -- 빈 범위는 무시
    t.check(true, "Draw 스모크 (컬링 포함) 오류 없음")

    Tilemap.Dispose(small)

    -- ---- 오류 계약 -------------------------------------------------------
    local missing, err1 = Tilemap.Load("./no_such_map.json")
    t.check(missing == nil and type(err1) == "string", "없는 파일: nil + 오류 메시지")

    writeFile("./tilemap_bad_size.json", fixtureText:gsub('"width": 4', '"width": 5'))
    local bad, err2 = Tilemap.Load("./tilemap_bad_size.json")
    t.check(bad == nil and type(err2) == "string", "데이터 크기 불일치: nil + 오류", err2)

    writeFile("./tilemap_bad_ver.json", fixtureText:gsub('"version": 1', '"version": 2'))
    local badv, err3 = Tilemap.Load("./tilemap_bad_ver.json")
    t.check(badv == nil and type(err3) == "string", "지원하지 않는 버전: nil + 오류", err3)

    os.remove("./tilemap_bad_size.json")
    os.remove("./tilemap_bad_ver.json")

    -- ---- 커밋된 샘플 맵 ----------------------------------------------------
    local sample, err4 = Tilemap.Load("./resources/maps/sample.json")
    t.check(sample ~= nil, "샘플 맵 로드 성공", err4)
    if sample == nil then return end

    local sw, sh, stw, sth, slayers = Tilemap.GetSize(sample)
    t.check(sw == 80 and sh == 70 and stw == 16 and sth == 16 and slayers == 2,
        "샘플 맵 크기 80x70, 16px, 2레이어",
        string.format("%dx%d %dx%d %d", sw, sh, stw, sth, slayers))

    -- 생성 규칙으로 고정된 값들: 외곽 울타리와 연못
    t.check_eq(Tilemap.GetTileId(sample, 2, 2, 2), 73, "샘플: 울타리 왼끝 gid")
    t.check_eq(Tilemap.GetTileId(sample, 3, 2, 2), 74, "샘플: 울타리 몸통 gid")
    t.check_eq(Tilemap.GetTileId(sample, 8, 6, 2), 59, "샘플: 연못 좌상 gid")
    t.check_eq(Tilemap.IsPassable(sample, 2, 2), false, "샘플: 울타리 통행 불가")
    t.check_eq(Tilemap.IsPassable(sample, 8, 6), false, "샘플: 연못 통행 불가")
    t.check_eq(Tilemap.IsPassable(sample, 5, 5), true, "샘플: 잔디 통행 가능")
    t.check_eq(Tilemap.IsPassable(sample, 0, 0), false, "샘플: 맵 가장자리 통행 불가")

    Tilemap.Dispose(sample)
end

return M
