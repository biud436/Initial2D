-- luatest.lua : Lua 단위 테스트 프레임워크 (검수 인프라, docs/plans/09-testing.md 3.2절)
-- 엔진 바이너리로 실행된다. 케이스 파일은 tests/lua/cases/ 에 추가하고
-- manifest.lua 목록에 명시한다.

local M = { pass = 0, fail = 0 }

function M.check(cond, label, detail)
    if cond then
        M.pass = M.pass + 1
        print("  PASS  " .. label)
    else
        M.fail = M.fail + 1
        print("  FAIL  " .. label .. (detail and ("  |  " .. tostring(detail)) or ""))
    end
end

function M.check_eq(actual, expected, label)
    M.check(actual == expected, label,
        string.format("실제 %s, 기대 %s", tostring(actual), tostring(expected)))
end

function M.check_type(value, typename, label)
    M.check(type(value) == typename, label,
        string.format("type은 %s, 기대 %s", type(value), typename))
end

-- pcall로 케이스를 실행해 런타임 오류도 FAIL로 집계한다
function M.run_case(name, module)
    print("[" .. name .. "]")
    local ok, err = pcall(module.run, M)
    if not ok then
        M.fail = M.fail + 1
        print("  FAIL  케이스 실행 오류  |  " .. tostring(err))
    end
end

function M.summary()
    -- 러너(파이썬)가 파싱하는 고정 형식. 바꾸면 run_engine_tests.py도 함께 바꿀 것.
    print(string.format("LUA_TESTS_RESULT: %d PASS / %d FAIL", M.pass, M.fail))
end

return M
