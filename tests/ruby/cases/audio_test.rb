# audio_test.rb : Audio 모듈. 커밋된 bless.ogg 로 재생 API 를 부른다 (헤드리스에서도 로드는 된다).

T.run_case("audio") do |t|
  t.check_eq(Audio.play_music("./resources/audio/bless.ogg", "test_bgm", true), true, "play_music 로드와 재생")
  t.check_type(Audio.volume, Integer, "volume 은 Integer")
  t.check_eq(Audio.volume, 255, "기본 볼륨 255")

  # volume 은 volume= 에 준 값을 돌려준다 (0..255 밖은 잘린다)
  Audio.volume = 100
  t.check_eq(Audio.volume, 100, "volume= 100")
  Audio.volume = 300
  t.check_eq(Audio.volume, 255, "255 를 넘는 값은 255")
  Audio.volume = -1
  t.check_eq(Audio.volume, 0, "음수는 0")
  Audio.volume = 255

  t.check([true, false].include?(Audio.playing_music?), "playing_music? 는 불리언")
  t.check_eq(Audio.play_sound("./resources/audio/bless.ogg", "test_se", 1), true, "play_sound (숫자 루프)")
  t.check_eq(Audio.play_sound("./resources/audio/bless.ogg", "test_se"), true, "play_sound (기본 한 번)")
  t.check_eq(Audio.play_music("./resources/audio/no_such.ogg", "nope"), false, "없는 파일은 false")
  t.check_eq(Audio.play_sound("./resources/audio/no_such.wav", "nope_se"), false, "없는 효과음 파일은 false")
  t.check_eq(Audio.insert_next_music("./resources/audio/bless.ogg", "test_next"), true, "insert_next_music 로드와 예약")

  Audio.pause_music
  Audio.resume_music
  Audio.music_position = 0.5
  Audio.fade_out_music(10)
  Audio.stop_music
  Audio.release_music("test_bgm")
  Audio.release_music("test_next")
  t.check(true, "pause / resume / position / fade / stop / release 호출")
end
