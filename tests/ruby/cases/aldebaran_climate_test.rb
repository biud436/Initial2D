# aldebaran_climate_test.rb : 기후의 단위 테스트. aldebaran_climate_test.lua 의 Ruby 판.
# (docs/plans/aldebaran-7-tomb.md 4절)
#
# 기후는 연출이 아니라 규칙이다. 그러니 규칙으로 검사한다. 눈은 멈추는 것을
# 늦추는가, 빛은 언제 켜지는가, 우박은 예고 뒤에 떨어지는가, 물은 잠기게
# 하는가. 그림은 골든이 본다.
#
# 뒤의 케이스 aldebaran_stages 는 Ruby 판에서 더한 것이다. 스테이지 목록과 두
# 스테이지 표가 읽히는지, 씬이 기대는 칸이 채워져 있는지를 본다 (Lua 에는 이
# 검사가 game.lua 를 돌리는 인수 씬 안에 흩어져 있다).

require "scripts/ruby/games/aldebaran/climate"
require "scripts/ruby/games/aldebaran/stages/init"
require "scripts/ruby/rpg/rng"

T.run_case("aldebaran_climate") do |t|
  climate = Aldebaran::Climate
  stages = Aldebaran::Stages

  dt = 1.0 / 60

  step = lambda do |c, seconds, ctx = nil|
    (seconds / dt).floor.times do
      climate.update(c, dt, ctx || { x: 0, floor_y: 400, ceil_y: 100 })
    end
  end

  # [A] 기후가 없는 방: 무엇을 물어도 기본값이다
  t.check_eq(climate.create(nil), nil, "표가 없으면 기후도 없다")
  env = climate.env(nil, 300)
  t.check_eq(env[:friction], 1, "마찰은 기본값")
  t.check_eq(env[:move_mult], 1, "이동 배율은 기본값")
  t.check_eq(env[:jump_mult], 1, "점프 배율은 기본값")
  t.check_eq(climate.lit(nil, 100), true, "빛기둥이 없으면 늘 벨 수 있다")
  t.check_eq(climate.light_on(nil), false, "켜져 있지 않다")
  t.check_eq(climate.water_y(nil), nil, "수면이 없다")
  t.check_eq(climate.hazards(nil).size, 0, "위험이 없다")
  # (Ruby 판에서 더한 검사) nil 상태는 어떤 함수에도 조용히 지나간다
  quiet = true
  begin
    climate.update(nil, dt, {})
    climate.drop(nil, 0, 400)
    climate.surge(nil, 1.0)
    climate.consume(nil, 0)
  rescue => e
    quiet = false
  end
  t.check(quiet, "nil 상태의 update, drop, surge, consume 은 아무 일도 하지 않는다")
  t.check_eq(climate.env(nil), Aldebaran::Climate::DEFAULT_ENV, "y 없이 물어도 기본값")

  # [B] 눈: 마찰만 낮춘다. 이동과 점프는 그대로다
  c = climate.create({ kind: :snow, friction: 0.34 })
  t.check_type(c, Aldebaran::Climate::State, "create 는 State 를 돌려준다")
  t.check_eq(c.kind, :snow, "종류는 Symbol")
  env = climate.env(c, 300)
  t.check_eq(env[:friction], 0.34, "지면 마찰이 준다")
  t.check_eq(env[:move_mult], 1, "걷는 속도는 그대로")
  t.check_eq(env[:jump_mult], 1, "점프 높이도 그대로")
  t.check_eq(climate.lit(c, 0), true, "눈은 벨 수 있고 없고와 무관하다")

  # [C] 빛기둥: 주기의 앞부분만 켜지고, 켜진 동안에도 기둥 안만 벤다
  c = climate.create({ kind: :light, period: 4.0, lit: 2.2,
                       pillars: [100, 300], half_w: 40 })
  t.check_eq(climate.light_on(c), true, "처음에는 켜져 있다")
  t.check_eq(climate.lit(c, 100), true, "기둥 한가운데는 빛 안")
  t.check_eq(climate.lit(c, 139), true, "기둥의 가장자리도 빛 안")
  t.check_eq(climate.lit(c, 200), false, "기둥 사이는 그늘")
  t.check_eq(climate.lit(c, 300), true, "두 번째 기둥도 빛 안")

  step.call(c, 2.5)                     # 켜진 구간(2.2초)을 지나면
  t.check_eq(climate.light_on(c), false, "2.2초가 지나면 꺼진다")
  t.check_eq(climate.lit(c, 100), false, "꺼져 있으면 기둥 안도 그늘")

  step.call(c, 2.0)                     # 주기 4.0초를 돌아 다시 켜진다
  t.check_eq(climate.light_on(c), true, "주기가 돌면 다시 켜진다")

  # [D] 우박: 예고가 먼저다. 예고 중에는 아프지 않다
  c = climate.create({ kind: :hail, interval: 1.6, first: 0.5,
                       warn: 0.5, damage: 9, speed: 320, half_w: 5, count: 1 })
  ctx = { x: 200, floor_y: 400, ceil_y: 100 }

  t.check_eq(c.drops.size, 0, "처음에는 떨어지는 것이 없다")
  step.call(c, 0.55, ctx)
  t.check_eq(c.drops.size, 1, "첫 알이 당겨 떨어진다 (방을 배우게)")
  t.check_eq(climate.hazards(c).size, 0, "예고 중에는 아직 아프지 않다")
  t.check(c.drops[0][:y].nil?, "예고 중에는 위치가 없다 (그림자만 있다)")
  # (Ruby 판에서 더한 검사) 난수가 없으면 i 번째 알은 (i-1)/n 자리에 뜬다
  t.check_eq(c.drops[0][:x], 104.0, "난수가 없으면 첫 알은 x - 96 에 뜬다")

  step.call(c, 0.55, ctx)
  t.check(!c.drops[0][:y].nil?, "예고가 끝나면 떨어지기 시작한다")
  hz = climate.hazards(c)
  t.check_eq(hz.size, 1, "이제 아프다")
  t.check_eq(hz[0][:damage], 9, "데미지는 표에서 온다")
  t.check(hz[0][:x1] - hz[0][:x0] == 10, "상자는 halfW의 두 배")
  t.check(hz[0][:y1] - hz[0][:y0] == 10, "상자의 높이도 half_w 의 두 배")

  # 맞으면 그 알은 사라진다 (한 알이 두 번 아프면 안 된다)
  climate.consume(c, 0)                 # Ruby 는 0 기준 (Lua 의 consume(c, 1))
  t.check_eq(climate.hazards(c).size, 0, "맞은 알은 지워진다")

  # 바닥에 닿으면 스스로 사라진다
  c2 = climate.create({ kind: :hail, interval: 1e9, first: 0.1,
                        warn: 0.1, speed: 400 })
  step.call(c2, 0.25, ctx)
  t.check_eq(c2.drops.size, 1, "한 알이 떨어지고 있다")
  step.call(c2, 1.5, ctx)
  t.check_eq(c2.drops.size, 0, "바닥에 닿으면 사라진다")

  # 보스가 밖에서 떨구는 길
  c3 = climate.create({ kind: :hail, interval: 1e9, first: 1e9, warn: 0.2 })
  climate.drop(c3, 500, 400)
  t.check_eq(c3.drops.size, 1, "밖에서도 한 알을 떨굴 수 있다 (보스의 패턴)")

  # (Ruby 판에서 더한 검사) consume 의 번호는 hazards 의 번호다. 예고 중인 알은 세지 않는다
  c4 = climate.create({ kind: :hail, interval: 1e9, first: 1e9, warn: 0.1, half_w: 5 })
  climate.drop(c4, 10, 400)
  climate.drop(c4, 20, 400)
  step.call(c4, 0.15, ctx)              # 두 알 모두 떨어지기 시작
  climate.drop(c4, 30, 400)             # 셋째는 아직 예고 중
  t.check_eq(climate.hazards(c4).size, 2, "예고 중인 알은 hazards 에 없다")
  climate.consume(c4, 1)                # hazards 의 둘째 (x = 20)
  left = c4.drops.map { |dp| dp[:x] }
  t.check_eq(left, [10, 30], "consume(1) 은 hazards 의 둘째 알을 지운다")

  # (Ruby 판에서 더한 검사) 표에 first 가 없으면 첫 알은 0.6초 뒤다. 이 VM 은 0.6 리터럴을
  # 1 ulp 어긋나게 읽으므로 climate.rb 는 6.0 / 10 으로 적는다 (Lua 의 0.6 과 같은 double)
  t.check_eq(climate.create({ kind: :hail }).next_drop, 6.0 / 10, "첫 알의 기본 지연은 Lua 의 0.6 과 같은 값")

  # (Ruby 판에서 더한 검사) 난수를 주면 플레이어 언저리(±96)에 떨어진다
  c5 = climate.create({ kind: :hail, interval: 0.1, first: 0.1, warn: 1e9, count: 2 })
  rng = Rpg::Rng.new(7)
  step.call(c5, 1.0, { x: 1000, floor_y: 400, ceil_y: 100, rng: rng })
  near = c5.drops.all? { |dp| dp[:x] >= 904 && dp[:x] <= 1096 }
  t.check(c5.drops.size >= 10 && near, "난수가 있으면 x ± 96 안에 흩어진다",
          "#{c5.drops.size}알")

  # [E] 홍수: 수위가 사다리꼴로 오르내리고, 잠기면 느려진다
  c = climate.create({ kind: :flood, period: 9.0, low: 400, high: 336,
                       move_mult: 0.55, jump_mult: 0.72 })
  t.check_eq(c.water_y, 400, "처음에는 낮다")
  t.check_eq(climate.env(c, 380)[:move_mult], 1, "수면 위에서는 그대로")
  t.check_eq(climate.env(c, 420)[:move_mult], 0.55, "수면 아래면 느려진다")
  t.check_eq(climate.env(c, 420)[:jump_mult], 0.72, "수면 아래면 낮게 뛴다")

  step.call(c, 5.0)                     # 주기의 절반쯤이면 최고 수위다
  t.check_eq(c.water_y, 336, "수위가 올라 있다")
  t.check_eq(climate.env(c, 380)[:move_mult], 0.55, "아까 마른 자리가 잠겼다")
  t.check_eq(climate.water_y(c), 336, "수면을 물어볼 수 있다")

  # 머무는 구간이 있어야 판단할 시간이 있다 (사인이 아니라 사다리꼴이다)
  c2 = climate.create({ kind: :flood, period: 9.0, low: 400, high: 336 })
  step.call(c2, 1.0)
  t.check_eq(c2.water_y, 400, "처음 3분의 1은 낮은 채로 머문다")
  step.call(c2, 1.5)
  t.check_eq(c2.water_y, 400, "아직 머문다")

  # 보스가 밀어 올리면 그동안은 최고 수위로 고정된다
  c3 = climate.create({ kind: :flood, period: 9.0, low: 400, high: 336 })
  climate.surge(c3, 1.0)
  step.call(c3, 0.5)
  t.check_eq(c3.water_y, 336, "보스가 밀어 올린 동안은 최고 수위")
  step.call(c3, 1.0)
  t.check_eq(c3.water_y, 400, "밀어 올린 시간이 끝나면 제 주기로 돌아온다")

  # (Ruby 판에서 더한 검사) 주기가 정수여도 오르는 도중의 수위는 실수다
  # (Ruby 의 정수 나눗셈이 사다리꼴을 계단으로 만들지 않는가)
  c6 = climate.create({ kind: :flood, period: 9, low: 400, high: 336 })
  step.call(c6, 3.6)                    # 위상 0.4: 오르는 도중
  w = c6.water_y
  t.check(w > 370 && w < 388 && w != w.floor, "오르는 도중의 수위는 사이값이다", w.to_s)
  t.check_eq(climate.surge(climate.create({ kind: :snow }), 1.0), nil,
             "홍수가 아닌 기후에는 surge 가 먹지 않는다")

  # [F] 스테이지의 표가 실제로 이 모듈이 아는 종류인가
  tomb = stages.get("tomb")[0]
  t.check(!tomb.nil?, "1-2가 있다")
  known = { snow: true, light: true, hail: true, flood: true }
  count = 0
  (tomb.climate || {}).each do |name, spec|
    count += 1
    t.check(known[spec[:kind]], "#{name}의 기후 '#{spec[:kind]}'을 안다")
    t.check(!climate.create(spec).nil?, "#{name}의 기후를 만들 수 있다")
  end
  t.check_eq(count, 4, "기후가 걸린 방은 넷이다 (입구는 없다)")
  t.check_eq(tomb.climate[:chest], nil, "가슴부 입구에는 기후가 없다 (배우는 방)")

  # 구간 이름과 기후 표의 열쇠가 어긋나면 기후가 조용히 사라진다
  tomb.sections.each do |sec|
    if sec[:name] != :chest
      t.check(!tomb.climate[sec[:name]].nil?, "구간 #{sec[:name]}에 기후가 있다")
    end
  end

  # [G] 1-1에는 기후가 없다 (A7이 숲을 건드리지 않았다는 회귀 검사)
  forest = stages.get("forest")[0]
  t.check_eq(forest.climate, nil, "검은 안개의 숲에는 기후 표가 없다")
