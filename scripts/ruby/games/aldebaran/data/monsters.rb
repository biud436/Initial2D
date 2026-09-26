# 알데바란, 몬스터 규격서 (docs/plans/aldebaran-6-source-mining.md 3절 6항).
#
# 원안 스피카의 몬스터 규격서(표 39 밀림 전갈 거미, 표 40 늑대 인간)의 항목 구성을
# 그대로 따른 표다. 채굴본은 docs/design/spica-source/tables.md에 있다.
#
# 종 하나는 두 부분으로 되어 있다.
#   평평한 필드  엔진이 그대로 읽는 값이다 (game.rb, monster.rb). 이 값을 바꾸면 게임이 바뀐다.
#   spec         원안 규격서의 항목이다. 코드는 대부분 읽지 않는다. 값이 원안에
#                없으면 nil로 둔다 ("비어 있다"와 "0이다"는 다르다).
# spec[:source]는 그 값이 어느 표 몇 절에서 왔는지다. 원안에 없어서 우리가 정한 것은
# source가 없고 notes에 그 사실을 적는다.
#
# 표기 규약 (docs/plans/s2-ruby-aldebaran.md 3절): 표는 전부 Symbol 키 Hash이고
# 키는 snake_case다 (예: :charge_atk). 방어력은 def가 Ruby 예약어라 :defense로 쓴다.
# 열거값(special, attack_type, element, move_speed, 속도 단계의 key, 페이즈
# 사이클의 패턴 이름)은 Symbol이다. 시트 경로와 서술문은 문자열이다.
#
# 0.3, 0.35, 0.6, 0.7을 3.0 / 10처럼 나눗셈으로 적는 이유: 이 엔진의 mruby 4.0.0은 그
# 리터럴들을 1 ulp 어긋나게 읽고, 나눗셈은 정확한 값을 준다. Lua 구현과 같은 골든
# 스크린샷을 통과하려면 값이 같아야 한다.

