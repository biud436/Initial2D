# assets.rb : 리소스 파일 고르기 (docs/plans/08-demo.md)
#
# 같은 그림이 두 종류 있다. RPG Maker 2003 RTP를 변환한 로컬 자산과, 저장소에
# 커밋된 플레이스홀더다. RTP 소재는 재배포할 수 없어 저장소에 없으므로, 이 모듈은
# "RTP가 있으면 RTP, 없으면 플레이스홀더"를 골라 경로를 돌려준다.
#
# 규격(어느 파일이 어떤 배치인가)은 specs.rb가 정하고, 어느 파일을 쓸 것인가는
# 이 모듈이 정한다.
#
#   require "scripts/ruby/rpg/assets"
#   charset = Rpg::Assets.player_charset                 # CharSet 한 장의 경로
#   map = Rpg::Assets.map_path("village", "Exterior")    # 칩셋에 맞는 맵 파일

module Rpg
  module Assets
    # INITIAL2D_NO_RTP가 설정되어 있으면 RTP 후보를 검사하지 않는다 (골든 스크린샷이
    # 어느 기계에서나 같아야 하므로 검수는 RTP 없이 실행한다). 밖에서는 rtp_enabled?를 쓴다.
    def self.rtp_allowed?
      return true unless Object.const_defined?(:System) && ::System.respond_to?(:env)
      ::System.env("INITIAL2D_NO_RTP").nil?
    end

    # 지금 RTP 자산을 쓸 수 있는가 (환경 변수로 끌 수 있다)
    def self.rtp_enabled?
      rtp_allowed?
    end

    # 파일이 있는가
    def self.exists?(path)
      return false unless path.is_a?(String)
      File.exist?(path)
    end

    # 후보 중 처음으로 존재하는 파일의 경로를 돌려준다. 전부 없으면 마지막 후보의
    # 경로를 돌려준다 (nil이 아니라 경로를 돌려주므로 오류에 파일 이름이 남는다).
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

    # 맵 파일 경로. RTP 칩셋이 있으면 RTP용 맵(base_rtp.json)을, 없으면 기본 맵을
    # 고른다 (두 맵은 tools/generate_demo_maps.py가 만든다).
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