end

T.run_case("aldebaran_stages") do |t|
  stages = Aldebaran::Stages

  # [1] 목록: 모르는 id 는 이유와 함께 nil
  forest, why = stages.get("forest")
  t.check_eq(forest, Aldebaran::Stages::Forest, "forest 는 Stages::Forest 모듈")
  t.check_eq(why, nil, "아는 id 에는 이유가 없다")
  tomb, why = stages.get("tomb")
  t.check_eq(tomb, Aldebaran::Stages::Tomb, "tomb 은 Stages::Tomb 모듈")
  t.check_eq(why, nil, "tomb 에도 이유가 없다")
  t.check_eq(stages.get("forest")[0], forest, "두 번 물어도 같은 모듈 (캐시)")

  nope, why = stages.get("nope")
  t.check_eq(nope, nil, "모르는 id 는 nil")
  t.check_eq(why, "모르는 스테이지 'nope'", "모르는 id 의 이유")
  none, why = stages.get(nil)
  t.check_eq(none, nil, "id 가 없으면 nil")
  t.check_eq(why, "스테이지 id가 없다", "id 가 없을 때의 이유")

  t.check_eq(Aldebaran::Stages::ORDER, ["forest", "tomb"], "순서는 1-1, 1-2")
  t.check_eq(stages.first.id, "forest", "처음 여는 스테이지는 숲")
  t.check_eq(stages.after("forest").id, "tomb", "숲 다음은 무덤")
  t.check(stages.after("tomb").nil?, "무덤 다음은 없다 (게임의 끝)")
  t.check(stages.after("nope").nil?, "모르는 id 의 다음도 없다")
  t.check_eq(stages.index_of("forest"), 1, "숲은 1 번째 (1 부터 센다)")
  t.check_eq(stages.index_of("tomb"), 2, "무덤은 2 번째")
  t.check_eq(stages.index_of("nope"), nil, "모르는 id 는 몇 번째도 아니다")
  t.check_eq(stages.count, 2, "스테이지는 둘")

  # [2] 칸: 두 스테이지가 씬이 읽는 칸을 모두 채웠다
  t.check_eq(forest.number, "1-1", "숲은 1-1")
  t.check_eq(tomb.number, "1-2", "무덤은 1-2")
  t.check_eq(forest.intro, :thief, "숲의 도입은 도둑 컷씬")
  t.check_eq(tomb.intro, :text, "무덤의 도입은 나레이션만")
  t.check_eq(forest.boss[:drops], :bag, "짐도둑은 배낭을 떨군다")
  t.check_eq(tomb.boss[:drops], nil, "아포피스는 떨구는 것이 없다")
  t.check_eq(forest.fog, true, "숲에는 안개가 있다")
  t.check_eq(tomb.fog, false, "무덤에는 안개가 없다")
  t.check_eq(tomb.bright, nil, "무덤에는 환각 그림이 없다")
  t.check_eq(forest.seed, 20260823, "숲의 시드")
  t.check_eq(tomb.seed, 20260824, "무덤의 시드")

  [forest, tomb].each do |st|
    name = st.id
    t.check(st.title.is_a?(String) && !st.title.empty?, "#{name}: 제목이 있다")
    t.check(st.map.is_a?(String) && st.bgm_slot.is_a?(String), "#{name}: 맵과 음악 경로가 있다")
    t.check(st.intro_text.is_a?(String) && !st.intro_text.empty?, "#{name}: 도입 나레이션이 있다")
    t.check(st.gameover_text.is_a?(String) && !st.gameover_text.empty?, "#{name}: 게임 오버 글이 있다")
    t.check(st.epilogue_full.is_a?(String), "#{name}: 마지막 한 줄이 있다")
    t.check_eq(st.epilogue.size, 4, "#{name}: 에필로그는 넷")
    t.check_eq(st.lives, 2, "#{name}: 목숨은 둘")
    t.check(st.start[:x].is_a?(Integer) && st.start[:y].is_a?(Integer), "#{name}: 시작 자리가 있다")
    t.check_eq(st.section_fade, 96, "#{name}: 구간 경계의 폭")
    t.check_eq(st.signs, [], "#{name}: 표지 글은 흔적으로 바뀌었다")

    t.check(!st.species.nil? && !st.species.empty?, "#{name}: 종별 표가 비어 있지 않다")
    t.check(!st.spawns.empty?, "#{name}: 배치가 비어 있지 않다")
    t.check(!st.checkpoints.empty?, "#{name}: 체크포인트가 비어 있지 않다")
    t.check(!st.landmarks.empty?, "#{name}: 흔적이 비어 있지 않다")
    t.check_eq(st.sections.size, 5, "#{name}: 구간은 다섯")

    missing = st.spawns.reject { |sp| st.species.key?(sp[:species]) }.map { |sp| sp[:species] }
    t.check(missing.empty?, "#{name}: 배치의 종이 모두 종별 표에 있다", missing.inspect)
    bosses = st.spawns.select { |sp| sp[:boss] }
    t.check(bosses.size == 1 && bosses[0][:species] == st.boss[:species],
            "#{name}: 보스 배치가 하나이고 boss 칸의 종과 같다")
    mk = st.species[st.boss[:species]]
    t.check(!mk.nil? && mk[:atk].is_a?(Numeric), "#{name}: 보스 종의 공격력을 읽을 수 있다")
    t.check(st.spawns.all? { |sp| sp[:min_x] <= sp[:x] && sp[:x] <= sp[:max_x] },
            "#{name}: 배치의 x 는 순찰 범위 안")
    t.check(st.checkpoints.all? { |cp| cp[:x].is_a?(Integer) && cp[:y].is_a?(Integer) },
            "#{name}: 체크포인트마다 x, y 가 있다")
    t.check(st.landmarks.all? { |lm| lm[:id].is_a?(Symbol) && lm[:x0] < lm[:x1] && lm[:title] && lm[:text] },
            "#{name}: 흔적마다 id, 구간, 제목, 글이 있다")
  end
  t.check_eq(forest.landmarks.map { |lm| lm[:skill] }, [:edge, :read, :leap, :berserk, :bolt],
             "숲의 흔적이 가르치는 기술 다섯")
  t.check_eq(forest.landmarks[3][:hallucination], 3.0, "부서진 우리에서 환각이 3초")

  # 체크포인트는 씬이 지난 표시를 적는다 (같은 Hash 가 다음에도 보인다)
  cp = forest.checkpoints[0]
  cp[:taken] = true
  t.check_eq(forest.checkpoints[0][:taken], true, "체크포인트의 taken 을 적을 수 있다")
  cp[:taken] = false

  # [3] 구간: 경계 앞뒤 96 픽셀에서 두 벌을 섞는다
  t.check_eq(forest.section_at(0), [:entrance, :road, 0], "숲 0: 입구, 섞지 않는다")
  t.check_eq(forest.section_at(700), [:entrance, :road, 29.0 / 192], "숲 700: 경계 앞 67px, 섞기 시작")
  t.check_type(forest.section_at(700)[2], Float, "섞는 비율은 실수 (정수 나눗셈이 아니다)")
  t.check_eq(forest.section_at(767), [:entrance, :road, 0.5], "숲 767: 경계에서 반반")
  t.check_eq(forest.section_at(800), [:entrance, :road, 0.5 + 33.0 / 192], "숲 800: 경계 뒤 33px")
  t.check_eq(forest.section_at(1000), [:road, :gorge, 0], "숲 1000: 옛 길 한가운데")
  t.check_eq(forest.section_at(4096), [:altar, :altar, 0], "숲 4096: 마지막 구간은 다음이 자기 자신")
  t.check_eq(forest.section_at(9999), [:altar, :altar, 0], "숲 끝 너머는 제단")

  t.check_eq(tomb.section_at(0), [:chest, :moon, 0], "무덤 0: 가슴부 입구")
  t.check_eq(tomb.section_at(1871), [:moon, :stars, 0.25], "무덤 1871: 달의 방 끝 48px 앞")
  t.check_eq(tomb.section_at(1000), [:moon, :stars, 0], "무덤 1000: 달의 방 한가운데")
  t.check_eq(tomb.section_at(4100), [:ruin, :sun, 0.5 + 69.0 / 192], "무덤 4100: 태양의 방에 69px 들어섰다")
  t.check_eq(tomb.section_at(9999), [:sun, :sun, 0], "무덤 끝 너머는 태양의 방")

  # [4] 무덤의 기후 표는 모두 State 가 된다
  tomb.sections.each do |sec|
    st = Aldebaran::Climate.create(tomb.climate[sec[:name]])
    if sec[:name] == :chest
      t.check_eq(st, nil, "chest 에는 기후 상태가 없다")
    else
      t.check_eq(st.kind, tomb.climate[sec[:name]][:kind], "#{sec[:name]} 의 기후 상태")
    end
  end
end
