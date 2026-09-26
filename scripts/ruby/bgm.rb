# bgm.rb : 배경음 한 곡의 재생 상태를 관리하는 모듈 (docs/plans/08-demo.md)
#
# 재생 중인 곡을 기억해 두고, 같은 곡을 다시 요청하면 아무것도 하지 않는다
# (Audio.play_music은 호출할 때마다 곡을 처음부터 다시 시작한다).
#
#   require "scripts/ruby/bgm"
#   Bgm.play("./resources/audio/bless.ogg")        # 이미 그 곡이면 무시
#   Bgm.play("./resources/audio/town.ogg", volume: 80)
#   Bgm.stop
#
# 곡마다 음압이 다르므로 볼륨을 곡과 함께 지정한다 (docs/music/의 LUFS 비교표).

module Bgm
  DEFAULT_ID = "bgm"
  DEFAULT_VOLUME = 96

  @audio = nil       # 주입된 Audio (없으면 호출 시점의 엔진 Audio 모듈)
  @playing = nil     # 재생 중인 파일 경로
  @playing_id = nil

  # 테스트가 가짜 Audio를 주입한다. nil을 주면 엔진 Audio로 되돌아간다.
  # 가짜는 엔진 Audio와 같은 메서드(play_music, volume=, release_music, stop_music)를 가진다.
  def self.bind(mock)
    @audio = mock
  end

  def self.backend
    return @audio unless @audio.nil?
    Object.const_defined?(:Audio) ? ::Audio : nil
  end

  # 재생 중인 곡의 경로 (없으면 nil)
  def self.current
    @playing
  end

  # 곡을 재생한다. 이미 같은 곡이 재생 중이면 아무것도 하지 않는다.
  # path          OGG/WAV 경로. nil이면 아무것도 하지 않는다 (곡 없는 맵)
  # opts[:id]     Audio 쪽 식별자 (기본 "bgm")
  # opts[:loop]   기본 true
  # opts[:volume] 0~128, 기본 96
  # opts[:force]  같은 곡이어도 처음부터 다시 시작
  # 돌려주는 값: 실제로 재생을 시작했으면 true
  def self.play(path, opts = {})
    return false if path.nil?
    opts ||= {}
    a = backend
    return false if a.nil? || !a.respond_to?(:play_music)

    if @playing == path && !opts[:force]
      a.volume = opts[:volume] if !opts[:volume].nil? && a.respond_to?(:volume=)
      return false
    end

    id = opts[:id] || DEFAULT_ID
    # 곡을 바꿀 때는 앞 곡을 해제한다 (엔진은 메모리를 수동으로 해제한다)
    if !@playing_id.nil? && @playing_id != id && a.respond_to?(:release_music)
      a.release_music(@playing_id)
    end

    loop = opts[:loop]
    loop = true if loop.nil?
    a.play_music(path, id, loop)
    if a.respond_to?(:volume=)
      a.volume = opts[:volume] || DEFAULT_VOLUME
    end

    @playing = path
    @playing_id = id
    true
  end

  # 곡을 멈추고 해제한다.
  def self.stop
    a = backend
    if a.nil?
      @playing = nil
      @playing_id = nil
      return
    end
    a.stop_music if a.respond_to?(:stop_music)
    a.release_music(@playing_id) if !@playing_id.nil? && a.respond_to?(:release_music)
    @playing = nil
    @playing_id = nil
  end

  # 재생 상태는 그대로 두고 기억한 경로만 지운다 (테스트와 씬 재시작용)
  def self.forget
    @playing = nil
    @playing_id = nil
  end
end
