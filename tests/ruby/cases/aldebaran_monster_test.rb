# aldebaran_monster_test.rb : 몬스터 상태 기계의 단위 테스트
# (docs/plans/aldebaran-2-combat.md 4절, 8절). aldebaran_monster_test.lua 의 Ruby 판.
#
# 가짜 지도 위에서 순찰, 추적, 공격, 돌격, 회복, 죽음을 프레임 단위로 재현한다.
#
# 0.3 과 0.7 은 3.0 / 10 처럼 나눗셈으로 적는다. 이 엔진의 mruby 는 그 리터럴을 1 ulp
# 어긋나게 읽어서, 리터럴로 쓰면 monster.rb 의 값과 == 이 어긋난다 (monster.rb 참고).

require "scripts/ruby/games/aldebaran/monster"

T.run_case("aldebaran_monster") do |t|
  monster = Aldebaran::Monster

  dt = 1.0 / 60
  far = 99999                 # 플레이어가 아주 멀다 (경계 밖)

  make_probe = lambda do |solids|
    lambda do |px, py|
      next true if px < 0 || px >= 500 * 16
      next false if py >= 100 * 16
      next false if py < 0
      solids["#{(px / 16.0).floor},#{(py / 16.0).floor}"] == true
    end
  end

  fill_row = lambda do |solids, ty, x0, x1|
    (x0..x1).each { |x| solids["#{x},#{ty}"] = true }
  end

  fill_col = lambda do |solids, tx, y0, y1|
    (y0..y1).each { |y| solids["#{tx},#{y}"] = true }
  end

  # 종별 표의 최소형 (stages/forest.rb 의 실물과 같은 필드)
  make_spec = lambda do |extra|
    base = {
      hp: 20, atk: 5, defense: 1, exp: 1, gold: 1,
      walk_speed: 30, chase_speed: 60,
      alert_range: 80, attack_range: 16,
      windup: 3.0 / 10, active: 0.1, recover: 0.4,
      half_w: 8, body_h: 16,
      cols: 4, frames: { walk: [0, 1], attack: 2, hurt: 3 },
    }
    base.merge(extra || {})
  end

  step = lambda do |m, probe, n, px = nil, py = nil|
    n.times { m.update(dt, probe, px || far, py || m.y) }
  end

  # 평평한 땅 (윗면 24)과 그 위의 몬스터
  flat = lambda do |spec_extra, opts|
    solids = {}
    fill_row.call(solids, 24, 0, 499)
    probe = make_probe.call(solids)
    spec = make_spec.call(spec_extra)
    opts ||= {}
    opts[:x] ||= 400
    opts[:y] ||= 384
    m = monster.new(spec, opts)
    step.call(m, probe, 2)      # 착지 확정
    [m, probe, solids, spec]
  end

  # [A] 순찰: 정해진 구간을 왕복한다
  begin
    m, probe = flat.call(nil, { x: 400, min_x: 360, max_x: 440, dir: 1 })
    step.call(m, probe, 120)     # 2초 = 60px. maxX(440)에 닿고 돌아선다
    t.check_eq(m.state, :patrol, "플레이어가 멀면 순찰")
    t.check(m.x < 440 + 1, "순찰 구간을 넘지 않는다", m.x)
    t.check_eq(m.dir, -1, "구간 끝에서 돌아선다")
  end

  # [B] 순찰: 벽에서 돌아선다 (원안 6.2.3절)
  begin
    m, probe, solids = flat.call(nil, { x: 400, min_x: 200, max_x: 600, dir: 1 })
    fill_col.call(solids, 27, 22, 24)     # px 432 벽
    step.call(m, probe, 90)
    t.check_eq(m.dir, -1, "벽과 부딪치면 반대 방향")
    t.check(m.x < 432 - 7, "벽을 뚫지 않는다", m.x)
  end

  # [C] 순찰: 벼랑에서 돌아선다 (스스로 떨어지지 않는다)
  begin
    solids = {}
    fill_row.call(solids, 24, 20, 30)     # px 320~495만 땅
    probe = make_probe.call(solids)
    m = monster.new(make_spec.call(nil), { x: 400, y: 384, min_x: 200, max_x: 700, dir: 1 })
    step.call(m, probe, 2)
    step.call(m, probe, 240)              # 4초면 구간을 몇 번 오간다
    t.check_eq(m.state, :patrol, "여전히 순찰")
    t.check(m.on_ground, "떨어지지 않았다")
    t.check(m.x > 320 && m.x < 496, "벼랑 사이를 오간다", m.x)
  end

  # [D] 경계 범위에 들어오면 추적, 벗어나면 복귀
  begin
    m, probe = flat.call(nil, { x: 400, min_x: 360, max_x: 440 })
    step.call(m, probe, 1, 400 + 70, 384)  # 경계(80) 안
    t.check_eq(m.state, :chase, "경계 안이면 추적")
    x0 = m.x
    step.call(m, probe, 30, 560, 384)
    t.check(m.x > x0, "추적은 플레이어 쪽으로 다가간다")
    step.call(m, probe, 5, 400 + 200, 384) # 경계 x1.5(120) 밖
    t.check_eq(m.state, :patrol, "멀어지면 순찰로 돌아간다")
  end

  # [E] 공격: 선딜레이 -> 판정 -> 후딜레이 -> 다시 추적
  begin
    m, probe = flat.call(nil, { x: 400 })
    px = 410                               # 공격 범위(16) 안
    step.call(m, probe, 1, px, 384)
    t.check_eq(m.state, :chase, "먼저 추적")
    step.call(m, probe, 1, px, 384)
    t.check_eq(m.state, :windup, "닿으면 움츠린다")
    t.check_eq(m.attack_box, nil, "선딜레이에는 판정이 없다")
    step.call(m, probe, (3.0 / 10 / dt).floor + 1, px, 384)
    t.check_eq(m.state, :strike, "선딜레이가 끝나면 공격")
    t.check(!m.attack_box.nil?, "공격 판정 상자가 선다")
    t.check(!m.strike_hit, "판정은 아직 쓰지 않았다")
    step.call(m, probe, (0.1 / dt).floor + 1, px, 384)
    t.check_eq(m.state, :recover, "판정이 끝나면 후딜레이")
    step.call(m, probe, (0.4 / dt).floor + 1, px, 384)
    t.check(m.state == :windup || m.state == :chase, "후딜레이가 끝나면 다시")
  end

  # [F] 돌격형(늑대): 발견 시 1회, 그 뒤로는 쓰지 않는다
  begin
    m, probe = flat.call({ special: :charge, charge_speed: 150,
                           charge_time: 0.5, charge_atk: 14 },
                         { x: 400, min_x: 300, max_x: 500 })
    step.call(m, probe, 1, 470, 384)
    t.check_eq(m.state, :charge, "발견하면 돌격")
    t.check(!m.attack_box.nil?, "돌격 중에는 몸이 판정이다")
    x0 = m.x
    step.call(m, probe, 6, 470, 384)
    t.check(m.x - x0 > 60 * 6 * dt, "돌격은 추적보다 빠르다", m.x - x0)
    step.call(m, probe, (0.5 / dt).floor + 2, 470, 384)
    t.check(m.charge_used, "돌격은 한 번뿐")
    t.check_eq(m.state != :charge, true, "돌격이 끝났다")
    # 다시 멀어졌다 돌아와도 돌격은 없다
    step.call(m, probe, 60, far, 384)
    t.check_eq(m.state, :patrol, "복귀")
    step.call(m, probe, 1, 470, 384)
    t.check_eq(m.state, :chase, "두 번째 발견은 그냥 추적")
  end

  # [G] 추적 중에는 낮은 턱을 뛰어넘는다 (원안: 벽이 있어도 점프)
  begin
    m, probe, solids = flat.call(nil, { x: 400, min_x: 200, max_x: 600 })
    fill_col.call(solids, 28, 23, 24)     # 한 타일 턱 (px 448, 벽면은 몸이 439에서 막힘)
    step.call(m, probe, 60, 470, 384)     # 경계(80) 안의 플레이어를 추적
    t.check(m.x > 445 || !m.on_ground, "턱을 뛰어넘는 중이거나 넘었다", m.x)
    step.call(m, probe, 150, 470, 384)
    t.check(m.x > 445, "결국 턱을 넘어 쫓아간다", m.x)
    t.check(m.state == :windup || m.state == :strike || m.state == :recover ||
            m.state == :chase, "플레이어 곁에 닿았다", m.state)
  end

  # [H] 비전투 회복 (원안: 4초마다 최대 HP의 1/20)
  begin
    m, probe = flat.call({ regen: true, hp: 40 }, { x: 400, min_x: 360, max_x: 440 })
    m.hp = 10
    step.call(m, probe, (4 / dt).floor + 5)
    t.check_eq(m.hp, 12, "4초 뒤 최대 HP의 1/20(2)을 회복")
    step.call(m, probe, 3, 420, 384)       # 전투가 시작되면
    m.hp = 10
    before = m.hp
    step.call(m, probe, (4 / dt).floor + 5, 420, 384)
    t.check_eq(m.hp, before, "전투 중에는 회복하지 않는다")
  end

  # [I] 피격: 경직과 밀림, 때린 쪽을 돌아본다
  begin
    m, probe = flat.call(nil, { x: 400, dir: 1 })
    died = m.hurt(5, 1)                    # 오른쪽에서 맞았다
    t.check(!died, "아직 살아 있다")
    t.check_eq(m.hp, 15, "체력이 줄었다")
    t.check_eq(m.state, :hurt, "경직")
    t.check_eq(m.dir, -1, "때린 쪽을 돌아본다")
    step.call(m, probe, (0.25 / dt).floor + 2, 500, 384)
    t.check_eq(m.state, :chase, "경직이 풀리면 반격하러 온다")
  end

  # [J] 죽음: 소멸 연출 뒤에 사라진다
  begin
    m, probe = flat.call(nil, { x: 400 })
    died = m.hurt(999, 1)
    t.check(died, "치명타면 hurt가 true를 돌려준다")
    t.check_eq(m.state, :dying, "소멸 연출로")
    t.check_eq(m.attack_box, nil, "죽는 중에는 판정이 없다")
    t.check(!m.dead, "연출 동안에는 남아 있다")
    step.call(m, probe, (0.5 / dt).floor + 3)
    t.check(m.dead, "연출이 끝나면 사라진다")
    hp0 = m.hp
    again = m.hurt(5, 1)
    t.check(!again && m.hp == hp0, "죽은 몬스터는 더 맞지 않는다")
  end

  # [K] 시트 칸: 상태마다 다른 칸, 왼쪽 보기는 아랫줄
  begin
    m, probe = flat.call(nil, { x: 400, dir: 1 })
    f = m.frame
    t.check(f == 0 || f == 1, "순찰은 걷기 칸", f)
    m.dir = -1
    t.check(m.frame >= 4, "왼쪽 보기는 아랫줄 (cols만큼 밀린다)")
    m.dir = 1
    m.state = :strike
    t.check_eq(m.frame, 2, "공격 칸")
    m.state = :hurt
    t.check_eq(m.frame, 3, "피격 칸")
  end

  # ---- A7: 1-2 황제의 무덤의 적 셋 ------------------------------------------
  # (docs/plans/aldebaran-7-tomb.md 5절) 적 하나는 질문 하나다. 그 질문이
  # 코드에서 실제로 성립하는지를 여기서 본다.

  # [I] 공중형: 중력이 없다. 떠 있다가 내려찍고 다시 올라간다
  begin
    solids = {}
    fill_row.call(solids, 24, 0, 499)
    probe = make_probe.call(solids)
    spec = make_spec.call({
      flies: true, fly_speed: 60, dive_speed: 380,
      alert_range: 120, attack_range: 40, alert_range_y: 96,
      windup: 0.55, active: 0.28, recover: 7.0 / 10, rise_speed: 190,
    })
    hover_y = 24 * 16 - 60                 # 지면보다 60px 위
    m = monster.new(spec, { x: 200, y: hover_y, min_x: 160, max_x: 260 })

    step.call(m, probe, 60)                # 플레이어가 멀다
    t.check_eq(m.y, hover_y, "공중형은 떨어지지 않는다 (중력 없음)")
    t.check_eq(m.on_ground, false, "땅에 닿지 않는다")

    # 플레이어가 아래 멀찍이 선다 → 추적 (아직 사거리 밖)
    py = 24 * 16
    step.call(m, probe, 10, 280, py)
    t.check_eq(m.state, :chase, "가까우면 추적")

    # 사거리 안으로 들어오면 움츠리며 위로 → 내려찍기
    px = 210

    rose = false
    240.times do
      m.update(dt, probe, px, py)
      rose = true if m.state == :windup && m.y < hover_y - 6
      break if m.state == :strike
    end
    t.check(rose, "움츠릴 때 위로 뜬다 (내려찍기의 예고)")
    t.check_eq(m.state, :strike, "내려찍는다")

    60.times do
      m.update(dt, probe, px, py)
      break if m.y >= py - 2
    end
    t.check(m.y >= py - 8, "플레이어 발치까지 내려온다")

    box = m.attack_box
    t.check(!box.nil? && !box[0].nil?, "내려찍는 동안 판정이 있다")
  end

  # [J] 방패형: 앞은 막고 등은 열린다. 돌아서는 데 시간이 걸린다
  begin
    m, probe = flat.call({ guard_front: true, turn_delay: 0.5, hp: 30 },
                         { x: 200, min_x: 160, max_x: 260 })
    m.dir = -1                             # 왼쪽을 본다

    # 왼쪽에서 오는 것(플레이어가 오른쪽을 보고 친다)은 앞이다 → 막는다
    died = m.hurt(10, 1)
    t.check_eq(died, false, "막았으니 죽지 않는다")
    t.check_eq(m.hp, 30, "앞에서 온 것은 체력을 깎지 못한다")
    t.check_eq(m.state, :block, "막으면 굳는다 (반격 창)")

    # 굳은 동안은 다시 막지 않는다 (막기 연타로 무적이 되면 안 된다)
    step.call(m, probe, 40, far)
    t.check(m.state != :block, "굳은 것은 풀린다")

    # 오른쪽에서 오는 것(플레이어가 왼쪽을 보고 친다)은 등이다 → 들어간다
    m.dir = -1
    before = m.hp
    m.hurt(10, -1)
    t.check_eq(m.hp, before - 10, "등은 그대로 맞는다")

    # 돌아서는 데 turn_delay가 걸린다
    m2 = flat.call({ guard_front: true, turn_delay: 0.5 },
                   { x: 200, min_x: 160, max_x: 260 })[0]
    m2.dir = -1
    m2.state = :chase
    m2.update(dt, probe, 260, m2.y)        # 플레이어가 오른쪽에
    t.check_eq(m2.dir, -1, "한 프레임에 홱 돌지 않는다")
    40.times { m2.update(dt, probe, 260, m2.y) }
    t.check_eq(m2.dir, 1, "0.5초가 지나면 돌아선다")
  end

  # [K] 자폭형: 붙으면 심지가 타고 터진다. 그 사이에 베면 터지지 않는다
  begin
    m, probe = flat.call({ special: :fuse, hp: 14, atk: 26,
                           alert_range: 150, chase_speed: 95,
                           fuse_range: 26, fuse_time: 0.75, blast_time: 0.15, blast_radius: 30 },
                         { x: 200, min_x: 100, max_x: 300 })

    px = 215
    120.times do
      m.update(dt, probe, px, m.y)
      break if m.state == :fuse
    end
    t.check_eq(m.state, :fuse, "붙으면 심지에 불이 붙는다")
    t.check(m.attack_box.nil?, "심지가 타는 동안은 아직 안 아프다")

    60.times do
      m.update(dt, probe, px, m.y)
      break if m.state == :boom
    end
    t.check_eq(m.state, :boom, "터진다")
    bx0, by0, bx1, by1 = m.attack_box
    t.check(!bx0.nil?, "터지는 순간 판정이 있다")
    t.check(bx1 - bx0 > 2 * 26, "폭발이 사거리보다 넓다")
    t.check(by0 < m.y - 16, "위로도 퍼진다")
    t.check(by1 > m.y, "아래로도 퍼진다")

    # 터지는 중에는 더 맞지 않는다 (터진 것을 또 베는 일이 없게)
    t.check_eq(m.hurt(99, 1), false, "터지는 중에는 판정을 받지 않는다")

    30.times { m.update(dt, probe, px, m.y) }
    t.check_eq(m.state, :dying, "터지고 나면 스러진다")

    # 심지가 타는 동안 베면 터지지 않고 그대로 죽는다
    m2, probe2 = flat.call({ special: :fuse, hp: 14,
                             alert_range: 150, chase_speed: 95,
                             fuse_range: 26, fuse_time: 0.75, blast_time: 0.15, blast_radius: 30 },
                           { x: 200, min_x: 100, max_x: 300 })
    120.times do
      m2.update(dt, probe2, 215, m2.y)
      break if m2.state == :fuse
    end
    t.check_eq(m2.state, :fuse, "심지가 탄다")
    t.check_eq(m2.hurt(14, 1), true, "이때 베면 죽는다")
    t.check_eq(m2.state, :dying, "터지지 않고 스러진다 (boom을 건너뛴다)")
    t.check(m2.attack_box.nil?, "그래서 아프지 않다")
  end

  # ---- Ruby 판의 덤: 씬(game.rb)이 기대는 표면 --------------------------------

  # [L] 보스 페이즈: 경계를 넘으면 무적이 되고 물러선다. 페이즈 번호는 1부터다
  begin
    m, probe = flat.call({ hp: 100, special: :charge, charge_speed: 150, charge_time: 0.5,
                           charge_atk: 14, charge_repeat: true,
                           phases: [1.0, 0.66, 0.33], phase_guard: 1.0 },
                         { x: 400, min_x: 300, max_x: 500 })
    t.check_eq(m.phase, 1, "처음은 1페이즈")
    t.check_eq(m.hurt(40, 1), false, "경계를 넘는 한 방은 죽이지 않는다")
    t.check_eq(m.phase, 2, "60%면 2페이즈")
    t.check_eq(m.state, :recover, "페이즈가 바뀌면 물러선다")
    t.check(m.phase_guard > 0, "페이즈 전환 무적")
    hp1 = m.hp
    t.check_eq(m.hurt(10, 1), false, "무적 중에는 안 맞는다")
    t.check_eq(m.hp, hp1, "무적 중에는 체력이 그대로다")
    step.call(m, probe, 61, 470, 384)      # 1초가 지나면 무적이 풀린다
    m.hurt(1, 1)
    t.check_eq(m.hp, hp1 - 1, "무적이 풀리면 다시 맞는다")
    t.check_eq(m.charge_used, false, "페이즈가 바뀌면 돌격을 다시 쓴다")
  end

  # [M] 짐도둑: 절반에서 두 번째 판, 돌은 씬이 던지므로 판정 상자가 없다
  begin
    m, probe = flat.call({ special: :throw, hp: 60, flee_range: 64,
                           alert_range: 200, attack_range: 160 },
                         { x: 400, min_x: 300, max_x: 500 })
    t.check(!m.phase2, "처음은 첫 번째 판")
    m.hurt(30, 1)
    t.check_eq(m.phase2, true, "절반이면 두 번째 판")
    step.call(m, probe, 30, 520, 384)      # 사거리 안, 도주 거리 밖
    t.check_eq(m.attack_box, nil, "투척형은 어느 상태에서도 판정 상자가 없다")
    t.check(m.x >= 300 && m.x <= 500, "제 구간을 벗어나지 않는다", m.x)
  end

  # [N] 접근자 표면: 상수와 씬이 읽고 쓰는 칸이 전부 있다
  begin
    t.check_eq(monster::GRAVITY, 980, "GRAVITY")
    t.check_eq(monster::MAX_FALL, 480, "MAX_FALL")
    t.check_eq(monster::HOP_V, -250, "HOP_V")
    t.check_eq(monster::HURT_TIME, 0.25, "HURT_TIME")
    t.check_eq(monster::DYING_TIME, 0.5, "DYING_TIME")
    t.check_eq(monster::REGEN_TICK, 4, "REGEN_TICK")
    t.check_eq(monster::BLOCK_TIME, 3.0 / 10, "BLOCK_TIME")
    m, = flat.call(nil, { x: 400 })
    [:spec, :x, :y, :vx, :vy, :dir, :on_ground, :min_x, :max_x, :state, :hp, :timer,
     :anim_time, :charge_used, :regen_timer, :hover_y, :phase, :phase_guard, :dead, :fade,
     :strike_hit, :thrown, :phase2, :pattern_fired, :cycle_index, :recover_time,
     :turn_timer, :blocked].each do |name|
      t.check(m.respond_to?(name) && m.respond_to?("#{name}="),
              "칸 #{name} 을 읽고 쓸 수 있다")
    end
    t.check_eq(m.body, [m.x - 8, m.y - 16, m.x + 8, m.y], "body 는 [x0, y0, x1, y1]")
    t.check_type(m.body, Array, "body 는 배열 하나로 돌려준다 (Lua 의 값 넷)")
    t.check(!m.respond_to?(:def), "def 라는 이름은 쓰지 않는다")
  end
end
