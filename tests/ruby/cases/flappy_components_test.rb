# flappy_components_test.rb : 플래피 컴포넌트(scripts/ruby/components/flappy/)의 규칙 검증
# resources/scenes/flappy.json 으로 진짜 씬을 만들고 컴포넌트 메서드를 직접 부른다. 입력, 효과음,
# 종료, 화면 크기는 가짜로 바꿔 끼운다. 라벨은 tests/lua/cases/flappy_components_test.lua 와 같다.

require "scripts/ruby/scene_loader"
require "scripts/ruby/components/flappy/common"
require "scripts/ruby/components/flappy/bird"
require "scripts/ruby/components/flappy/pipes"
require "scripts/ruby/components/flappy/scroller"
require "scripts/ruby/components/flappy/director"

T.run_case("flappy_components") do |t|
  c = FlappyCommon
  w = 768
  h = 896
  ground_y = h - c::GROUND_H + 12        # 844, 새의 아래 끝이 여기 닿으면 죽는다
  bird_rest = h / 2.0 - c::BIRD_H / 2.0  # 416
  tick = 20                              # ms, dt 0.02초

  bird_c = Bird.new
  pipes_c = Pipes.new
  scroller_c = Scroller.new

  # 가짜 엔진의 상태. 바꿔 끼운 엔진 메서드가 이 Hash 를 읽고 쓴다
  fake = {}
  reset_fake = lambda do
    fake[:keys] = {}
    fake[:mouse_down] = false
    fake[:mouse_y] = 0
    fake[:sounds] = []
    fake[:exits] = 0
  end

  stubbed = []
  stub = lambda do |mod, name, body|
    saved = :"__flappy_test_#{name}"
    mod.singleton_class.send(:alias_method, saved, name)
    mod.define_singleton_method(name, &body)
    stubbed << [mod, name, saved]
  end
  rand_stubbed = false
  stub_rand = lambda do |body|
    c.define_singleton_method(:rand, &body)
    rand_stubbed = true
  end
  unstub_rand = lambda do
    c.singleton_class.send(:remove_method, :rand) if rand_stubbed
    rand_stubbed = false
  end

  opened = []

  begin
    stub.call(Graphics, :width, proc { w })
    stub.call(Graphics, :height, proc { h })
    stub.call(System, :exit, proc { |*_a| fake[:exits] += 1 })
    stub.call(Audio, :play_sound, proc { |_path, id, *_rest| fake[:sounds] << id; true })
    stub.call(Input, :key_down?, proc { |key| fake[:keys][key] == true })
    stub.call(Input, :mouse_down?, proc { |button| button == :left && fake[:mouse_down] })
    stub.call(Input, :mouse_y, proc { fake[:mouse_y] })

    # 새 판: 씬 파일로 씬을 만들고 상태 Hash 를 돌려준다 (자동 시연은 끈다).
    # 감독 컴포넌트의 puts 는 lines 에 모은다
    lines = []
    new_game = lambda do
      reset_fake.call
      scene = SceneLoader.open("flappy")
      opened << scene
      st = c.state(scene)
      st[:autoplay] = false
      scene.find("director").components[0].define_singleton_method(:puts) { |s| lines << s }
      [scene, st]
    end

    director_tick = lambda do |scene, elapsed = tick|
      lines.clear
      scene.find("director").components[0].update(scene.find("director"), scene, elapsed)
      lines.dup
    end

    count = lambda { |list, item| list.count { |v| v == item } }
    index_of = lambda { |scene, id| scene.objects.index { |o| o.id == id } }
    check_near = lambda do |actual, expected, label|
      t.check(actual.is_a?(Numeric) && (actual - expected).abs < 1e-6, label,
              "실제 #{actual.inspect}, 기대 #{expected.inspect}")
    end

    # [공용] 시간, 속도, 간격 --------------------------------------------------
    check_near.call(c.dt(20), 0.02, "dt: 20ms 는 0.02초")
    check_near.call(c.dt(100), 0.05, "dt: 50ms 를 넘는 틱은 0.05초로 자른다")
    t.check_eq(c.speed({ score: 0 }), 210.0, "speed: 0점은 기본 속도 210")
    t.check_eq(c.speed({ score: 10 }), 240.0, "speed: 1점마다 3씩 빨라진다")
    t.check_eq(c.speed({ score: 37 }), 320.0, "speed: 320 에서 멈춘다")
    t.check_eq(c.gap({ score: 0 }), 280, "gap: 0점은 280")
    t.check_eq(c.gap({ score: 21 }), 196, "gap: 1점마다 4씩 좁아진다")
    t.check_eq(c.gap({ score: 22 }), 195, "gap: 195 아래로는 좁아지지 않는다")

    # [공용] 파이프 높이: 200 부터 200 + (H - 지면 - 간격 - 340) 까지, 양 끝 포함
    tall = { h: h, score: 0 }
    lo = 200
    hi = 200 + (h - c::GROUND_H - 280 - 340)   # 200..412
    in_range = (1..300).all? do
      g = c.random_gap(tall)
      g.is_a?(Integer) && g >= lo && g <= hi
    end
    t.check(in_range, "randomGap: 300번 모두 200..412 의 정수")
    stub_rand.call(proc { |n| n - 1 })
    t.check_eq(c.random_gap(tall), hi, "randomGap: 위 끝 412 를 포함한다")
    t.check_eq(c.random_gap({ h: 600, score: 0 }), 201, "randomGap: 남는 높이가 없으면 200 이나 201")
    stub_rand.call(proc { |_n| 0 })
    t.check_eq(c.random_gap(tall), lo, "randomGap: 아래 끝 200 을 포함한다")
    unstub_rand.call
    scene, st = new_game.call
    bird = scene.find("bird")

    # [공용] 충돌 판정: 새의 판정 상자는 (182, y+10)..(246, y+54), 그림보다 작다 ---------
    pp = { x: 190, gap_y: 300 }   # 위 파이프 29..300, 아래 파이프 580..851 (간격 280)
    bird.y = 400
    t.check_eq(c.hit_pipe?(st, pp), false, "충돌: 간격 한가운데는 부딪치지 않는다")
    bird.y = 290
    t.check_eq(c.hit_pipe?(st, pp), false, "충돌: 위 파이프 끝에 닿기만 하면 부딪치지 않는다")
    bird.y = 289
    t.check_eq(c.hit_pipe?(st, pp), true, "충돌: 위 파이프로 1px 들어가면 부딪친다")
    bird.y = 526
    t.check_eq(c.hit_pipe?(st, pp), false, "충돌: 아래 파이프 끝에 닿기만 하면 부딪치지 않는다")
    bird.y = 527
    t.check_eq(c.hit_pipe?(st, pp), true, "충돌: 아래 파이프로 1px 들어가면 부딪친다")
    bird.y = 100
    t.check_eq(c.hit_pipe?(st, { x: 246, gap_y: 300 }), false, "충돌: 파이프 왼쪽 끝 246 은 부딪치지 않는다")
    t.check_eq(c.hit_pipe?(st, { x: 245, gap_y: 300 }), true, "충돌: 파이프 왼쪽 끝 245 는 부딪친다")
    t.check_eq(c.hit_pipe?(st, { x: 130, gap_y: 300 }), false, "충돌: 파이프 오른쪽 끝 182 는 부딪치지 않는다")
    t.check_eq(c.hit_pipe?(st, { x: 131, gap_y: 300 }), true, "충돌: 파이프 오른쪽 끝 183 은 부딪친다")
    bird.y = 450
    t.check_eq(c.hit_pipe?(st, pp), false, "충돌: 0점(간격 280)에서는 같은 자리가 안전하다")
    st[:score] = 20
    t.check_eq(c.hit_pipe?(st, pp), true, "충돌: 20점(간격 200)에서는 같은 자리가 부딪친다")

    # [공용] 죽음과 최고 점수
    st[:score] = 3
    st[:best] = 5
    st[:dead_time] = 1.0
    c.die(st)
    t.check_eq(st[:state], :dead, "die: 상태는 dead")
    t.check_eq(st[:dead_time], 0.0, "die: 죽은 뒤 시간을 0 부터 센다")
    t.check_eq(st[:best], 5, "die: 최고 점수보다 낮으면 최고 점수는 그대로")
    st[:score] = 7
    c.die(st)
    t.check_eq(st[:best], 7, "die: 최고 점수를 넘으면 갱신한다")
    t.check_eq(count.call(fake[:sounds], "hit"), 2, "die: 죽을 때마다 hit 효과음")

    # [공용] 새 판으로 되돌리기: 최고 점수만 남는다
    st[:score] = 9
    st[:best] = 9
    st[:ready_time] = 3.0
    st[:bird_vy] = 300.0
    st[:bird_angle] = 45.0
    bird.y = 10
    c.reset_game(st)
    t.check_eq(bird.y, bird_rest, "resetGame: 새는 화면 세로 가운데 416")
    t.check_eq(st[:bird_vy], 0.0, "resetGame: 속도 0")
    t.check_eq(st[:bird_angle], 0.0, "resetGame: 기울기 0")
    t.check_eq(st[:score], 0, "resetGame: 점수 0")
    t.check_eq(st[:ready_time], 0.0, "resetGame: 대기 시간 0")
    t.check_eq(st[:best], 9, "resetGame: 최고 점수는 남는다")
    t.check_eq(st[:pipes].size, 3, "resetGame: 파이프는 3쌍")
    st[:pipes].each_with_index do |p, idx|
      i = idx + 1
      x = w + 160 + idx * c::PIPE_SPACING
      t.check_eq(p[:x], x, "resetGame: #{i}번 파이프는 화면 밖 #{x}")
      t.check_eq(p[:passed], false, "resetGame: #{i}번 파이프는 아직 안 지나갔다")
      t.check(p[:gap_y] >= lo && p[:gap_y] <= hi, "resetGame: #{i}번 파이프 높이는 범위 안", p[:gap_y])
      # 위 파이프는 원점 기준 180도 회전이라 (x + 폭, gap_y) 에 놓아야 (x, gap_y - 높이) 에 그려진다
      t.check_eq(p[:top].x, x + c::PIPE_W, "placePipes: #{i}번 위 파이프 x 는 x + 52")
      t.check_eq(p[:top].y, p[:gap_y], "placePipes: #{i}번 위 파이프 y 는 gapY")
      t.check_eq(p[:bottom].x, x, "placePipes: #{i}번 아래 파이프 x 는 x")
      t.check_eq(p[:bottom].y, p[:gap_y] + 280, "placePipes: #{i}번 아래 파이프 y 는 gapY + 간격")
    end

    # [새] 대기: 가운데에서 위아래로 뜬다 (대기 시간은 감독이 센다) ------------------
    scene, st = new_game.call
    bird = scene.find("bird")
    t.check_eq(bird.x, c::BIRD_X, "bird.init: x 는 170")
    t.check_eq(bird.y, bird_rest, "bird.init: y 는 416")
    st[:ready_time] = Math::PI / 8   # sin(4t) = 1
    bird_c.update(bird, scene, tick)
    check_near.call(bird.y, bird_rest + 14, "대기: 사인 꼭대기에서 14px 위아래")
    check_near.call(st[:bird_angle], 6, "대기: 기울기는 6도까지")
    check_near.call(bird.props["angle"], 6, "대기: 기울기가 스프라이트 각도로 간다")
    t.check_eq(st[:ready_time], Math::PI / 8, "대기: 새는 대기 시간을 늘리지 않는다")
    t.check_eq(bird.animate, true, "대기: 날갯짓 애니메이션은 돈다")

    # [새] 플레이: 중력, 최대 낙하 속도, 천장
    st[:state] = :play
    bird.y = 400
    st[:bird_vy] = 0.0
    bird_c.update(bird, scene, tick)
    check_near.call(st[:bird_vy], 30, "중력: 한 틱(0.02초)에 속도 +30")
    check_near.call(bird.y, 400.6, "중력: 위치는 새 속도로 움직인다")
    check_near.call(st[:bird_angle], 2.25, "중력: 기울기는 속도 x 0.075")
    st[:bird_vy] = 810.0
    bird_c.update(bird, scene, tick)
    t.check_eq(st[:bird_vy], c::MAX_FALL, "최대 낙하: 속도는 820 에서 멈춘다")
    t.check_eq(st[:bird_angle], 60.0, "최대 낙하: 기울기는 60도까지")
    bird.y = 1
    st[:bird_vy] = -480.0
    bird_c.update(bird, scene, tick)
    t.check_eq(bird.y, 0, "천장: 화면 위로 나가지 않는다")
    t.check_eq(st[:bird_vy], 0, "천장: 닿으면 속도 0")

    # [새] 날갯짓: 스페이스나 마우스 왼쪽
    bird.y = 400
    st[:bird_vy] = 200.0
    fake[:keys][:space] = true
    bird_c.update(bird, scene, tick)
    fake[:keys].delete(:space)
    t.check_eq(st[:bird_vy], c::FLAP, "날갯짓: 스페이스면 속도 -480")
    check_near.call(bird.y, 404.6, "날갯짓: 이번 틱의 이동은 날갯짓 전 속도로 한다")
    t.check_eq(st[:bird_angle], -22.0, "날갯짓: 기울기는 -22도까지")
    t.check_eq(count.call(fake[:sounds], "flap"), 1, "날갯짓: flap 효과음")
    bird.y = 400
    st[:bird_vy] = 200.0
    fake[:mouse_down] = true
    bird_c.update(bird, scene, tick)
    fake[:mouse_down] = false
    t.check_eq(st[:bird_vy], c::FLAP, "날갯짓: 마우스 왼쪽도 된다")

    # [새] 자동 시연: 입력을 무시하고, 화면 가운데 아래로 떨어지면 스스로 난다
    st[:autoplay] = true
    bird.y = 500
    st[:bird_vy] = 100.0
    bird_c.update(bird, scene, tick)
    t.check_eq(st[:bird_vy], c::FLAP, "자동 시연: 가운데(448) 아래에서 떨어지면 난다")
    bird.y = 400
    st[:bird_vy] = 100.0
    bird_c.update(bird, scene, tick)
    check_near.call(st[:bird_vy], 130, "자동 시연: 가운데 위에서는 날지 않는다")
    bird.y = 400
    st[:bird_vy] = 0.0
    fake[:keys][:space] = true
    bird_c.update(bird, scene, tick)
    fake[:keys].delete(:space)
    check_near.call(st[:bird_vy], 30, "자동 시연: 스페이스를 무시한다")
    st[:autoplay] = false

    # [새] 지면: 아래 끝이 844 에 닿는 순간 죽는다
    bird.y = 779
    st[:bird_vy] = -30.0
    bird_c.update(bird, scene, tick)
    t.check_eq(st[:state], :play, "지면: 843 에서는 아직 산다")
    bird.y = 780
    st[:bird_vy] = -30.0
    bird_c.update(bird, scene, tick)
    t.check_eq(st[:state], :dead, "지면: 844 에 닿으면 죽는다")
    t.check_eq(bird.y, ground_y - c::BIRD_H, "지면: 새는 지면 위 780 에 놓인다")
    t.check_eq(bird.animate, false, "지면: 죽으면 날갯짓 애니메이션을 멈춘다")

    # [새] 게임 오버: 고꾸라지며 지면까지 떨어지고, 거기서 멈춘다
    bird.y = 600
    st[:bird_vy] = 0.0
    st[:bird_angle] = 0.0
    bird_c.update(bird, scene, tick)
    check_near.call(st[:bird_vy], 30, "추락: 중력을 받는다")
    check_near.call(bird.y, 600.6, "추락: 떨어진다")
    check_near.call(st[:bird_angle], 4.4, "추락: 초당 220도씩 고꾸라진다")
    st[:bird_angle] = 89.0
    bird_c.update(bird, scene, tick)
    t.check_eq(st[:bird_angle], 90.0, "추락: 기울기는 90도까지")
    bird.y = 779
    st[:bird_vy] = 500.0
    bird_c.update(bird, scene, tick)
    t.check_eq(bird.y, ground_y - c::BIRD_H, "추락: 지면을 뚫지 않고 780 에 멈춘다")
    bird_c.update(bird, scene, tick)
    t.check_eq(bird.y, ground_y - c::BIRD_H, "추락: 지면에 닿은 뒤로는 움직이지 않는다")

    # [파이프] spawn: 배경(bg2) 바로 뒤, 지면 앞에 그린다 --------------------------
    scene, st = new_game.call
    bird = scene.find("bird")
    pipes_obj = scene.find("pipes")
    bg2 = index_of.call(scene, "bg2")
    ground1 = index_of.call(scene, "ground1")
    between = true
    (1..3).each do |i|
      ["pipe_top_#{i}", "pipe_bottom_#{i}"].each do |id|
        at = index_of.call(scene, id)
        between = false if at.nil? || at <= bg2 || at >= ground1
      end
      t.check(st[:pipes][i - 1][:top].equal?(scene.find("pipe_top_#{i}")), "spawn: #{i}번 위 파이프가 씬에 있다")
      t.check(st[:pipes][i - 1][:bottom].equal?(scene.find("pipe_bottom_#{i}")), "spawn: #{i}번 아래 파이프가 씬에 있다")
    end
    t.check(between, "spawn: 파이프 6장은 모두 bg2 뒤, ground1 앞에 그린다")
    t.check_eq(st[:pipes][0][:top].props["angle"], 180, "spawn: 위 파이프는 180도 돌려 그린다")
    t.check(st[:pipes][0][:bottom].props["angle"] != 180, "spawn: 아래 파이프는 돌리지 않는다")

    # [파이프] 대기와 게임 오버에는 멈춰 있다
    set_pipes = lambda do |*xs|
      xs.each_with_index do |x, i|
        st[:pipes][i][:x] = x
        st[:pipes][i][:gap_y] = 300
        st[:pipes][i][:passed] = false
      end
    end
    bird.y = 400   # 간격 안
    set_pipes.call(600.0, 940.0, 1280.0)
    pipes_c.update(pipes_obj, scene, tick)
    t.check_eq(st[:pipes][0][:x], 600, "파이프: 대기 중에는 움직이지 않는다")
    st[:state] = :dead
    pipes_c.update(pipes_obj, scene, tick)
    t.check_eq(st[:pipes][0][:x], 600, "파이프: 게임 오버에는 움직이지 않는다")

    # [파이프] 플레이: 속도만큼 흐르고 스프라이트가 따라간다
    st[:state] = :play
    pipes_c.update(pipes_obj, scene, tick)
    check_near.call(st[:pipes][0][:x], 595.8, "파이프: 0점은 한 틱에 4.2px")
    check_near.call(st[:pipes][2][:x], 1275.8, "파이프: 3쌍이 함께 흐른다")
    check_near.call(st[:pipes][0][:bottom].x, 595.8, "파이프: 스프라이트가 자료를 따라간다")
    st[:score] = 10
    pipes_c.update(pipes_obj, scene, tick)
    check_near.call(st[:pipes][0][:x], 591.0, "파이프: 10점은 한 틱에 4.8px")

    # [파이프] 점수: 파이프 오른쪽 끝이 새의 x(170) 를 지나면 1점, 한 번만
    st[:score] = 0
    fake[:sounds] = []
    set_pipes.call(130.0, 940.0, 1280.0)
    pipes_c.update(pipes_obj, scene, tick)
    t.check_eq(st[:score], 0, "점수: 오른쪽 끝 177.8 은 아직 안 지났다")
    set_pipes.call(70.0, 940.0, 1280.0)
    pipes_c.update(pipes_obj, scene, tick)
    t.check_eq(st[:score], 1, "점수: 오른쪽 끝 117.8 은 지났다")
    t.check_eq(st[:pipes][0][:passed], true, "점수: 지난 파이프에 표시한다")
    pipes_c.update(pipes_obj, scene, tick)
    t.check_eq(st[:score], 1, "점수: 같은 파이프로 두 번 세지 않는다")
    t.check_eq(count.call(fake[:sounds], "point"), 1, "점수: point 효과음 한 번")

    # [파이프] 되돌리기: 화면 왼쪽으로 다 나가면 3 x 340 만큼 오른쪽으로 간다
    st[:score] = 0
    set_pipes.call(-50.0, 940.0, 1280.0)
    st[:pipes][0][:passed] = true
    stub_rand.call(proc { |n| n - 1 })
    pipes_c.update(pipes_obj, scene, tick)
    unstub_rand.call
    check_near.call(st[:pipes][0][:x], -54.2 + 3 * c::PIPE_SPACING, "되돌리기: x 에 1020 을 더한다")
    t.check_eq(st[:pipes][0][:passed], false, "되돌리기: 다시 지나갈 수 있다")
    t.check_eq(st[:pipes][0][:gap_y], 200 + (h - c::GROUND_H - c.gap(st) - 340), "되돌리기: 높이를 새로 뽑는다")

    # [파이프] 충돌: 부딪치면 죽고, 그 뒤로 파이프는 멈춘다
    bird.y = 289
    set_pipes.call(194.2, 940.0, 1280.0)
    pipes_c.update(pipes_obj, scene, tick)
    t.check_eq(st[:state], :dead, "충돌: 파이프에 부딪치면 죽는다")
    frozen = st[:pipes][0][:x]
    pipes_c.update(pipes_obj, scene, tick)
    t.check_eq(st[:pipes][0][:x], frozen, "충돌: 죽은 뒤로 파이프는 멈춘다")

    # [배경과 지면] ------------------------------------------------------------
    scene, st = new_game.call
    bg1 = scene.find("bg1")
    ground = scene.find("ground1")
    scroller_c.update(bg1, scene, tick)
    check_near.call(bg1.x, -0.6, "배경: 초당 30px")
    st[:state] = :dead
    scroller_c.update(bg1, scene, tick)
    check_near.call(bg1.x, -1.2, "배경: 게임 오버에도 흐른다")
    st[:state] = :ready
    scroller_c.update(ground, scene, tick)
    check_near.call(ground.x, -1.68, "지면: 대기 중에는 기본 속도의 0.4배(84px/초)")
    ground.x = 0
    st[:state] = :play
    scroller_c.update(ground, scene, tick)
    check_near.call(ground.x, -4.2, "지면: 플레이 중에는 파이프와 같은 속도")
    ground.x = 0
    st[:state] = :dead
    scroller_c.update(ground, scene, tick)
    t.check_eq(ground.x, 0, "지면: 게임 오버에는 멈춘다")
    st[:state] = :play
    ground.x = -767
    scroller_c.update(ground, scene, tick)
    check_near.call(ground.x, -771.2 + 2 * w, "지면: -768 을 넘으면 1536 만큼 오른쪽으로")
    bg1.x = -767.5
    scroller_c.update(bg1, scene, tick)
    check_near.call(bg1.x, -768.1 + 2 * w, "배경: -768 을 넘으면 1536 만큼 오른쪽으로")

    # 두 장은 오래 흘러도 768 간격으로 이어진다
    g1 = scene.find("ground1")
    g2 = scene.find("ground2")
    g1.x = 0
    g2.x = w
    2000.times do
      scroller_c.update(g1, scene, tick)
      scroller_c.update(g2, scene, tick)
    end
    check_near.call((g1.x - g2.x).abs, w, "이어붙이기: 40초 뒤에도 두 장의 간격은 768")
    t.check(g1.x > -w && g1.x <= w && g2.x > -w && g2.x <= w, "이어붙이기: 두 장 모두 -768..768 안",
            "#{g1.x}, #{g2.x}")

    # [감독] 시작 화면 ---------------------------------------------------------
    scene, st = new_game.call
    shown = lambda { |id| scene.find(id).visible }
    t.check_eq(st[:state], :ready, "감독: 처음은 ready")
    t.check(shown.call("title") && shown.call("best"), "감독: 대기 화면은 title, best 를 보인다")
    t.check(!(shown.call("score") || shown.call("over") || shown.call("result") || shown.call("hint1") || shown.call("hint2")),
            "감독: 대기 화면은 점수와 게임 오버 글자를 숨긴다")
    t.check_eq(scene.find("best").props["text"], "최고 점수 0", "감독: 최고 점수 글자")

    # [감독] ready: 입력이 없으면 기다린다
    out = director_tick.call(scene)
    t.check_eq(st[:state], :ready, "감독: 입력이 없으면 ready 에 머문다")
    check_near.call(st[:ready_time], 0.02, "감독: 대기 시간을 센다")
    t.check_eq(out.join("|"), "flappy:state:ready|flappy:score:0", "감독: 첫 틱에 상태와 점수를 알린다")
    out = director_tick.call(scene)
    t.check_eq(out.size, 0, "감독: 바뀐 것이 없으면 알리지 않는다")

    # [감독] ready -> play
    fake[:keys][:space] = true
    out = director_tick.call(scene)
    fake[:keys].delete(:space)
    t.check_eq(st[:state], :play, "감독: 날갯짓으로 시작한다")
    t.check_eq(st[:bird_vy], c::FLAP, "감독: 시작하면서 한 번 난다")
    t.check_eq(count.call(fake[:sounds], "flap"), 1, "감독: 시작 flap 효과음")
    t.check_eq(out.join("|"), "flappy:state:play", "감독: 상태가 바뀌면 알린다")
    t.check(shown.call("score") && !shown.call("title"), "감독: 플레이 중에는 점수만 보인다")
    st[:score] = 1
    out = director_tick.call(scene)
    t.check_eq(out.join("|"), "flappy:score:1", "감독: 점수가 바뀌면 알린다")
    t.check_eq(scene.find("score").props["text"], "점수 1", "감독: 점수 글자")

    # [감독] 자동 시연은 1초 기다린 뒤 시작한다
    scene, st = new_game.call
    st[:autoplay] = true
    st[:ready_time] = 0.97
    director_tick.call(scene)
    t.check_eq(st[:state], :ready, "자동 시연: 0.99초에는 아직 기다린다")
    director_tick.call(scene)
    t.check_eq(st[:state], :play, "자동 시연: 1초를 넘으면 시작한다")

    # [감독] 게임 오버 화면
    scene, st = new_game.call
    st[:state] = :dead
    st[:dead_time] = 0.0
    st[:score] = 3
    st[:best] = 5
    director_tick.call(scene)
    t.check(shown.call("over") && shown.call("result") && !shown.call("score"), "게임 오버: over, result 를 보인다")
    t.check_eq(scene.find("result").props["text"], "점수 3  최고 5", "게임 오버: 점수와 최고 점수 글자")
    t.check(!(shown.call("hint1") || shown.call("hint2")), "게임 오버: 0.6초 전에는 안내를 숨긴다")
    fake[:keys][:space] = true
    director_tick.call(scene)
    fake[:keys].delete(:space)
    t.check_eq(st[:state], :dead, "게임 오버: 0.6초 전의 날갯짓은 무시한다")
    st[:dead_time] = 0.59
    director_tick.call(scene)
    t.check(shown.call("hint1") && shown.call("hint2"), "게임 오버: 0.6초가 지나면 안내를 보인다")

    # [감독] 다시 시작: 최고 점수만 남기고 새 판
    scene.find("bird").y = 700
    fake[:keys][:space] = true
    out = director_tick.call(scene)
    fake[:keys].delete(:space)
    t.check_eq(st[:state], :ready, "다시 시작: 날갯짓하면 ready 로")
    t.check_eq(st[:score], 0, "다시 시작: 점수 0")
    t.check_eq(st[:best], 5, "다시 시작: 최고 점수는 남는다")
    t.check_eq(scene.find("bird").y, bird_rest, "다시 시작: 새는 가운데로")
    t.check_eq(out.join("|"), "flappy:state:ready|flappy:score:0", "다시 시작: 상태와 점수를 알린다")
    t.check(shown.call("title") && !shown.call("over"), "다시 시작: 대기 화면으로 돌아간다")

    # [감독] 게임 오버에서 화면 위 1/3 을 누르면 끝낸다 (아래는 다시 시작)
    st[:state] = :dead
    st[:dead_time] = 0.3
    fake[:mouse_down] = true
    fake[:mouse_y] = 100
    director_tick.call(scene)
    t.check_eq(fake[:exits], 0, "종료: 0.6초 전에는 화면 위를 눌러도 끝내지 않는다")
    t.check_eq(st[:state], :dead, "종료: 0.6초 전에는 다시 시작도 하지 않는다")
    st[:dead_time] = 0.7
    director_tick.call(scene)
    t.check_eq(fake[:exits], 1, "종료: 화면 위 1/3 을 누르면 끝낸다")
    t.check_eq(st[:state], :dead, "종료: 다시 시작하지 않는다")
    fake[:exits] = 0
    fake[:mouse_y] = 400
    director_tick.call(scene)
    fake[:mouse_down] = false
    t.check_eq(fake[:exits], 0, "종료: 화면 아래쪽 클릭은 끝내지 않는다")
    t.check_eq(st[:state], :ready, "종료: 화면 아래쪽 클릭은 다시 시작이다")

    # [감독] 자동 시연의 게임 오버: 클릭을 무시하고 1.5초 뒤 다시 시작
    st[:state] = :dead
    st[:dead_time] = 0.7
    st[:autoplay] = true
    fake[:mouse_down] = true
    fake[:mouse_y] = 100
    director_tick.call(scene)
    fake[:mouse_down] = false
    t.check_eq(fake[:exits], 0, "자동 시연: 화면 위 클릭으로 끝내지 않는다")
    t.check_eq(st[:state], :dead, "자동 시연: 1.5초 전에는 다시 시작하지 않는다")
    st[:dead_time] = 1.49
    director_tick.call(scene)
    t.check_eq(st[:state], :ready, "자동 시연: 1.5초를 넘으면 다시 시작한다")

    # [감독] ESC 는 어느 상태에서든 끝내고, 그 틱은 세지 않는다
    st[:autoplay] = false
    st[:state] = :play
    ticks_before = st[:ticks]
    fake[:keys][:escape] = true
    director_tick.call(scene)
    fake[:keys].delete(:escape)
    t.check_eq(fake[:exits], 1, "ESC: 플레이 중에도 끝낸다")
    t.check_eq(st[:ticks], ticks_before, "ESC: 그 틱은 세지 않는다")

    # [감독] 자동 시연은 900틱에 결과를 찍고 끝낸다
    scene, st = new_game.call
    st[:autoplay] = true
    st[:ticks] = c::TICK_BUDGET - 2
    st[:best] = 4
    director_tick.call(scene)
    t.check_eq(fake[:exits], 0, "틱 예산: 899틱에는 끝내지 않는다")
    out = director_tick.call(scene)
    t.check_eq(fake[:exits], 1, "틱 예산: 900틱에 끝낸다")
    t.check_eq(out[-1], "flappyFinal state=ready score=0 best=4 ticks=900", "틱 예산: 결과 한 줄")
    scene, st = new_game.call
    st[:ticks] = c::TICK_BUDGET
    director_tick.call(scene)
    t.check_eq(fake[:exits], 0, "틱 예산: 사람이 할 때는 끝내지 않는다")

    # [씬] 진짜 씬의 틱: 한 번 날고 두면 땅에 떨어져 끝난다 ---------------------------
    scene, st = new_game.call
    bird = scene.find("bird")
    fake[:keys][:space] = true
    scene = scene.tick(tick)
    fake[:keys].delete(:space)
    t.check_eq(st[:state], :play, "씬: 첫 틱의 스페이스로 시작한다")
    ticks = 0
    while st[:state] == :play && ticks < 200
      scene = scene.tick(tick)
      ticks += 1
    end
    t.check_eq(st[:state], :dead, "씬: 날갯짓 없이 두면 죽는다")
    t.check_eq(ticks, 56, "씬: 56틱(약 1.1초) 만에 땅에 닿는다")
    t.check_eq(bird.y, ground_y - c::BIRD_H, "씬: 새는 지면 위에 멈춘다")
    t.check_eq(st[:score], 0, "씬: 파이프에 닿기 전이라 0점")
    check_near.call(st[:pipes][0][:x], w + 160 - 55 * 4.2, "씬: 파이프는 새가 살아 있던 55틱만큼 흘렀다")
    scene = scene.tick(tick)
    t.check(shown.call("over") && shown.call("result"), "씬: 다음 틱에 게임 오버 화면")
  ensure
    unstub_rand.call
    stubbed.reverse_each do |mod, name, saved|
      mod.singleton_class.send(:alias_method, name, saved)
      mod.singleton_class.send(:remove_method, saved)
    end
    opened.each { |s| s.close unless s.closed? }
  end
end
