# assets.rb : 리소스 고르기 (8단계, docs/plans/08-demo.md)
# scripts/lua/rpg/assets.lua 의 Ruby 판.
#
# 같은 그림이 두 벌 있다. RPG Maker 2003 RTP를 변환해 둔 로컬 자산과, 저장소에
# 커밋된 플레이스홀더다. RTP 소재는 재배포할 수 없어 저장소에 없으므로 어느
# 게임이든 "있으면 RTP, 없으면 플레이스홀더"를 골라야 하고, 그 규칙이 씬과 맵
# 정의마다 복사되어 있었다. 여기 한 곳에 모은다.
#
# 규격(어느 파일이 어떤 배치인가)은 specs.rb가, 어느 파일을 쓸 것인가는 여기가
# 정한다.
#
#   require "scripts/ruby/rpg/assets"
#   charset = Rpg::Assets.player_charset                 # CharSet 한 장의 경로
#   map = Rpg::Assets.map_path("village", "Exterior")    # 칩셋에 맞는 맵 파일

module Rpg
  module Assets
    # INITIAL2D_NO_RTP 가 있으면 RTP 후보를 아예 보지 않는다. 검수는 어느 기계에서나
    # 같은 그림으로 돌아야 하고(골든 스크린샷), RTP 소재는 재배포할 수 없어 저장소에
    # 없기 때문이다. 개발 중 "RTP 없는 사람에게는 어떻게 보이는가"를 볼 때도 쓴다.
    # (Lua 판의 local 함수 rtpAllowed 에 해당한다. 밖에서는 rtp_enabled? 를 쓴다)
    def self.rtp_allowed?
      return true unless Object.const_defined?(:System) && ::System.respond_to?(:env)
      ::System.env("INITIAL2D_NO_RTP").nil?
    end

    # 지금 RTP 자산을 쓸 수 있는가 (환경 변수로 끌 수 있다)
    def self.rtp_enabled?
      rtp_allowed?
    end

    # 파일이 실제로 있는가 (엔진 없이도 도는 순수 Ruby)
    def self.exists?(path)
      return false unless path.is_a?(String)
      File.exist?(path)
    end

    # 후보를 앞에서부터 보고 처음 있는 것을 고른다. 전부 없으면 마지막 후보.
    # 마지막(플레이스홀더)은 저장소에 있으므로 대개 없을 수가 없지만, 없더라도
    # nil 대신 경로를 돌려주어 오류가 "그림이 안 뜬다"가 아니라 "이 파일이 없다"로
    # 드러나게 한다.
    def self.pick(candidates)
      raise ArgumentError, "assets: 후보가 필요하다" unless candidates.is_a?(Array) && candidates.size > 0
      allow_rtp = rtp_allowed?
      candidates.each do |path|
        is_rtp = path.include?("/rtp/")
        return path if (allow_rtp || !is_rtp) && exists?(path)
      end
      candidates.last
    end

    # 후보 목록. 앞이 RTP(로컬), 뒤가 플레이스홀더(커밋됨).
    PLAYER_CHARSET = ["./resources/rtp/CharSet/Actor1.png", "./resources/charsets/placeholder.png"]
    NPC_CHARSET = ["./resources/rtp/CharSet/People1.png", "./resources/charsets/placeholder.png"]
    FACESET = ["./resources/rtp/FaceSet/People1.png", "./resources/faces/placeholder.png"]
    WINDOWSKIN = ["./resources/rtp/System/System.png", "./resources/ui/window.png"]

    def self.player_charset
      pick(PLAYER_CHARSET)
    end

    def self.npc_charset
      pick(NPC_CHARSET)
    end

    def self.faceset
      pick(FACESET)
    end

    def self.windowskin
      pick(WINDOWSKIN)
    end

    # 맵 파일. 같은 지오메트리를 타일 번호만 바꿔 두 벌 만들어 두었으므로
    # (tools/generate_demo_maps.py) 칩셋이 있으면 RTP 판을, 없으면 기본 판을 연다.
    # base    맵 이름 (village, room)
    # chipset RTP 칩셋 이름 (Exterior, Interior)
    def self.map_path(base, chipset = nil)
      if !chipset.nil? && rtp_allowed? &&
         exists?("./resources/rtp/ChipSet/#{chipset}.png")
        return "./resources/maps/#{base}_rtp.json"
      end
      "./resources/maps/#{base}.json"
    end
  end
end
