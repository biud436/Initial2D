# 알데바란, 스테이지 1-1 「검은 안개의 숲」 (기획서 4.3절).
#
# 스테이지의 항목과 이야기 글. 시작 지점, 체크포인트, 몬스터, 흔적, 구간은 맵 파일의
# objects에서 읽는다 (stages/placement.rb, 스키마는 resources/schema/map-objects.json).
# 좌표는 픽셀이며 tools/generate_aldebaran_maps.py의 지형과 일치해야 한다.
# 종별 표는 data/monsters.rb에 있다.
#
# 값은 대문자 상수에 두고 씬은 모듈 함수(stage.id, stage.sections, ...)로 읽는다.
# 함수 이름은 상수 이름의 snake_case이며, 예외는 INTRO_KIND/intro, INTRO/intro_text,
# GAMEOVER/gameover_text 셋이다.

require "scripts/ruby/games/aldebaran/data/monsters"
require "scripts/ruby/games/aldebaran/stages/placement"

module Aldebaran
  module Stages
    module Forest
      # ---- 스테이지가 씬에게 알려 주는 것 -------------------------------------
      # game.rb가 읽는 항목. 새 스테이지는 같은 항목을 정의한다.

      ID = "forest"
      NUMBER = "1-1"
      TITLE = "검은 안개의 숲"
      MAP = "./resources/maps/aldebaran_forest.json"
      BGM_SLOT = "./resources/audio/aldebaran_forest.ogg"
      BRIGHT = "./resources/aldebaran/forest_bright.png"   # 환각 연출 때 겹쳐 그리는 옛 숲
      FOG = true                                            # 안개 입자를 그린다
      BOSS = { species: :monkey, kind: :thief, drops: :bag }  # 짐도둑
      INTRO_KIND = :thief                                   # 도입 컷씬의 종류

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

      # ---- 구간 (기획서 4.3절) -------------------------------------------------
      # 구간마다 배경이 다르다. 씬은 카메라 x로 구간을 찾고, 경계 앞뒤 SECTION_FADE
      # 픽셀에서 두 배경을 겹친다. 구간은 맵의 section 띠다
      # (entrance 타일 0~47, road 48~99, gorge 100~147, den 148~203, altar 204~255).

      SECTIONS = PLACED[:sections]
      SECTION_FADE = 96                   # 경계 앞뒤로 겹치는 폭 (픽셀)

      def self.sections; SECTIONS; end
      def self.section_fade; SECTION_FADE; end

      # 카메라 x가 속한 구간과, 다음 구간으로 얼마나 넘어갔는가 (0..1).
      # [지금 구간, 다음 구간, 섞는 비율]을 돌려준다.
      def self.section_at(x)
        Placement.section_at(SECTIONS, SECTION_FADE, x)
      end

      START = PLACED[:start]             # 숲 입구 (타일 3.5, 지면 24)
      # 체크포인트 둘 (2구간 끝의 석주, 4구간 초입의 우리). 지나면 부활 지점이 된다.
      # 씬이 지났다는 표시를 cp[:taken]에 기록하므로 freeze하지 않는다.
      CHECKPOINTS = PLACED[:checkpoints]
      LIVES = 2                          # 원안 1절의 "2번의 목숨"
      SEED = 20260823                    # 전투 굴림의 시드 (테스트 재현용)

      def self.start; START; end
      def self.checkpoints; CHECKPOINTS; end
      def self.lives; LIVES; end
      def self.seed; SEED; end

      # 1-1에는 기후가 없다
      def self.climate; nil; end

      # ---- 종별 표 ------------------------------------------------------------
      # data/monsters.rb의 표를 그대로 내보낸다. 배치(spawns)가 이 표의 키를 쓴다.

      def self.species; Aldebaran::Monsters::SPECIES; end

      # ---- 배치 (지형: 입구 24, 턱 22/21/20, 다리, 어깨 20, 내리막 22, 숲 24) ----
      # 맵의 spawn 오브젝트다. 몬스터 id와 난수 소비가 이 순서를 따른다.
      # 적은 구간 경계에서 100px 이상 안쪽에 둔다 (계획 3.5절의 레벨 디자인 원칙).
      #   1구간 숲 입구 (지면 384 / 턱 352): 베기를 가르치고, 점프한 뒤 싸우게 한다
      #   2구간 옛 길 (계단 352, 336, 320, 304): 턱마다 하나, 마지막에 둘
      #   3구간 기암 절벽: 어깨 한가운데 (착지하자마자 공격받지 않게)
      #   4구간 늑대 마을: 둘씩 두 번, 그리고 안쪽에 검은 늑대
      #   5구간 제단 앞: 전초 하나와 짐도둑
      SPAWNS = PLACED[:spawns]

      def self.spawns; SPAWNS; end

      # ---- 흔적 (기획서 4.3.1절) ----------------------------------------------
      # 구간마다 하나. 그 위를 지나면 글이 표시되고 발견 기록에 남는다. 강제가 아니다.
      # 맵의 landmark 띠다.
      #   tracks  첫 거미를 잡은 뒤, 턱 앞의 평지 (읽는 동안 공격받지 않는 자리)
      #   road    포석이 시작되는 자리 (2구간 초입)
      #   cart    다리를 건너기 전 어깨 (체크포인트 바로 뒤)
      #   cage    마을 초입의 우리. 여기서 안개의 환각으로 옛 숲이 보인다 (hallucination)
      #   altar   제단 앞. 보스와 싸우기 전에 읽는다
      LANDMARKS = PLACED[:landmarks]

      # 흔적 다섯을 모두 찾은 플레이어만 읽는 마지막 한 줄
      EPILOGUE_FULL = "도둑이 노린 것은 금괴가 아니었다. 이 숲의 지형을 그린 그 지도였다."

      def self.landmarks; LANDMARKS; end
      def self.epilogue_full; EPILOGUE_FULL; end

      # ---- 이야기 글 (기획서 4절) ---------------------------------------------

      # 도입 컷씬의 나레이션. 대화창이 쪽을 나눈다.
      INTRO = "알데바란에 발을 디딘 순간이었다. 발 빠른 가면 원숭이들이 배낭과 금괴, " +
        "지도까지 전부 채 갔다. 남은 것은 단검 한 자루와, 본능적으로 지켜 낸 몇 장의 " +
        "단서뿐. 깜깜한 하늘, 우거진 숲, 마른 넝쿨과 부서진 대나무. 잔상 같은 세계 " +
        "속에서, 카르토는 달아난 원숭이의 발자국을 뒤따랐다."

      # 에필로그 (배낭을 되찾으면). 넷으로 나눠 한 쪽씩 보여 준다.
      EPILOGUE = [
        "배낭은 반쯤 비어 있었다. 금괴는 사라졌지만, 지도는 무사했다.",
        "지도 위, 협회의 문양과 일치하던 그 지형에 누군가 새로 표시를 남겨 두었다.",
        "스핑크스를 닮은 왕릉, 사람들이 황제의 무덤이라 부르는 곳이었다.",
        "카르토는 배낭을 고쳐 메고, 더 깊은 숲을 향해 걸음을 옮겼다.",
      ]

      # 게임 오버 (목숨을 다 잃으면)
      GAMEOVER = "검은 안개가 시야를 덮었다. ...멀리서 늑대 울음이 들린다."

      # 표지 글: 그 x 구간에 처음 들어가면 화면 위에 잠깐 표시된다. 이 스테이지에는 없다.
      SIGNS = []

      def self.intro_text; INTRO; end
      def self.epilogue; EPILOGUE; end
      def self.gameover_text; GAMEOVER; end
      def self.signs; SIGNS; end
    end
  end
end