module Aldebaran
  module Monsters
    # ---- 원안 2.3.1절 표 6: 적의 4가지 공격 방식 --------------------------------
    # 종마다 하나를 고른다. 체력/공격력/방어력의 상대적인 높낮이가 여기서 정해진다.
    # suicide(자폭 형)는 파괴의 조각(:shard) 하나만 쓴다.

    ATTACK_TYPES = {
      melee: { name: "근접 형", hp: "많음", atk: "낮음", defense: "보통",
               pattern: "둔기 또는 신체 부위로 적에게 근접하여 공격을 한다." },
      charge: { name: "돌격 형", hp: "보통", atk: "보통", defense: "높음",
                pattern: "높은 방어력을 가지고 있으며 몸통 박치기로 공격 한다." },
      throw: { name: "투척 형", hp: "적음", atk: "높음", defense: "낮음",
               pattern: "장거리에서 원거리 공격을 한다." },
      suicide: { name: "자폭 형", hp: "적음", atk: "높음", defense: "보통",
                 pattern: "매우 강한 공격력으로 자폭을 한다." },
    }

    # 원안에 없는 공격 방식 (docs/plans/aldebaran-7-tomb.md 5절). 원안 자료와 섞이지 않도록
    # 표를 따로 둔다.
    EXTRA_ATTACK_TYPES = {
      air: { name: "공중 형", hp: "적음", atk: "보통", defense: "낮음",
             pattern: "떠다니다가 내려찍는다. 지면에서는 닿지 않는다.",
             question: "2단 점프의 정점을 써라" },
      shield: { name: "방패 형", hp: "많음", atk: "보통", defense: "높음",
                pattern: "앞을 막는다. 등은 비어 있고 돌아서는 데 시간이 걸린다.",
                question: "뒤로 돌아가라" },
    }

    # 공격 방식 하나 (원안의 표와 우리가 추가한 표 모두에서 찾는다)
    def self.attack_type(key)
      ATTACK_TYPES[key] || EXTRA_ATTACK_TYPES[key]
    end

    # ---- 원안 6.2.2절 표 37: 몬스터의 이동 속도 5단계 ----------------------------
    # 원안의 값은 초당 픽셀이 아니라 배율이다. 우리 walk_speed(픽셀/초)와 대응시켜 둔다.

    SPEED_TIERS = [
      { key: :veryslow, name: "아주 느림", scale: 3.0 / 10 },
      { key: :slow,     name: "느림",     scale: 0.5 },
      { key: :normal,   name: "보통",     scale: 0.8 },
      { key: :fast,     name: "빠름",     scale: 1.0 },
      { key: :veryfast, name: "아주 빠름", scale: 3.0 },
    ]

    # ---- 종별 표 ----------------------------------------------------------------

    SPECIES = {
      # 밀림 전갈거미: 근접형. 몸을 움츠렸다가 턱을 내미는 선딜레이 동작이 공격 예고다.
      spider: {
        name: "밀림 전갈거미",
        hp: 26, atk: 9, defense: 2, exp: 5, gold: 10,
        walk_speed: 25, chase_speed: 55,
        alert_range: 96, attack_range: 20,
        windup: 35.0 / 100, active: 0.15, recover: 0.5,
        half_w: 12, body_h: 14,
        special: :sting,             # 명중 시 20% 확률로 데미지 +8 (확률 판정은 씬이 한다)
        sting_chance: 0.2, sting_bonus: 8,
        sheet: "./resources/aldebaran/spider.png",
        cols: 4, rows: 2, frame_w: 48, frame_h: 32,
        anchor_x: 22, anchor_y: 30,
        frames: { walk: [0, 1], attack: 2, hurt: 3 },

        spec: {
          source: { table: 39, section: "6.3" },
          index: 1,
          name: "밀림 전갈거미",
          gender: nil,                     # 원안 "없음"
          element: :dark,                  # 암 속성
          attack_type: :melee,
          traits: "썩은 시체의 살점이나 죽어가는 동물의 체액을 빨아먹으며 생명을 " +
            "연장한다. 거미도 전갈도 아닌 절지동물이며, 스피카 숲의 기운을 견디려고 " +
            "사람 크기로 거대해졌다. 거미줄을 만드는 기능은 일부 퇴화했다.",
          habitat: "시체가 썩고 습기가 많은 지역. 부서진 스피카 사원의 유적지 일대에 " +
            "다수가 서식한다.",
          preference: "살아 있는 생명체를 거의 죽을 때까지 공격한다. 그 뒤 독이나 마비로 " +
            "살점이 썩는 속도를 높인다.",
          strength: "다리가 많아 이동이 빠르고 민첩하다. 군락 생활을 하며 동료가 피해를 " +
            "입으면 즉시 전투에 동참한다.",
          weakness: {
            text: "두터운 세포로 둘러싸여 있으나 빛에 민감해 오래 노출되면 세포질이 " +
              "약해져 부서진다. 신성 계열 마법에 상당히 약하고, 은으로 도금된 " +
              "무기에 치명타를 입는다.",
            light: true, holy: true, silver: true,   # 상성 계산이 이 값을 쓴다
          },
          weapon: "발달된 턱과 강한 산성의 독침.",
          combat_style: "민첩하게 접근해 큰 턱으로 타격하고, 일정 확률로 마비와 독침을 " +
            "쓴다. 마법 공격은 2순위다. 도주하는 적에게 동료와 합세해 달라붙는다.",
          attack_patterns: {
            normal: "몸을 움츠렸다가 턱을 앞으로 내빼며 가격한다.",
            skill: "강한 산성의 독 공격. 플레이어가 10% 확률로 마비에 걸린다.",
            ultimate: "앞다리로 상체를 고정한 뒤 턱으로 가위 자르듯 공격한다.",
            defense: nil,                  # 원안 "없음"
            other: nil,                    # 원안 "없음"
          },
          appearance: { length: nil, weight: nil, body: nil, face: nil,
                        hair: nil, outfit: nil },   # 원안이 비워 둔 항목
          behavior_stages: [
            "단계 1 : 평타",
            "단계 2 : 마비, 평타",
            "단계 3 : 독침, 평타",
          ],
          chase_bounds: nil,               # 원안 "-"
          reward: { exp: 5, gold: 10, item: "ITEM 001 끈적거리는 거미줄" },
          stats: {
            move_speed: :slow, move_pattern: "왕복 이동",
            max_hp: nil, max_mp: nil, atk: nil, defense: nil,
            hit: nil, int: nil, agi: nil,
            regen_hp: nil, regen_mp: nil,
          },
          specials: [
            { name: "독침", effect: "HP 감소", chance: 0.2, mp: nil,
              damage: 28, text: "28의 데미지." },
          ],
          notes: [
            "원안은 능력치 칸(최대 HP, 힘, 방어, 명중, 지능, 민첩력, 자가 치유량)을 " +
              "전부 '-'로 비워 두었다. 평평한 칸의 수치는 A2에서 정한 것이다.",
            "독침은 원안이 20% 확률에 28 데미지다. 구현은 20%에 +8이다 (A2). " +
              "차이는 의도적이며 P2의 계측 뒤에 다시 본다.",
            "마비(일반 스킬 10%)는 아직 구현이 없다. P5의 상태 이상에서 쓴다.",
          ],
        },
      },

      # 늑대 인간: 돌격형. 발견하면 한 번 돌진하고, 그 뒤로는 근접전.
      wolf: {
        name: "늑대 인간",
        hp: 48, atk: 16, defense: 4, exp: 8, gold: 10,
        walk_speed: 30, chase_speed: 70,
        alert_range: 128, attack_range: 24,
        windup: 3.0 / 10, active: 0.15, recover: 0.55,
        half_w: 9, body_h: 30,
        special: :charge,            # 돌격: 데미지 14와 큰 넉백, 1회
        charge_speed: 150, charge_time: 0.9, charge_atk: 14,
        regen: true,                 # 비전투 시 4초마다 최대 HP의 1/20 회복
        sheet: "./resources/aldebaran/wolf.png",
        cols: 5, rows: 2, frame_w: 48, frame_h: 48,
        anchor_x: 22, anchor_y: 46,
        frames: { walk: [0, 1], charge: 2, attack: 3, hurt: 4 },

        spec: {
          source: { table: 40, section: "6.4" },
          index: 2,
          name: "늑대 인간",
          gender: "수컷, 남성",
          element: :dark,                  # 암(暗)
          attack_type: :charge,
          traits: "레굴루스 마법 생명학자의 연구실에서 인간 노예를 실험한 프로젝트 " +
            "'늑대 인간의 모체'가 탈출하며 개체수가 늘었다. 야수 또는 인간으로 " +
            "변신할 수 있고 살상과 마법 능력이 출중하다.",
          habitat: "습도가 낮은 자연 동굴이나 큰 바위 동굴 밑에 가족 단위로 서식한다.",
          preference: "비문명 늑대인간은 야행성이며 깊은 산림 근처에 모여 사냥한다. " +
            "문명을 이룩한 늑대인간들과는 습성이 달라 대립 중이다.",
          strength: "인간보다 발달된 근육으로 빠르게 접근하고, 민첩한 몸놀림과 공격 " +
            "속도로 짧은 시간에 많은 데미지를 준다. 힘과 민첩력과 지능이 높다.",
          weakness: {
            text: "불완전한 실험 생명체라 면역력이 떨어지고 오래 살지 못한다. 독이나 " +
              "저주 마법에 대한 방어 면역이 생물학적으로 뒤떨어진다. 폴리모프한 " +
              "상태에서는 모든 능력치가 절반 이하로 떨어진다.",
            poison: true, curse: true,
          },
          weapon: "강철 둔기 같은 근육과 뾰족한 손톱, 발톱.",
          combat_style: nil,               # 원안이 서술 지시만 남기고 비워 둔 항목
          attack_patterns: {
            normal: "단단한 팔과 손톱을 검처럼 머리 위로 높이 뻗어 내리찍는다. " +
              "공격 속도가 매우 빠르다.",
            skill: "충돌 범위 안에 플레이어가 있으면 돌격을 시전한다. 첫 발동이 " +
              "성공한 뒤로는 다시 발동되지 않는다.",
            ultimate: nil, defense: nil, other: nil,
          },
          appearance: { length: nil, weight: nil, body: nil, face: nil,
                        hair: nil, outfit: nil },
          behavior_stages: [
            "단계 1 : [돌격]은 범위 내에 적군이 들어왔을 경우 발동된다.",
            "단계 2 : [평타]를 가하고 이후에도 단계 2를 반복한다.",
          ],
          chase_bounds: nil,               # 원안: "나중에 적는 것이 옳다"
          reward: { exp: 8, gold: 10, item: "ITEM 002 검은 밀랍 인형" },
          stats: {
            move_speed: :slow, move_pattern: nil,
            max_hp: 72, max_mp: 40, atk: 24, defense: 5,
            hit: nil, int: 41, agi: "민첩력이 높을수록 공격 속도가 빨라진다.",
            regen_hp: "전투 중이 아닌 경우 4초마다 최대 HP/20을 회복.",
            regen_mp: "전투 중이나 일반 상태에서 4초마다 지능/8을 회복.",
          },
          specials: [
            { name: "돌격", effect: "스턴", chance: 0.4, mp: 23,
              damage: 27,
              text: "보통 속도로 접근하여 27의 데미지를 입히고 스턴을 가한다." },
          ],
          notes: [
            "원안의 능력치(HP 72, 공격 24, 방어 5)는 구현에서 검은 늑대가 물려받았다. " +
              "늑대 인간은 그보다 약한 48/16/4다 (A2가 난이도 곡선을 위해 " +
              "한 칸 내린 것이다).",
            "돌격은 원안이 40% 확률에 MP 23을 소비하고 27 데미지에 스턴이다. 구현은 " +
              "확률도 MP도 스턴도 없이 1회 고정에 14 데미지다.",
            "몬스터의 MP와 MP 회복은 구현에 아예 없다. P4의 자원 루프에서 다시 본다.",
          ],
        },
      },

      # 검은 늑대: 마을의 우두머리. 늑대 인간의 1.5배이고 돌격을 반복한다.
      blackwolf: {
        name: "검은 늑대",
        hp: 72, atk: 24, defense: 6, exp: 16, gold: 25,
        walk_speed: 34, chase_speed: 82,
        alert_range: 150, attack_range: 26,
        windup: 0.26, active: 0.16, recover: 0.45,
        half_w: 10, body_h: 32,
        special: :charge,
        charge_speed: 170, charge_time: 0.9, charge_atk: 20,
        charge_repeat: true,             # 돌격을 반복한다
        regen: true,
        sheet: "./resources/aldebaran/blackwolf.png",
        cols: 5, rows: 2, frame_w: 48, frame_h: 48,
        anchor_x: 22, anchor_y: 46,
        frames: { walk: [0, 1], charge: 2, attack: 3, hurt: 4 },

        spec: {
          source: nil,                     # 원안에 규격서가 없다. 우리가 만든 종이다
          index: 3,
          name: "검은 늑대",
          element: :dark,
          attack_type: :charge,
          traits: "늑대 인간 마을의 우두머리. 원안 4.2.1.1절의 '지능 차이에 따라 " +
            "지배자와 피지배자로 나뉜다'는 서술을 종으로 옮긴 것이다.",
          habitat: "검은 안개의 숲 4구간, 늑대 마을 안쪽.",
          weakness: { poison: true, curse: true },
          attack_patterns: {
            normal: "늑대 인간과 같은 내리찍기. 더 빠르다.",
            skill: "돌격을 한 번으로 끝내지 않고 되풀이한다.",
          },
          reward: { exp: 16, gold: 25, item: nil },
          stats: { move_speed: :normal, max_hp: 72, atk: 24, defense: 6 },
          notes: [
            "원안에 규격서가 없는 종이다. 능력치는 원안 표 40(늑대 인간)의 값을 " +
              "그대로 가져다 썼다.",
            "보상 아이템이 없다. 원안의 'ITEM 002 검은 밀랍 인형'을 상위 등급으로 " +
              "쓸지는 P8의 아이템 작업에서 정한다.",
          ],
        },
      },

      # 가면 원숭이 짐도둑: 투척형 (1-1의 보스)
      monkey: {
        name: "가면 원숭이",
        hp: 60, atk: 8, defense: 1, exp: 12, gold: 30,
        walk_speed: 60, chase_speed: 110,
        alert_range: 200, attack_range: 160,
        windup: 0.4, active: 0.2, recover: 6.0 / 10,
        half_w: 8, body_h: 28,
        special: :throw,
        flee_range: 64,              # 이 거리보다 가까우면 반대 방향으로 달아난다
        sheet: "./resources/aldebaran/monkey.png",
        cols: 4, rows: 2, frame_w: 48, frame_h: 48,
        anchor_x: 24, anchor_y: 46,
        frames: { walk: [0, 1], attack: 2, hurt: 3 },

        spec: {
          source: nil,                     # 규격서는 없고 배경 서술만 있다 (4.2.3절)
          index: 4,
          name: "가면 원숭이",
          element: nil,
          attack_type: :throw,
          traits: "스피카 문양 가면을 쓴 원숭이. 발이 빠르고 무리를 짓는다. " +
            "원안 3.2.1절에서 카르토의 배낭과 금괴와 지도를 빼앗는 무리다.",
          habitat: "원숭이 소굴(원안 4.2.3절). 바위산에 벌집처럼 판 동굴 40동 규모이며, " +
            "1동에 4~5마리가 산다. 동장 열을 우두머리 넷이 거느리고, 그 위에 대장이 " +
            "있다. 전부 무장하고 있다.",
          attack_patterns: {
            normal: "돌팔매. 거리를 벌리며 던진다.",
            skill: "가까이 붙으면 반대 방향으로 달아난다 (코너로 몰아야 한다).",
          },
          reward: { exp: 12, gold: 30, item: nil },
          stats: { move_speed: :veryfast, max_hp: 60, atk: 8, defense: 1 },
          notes: [
            "원안에 몬스터 규격서가 없다. 배경(4.2.3절)과 발단 시나리오(3.2.1절)에서 " +
              "만든 종이다.",
            "P7의 원숭이 소굴은 이 서술의 계급 구조(동장, 우두머리, 대장)를 적 종별로 " +
              "쓸 수 있다.",
          ],
        },
      },
    }

    # ---- 1-2 황제의 무덤의 적 셋 (docs/plans/aldebaran-7-tomb.md 5절) ----------
    #
    # 원안의 서술에 근거가 있지만 수치는 우리가 정했다. 선딜은 텔레그래프 부등식
    # (회피 성립 17프레임 + 인지 15프레임 = 0.53초 이상)을 지킨다 (검사: tests/ruby/cases/aldebaran_monsters_data_test.rb).

    SPECIES[:soul] = {
      name: "순장된 영혼",
      hp: 30, atk: 12, defense: 1, exp: 7, gold: 8,
      walk_speed: 24, chase_speed: 52,
      alert_range: 128, attack_range: 40, alert_range_y: 96,
      windup: 0.55, active: 0.28, recover: 7.0 / 10,  # 선딜 33프레임
      half_w: 10, body_h: 22,
      # 내려찍기는 0.28초에 380px/s = 106px. 떠 있는 높이(약 64px)보다 더 내려온다.
      flies: true, fly_speed: 55, dive_speed: 380, rise_speed: 190,
      sheet: "./resources/aldebaran/soul.png",
      cols: 4, rows: 2, frame_w: 32, frame_h: 32,
      anchor_x: 15, anchor_y: 26,
      frames: { walk: [0, 1], attack: 2, hurt: 3 },

      spec: {
        source: nil,                     # 규격서는 없다. 표 16과 20의 서술에서 만들었다
        index: 5,
        name: "순장된 영혼",
        element: :dark,
        attack_type: :air,
        traits: "왕이 사후에도 함께하길 원해 강제로 순장된 신하와 자식들의 영혼. " +
          "수호자들이 침입자를 막으려 불러낸다 (원안 표 16, 표 20).",
        habitat: "황제의 무덤. 방을 떠날 수 없다.",
        weakness: { light: true },       # 별들의 방의 빛기둥 안에서 실체가 된다
        attack_patterns: {
          normal: "떠 있다가 몸을 위로 당겼다 발치까지 내려찍는다.",
        },
        reward: { exp: 7, gold: 8, item: nil },
        stats: { move_speed: :slow, max_hp: 30, atk: 12, defense: 1 },
        notes: [
          "원안에 몬스터 규격서가 없다. 순장(표 16)과 '희생된 영혼들을 소환'(표 20)에서 " +
            "만든 종이다.",
          "공중형은 원안 표 6의 넷에 없다. 우리가 더한 공격 방식이다 " +
            "(EXTRA_ATTACK_TYPES).",
        ],
      },
    }

    SPECIES[:sentinel] = {
      name: "무덤 번병",
      hp: 60, atk: 18, defense: 8, exp: 11, gold: 14,
      walk_speed: 22, chase_speed: 40,
      alert_range: 112, attack_range: 26,
      windup: 6.0 / 10, active: 0.18, recover: 6.0 / 10,    # 선딜 36프레임
      half_w: 11, body_h: 30,
      guard_front: true, turn_delay: 0.55,
      sheet: "./resources/aldebaran/sentinel.png",
      cols: 5, rows: 2, frame_w: 48, frame_h: 48,
      anchor_x: 23, anchor_y: 46,
      frames: { walk: [0, 1], attack: 2, hurt: 3, block: 4 },

      spec: {
        source: nil,
        index: 6,
        name: "무덤 번병",
        element: :dark,
        attack_type: :shield,
        traits: "수호자들이 '직접 나서지 않고 부하를 통솔'한다는 서술(원안 표 20)의 " +
          "그 부하다. 석회암 방패를 들고 통로를 막는다.",
        habitat: "황제의 무덤의 복도와 방 입구.",
        weakness: { text: "방패는 앞만 가린다. 등은 비어 있다." },
        attack_patterns: {
          normal: "방패로 밀고 창을 내지른다.",
          defense: "바라보는 쪽에서 오는 것은 막는다. 막은 뒤 잠깐 굳는다.",
        },
        reward: { exp: 11, gold: 14, item: nil },
        stats: { move_speed: :veryslow, max_hp: 60, atk: 18, defense: 8 },
        notes: [
          "원안에 규격서가 없다. 표 20의 '부하를 통솔하고 지휘하에 침입자를 처치'에서 " +
            "만든 종이다.",
          "방패형은 원안 표 6의 넷에 없다. 원안 표 39의 '방어 기술' 칸이 '없음'이라 " +
            "막는 적이 아예 없었다.",
        ],
      },
    }

    SPECIES[:shard] = {
      name: "파괴의 조각",
      hp: 14, atk: 26, defense: 3, exp: 6, gold: 12,
      walk_speed: 30, chase_speed: 95,
      alert_range: 150, attack_range: 20,
      windup: 0.75, active: 0.15, recover: 3.0 / 10,
      half_w: 8, body_h: 16,
      special: :fuse,
      fuse_range: 26, fuse_time: 0.75, blast_time: 0.15, blast_radius: 30,
      sheet: "./resources/aldebaran/shard.png",
      cols: 4, rows: 2, frame_w: 32, frame_h: 32,
      anchor_x: 15, anchor_y: 30,
      frames: { walk: [0, 1], attack: 2, hurt: 3, fuse: 2, boom: 2 },

      spec: {
        source: { table: 6, section: "2.3.1" },   # 자폭형은 원안의 것이다
        index: 7,
        name: "파괴의 조각",
        element: :dark,
        attack_type: :suicide,
        traits: "파괴의 방에서 떨어져 나온 돌조각에 아포피스의 힘이 붙은 것. " +
          "원안 표 6의 자폭형은 넷 중 하나인데 지금까지 쓰이지 않았다.",
        habitat: "파괴의 방과 그 복도.",
        weakness: { text: "체력이 낮다. 심지가 타는 동안 베면 터지지 않고 스러진다." },
        attack_patterns: {
          normal: "붙으면 멈춰 서서 심지가 탄다. 그리고 터진다.",
        },
        reward: { exp: 6, gold: 12, item: nil },
        stats: { move_speed: :fast, max_hp: 14, atk: 26, defense: 3 },
        notes: [
          "공격 방식은 원안 표 6의 자폭형이다. 이름과 수치는 우리가 정했다.",
          "멈춰 서는 것이 예고다 (45프레임). 그 사이에 물러나거나 베어 없앤다.",
        ],
      },
    }

    # ---- 보스: 아포피스 (원안 표 16, 19, 20) ------------------------------------
    #
    # 파괴의 방의 수호자이자 무덤의 기후를 좌우하는 자 (표 19, 20). 마지막 방에서만 만난다.
    # 보스 규칙: 3페이즈, 명시적인 패턴 사이클, 반격 가능 구간, 즉사 없음.
    # 페이즈 표는 BOSS_PHASES에 있다.

    SPECIES[:apophis] = {
      name: "아포피스",
      hp: 260, atk: 20, defense: 7, exp: 60, gold: 120,
      walk_speed: 34, chase_speed: 66,
      alert_range: 260, attack_range: 30,
      windup: 7.0 / 10, active: 0.22, recover: 1.2,   # 후딜레이 1.2초가 1페이즈의 반격 가능 구간
      half_w: 16, body_h: 44,
      special: :charge,
      charge_speed: 190, charge_time: 0.8, charge_atk: 22, charge_repeat: true,
      phases: [1.0, 0.66, 0.33],                  # 남은 체력 비율의 경계
      phase_guard: 1.0,                           # 페이즈가 바뀔 때의 무적 (초)
      sheet: "./resources/aldebaran/apophis.png",
      cols: 5, rows: 2, frame_w: 64, frame_h: 64,
      anchor_x: 31, anchor_y: 60,
      frames: { walk: [0, 1], charge: 2, attack: 3, hurt: 4 },

      spec: {
        source: { table: 19, section: "4.2.2.4" },
        index: 8,
        name: "아포피스",
        element: :dark,
        attack_type: :charge,
        traits: "이집트 문화의 파괴의 신. 원안 표 16이 황제의 무덤의 주 서식 세력으로 " +
          "아크나톤과 함께 적어 두었다.",
        habitat: "황제의 무덤. 파괴의 방의 수호자이며 방을 떠날 수 없다 (표 20).",
        preference: "직접 나서지 않고 부하를 통솔한다 (표 20). 태양의 방에서만 싸운다.",
        strength: "무덤의 기후를 좌우한다 (눈, 우박, 비, 폭풍우, 홍수. 표 19).",
        weakness: { text: "패턴이 정해져 있다. 후딜이 길고, 페이즈마다 짧아진다." },
        attack_patterns: {
          normal: "몸을 낮췄다 휘두른다.",
          skill: "우박을 부른다. 떨어질 자리에 그림자가 먼저 뜬다.",
          ultimate: "수위를 올리고 영혼 둘을 부른다 (2페이즈).",
        },
        behavior_stages: [
          "단계 1 (100~66%) : 우박 세 줄 → 돌진 → 긴 후딜",
          "단계 2 (66~33%) : 수위 상승 → 영혼 둘 소환 → 우박 다섯 줄 → 후딜",
          "단계 3 (33~0%) : 사이클이 빨라지고 돌진이 둘로 늘어난다 → 짧은 후딜",
        ],
        reward: { exp: 60, gold: 120, item: nil },
        stats: { move_speed: :normal, max_hp: 260, atk: 20, defense: 7 },
        notes: [
          "원안에 몬스터 규격서가 없다. 표 16(주 서식 세력)과 표 19(기후를 좌우한다)와 " +
            "표 20(부하를 통솔한다)에서 만든 종이다.",
          "즉사기가 없다. 페이즈 전환의 무적 1초가 '언제 때리는가'를 눈에 보이게 한다.",
        ],
      },
    }

    # 종별 표. id를 주면 그 종 하나, 없으면 표 전체를 돌려준다.
    def self.species(id = nil)
      id.nil? ? SPECIES : SPECIES[id]
    end

    # 페이즈 표. game.rb가 이 표를 읽어 패턴 사이클을 진행한다.
    #   at            체력 비율이 이 값 이하로 내려가면 이 페이즈다
    #   cycle         패턴 순서. 차례로 반복한다
    #   recover       그 페이즈의 후딜레이 (반격 가능 구간)
    #   hail          우박 줄 수, summon 소환 수
    # 페이즈 번호는 1부터 센다 (Monster#phase). 배열 첨자는 [n - 1]이며,
    # boss_phase(n)이 그 변환을 대신한다.
    BOSS_PHASES = [
      { at: 1.00, cycle: [:hail, :charge], recover: 1.2,
        hail: 3, summon: 0, charge_count: 1 },
      { at: 0.66, cycle: [:flood, :summon, :hail], recover: 0.9,
        hail: 5, summon: 2, charge_count: 1 },
      { at: 0.33, cycle: [:hail, :charge, :charge], recover: 6.0 / 10,
        hail: 5, summon: 0, charge_count: 2 },
    ]

    # 남은 체력 비율의 페이즈 번호 (1에서 3)
    def self.phase_for(ratio)
      n = 1
      BOSS_PHASES.each_with_index do |ph, i|
        n = i + 1 if ratio <= ph[:at]
      end
      n
    end

    # 페이즈 번호(1에서 3)의 페이즈 표 한 줄. 모르는 번호면 nil.
    def self.boss_phase(n)
      return nil if n.nil? || n < 1
      BOSS_PHASES[n - 1]
    end

    # ---- 스키마 검사 ------------------------------------------------------------
    # 표의 구조가 규약대로인지 검사한다 (빠진 필드와 오타를 찾는다).

    # 엔진이 반드시 읽는 필드. 하나라도 없으면 game.rb가 nil 산술 오류로 중단된다.
    REQUIRED = [
      :name, :hp, :atk, :defense, :exp, :gold,
      :walk_speed, :chase_speed, :alert_range, :attack_range,
      :windup, :active, :recover, :half_w, :body_h,
      :sheet, :cols, :rows, :frame_w, :frame_h, :anchor_x, :anchor_y,
    ]

    # 원안 규격서(표 39, 40)의 항목 이름. spec에 이 밖의 이름이 있으면 오타로 본다.
    SPEC_FIELDS = {
      source: true, index: true, name: true, gender: true, element: true,
      attack_type: true, traits: true, habitat: true, preference: true,
      strength: true, weakness: true, weapon: true, combat_style: true,
      attack_patterns: true, appearance: true, behavior_stages: true,
      chase_bounds: true, reward: true, stats: true, specials: true,
      notes: true,
    }

    STATS_FIELDS = {
      move_speed: true, move_pattern: true, max_hp: true, max_mp: true,
      atk: true, defense: true, hit: true, int: true, agi: true,
      regen_hp: true, regen_mp: true,
    }

    # 종 하나를 검사한다. 문제가 없으면 nil, 있으면 사람이 읽을 수 있는 이유를 돌려준다.
    # entry는 종 하나의 표(평평한 필드 + spec)다.
    def self.validate_species(key, entry)
      unless entry.is_a?(Hash)
        return "#{key}: 종의 정의가 표가 아니다"
      end
      REQUIRED.each do |field|
        if entry[field].nil?
          return "#{key}: 엔진이 읽는 칸 '#{field}'이 없다"
        end
      end
      if !entry[:frames].is_a?(Hash) || !entry[:frames][:walk].is_a?(Array)
        return "#{key}: frames.walk 이 없다"
      end
      spec = entry[:spec]
      unless spec.is_a?(Hash)
        return "#{key}: spec 이 없다 (원안 규격서의 그릇)"
      end
      spec.each_key do |field|
        unless SPEC_FIELDS[field]
          return "#{key}: spec 에 모르는 칸 '#{field}'이 있다"
        end
      end
      if spec[:attack_type] && attack_type(spec[:attack_type]).nil?
        return "#{key}: 모르는 공격 방식 '#{spec[:attack_type]}'"
      end
      if spec[:stats].is_a?(Hash)
        spec[:stats].each_key do |field|
          unless STATS_FIELDS[field]
            return "#{key}: spec.stats 에 모르는 칸 '#{field}'이 있다"
          end
        end
        tier = spec[:stats][:move_speed]
        unless tier.nil?
          found = false
          SPEED_TIERS.each do |t|
            found = true if t[:key] == tier
          end
          unless found
            return "#{key}: 모르는 이동 속도 단계 '#{tier}'"
          end
        end
      end
      nil
    end

    # 표 전체를 검사한다. 문제가 없으면 빈 목록.
    def self.validate
      problems = []
      SPECIES.each do |key, entry|
        why = validate_species(key, entry)
        problems.push(why) if why
      end
      problems.sort
    end
  end
end
