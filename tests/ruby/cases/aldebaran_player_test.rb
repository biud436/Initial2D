# aldebaran_player_test.rb : 카르토 이동 물리의 단위 테스트. aldebaran_player_test.lua 의 Ruby 판.
# (docs/plans/aldebaran-1-core.md 8절)
#
# 가짜 충돌 지도를 주입해 물리를 프레임 단위로 재현한다. 엔진이 필요 없다.

require "scripts/ruby/games/aldebaran/player"

T.run_case("aldebaran_player") do |t|
  player = Aldebaran::Player

  dt = 1.0 / 60

  # solids: { "tx,ty" => true } 인 가짜 지도. 좌우 밖은 벽, 아래 밖은 낭떠러지.
  make_probe = lambda do |solids|
    lambda do |px, py|
      next true if px < 0 || px >= 200 * 16
      next false if py >= 200 * 16
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

  # n 프레임 굴린다. inputs[i]가 있으면 그 프레임의 입력, 없으면 빈 입력.
  step = lambda do |pl, probe, n, inputs = nil|
    n.times do |i|
      pl.update((inputs && inputs[i]) || {}, dt, probe)
    end
  end

  # 평평한 땅 (윗면 타일 24, 발 픽셀 384)과 그 위에 선 플레이어
  flat_ground = lambda do
    solids = {}
    fill_row.call(solids, 24, 0, 199)
    probe = make_probe.call(solids)
    pl = player.new(100, 384)
    step.call(pl, probe, 3)   # 첫 프레임에 착지를 확정
    [pl, probe, solids]
  end

  # [A] 걷기: 등속이다 (가속 없음)
  pl, probe = flat_ground.call
  x0 = pl.x
  step.call(pl, probe, 1, [{ right: true }])
  step1 = pl.x - x0
  step.call(pl, probe, 1, [{ right: true }])
  step2 = pl.x - x0 - step1
  t.check((step1 - player::WALK_SPEED * dt).abs < 0.01, "걷기 한 프레임 = 속도 x dt", step1)
  t.check((step2 - step1).abs < 0.001, "걷기는 등속 (가속 없음)")
  t.check_eq(pl.facing, 1, "오른쪽을 본다")
  step.call(pl, probe, 1, [{ left: true }])
  t.check_eq(pl.facing, -1, "왼쪽 입력이면 왼쪽을 본다")
  step.call(pl, probe, 1, [{ left: true, right: true }])
  t.check_eq(pl.vx, 0, "양쪽을 같이 누르면 멈춘다")

  # [B] 벽에 막힌다
  pl, probe, solids = flat_ground.call
  fill_col.call(solids, 8, 20, 24)    # px 128~143 벽
  pl.x = 200                          # 벽의 오른쪽에서 왼쪽으로 걷는다
  inputs = Array.new(120) { { left: true } }
  step.call(pl, probe, 120, inputs)
  t.check(pl.x > 8 * 16 + 16, "벽을 뚫지 않는다", pl.x)
  t.check((pl.x - (9 * 16 + player::HALF_W)).abs < 1, "벽에 붙어 멈춘다", pl.x)

  # [C] 점프 최고점: 3타일(48px)은 넘고 4타일(64px)은 못 넘는다
  pl, probe = flat_ground.call
  top = pl.y
  step.call(pl, probe, 1, [{ jump_edge: true }])
  t.check(pl.jumped, "점프가 일어났다")
  120.times do
    pl.update({}, dt, probe)
    top = [top, pl.y].min
    break if pl.on_ground
  end
  rise = 384 - top
  t.check(rise > 48, "점프 상승이 3타일을 넘는다", rise)
  t.check(rise < 64, "점프 상승이 4타일에는 못 미친다", rise)
  t.check(pl.on_ground, "다시 착지한다")

  # [D] 2단 점프: 합쳐 5타일(80px)을 넘고 6타일(96px)은 못 넘는다
  pl, probe = flat_ground.call
  top = pl.y
  step.call(pl, probe, 1, [{ jump_edge: true }])
  second = false
  200.times do
    input = {}
    if !second && pl.vy >= 0          # 최고점에서 한 번 더
      input[:jump_edge] = true
      second = true
    end
    pl.update(input, dt, probe)
    top = [top, pl.y].min
    break if pl.on_ground
  end
  rise = 384 - top
  t.check(rise > 80, "2단 점프가 5타일을 넘는다", rise)
  t.check(rise < 96, "2단 점프도 6타일에는 못 미친다", rise)

  # [E] 공중 점프는 한 번만
  pl, probe = flat_ground.call
  step.call(pl, probe, 1, [{ jump_edge: true }])
  step.call(pl, probe, 2)
  step.call(pl, probe, 1, [{ jump_edge: true }])
  t.check_eq(pl.air_jumps, 0, "공중 점프를 쓰면 남은 횟수가 0")
  vy_before = pl.vy
  step.call(pl, probe, 1, [{ jump_edge: true }])
  t.check(pl.vy > vy_before - 1, "세 번째 점프는 없다 (속도가 다시 튀지 않는다)")

  # [F] 걸어서 떨어져도 공중 점프는 한 번 남는다
  solids = {}
  fill_row.call(solids, 24, 0, 10)    # 절벽: x<=175까지만 땅
  probe = make_probe.call(solids)
  pl = player.new(160, 384)
  step.call(pl, probe, 3)
  inputs = Array.new(30) { { right: true } }
  step.call(pl, probe, 30, inputs)    # 오른쪽 끝을 지나 떨어진다
  t.check(!pl.on_ground, "절벽을 걸어 나가면 공중이다")
  vy_before = pl.vy
  step.call(pl, probe, 1, [{ jump_edge: true }])
  t.check(pl.vy < vy_before, "떨어지는 중에도 점프가 한 번 된다")
  t.check_eq(pl.air_jumps, 0, "그 한 번을 쓰면 끝")

  # [G] 2타일 턱에 뛰어 올라선다
  pl, probe, solids = flat_ground.call
  fill_row.call(solids, 22, 10, 20)   # 턱 윗면 22 (지면보다 2타일 위)
  fill_row.call(solids, 23, 10, 20)
  pl.x = 140                          # 턱 바로 앞 (모서리 154에서 14px)
  inputs = [{ jump_edge: true, right: true }]
  89.times { inputs.push({ right: true }) }
  step.call(pl, probe, 90, inputs)
  t.check(pl.on_ground, "턱 위에 착지했다")
  t.check_eq(pl.y, 22 * 16, "발이 턱 윗면에 있다")

  # [H] 더블탭 대쉬
  pl, probe = flat_ground.call
  step.call(pl, probe, 1, [{ right_edge: true, right: true }])
  step.call(pl, probe, 3, [{ right: false }, {}, {}])
  step.call(pl, probe, 1, [{ right_edge: true, right: true }])
  t.check(pl.dashed, "빠른 두 번 누름은 대쉬다")
  t.check((pl.vx - player::DASH_SPEED).abs < 0.01, "대쉬 속도", pl.vx)
  # 대쉬가 끝나면 걷기 속도로
  inputs = Array.new(30) { { right: true } }
  step.call(pl, probe, 30, inputs)
  t.check((pl.vx - player::WALK_SPEED).abs < 0.01, "대쉬가 끝나면 걷기 속도", pl.vx)

  # [I] 느린 두 번 누름은 대쉬가 아니다
  pl, probe = flat_ground.call
  step.call(pl, probe, 1, [{ right_edge: true, right: true }])
  step.call(pl, probe, 20)            # 0.33초, 판정 창(0.25초) 밖
  step.call(pl, probe, 1, [{ right_edge: true, right: true }])
  t.check(!pl.dashed, "판정 창을 지난 두 번째 누름은 그냥 걷기다")

  # [J] 낙하 최대 속도
  probe = make_probe.call({})         # 땅이 없다
  pl = player.new(100, 0)
  step.call(pl, probe, 120)
  t.check_eq(pl.vy, player::MAX_FALL, "낙하 속도가 상한에서 멈춘다")

  # [K] 천장에 머리를 부딪히면 상승이 멈춘다
  pl, probe, solids = flat_ground.call
  fill_row.call(solids, 21, 0, 199)   # 낮은 천장 (턱 위 공간 2타일)
  step.call(pl, probe, 1, [{ jump_edge: true }])
  step.call(pl, probe, 10)
  t.check(pl.y >= 22 * 16 + player::BODY_H, "머리가 천장을 뚫지 않는다", pl.y)

  # [M] 달리기 기억과 공중 관성: 달리다 손을 떼고 점프해도 앞으로 나아간다
  #     (단일 터치 조작, 패드와 점프 버튼을 동시에 누를 수 없다)
  pl, probe = flat_ground.call
  inputs = [{ right: true }, { right: true }, {}, { jump_edge: true }]
  step.call(pl, probe, 4, inputs)     # 달리고, 손을 떼고, 다음 프레임에 점프
  t.check(!pl.on_ground, "공중에 떠 있다")
  t.check((pl.vx - player::WALK_SPEED).abs < 0.01,
          "손을 뗀 직후의 점프가 달리기 속도를 잇는다", pl.vx)
  x0 = pl.x
  step.call(pl, probe, 5)             # 입력 없음
  t.check(pl.x > x0 + 5, "공중에서는 관성으로 나아간다", pl.x - x0)
  90.times do
    pl.update({}, dt, probe)
    break if pl.on_ground
  end
  xl = pl.x
  step.call(pl, probe, 3)
  t.check((pl.x - xl).abs < 0.001, "착지하면 멈춘다")

  # [N] 서 있다가 한참 뒤의 점프는 제자리 점프다 (기억 유예가 끝났다)
  pl, probe = flat_ground.call
  step.call(pl, probe, 2, [{ right: true }, { right: true }])
  step.call(pl, probe, 20)            # 0.33초, 유예(0.18초)를 지난다
  step.call(pl, probe, 1, [{ jump_edge: true }])
  t.check_eq(pl.vx, 0, "유예가 지난 점프는 제자리 점프")

  # [L] 시트 칸 고르기
  pl, probe = flat_ground.call
  t.check(pl.frame <= 1, "서 있으면 서기 칸")
  step.call(pl, probe, 1, [{ right: true }])
  f = pl.frame
  t.check(f >= 2 && f <= 5, "걸으면 걷기 칸", f)
  step.call(pl, probe, 1, [{ jump_edge: true }])
  t.check_eq(pl.frame, 6, "상승 중엔 점프 칸")
  step.call(pl, probe, 1, [{ left: true }])
  t.check(pl.frame >= 12, "왼쪽을 보면 아랫줄 칸")
  t.check_type(pl.frame, Integer, "시트 칸은 정수")

  # [O] 3단 콤보: 활성 이후의 입력이 다음 단으로 이어진다 (2단계)
  pl, probe = flat_ground.call
  step.call(pl, probe, 1, [{ attack_edge: true }])
  t.check_eq(pl.attack_stage, 1, "첫 누름은 1단")
  t.check(pl.swung, "베기가 일어났다")
  t.check_eq(pl.attack_phase, :wind, "처음에는 선딜레이")
  t.check(!pl.attack_active?, "선딜레이에는 판정이 없다")
  step.call(pl, probe, 7)             # 0.117초, 활성 구간
  t.check_eq(pl.attack_phase, :active, "판정 구간")
  t.check(pl.attack_active?, "판정이 살아 있다")
  x0, _, x1 = pl.attack_box
  t.check(x0 > pl.x, "오른쪽을 보면 판정 상자는 앞쪽", x0)
  t.check_eq(x1 - x0, 22, "판정 상자의 폭은 22")
  step.call(pl, probe, 1, [{ attack_edge: true }])   # 활성 중의 입력 = 예약
  30.times do
    pl.update({}, dt, probe)
    break if pl.attack_stage == 2
  end
  t.check_eq(pl.attack_stage, 2, "예약된 입력이 2단으로 이어진다")
  t.check_eq(pl.attack_mult, 1, "2단까지는 배율 1")
  # 2단이 끝난 뒤 유예 안의 입력은 3단
  60.times do
    pl.update({}, dt, probe)
    break if pl.attack_timer <= 0
  end
  step.call(pl, probe, 3)             # 유예(0.4초) 안
  step.call(pl, probe, 1, [{ attack_edge: true }])
  t.check_eq(pl.attack_stage, 3, "유예 안의 입력은 3단 십자 베기")
  t.check((pl.attack_mult - player::COMBO_FINISHER).abs < 0.001,
          "십자 베기는 데미지 배율 1.6")
  # 3단이 끝나면 콤보가 처음으로
  60.times { pl.update({}, dt, probe) }
  step.call(pl, probe, 1, [{ attack_edge: true }])
  t.check_eq(pl.attack_stage, 1, "십자 베기 뒤에는 처음부터")

  # [P] 콤보 유예가 지나면 처음부터
  pl, probe = flat_ground.call
  step.call(pl, probe, 1, [{ attack_edge: true }])
  step.call(pl, probe, 60)            # 1초, 베기와 유예가 다 지난다
  step.call(pl, probe, 1, [{ attack_edge: true }])
  t.check_eq(pl.attack_stage, 1, "유예가 지난 입력은 1단부터")

  # [Q] 베는 동안에는 제자리 (지상)
  pl, probe = flat_ground.call
  step.call(pl, probe, 2, [{ right: true }, { right: true }])
  step.call(pl, probe, 1, [{ attack_edge: true, right: true }])
  x0 = pl.x
  step.call(pl, probe, 5, [{ right: true }, { right: true }, { right: true },
                           { right: true }, { right: true }])
  t.check((pl.x - x0).abs < 0.001, "베는 동안 방향키가 안 먹는다")

  # [R] 피격: 넉백, 경직, 무적 1초
  pl, probe = flat_ground.call
  ok = pl.apply_hit(pl.x + 10)        # 오른쪽에서 맞았다
  t.check(ok, "맞았다")
  t.check(pl.vx < 0, "때린 반대쪽으로 밀린다")
  t.check(pl.hurt_timer > 0, "경직")
  t.check(pl.invuln_timer > 0, "무적 시간")
  t.check_eq(pl.frame % 12, 11, "피격 칸")
  t.check(!pl.apply_hit(pl.x + 10), "무적 중에는 다시 맞지 않는다")
  # 경직 중에는 입력이 안 먹는다
  vy0 = pl.vy
  step.call(pl, probe, 1, [{ jump_edge: true }])
  t.check(pl.vy >= vy0, "경직 중에는 점프가 안 된다")
  # 경직이 풀리고 무적이 끝나면 다시 맞는다
  70.times { pl.update({}, dt, probe) }
  t.check_eq(pl.hurt_timer, 0, "경직이 풀렸다")
  t.check_eq(pl.invuln_timer, 0, "무적이 끝났다")
  t.check(pl.apply_hit(pl.x - 10), "다시 맞을 수 있다")
  t.check(pl.vx > 0, "왼쪽에서 맞으면 오른쪽으로 밀린다")
end
