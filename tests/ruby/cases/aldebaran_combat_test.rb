# aldebaran_combat_test.rb : 전투와 성장 수식의 단위 테스트. aldebaran_combat_test.lua 의 Ruby 판.
# (docs/plans/aldebaran-2-combat.md 3절, 8절)

require "scripts/ruby/games/aldebaran/combat"
require "scripts/ruby/rpg/rng"

T.run_case("aldebaran_combat") do |t|
  combat = Aldebaran::Combat
  rng_class = Rpg::Rng

  # [A] 데미지: 하한 1
  t.check_eq(combat.damage(10, 2), 8, "평타 = 공격 - 방어")
  t.check_eq(combat.damage(5, 10), 1, "방어가 더 높아도 데미지는 1")
  t.check_eq(combat.damage(10.9, 2), 8, "데미지는 내림")
  t.check_type(combat.damage(10.9, 2), Integer, "데미지는 정수")

  # [B] 명중 굴림: 행운 0.2면 크리티컬 약 15%에 회피 없음, 행운 0이면
  #     크리티컬 없음에 회피 약 5% (시드 고정이라 수치가 결정적이다)
  rng = rng_class.new(42)
  crit = 0
  miss = 0
  1000.times do
    r = combat.roll(rng, 0.2)
    crit += 1 if r[:kind] == :crit
    miss += 1 if r[:kind] == :miss
  end
  t.check(crit > 100 && crit < 200, "행운 0.2의 크리티컬은 약 15%", crit)
  t.check_eq(miss, 0, "행운 0.2면 회피당하지 않는다")

  rng = rng_class.new(42)
  crit = 0
  miss = 0
  1000.times do
    r = combat.roll(rng, 0)
    crit += 1 if r[:kind] == :crit
    miss += 1 if r[:kind] == :miss
  end
  t.check_eq(crit, 0, "행운 0이면 크리티컬이 없다")
  t.check(miss > 20 && miss < 90, "행운 0의 회피는 약 5%", miss)

  # [C] resolve: 배율까지 합친 최종 데미지
  # 가짜 난수: float 만 흉내낸다 (Lua 는 { float = function() ... end } 표)
  fake_rng = Class.new do
    attr_accessor :value
    def float
      @value
    end
  end
  fake = fake_rng.new
  fake.value = 0.99                                   # 크리티컬 구간
  r = combat.resolve(10, 2, fake, 0.2)
  t.check_eq(r[:kind], :crit, "0.99 굴림 + 행운 0.2는 크리티컬")
  t.check_eq(r[:dmg], 12, "크리티컬은 1.5배 내림 (8 -> 12)")
  fake.value = 0.01
  r = combat.resolve(10, 2, fake, 0)
  t.check_eq(r[:kind], :miss, "0.01 굴림 + 행운 0은 회피")
  t.check_eq(r[:dmg], 0, "회피는 데미지 0")

  # [D] 레벨 표의 경계
  t.check_eq(combat.level_for(0), 1, "경험치 0은 레벨 1")
  t.check_eq(combat.level_for(9), 1, "9는 아직 레벨 1")
  t.check_eq(combat.level_for(10), 2, "10에서 레벨 2")
  t.check_eq(combat.level_for(24), 2, "24는 레벨 2")
  t.check_eq(combat.level_for(25), 3, "25에서 레벨 3")
  t.check_eq(combat.level_for(140), 7, "140에서 최고 레벨 7")
  t.check_eq(combat.level_for(9999), 7, "그 위로도 7")

  # [E] 성장치
  s1 = combat.stats_at(1)
  t.check(s1[:hp] == 60 && s1[:mp] == 20 && s1[:atk] == 10 && s1[:defense] == 2,
          "레벨 1은 시작 능력치")
  s3 = combat.stats_at(3)
  t.check(s3[:hp] == 84 && s3[:mp] == 30 && s3[:atk] == 16 && s3[:defense] == 4,
          "레벨 3 = 시작 + 성장 x2")

  # [F] EXP 바의 비율
  t.check_eq(combat.exp_ratio(5), 0.5, "레벨 1 구간의 절반")
  t.check_eq(combat.exp_ratio(10), 0, "레벨이 오르면 바는 처음부터")
  t.check_eq(combat.exp_ratio(140), 1, "최고 레벨은 가득")
  t.check_eq(combat.exp_to_next(5), 5, "다음 레벨까지 5")
  t.check_eq(combat.exp_to_next(140), nil, "최고 레벨은 다음이 없다")

  # [H] 힘과 쿨타임 (기획서 5.3절)
  s = combat.new_skills
  t.check(!s[:berserk], "처음에는 아무 힘도 없다")
  t.check(!combat.can_use?(s, :berserk, 99), "익히지 않으면 쓸 수 없다")
  s[:berserk] = true
  t.check(combat.can_use?(s, :berserk, 10), "익히고 MP가 있으면 쓸 수 있다")
  t.check(!combat.can_use?(s, :berserk, 9), "MP가 모자라면 못 쓴다")
  s[:cooldown][:berserk] = 3
  t.check(!combat.can_use?(s, :berserk, 99), "쿨타임이 돌면 못 쓴다")
  combat.tick_cooldowns(s, 1)
  t.check_eq(s[:cooldown][:berserk], 2, "쿨타임이 시간만큼 줄어든다")
  combat.tick_cooldowns(s, 5)
  t.check_eq(s[:cooldown][:berserk], 0, "0 아래로는 내려가지 않는다")
  t.check(combat.can_use?(s, :berserk, 99), "다 식으면 다시 쓸 수 있다")
  t.check(!combat.can_use?(s, :edge, 99), "늘 켜져 있는 힘은 쓰는 것이 아니다")
  t.check_eq(combat::SKILL_ORDER.size, 5, "힘은 다섯이다")

  # [G] 버서커
  t.check(combat.can_berserk?(10, false), "MP가 넉넉하면 발동")
  t.check(!combat.can_berserk?(9, false), "MP가 모자라면 못 켠다")
  t.check(!combat.can_berserk?(20, true), "이미 켜져 있으면 못 켠다")
  t.check_eq(combat::BERSERK[:time], 4, "지속 4초")
end
