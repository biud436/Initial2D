-- lua_error_scene.lua : 스크립트 오류가 PANIC(abort) 이 아니라 "파일:줄: 메시지" 한 줄과 종료 코드 1 로
-- 끝나는지 본다 (test_lua_error_scene). 에디터 콘솔이 이 줄을 링크로 만든다 (InitialEditor E1).
-- 두 번째 프레임에서 일부러 nil 을 인덱싱한다.

local frame = 0

function Initialize()
    print("lua_error:init")
end

function Update(elapsed)
    frame = frame + 1
    if frame == 2 then
        local t = nil
        print(t.field) -- 여기서 오류
    end
end

function Render()
end

function Destroy()
    print("lua_error:destroy")
end
