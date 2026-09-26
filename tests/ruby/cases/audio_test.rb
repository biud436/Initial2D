# audio_test.rb : Audio 모듈. 커밋된 bless.ogg 로 재생 API 를 부른다 (헤드리스에서도 로드는 된다).

T.run_case("audio") do |t|
  t.check_eq(Audio.play_music("./resources/audio/bless.ogg", "test_bgm", true), true, "play_music 로드와 재생")
  t.check_type(Audio.volume, Integer, "volume 은 Integer")
  t.check_eq(Audio.volume, 128, "기본 볼륨 128")

  # 엔진의 setVolume 은 0..255 를 받아 SDL_mixer 의 0..128 로 바꾸고 (SoundManager.cpp),
  # getVolume 은 SDL_mixer 값을 그대로 돌려준다. Lua 의 SetVolume/GetVolume 과 같은 계약이다.
  Audio.volume = 255
  t.check_eq(Audio.volume, 128, "volume= 255 는 SDL_mixer 최대 128")
  Audio.volume = 100
  t.check_eq(Audio.volume, 50, "volume= 100 은 128 * 100 / 255 = 50")
  Audio.volume = 0
  t.check_eq(Audio.volume, 0, "volume= 0")
  Audio.volume = 255

  t.check([true, false].include?(Audio.playing_music?), "playing_music? 는 불리언")
  t.check_eq(Audio.play_sound("./resources/audio/bless.ogg", "test_se", 1), true, "play_sound (숫자 루프)")
  t.check_eq(Audio.play_sound("./resources/audio/bless.ogg", "test_se"), true, "play_sound (기본 한 번)")
  t.check_eq(Audio.play_music("./resources/audio/no_such.ogg", "nope"), false, "없는 파일은 false")

  Audio.pause_music
  Audio.resume_music
  Audio.music_position = 0.5
  Audio.fade_out_music(10)
  Audio.stop_music
  Audio.release_music("test_bgm")
  t.check(true, "pause / resume / position / fade / stop / release 호출")
end
