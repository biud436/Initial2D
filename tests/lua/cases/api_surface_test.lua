-- api_surface_test.lua : 엔진이 Lua에 노출하는 API 표면의 계약 검증.
-- 바인딩이 실수로 빠지거나 이름이 바뀌면 여기서 잡힌다.
-- 새 바인딩을 추가하면(1단계: GetTextWidth, Json.Load 등) 이 목록도 갱신할 것.

local M = {}

local GLOBALS = {
    "print", "MessageBox", "LoadScript", "PreparaFont", "DrawText",
    "GetTextWidth",
    "WindowWidth", "WindowHeight", "SetRenderScale", "GetRenderScale",
    "GetFrameCount", "GameExit",
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
    Json = { "Load" },
    Sprite = { "Create", "Update", "Draw", "Dispose", "SetPosition", "GetPosition",
               "SetScale", "SetAngle", "SetVisible", "SetOpacity",
               "SetFrames", "SetCurrentFrame", "SetRect", "SetLoop",
               "SetSheetGrid", "GetRect" },
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

    -- 값 계약: 논리 해상도 (game.json, INITIAL2D_WINDOW, 렌더 배율로 결정된다)
    t.check_type(WindowWidth(), "number", "WindowWidth()가 숫자를 돌려준다")
    t.check(WindowWidth() > 0 and WindowHeight() > 0, "논리 해상도가 양수다")

    -- 렌더 배율: 논리 해상도를 나눈다. 다른 케이스에 영향이 없도록 반드시 되돌린다.
    local baseW, baseH = WindowWidth(), WindowHeight()
    t.check_eq(GetRenderScale(), 1, "기본 배율은 1")
    t.check_eq(SetRenderScale(2), 2, "SetRenderScale은 적용된 배율을 돌려준다")
    t.check(WindowWidth() == baseW // 2 and WindowHeight() == baseH // 2,
        "배율 2에서 논리 해상도는 절반", WindowWidth() .. "x" .. WindowHeight())
    t.check_eq(SetRenderScale(-5), 1, "0 이하는 1로 잘린다")
    t.check_eq(SetRenderScale(100), 16, "상한 16으로 잘린다")
    SetRenderScale(1)
    t.check(WindowWidth() == baseW and WindowHeight() == baseH,
        "배율을 1로 되돌리면 원래 해상도")
end

return M
