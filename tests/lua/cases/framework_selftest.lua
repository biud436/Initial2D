-- framework_selftest.lua : 테스트 프레임워크 자체가 동작하는지 확인한다.

local M = {}

function M.run(t)
    t.check(1 + 1 == 2, "check가 참을 통과시킨다")
    t.check_eq("가" .. "나", "가나", "check_eq 문자열 비교 (UTF-8)")
    t.check_type(print, "function", "check_type 함수 판별")

    -- pcall 오류 집계 확인: 의도적 오류를 스스로 잡아 본다
    local ok = pcall(function() error("의도적 오류") end)
    t.check(ok == false, "pcall이 오류를 잡는다")
end

return M
