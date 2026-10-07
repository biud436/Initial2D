-- audio_test.lua : Audio 모듈. 커밋된 bless.ogg 로 재생 API 를 부른다 (헤드리스에서도 로드는 된다).

local M = {}

function M.run(t)
    t.check_eq(Audio.PlayMusic("./resources/audio/bless.ogg", "test_bgm", true), true, "PlayMusic 로드와 재생")
    t.check_eq(Audio.PlayMusic("./resources/audio/bless.ogg", "test_bgm"), true, "PlayMusic 의 loop 는 생략할 수 있다")
    t.check_eq(Audio.GetVolume(), 255, "기본 볼륨 255")

    -- GetVolume 은 SetVolume 에 준 값을 돌려준다 (0..255 밖은 잘린다)
    Audio.SetVolume(100)
    t.check_eq(Audio.GetVolume(), 100, "SetVolume(100)")
    Audio.SetVolume(300)
    t.check_eq(Audio.GetVolume(), 255, "255 를 넘는 값은 255")
    Audio.SetVolume(-1)
    t.check_eq(Audio.GetVolume(), 0, "음수는 0")
    Audio.SetVolume(255)

    t.check_eq(Audio.PlaySound("./resources/audio/bless.ogg", "test_se"), true, "PlaySound 의 loop 는 생략할 수 있다")
    t.check_eq(Audio.PlaySound("./resources/audio/bless.ogg", "test_se", 0), true, "PlaySound (숫자 루프)")
    t.check_eq(Audio.PlayMusic("./resources/audio/no_such.ogg", "nope"), false, "없는 파일은 false")
    t.check_eq(Audio.PlaySound("./resources/audio/no_such.wav", "nope_se"), false, "없는 효과음 파일은 false")
    t.check_eq(Audio.InsertNextMusic("./resources/audio/bless.ogg", "test_next"), true, "InsertNextMusic 의 loop 는 생략할 수 있다")
    t.check(not pcall(Audio.PlaySound), "경로 없이 부르면 오류")

    Audio.StopMusic()
    Audio.ReleaseMusic("test_bgm")
    Audio.ReleaseMusic("test_next")
end

return M
