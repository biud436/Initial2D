# aldebaran_monsters_data_test.rb : 몬스터 규격서 스키마의 단위 테스트
# (docs/plans/aldebaran-6-source-mining.md 3절 7항). aldebaran_monsters_data_test.lua 의 Ruby 판.
#
# 이 표는 P5에서 적 열 종을 담을 그릇이다. 그릇의 모양이 지켜지는지, 그리고
# stages/forest.rb를 거쳐 게임에 그대로 닿는지를 본다. 원안 값(spec)은 사료라
# 바뀌면 안 되므로 몇 개를 못 박아 둔다.
#
# 0.3, 0.35, 0.7 은 3.0 / 10 처럼 나눗셈으로 적는다. 이 엔진의 mruby 는 그 리터럴을 1 ulp
# 어긋나게 읽어서, 리터럴로 쓰면 표의 값과 == 이 어긋난다 (data/monsters.rb 참고).

require "scripts/ruby/games/aldebaran/data/monsters"
require "scripts/ruby/games/aldebaran/stages/init"

T.run_case("aldebaran_monsters_data") do |t|
  monsters = Aldebaran::Monsters
  species = Aldebaran::Monsters::SPECIES
  # Stages.get 은 Lua 의 두 값 반환을 [모듈, 이유] 로 옮겼다
  got = Aldebaran::Stages.get("forest")
  stage = got.is_a?(Array) ? got[0] : got

  # [A] 스키마: 모든 종이 검사를 통과한다
  begin
    problems = monsters.validate
    t.check_eq(problems.size, 0, "스키마 문제 없음: " + problems.join(" / "))
    t.check_eq(species.size, 8, "종은 여덟이다 (숲 넷, 무덤 셋, 보스 아포피스)")
  end

  # [B] 검사기가 진짜로 잡는가 (통과만 보면 검사기가 죽어도 모른다)
  begin
    t.check(!monsters.validate_species(:x, {}).nil?, "빈 종은 걸러진다")
    t.check(!monsters.validate_species(:x, "표가 아님").nil?, "표가 아니면 걸러진다")

    broken = species[:spider].dup
    broken.delete(:hp)
    t.check(!monsters.validate_species(:x, broken).nil?, "엔진 칸이 빠지면 걸러진다")

    badspec = species[:spider].dup
    badspec[:spec] = { element: :dark, 오타칸: 1 }
    t.check(!monsters.validate_species(:x, badspec).nil?, "spec의 모르는 칸은 걸러진다")

    badtype = species[:spider].dup
    badtype[:spec] = { attack_type: :없는형 }
    t.check(!monsters.validate_species(:x, badtype).nil?, "모르는 공격 방식은 걸러진다")

    badtier = species[:spider].dup
    badtier[:spec] = { stats: { move_speed: :초광속 } }
    t.check(!monsters.validate_species(:x, badtier).nil?,
            "모르는 이동 속도 단계는 걸러진다")
  end

  # [C] 원안 2.3.1절 표 6: 공격 방식 넷. 사료 표에 우리 것이 섞이면 안 된다
  begin
    t.check_eq(Aldebaran::Monsters::ATTACK_TYPES.size, 4, "원안의 공격 방식은 넷이다")
    [:melee, :charge, :throw, :suicide].each do |key|
      t.check(!Aldebaran::Monsters::ATTACK_TYPES[key].nil?, "원안의 공격 방식 #{key}")
    end
    t.check_eq(Aldebaran::Monsters::EXTRA_ATTACK_TYPES.size, 2, "우리가 더한 것은 둘이다")
    [:air, :shield].each do |key|
      t.check(Aldebaran::Monsters::ATTACK_TYPES[key].nil?, "#{key}는 원안 표에 없다")
      t.check(!Aldebaran::Monsters::EXTRA_ATTACK_TYPES[key].nil?, "우리 공격 방식 #{key}")
      t.check(!Aldebaran::Monsters::EXTRA_ATTACK_TYPES[key][:question].nil?,
              "#{key}는 묻는 질문이 적혀 있다")
    end
    t.check(!monsters.attack_type(:melee).nil?, "attackType은 원안 것을 찾는다")
    t.check(!monsters.attack_type(:air).nil?, "attackType은 우리 것도 찾는다")
    t.check(monsters.attack_type(:없는형).nil?, "모르는 것은 nil")

    # 자폭형은 A7에서 처음 쓰인다 (원안 표 6의 넷 중 마지막 빈 칸이었다)
    used = {}
    species.each_value do |entry|
      if entry[:spec] && entry[:spec][:attack_type]
        used[entry[:spec][:attack_type]] = true
      end
    end
    [:melee, :charge, :throw, :suicide, :air, :shield].each do |key|
      t.check(used[key], "공격 방식 #{key}을 쓰는 종이 있다")
    end
  end

  # [C2] 텔레그래프 부등식 (계획 aldebaran-7-tomb.md 5절):
  #      선딜 >= 회피 성립 프레임 + 인지 반응(15프레임).
  #
  #      **이 규칙은 1-1의 적에게는 아직 적용할 수 없다.** 부등식의 왼쪽 항은
  #      "회피 수단의 성립 프레임"인데, 지금 게임에는 무적 프레임을 가진 회피가
  #      없다 (대쉬는 그냥 빠른 이동이다). 진짜 회피는 P3의 일이고, 그때 1-1의
  #      수치도 함께 본다.
  #
  #      그래서 여기서는 둘로 나눠 검사한다.
  #        1) A7의 새 적 셋 (부등식을 지켜 설계했으므로 지킨다).
  #        2) 1-1의 적 넷 (지금 값을 못 박아 둔다. 누가 바꾸면 여기가 알려 준다).
  begin
    min_windup = 32.0 / 60
    [:soul, :sentinel, :shard].each do |key|
      entry = species[key]
      t.check(entry[:windup] >= min_windup - 1e-9,
              "#{key}의 선딜이 32프레임 이상 (#{entry[:windup]})")
    end
    shard = species[:shard]
    t.check(shard[:fuse_time] >= 45.0 / 60 - 1e-9,
            "자폭 예고는 45프레임 이상 (#{shard[:fuse_time]})")

    # 1-1의 적은 셋 다 부등식을 깬다 (21, 18, 16프레임). 알고 두는 것이다.
    known = { spider: 35.0 / 100, wolf: 3.0 / 10, blackwolf: 0.26, monkey: 0.4 }
    # 아포피스는 A7에서 설계했으므로 부등식을 지킨다
    t.check(species[:apophis][:windup] >= min_windup - 1e-9,
            "아포피스의 선딜이 32프레임 이상")
    known.each do |key, want|
      t.check_eq(species[key][:windup], want,
                 "1-1 #{key}의 선딜은 아직 #{want}초다 (P3에서 다시 본다)")
      t.check(want < min_windup,
              "기록: #{key}은 부등식을 깬다 (P3가 회피를 넣을 때 함께 고친다)")
    end
  end

  # [D] 원안 6.2.2절 표 37: 이동 속도 5단계
  begin
    tiers = Aldebaran::Monsters::SPEED_TIERS
    t.check_eq(tiers.size, 5, "이동 속도는 5단계다")
    t.check_eq(tiers[0][:scale], 3.0 / 10, "1단계는 0.3")
    t.check_eq(tiers[4][:scale], 3.0, "5단계는 3.0")
  end

  # [E] 원안 표 39와 40의 값은 사료다. 바뀌면 채굴본과 어긋난 것이다
  begin
    spider = species[:spider][:spec]
    t.check_eq(spider[:source][:table], 39, "거미는 원안 표 39")
    t.check_eq(spider[:source][:section], "6.3", "거미는 원안 6.3절")
    t.check_eq(spider[:element], :dark, "거미는 암 속성")
    t.check_eq(spider[:weakness][:light], true, "거미는 빛에 약하다 (P4의 상성)")
    t.check_eq(spider[:reward][:exp], 5, "거미 보상 경험치 5")
    t.check_eq(spider[:reward][:gold], 10, "거미 보상 골드 10")
    t.check_eq(spider[:specials][0][:chance], 0.2, "독침 발동 20%")
    t.check_eq(spider[:specials][0][:damage], 28, "독침 28 데미지 (원안)")
    t.check_eq(spider[:behavior_stages].size, 3, "거미의 단계별 행동은 셋")
    t.check_eq(spider[:stats][:max_hp], nil, "원안은 거미의 최대 HP를 비워 두었다")

    wolf = species[:wolf][:spec]
    t.check_eq(wolf[:source][:table], 40, "늑대 인간은 원안 표 40")
    t.check_eq(wolf[:stats][:max_hp], 72, "늑대 인간 최대 HP 72 (원안)")
    t.check_eq(wolf[:stats][:max_mp], 40, "늑대 인간 최대 MP 40 (원안)")
    t.check_eq(wolf[:stats][:atk], 24, "늑대 인간 공격력 24 (원안)")
    t.check_eq(wolf[:stats][:defense], 5, "늑대 인간 방어 5 (원안)")
    t.check_eq(wolf[:stats][:int], 41, "늑대 인간 지능 41 (원안)")
    t.check_eq(wolf[:specials][0][:mp], 23, "돌격은 MP 23을 쓴다 (원안)")
    t.check_eq(wolf[:specials][0][:damage], 27, "돌격 27 데미지 (원안)")
  end

  # [E2] 무덤의 적 셋: 각자 다른 질문을 한다 (질문이 겹치면 적이 아니라 장식이다)
  begin
    soul = species[:soul]
    t.check_eq(soul[:flies], true, "순장된 영혼은 떠다닌다")
    t.check(soul[:dive_speed] > soul[:fly_speed], "내려찍기가 떠다니기보다 빠르다")
    t.check_eq(soul[:spec][:attack_type], :air, "공중형")

    sen = species[:sentinel]
    t.check_eq(sen[:guard_front], true, "무덤 번병은 앞을 막는다")
    t.check(sen[:turn_delay] > 0, "돌아서는 데 시간이 걸린다 (등이 열리는 시간)")
    t.check_eq(sen[:spec][:attack_type], :shield, "방패형")

    shard = species[:shard]
    t.check_eq(shard[:special], :fuse, "파괴의 조각은 심지가 탄다")
    t.check(shard[:blast_radius] > shard[:attack_range], "폭발이 사거리보다 넓다")
    t.check_eq(shard[:spec][:attack_type], :suicide, "자폭형 (원안 표 6)")
    t.check_eq(shard[:spec][:source][:table], 6, "자폭형만은 원안에 출처가 있다")

    types = {}
    [:soul, :sentinel, :shard].each do |key|
      at = species[key][:spec][:attack_type]
      t.check(!types[at], "#{key}의 공격 방식이 다른 둘과 겹치지 않는다")
      types[at] = true
    end
  end

  # [E3] 보스 아포피스: 3페이즈, 즉사기 없음, 펀치 윈도우가 줄어든다
  begin
    boss = species[:apophis]
    phases = Aldebaran::Monsters::BOSS_PHASES
    t.check_eq(boss[:phases].size, 3, "페이즈는 셋이다")
    t.check_eq(phases.size, 3, "페이즈 표도 셋이다")
    t.check(boss[:phase_guard] > 0, "페이즈 전환에 무적이 있다 (언제 때리는지 보이게)")

    # 후딜은 페이즈마다 짧아진다. 그래야 두 번째 시도에서 더 잘하게 된다
    prev = nil
    phases.each_with_index do |ph, idx|
      i = idx + 1                    # Lua 와 같은 1부터의 페이즈 번호
      t.check(ph[:recover] > 0, "#{i}페이즈에 펀치 윈도우가 있다")
      if prev
        t.check(ph[:recover] < prev, "#{i}페이즈의 후딜이 앞보다 짧다")
      end
      t.check(ph[:cycle].size > 0, "#{i}페이즈의 패턴 사이클이 비어 있지 않다")
      t.check(ph[:cycle].all? { |p| p.is_a?(Symbol) }, "#{i}페이즈의 패턴 이름은 Symbol이다")
      prev = ph[:recover]
    end

    # 즉사가 없다: 한 방이 레벨 1의 최대 HP(60)보다 작아야 한다
    t.check(boss[:atk] < 60, "평타로 즉사하지 않는다")
    t.check(boss[:charge_atk] < 60, "돌진으로도 즉사하지 않는다")

    t.check_eq(monsters.phase_for(1.0), 1, "가득 차 있으면 1페이즈")
    t.check_eq(monsters.phase_for(7.0 / 10), 1, "0.7은 아직 1페이즈")
    t.check_eq(monsters.phase_for(0.66), 2, "0.66에서 2페이즈")
    t.check_eq(monsters.phase_for(0.4), 2, "0.4는 2페이즈")
    t.check_eq(monsters.phase_for(0.33), 3, "0.33에서 3페이즈")
    t.check_eq(monsters.phase_for(0.0), 3, "바닥은 3페이즈")
    # Ruby 판의 덤: 페이즈 번호로 표 한 줄을 꺼내는 boss_phase
    t.check(monsters.boss_phase(1).equal?(phases[0]), "boss_phase(1)은 표의 첫 줄")
    t.check(monsters.boss_phase(3).equal?(phases[2]), "boss_phase(3)은 표의 마지막 줄")
    t.check_eq(monsters.boss_phase(4), nil, "boss_phase(4)는 nil")
    t.check_eq(monsters.boss_phase(0), nil, "boss_phase(0)은 nil")
  end

  # [F] 원안에 규격서가 없는 종은 그 사실이 남아 있다
  begin
    t.check_eq(species[:blackwolf][:spec][:source], nil,
               "검은 늑대는 원안에 규격서가 없다")
    t.check_eq(species[:monkey][:spec][:source], nil,
               "가면 원숭이는 원안에 규격서가 없다")
    t.check(species[:blackwolf][:spec][:notes].size > 0, "그 사실이 note에 있다")
    t.check(species[:monkey][:spec][:notes].size > 0, "그 사실이 note에 있다")
  end

  # [G] 회귀: 스테이지를 거쳐도 게임이 읽던 값 그대로다 (A6는 수치를 바꾸지 않는다)
  begin
    t.check(stage.species.equal?(species), "스테이지의 종별 표는 같은 표를 가리킨다")
    t.check(monsters.species.equal?(species), "Monsters.species 도 같은 표를 가리킨다")
    t.check(monsters.species(:spider).equal?(species[:spider]), "Monsters.species(id)는 그 종 하나")
    t.check_eq(stage.species[:spider][:hp], 26, "거미 HP 26")
    t.check_eq(stage.species[:spider][:atk], 9, "거미 공격 9")
    t.check_eq(stage.species[:spider][:sting_bonus], 8, "거미 독침 보너스 8 (구현값)")
    t.check_eq(stage.species[:wolf][:hp], 48, "늑대 HP 48")
    t.check_eq(stage.species[:wolf][:charge_atk], 14, "늑대 돌격 14")
    t.check_eq(stage.species[:blackwolf][:hp], 72, "검은 늑대 HP 72")
    t.check_eq(stage.species[:monkey][:attack_range], 160, "짐도둑 사거리 160")
    t.check_eq(stage.species[:monkey][:flee_range], 64, "짐도둑 도주 거리 64")
  end

  # [H] 배치가 부르는 종이 전부 표에 있다 (오타가 나면 스폰이 조용히 사라진다)
  begin
    stage.spawns.each_with_index do |s, idx|
      t.check(!species[s[:species]].nil?,
              "배치 #{idx + 1}의 종 '#{s[:species]}'이 표에 있다")
    end
  end
end
