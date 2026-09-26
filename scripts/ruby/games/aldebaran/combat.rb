# 알데바란, 전투와 성장의 수식 (docs/design/aldebaran.md 7절, docs/plans/s2-ruby-aldebaran.md).
#
# 엔진에 의존하지 않는 순수 함수 묶음. 난수는 시드 난수(scripts/ruby/rpg/rng.rb의 Rpg::Rng)를
# 주입받는다 (같은 시드는 같은 전투를 만든다). float만 있으면 가짜 객체도 된다.
#
# 방어력 키는 def가 Ruby 예약어라 :defense로 쓴다 (BASE, GROWTH, stats_at).

module Aldebaran
  module Combat
    # ---- 데미지 ---------------------------------------------------------------

    # 평타 데미지 (하한 1)
    def self.damage(atk, defense)
      [1, (atk - defense).floor].max
    end

    # 명중 굴림. q = 0.45 + 난수(0..1) + 행운.
    #   q >= 1.5 크리티컬 (1.5배), q < 0.5 회피 (0배), 그 외 일반 (1배).
    # 행운 0.2면 크리티컬 15%에 회피 없음, 행운 0이면 크리티컬 없음에 회피 5%.
    def self.roll(rng, luck = 0)
      q = 0.45 + rng.float + (luck || 0)
      if q >= 1.5
        return { kind: :crit, mult: 1.5 }
      elsif q < 0.5
        return { kind: :miss, mult: 0 }
      end
      { kind: :normal, mult: 1 }
    end

    # 굴림까지 합친 최종 데미지. { dmg:, kind: }를 돌려준다.
    def self.resolve(atk, defense, rng, luck = 0)
      r = roll(rng, luck)
      { dmg: (damage(atk, defense) * r[:mult]).floor, kind: r[:kind] }
    end

    # ---- 레벨 (기획서 7.2절) ---------------------------------------------------

    # 레벨 n+1이 되는 누적 경험치. 최고 레벨은 7이다.
    EXP_TABLE = [10, 25, 45, 70, 100, 140]
    MAX_LEVEL = EXP_TABLE.size + 1

    BASE = { hp: 60, mp: 20, atk: 10, defense: 2, luck: 0.2 }
    GROWTH = { hp: 12, mp: 5, atk: 3, defense: 1 }

    # 누적 경험치의 레벨
    def self.level_for(exp)
      level = 1
      EXP_TABLE.each_with_index do |need, i|
        level = i + 2 if exp >= need   # i는 0부터라 레벨은 i + 2
      end
      level
    end

    # 레벨의 능력치 표
    def self.stats_at(level)
      n = [0, [level, MAX_LEVEL].min - 1].max
      {
        hp: BASE[:hp] + GROWTH[:hp] * n,
        mp: BASE[:mp] + GROWTH[:mp] * n,
        atk: BASE[:atk] + GROWTH[:atk] * n,
        defense: BASE[:defense] + GROWTH[:defense] * n,
        luck: BASE[:luck],
      }
    end

    # 다음 레벨까지 남은 경험치 (최고 레벨이면 nil)
    def self.exp_to_next(exp)
      level = level_for(exp)
      return nil if level >= MAX_LEVEL
      EXP_TABLE[level - 1] - exp
    end

    # 지금 레벨 구간에서의 진행 비율 (EXP 막대가 쓴다, 0..1 실수)
    def self.exp_ratio(exp)
      level = level_for(exp)
      return 1.0 if level >= MAX_LEVEL
      floor = level > 1 ? EXP_TABLE[level - 2] : 0
      ceil = EXP_TABLE[level - 1]
      (exp - floor).to_f / (ceil - floor)
    end

    # ---- 힘 (기획서 5.3절) ------------------------------------------------------
    #
    # 숲을 지날수록 **검은 안개가 단검에 스며** 힘이 강해진다는 설정이다. 다섯 흔적이
    # 힘을 하나씩 준다. 셋은 상시 효과(passive)이고 둘은 직접 사용하는 기술(active)이다.
    # 사용하는 기술에는 **쿨타임**이 있고 HUD의 슬롯에 남은 시간이 표시된다.

    SKILLS = {
      edge: {
        name: "검기", kind: :passive,
        desc: "단검에 안개가 스민다. 베기가 길고 세진다.",
        reach: 8, atk_bonus: 3,
      },
      read: {
        name: "흔적 읽기", kind: :passive,
        desc: "보물 사냥꾼의 눈. 적의 남은 힘이 보인다.",
      },
      leap: {
        name: "도약", kind: :passive,
        desc: "골짜기의 바람이 몸을 든다. 두 번째 도약이 높아진다.",
        air_jump: -330,
      },
      berserk: {
        name: "폭주", kind: :active, slot: 1, key: "C",
        desc: "안개에 취한다. 4초 동안 세지고 덜 아프다.",
        mp: 10, cooldown: 12, time: 4,
      },
      bolt: {
        name: "검기 방출", kind: :active, slot: 2, key: "V",
        desc: "검기를 날린다. 닿으면 터진다.",
        mp: 8, cooldown: 2.5, damage: 14, speed: 260,
      },
    }

    SKILL_ORDER = [:edge, :read, :leap, :berserk, :bolt]

    # 익힌 힘 표를 하나 만든다 (전부 익히지 않은 상태로)
    def self.new_skills
      s = { cooldown: {} }
      SKILL_ORDER.each do |id|
        s[id] = false
        s[:cooldown][id] = 0
      end
      s
    end

    # 쓸 수 있는가 (익혔고, 쿨타임이 끝났고, MP가 충분하다)
    def self.can_use?(skills, id, mp)
      spec = SKILLS[id]
      return false if spec.nil? || spec[:kind] != :active
      return false unless skills[id]
      return false if (skills[:cooldown][id] || 0) > 0
      mp >= spec[:mp]
    end

    # 매 프레임 쿨타임을 dt만큼 줄인다
    def self.tick_cooldowns(skills, dt)
      cooldown = skills[:cooldown]
      cooldown.keys.each do |id|
        left = cooldown[id]
        if left > 0
          cooldown[id] = [0, left - dt].max
        end
      end
    end

    # ---- 버서커 (기획서 7.3절) -------------------------------------------------

    BERSERK = {
      cost: 10,           # MP
      time: 4,            # 초
      atk_mult: 1.5,      # 주는 데미지
      taken_mult: 0.5,    # 받는 데미지
    }

    # 발동할 수 있는가
    def self.can_berserk?(mp, active)
      !active && mp >= BERSERK[:cost]
    end
  end
end
