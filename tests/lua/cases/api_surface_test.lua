-- api_surface_test.lua : 엔진이 Lua에 노출하는 API 표면의 계약 검증.
-- 바인딩이 실수로 빠지거나 이름이 바뀌면 여기서 잡힌다.
-- 새 바인딩을 추가하면(1단계: GetTextWidth, Json.Load 등) 이 목록도 갱신할 것.

local M = {}

local GLOBALS = {
    "print", "MessageBox", "LoadScript", "PreparaFont", "DrawText",
    "GetTextWidth",
    "WindowWidth", "WindowHeight", "GetFrameCount", "GameExit",
    "draw_text", "draw_point", "draw_set_color",
    "GetCurrentDirectory", "SetAppIcon", "GetResourcesFiles",
}

local MODULES = {
    Input = { "IsKeyDown", "IsKeyUp", "IsKeyPress", "IsAnyKeyDown",
              "GetMouseX", "GetMouseY", "IsMouseDown", "IsMouseUp",
              "IsMousePress", "IsAnyMouseDown", "GetMouseZ", "SetMouseZ" },
    Audio = { "PlayMusic", "PlaySound", "SetVolume", "GetVolume",
              "PauseMusic", "StopMusic", "ResumeMusic", "IsPlayingMusic",
              "FadeOutMusic", "SetMusicPosition", "ReleaseMusic" },
    TextureManager = { "Load", "Remove", "IsValid" },
    Sprite = { "Create", "Update", "Draw", "SetPosition", "GetPosition",
               "SetScale", "SetAngle", "SetVisible", "SetOpacity",
               "SetFrames", "SetCurrentFrame", "SetRect", "SetLoop" },
}

function M.run(t)
    for _, name in ipairs(GLOBALS) do
        t.check_type(_G[name], "function", "전역 " .. name)
    end

    for moduleName, fns in pairs(MODULES) do
        t.check_type(_G[moduleName], "table", "모듈 " .. moduleName)
        if type(_G[moduleName]) == "table" then
            for _, fn in ipairs(fns) do
                t.check_type(_G[moduleName][fn], "function", moduleName .. "." .. fn)
            end
        end
    end

    -- 값 계약: 논리 해상도 (현재 768x896 하드코딩, 1단계에서 설정 가능해지면 갱신)
    t.check_type(WindowWidth(), "number", "WindowWidth()가 숫자를 돌려준다")
    t.check(WindowWidth() > 0 and WindowHeight() > 0, "논리 해상도가 양수다")
end

return M
