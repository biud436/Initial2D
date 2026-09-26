# 알데바란, 스테이지 1-2 「황제의 무덤」 (docs/plans/aldebaran-7-tomb.md).
#
# 원안 4.2.2절. 스핑크스 모양으로 깎은 무덤이며 가슴부로 들어간다 (표 17). 방 다섯 중
# 넷과 입구를 쓰고, 파괴의 신 아포피스가 방마다 기후를 좌우한다 (표 19).
#
# 스테이지의 항목, 기후 수치, 이야기 글. 시작 지점, 체크포인트, 몬스터, 흔적, 구간, 빛기둥은
# 맵 파일의 objects에서 읽는다 (stages/placement.rb). 지형은 tools/generate_aldebaran_tomb_map.py,
# 자산은 generate_aldebaran_tomb.py가 만든다. 항목의 이름 규칙은 stages/forest.rb 위쪽에 있다.

require "scripts/ruby/games/aldebaran/data/monsters"
require "scripts/ruby/games/aldebaran/stages/placement"

module Aldebaran
  module Stages
    module Tomb
      ID = "tomb"
      NUMBER = "1-2"
      TITLE = "황제의 무덤"
      MAP = "./resources/maps/aldebaran_tomb.json"
      BGM_SLOT = "./resources/audio/aldebaran_tomb.ogg"
      BRIGHT = nil                          # 환각 연출 없음 (1-1에만 있다)
      FOG = false                           # 원안 표 19: 안개 없음
      BOSS = { species: :apophis, kind: :guardian }   # 보스가 떨어뜨리는 물건이 없다
      INTRO_KIND = :text                    # 컷씬 없이 나레이션만

      def self.id; ID; end
      def self.number; NUMBER; end
      def self.title; TITLE; end
      def self.map; MAP; end
      def self.bgm_slot; BGM_SLOT; end
      def self.bright; BRIGHT; end
      def self.fog; FOG; end
      def self.boss; BOSS; end
      def self.intro; INTRO_KIND; end

      PLACED = Placement.build(MAP)

      def self.species; Aldebaran::Monsters::SPECIES; end

      # ---- 구간 다섯 (원안 표 19의 방 이름) -----------------------------------
      # 맵의 section 띠다. 경계는 맵 생성기의 ROOMS와 타일 단위로 같아야 한다
      # (chest 타일 0~55, moon 56~119, stars 120~183, ruin 184~251, sun 252~319).

      SECTIONS = PLACED[:sections]
      SECTION_FADE = 96

      def self.sections; SECTIONS; end
      def self.section_fade; SECTION_FADE; end

      # 1-1과 같은 규칙. 구간 경계 앞뒤에서 두 구간의 배경을 겹친다.
      # [지금 구간, 다음 구간, 섞는 비율]을 돌려준다.
      def self.section_at(x)
        Placement.section_at(SECTIONS, SECTION_FADE, x)
      end

      START = PLACED[:start]               # 가슴부 입구 (타일 3.5, 바닥 24)
      # 별들의 방 앞 목 (타일 124, 바닥 25), 파괴의 방 초입 (타일 188, 바닥 24).
      # 씬이 지났다는 표시를 cp[:taken]에 기록하므로 freeze하지 않는다.
      CHECKPOINTS = PLACED[:checkpoints]
      LIVES = 2
      SEED = 20260824

      def self.start; START; end
      def self.checkpoints; CHECKPOINTS; end
      def self.lives; LIVES; end
      def self.seed; SEED; end

      # ---- 기후 (원안 표 19: 아포피스가 방마다 기후를 좌우한다) ----------------
      # 규칙은 코드(game.rb와 climate.rb)에, 수치는 여기에 있다. 방 이름(Symbol)으로 찾는다.
      # 빛기둥의 x는 맵의 light 오브젝트 중 그 방 안의 것이다. 나머지는 방 전체에 걸리는
      # 수치라 여기에 둔다.

      CLIMATE = {
        # chest(입구)는 기후가 없다. 기후가 없는 방은 키를 두지 않는다.

        # 달의 방: 눈. 지면 마찰이 줄어든다. 멈추려면 미리 방향키를 떼어야 한다
        moon: { kind: :snow, friction: 0.34, flakes: 40 },

        # 별들의 방: 빛기둥 셋이 켜지고 꺼진다. 빛 안에 있는 영혼만 실체가 되어 공격이 통한다
        stars: { kind: :light, period: 4.0, lit: 2.2,
                 pillars: Placement.lights_in(PLACED, :stars), half_w: 44 },

        # 파괴의 방: 우박. 떨어질 자리에 그림자가 먼저 표시된다 (예고 30프레임)
        ruin: { kind: :hail, interval: 1.6, warn: 0.5, damage: 9,
                speed: 320, half_w: 5, count: 2 },

        # 태양의 방: 홍수. 수위가 오르내린다. 물에 잠기면 이동이 느려지고 점프가 낮아진다
        sun: { kind: :flood, period: 9.0, low: 400, high: 336,
               move_mult: 0.55, jump_mult: 0.72 },
      }

      def self.climate; CLIMATE; end

      # ---- 배치 ---------------------------------------------------------------
      # 맵의 spawn 오브젝트다. 몬스터 id와 난수 소비가 이 순서를 따른다.
      # 새 적은 안전한 자리에서 혼자 처음 나오고, 그다음 조합, 그다음 지형과 결합한다.
      #   1구간 가슴부 입구: 무덤 번병 하나. 앞을 막는 적을 뒤로 돌아 공격하는 것을 배운다
      #   2구간 달의 방 (눈): 순장된 영혼이 처음 나온다. 미끄러운 바닥에서 2단 점프의 정점을 맞춘다
      #   3구간 별들의 방 (빛기둥): 영혼 셋. 그늘에서는 공격이 통하지 않으므로 빛이 켜질 때를 기다린다
      #   4구간 파괴의 방 (우박): 파괴의 조각이 구덩이 앞 평지에서 혼자 처음 나온다. 그다음은
      #     번병이 길을 막고 조각이 뒤에서 접근하는 조합, 구덩이 위의 영혼
      #   5구간 태양의 방 (홍수): 삼각 조합 하나와 아포피스
      SPAWNS = PLACED[:spawns]

      def self.spawns; SPAWNS; end

      # ---- 흔적 (1-1과 같은 장치. 여기서는 무덤의 내력을 알려 준다) ------------
      # 맵의 landmark 띠다. 글은 원안의 서술을 따른다.
      LANDMARKS = PLACED[:landmarks]

      EPILOGUE_FULL = "지도의 표시는 여기까지였다. 다음 표시는 카르토가 직접 그려야 한다."

      def self.landmarks; LANDMARKS; end
      def self.epilogue_full; EPILOGUE_FULL; end

      # ---- 이야기 글 ----------------------------------------------------------

      INTRO = "스핑크스를 닮은 바위산이 지평을 가로막았다. 벽돌을 쌓은 것이 아니라 " +
        "산을 깎아 만든 것이었다. 지면에 닿은 가슴께에 문이 있었고, 그 문은 " +
        "열려 있었다. 닫힌 적이 없다는 듯이. 카르토는 지도를 접어 넣고 안으로 " +
        "들어섰다."

      EPILOGUE = [
        "수호자가 무너지자 방마다 다르던 하늘이 한꺼번에 멎었다.",
        "태양의 방 한가운데, 물이 빠진 자리에 석판 하나가 드러났다.",
        "협회의 문양과 같은 것이 새겨져 있었다. 이번에는 지도가 아니라 돌에.",
        "카르토는 그것을 옮겨 그렸다. 다음으로 가야 할 곳이 거기 있었다.",
      ]

      GAMEOVER = "빛이 꺼졌다. ...멀리서 물이 차오르는 소리가 들린다."

      SIGNS = []

      def self.intro_text; INTRO; end
      def self.epilogue; EPILOGUE; end
      def self.gameover_text; GAMEOVER; end
      def self.signs; SIGNS; end
    end
  end
end
