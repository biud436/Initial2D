-- run_tests.lua : Lua 단위 테스트 진입점.
-- 러너(run_engine_tests.py)가 이 파일을 워크 디렉터리의 scripts/main.lua로 복사해
-- 엔진 바이너리로 실행한다. 첫 프레임에 전부 실행하고 즉시 종료한다.

local t = require("scripts/luatests/luatest")

function Initialize()
    print("[lua_unit_tests]")
    local manifest = require("scripts/luatests/manifest")
    for _, name in ipairs(manifest) do
        local ok, module = pcall(require, name)
        if ok then
            t.run_case(name, module)
        else
            t.fail = t.fail + 1
            print("  FAIL  케이스 로드 실패: " .. name .. "  |  " .. tostring(module))
        end
    end
    t.summary()
    GameExit()
end

function Update(elapsed) end
function Render() end
function Destroy() end
