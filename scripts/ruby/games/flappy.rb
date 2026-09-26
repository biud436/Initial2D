# 엔진 데모: Flappy Bird 스타일, mruby 판 (S1, docs/plans/s1-mruby-binding.md)
#
# scripts/lua/games/flappy.lua 를 Ruby 로 옮긴 것이다. 규칙과 수치는 같다.
# (Lua 는 scripts/lua/, Ruby 는 scripts/ruby/ 에 둔다)
# 조작: 마우스 클릭/터치 또는 스페이스 바로 날갯짓
# 상태: :ready(대기) -> :play(플레이) -> :dead(게임 오버) -> :ready
# 게임 오버 화면에서 화면 상단(1/3)을 누르면 게임을 끝낸다.
#
# 물리는 elapsed(ms)를 초로 정규화한 px/초 단위라 프레임레이트에 독립적이다.
# INITIAL2D_AUTOPLAY 환경 변수가 있으면 자동 시연 모드로 동작한다 (테스트/CI용).

module FlappyScene
  # 튜닝 상수 (px/초)
  GRAVITY      = 1500.0   # 중력 가속도
  FLAP         = -480.0   # 날갯짓 순간 속도
  MAX_FALL     = 820.0    # 최대 낙하 속도
  BASE_SPEED   = 210.0    # 파이프와 지면 기본 속도
  SCROLL       = 30.0     # 배경(원경) 스크롤 속도
  BASE_GAP     = 280      # 파이프 상하 간격(시작값)
  MIN_GAP      = 195      # 파이프 간격 하한
  PIPE_SPACING = 340      # 파이프 수평 간격
  PIPE_W       = 52
  PIPE_H       = 271
  GROUND_H     = 64
  BIRD_X       = 170
  BIRD_W       = 92
  BIRD_H       = 64

  class << self
    attr_reader :state, :score, :best

    def autoplay?
      @autoplay
    end

    def speed
      [BASE_SPEED + @score * 3.0, 320.0].min
    end

    def gap
      [BASE_GAP - @score * 4, MIN_GAP].max
    end

    def sfx(name)
      # loop 에 숫자를 주면 추가 반복 횟수다 (1 = 2회 연속 재생).
      # 효과음 파일이 절반 길이로 만들어져 있어 2회 재생이 정상 길이가 된다.
      Audio.play_sound("./resources/audio/#{name}.wav", name, 1)
    end

    def flap_pressed?
      return false if @autoplay # 자동 시연은 별도 로직에서 처리
      Input.mouse_down?(:left) || Input.key_down?(:space)
    end

    def random_gap
      # Lua 의 math.random(0, n) 은 양 끝을 포함한다
      200 + rand([1, (@h - GROUND_H - gap - 340).floor].max + 1)
    end

    def reset_pipes
      @pipes.each_with_index do |p, i|
        p[:x] = (@w + 160 + i * PIPE_SPACING).to_f
        p[:gap_y] = random_gap
        p[:passed] = false
      end
    end

    def reset_game
      @bird_y = @h / 2.0 - BIRD_H / 2.0
      @bird_vy = 0.0
      @bird_angle = 0.0
      @score = 0
      @ready_time = 0.0
      reset_pipes
    end

    def init
      @w = Graphics.width
      @h = Graphics.height
      @ground_y = @h - GROUND_H + 12 # 충돌 기준(잔디 약간 아래)
      @autoplay = !System.env("INITIAL2D_AUTOPLAY").nil?

      @state = :ready # 메뉴에서 재진입 시 이전 상태가 남지 않도록 명시적으로 초기화
      @best ||= 0
      @dead_time = 0.0

      # 스크롤 배경 2장 (이어붙여 좌측으로 흐름)
      @bg1 = Sprite.load("./resources/background_768x896.png", "Background", 0, 0, @w, @h, 1)
      @bg2 = Sprite.load("./resources/background_768x896.png", "Background", 0, 0, @w, @h, 1)

      # 지면 2장 (파이프와 같은 속도로 흘러 속도감을 준다)
      @gnd1 = Sprite.load("./resources/ground_768x64.png", "Ground", 0, 0, @w, GROUND_H, 1)
      @gnd2 = Sprite.load("./resources/ground_768x64.png", "Ground", 0, 0, @w, GROUND_H, 1)

      # 파이프 3쌍 (위 파이프는 180도 회전이며 원점 회전이므로 위치를 보정한다)
      @pipes = (1..3).map do
        top = Sprite.load("./resources/object_52x271.png", "pipe", 0, 0, PIPE_W, PIPE_H, 1)
        bottom = Sprite.load("./resources/object_52x271.png", "pipe", 0, 0, PIPE_W, PIPE_H, 1)
        top.angle = 180.0
        { x: 0.0, gap_y: 0, top: top, bottom: bottom, passed: false }
      end

      # 새 (3프레임 날갯짓 애니메이션)
      @player = Sprite.load("./resources/bird_276x64.png", "Player", 0, 0, BIRD_W, BIRD_H, 3)
      @player.loop = true
      @player.set_frames(0, 3)
      @player.frame_delay = 110.0
      @player.anim_complete = false

      @bg_x1 = 0.0
      @bg_x2 = @w.to_f
      @gnd_x1 = 0.0
      @gnd_x2 = @w.to_f
      reset_game
    end

    def bird_rect
      # 충돌 판정은 그림보다 약간 작게
      [BIRD_X + 12, @bird_y + 10, BIRD_X + BIRD_W - 16, @bird_y + BIRD_H - 10]
    end

    def overlap?(l1, t1, r1, b1, l2, t2, r2, b2)
      l1 < r2 && r1 > l2 && t1 < b2 && b1 > t2
    end

    def hit_pipe?(p)
      left, top, right, bottom = bird_rect
      # 위 파이프: (x, gap_y-PIPE_H)..(x+PIPE_W, gap_y)
      return true if overlap?(left, top, right, bottom, p[:x], p[:gap_y] - PIPE_H, p[:x] + PIPE_W, p[:gap_y])
      # 아래 파이프: (x, gap_y+gap)..(x+PIPE_W, gap_y+gap+PIPE_H)
      overlap?(left, top, right, bottom, p[:x], p[:gap_y] + gap, p[:x] + PIPE_W, p[:gap_y] + gap + PIPE_H)
    end

    def die
      @state = :dead
      @dead_time = 0.0
      @best = @score if @score > @best
      sfx("hit")
    end

    def update_play(dt)
      # 새 물리
      @bird_vy += GRAVITY * dt
      @bird_vy = MAX_FALL if @bird_vy > MAX_FALL
      @bird_y += @bird_vy * dt

      if @bird_y < 0
        @bird_y = 0.0
        @bird_vy = 0.0
      end

      # 날갯짓
      if flap_pressed?
        @bird_vy = FLAP
        sfx("flap")
      end
      if @autoplay && @bird_vy > 0 && @bird_y > @h * 0.5
        @bird_vy = FLAP # 자동 시연: 일정 높이 아래로 떨어지면 날갯짓
      end

      # 속도에 따른 기울기 (상승 시 -22도, 낙하 시 최대 60도)
      @bird_angle = [-22.0, [60.0, @bird_vy * 0.075].min].max

      # 파이프 이동, 리사이클, 점수
      @pipes.each do |p|
        p[:x] -= speed * dt

        if p[:x] + PIPE_W < 0
          p[:x] += @pipes.size * PIPE_SPACING
          p[:gap_y] = random_gap
          p[:passed] = false
        end

        if !p[:passed] && p[:x] + PIPE_W < BIRD_X
          p[:passed] = true
          @score += 1
          sfx("point")
        end

        die if hit_pipe?(p)
      end

      # 지면 충돌
      if @bird_y + BIRD_H >= @ground_y
        @bird_y = (@ground_y - BIRD_H).to_f
        die
      end
    end

    def update(elapsed)
      dt_ms = [elapsed, 50].min # 스파이크 방어
      dt = dt_ms / 1000.0

      # ESC (Android 뒤로가기): 어느 상태에서든 게임 종료 (단독 진입점이다)
      if Input.key_down?(:escape)
        System.exit
        return
      end

      # 배경(원경)은 느리게, 지면은 파이프와 같은 속도로 스크롤
      ground_speed = @state == :play ? speed : BASE_SPEED * 0.4
      @bg_x1 -= SCROLL * dt
      @bg_x2 -= SCROLL * dt
      @bg_x1 += @w * 2 if @bg_x1 <= -@w
      @bg_x2 += @w * 2 if @bg_x2 <= -@w

      if @state != :dead
        @gnd_x1 -= ground_speed * dt
        @gnd_x2 -= ground_speed * dt
        @gnd_x1 += @w * 2 if @gnd_x1 <= -@w
        @gnd_x2 += @w * 2 if @gnd_x2 <= -@w
      end

      case @state
      when :ready
        @ready_time += dt
        # 대기 중엔 새가 상하로 부유
        @bird_y = (@h / 2.0 - BIRD_H / 2.0) + Math.sin(@ready_time * 4.0) * 14.0
        @bird_angle = Math.sin(@ready_time * 4.0) * 6.0
        if flap_pressed? || (@autoplay && @ready_time > 1.0)
          @state = :play
          @bird_vy = FLAP
          sfx("flap")
        end
      when :play
        update_play(dt)
      when :dead
        @dead_time += dt
        # 게임 오버 후 새는 고꾸라지며 지면까지 낙하
        if @bird_y + BIRD_H < @ground_y
          @bird_vy += GRAVITY * dt
          @bird_y += @bird_vy * dt
          @bird_angle = [90.0, @bird_angle + 220.0 * dt].min
          @bird_y = (@ground_y - BIRD_H).to_f if @bird_y + BIRD_H > @ground_y
        end
        if @dead_time > 0.6 && !@autoplay && Input.mouse_down?(:left) && Input.mouse_y < @h / 3.0
          System.exit # 화면 상단 터치: 종료
        elsif (@dead_time > 0.6 && flap_pressed?) || (@autoplay && @dead_time > 1.5)
          @state = :ready
          reset_game
        end
      end

      # 스프라이트 갱신 (트랜스폼, 애니메이션)
      @player.set_position(BIRD_X, @bird_y)
      @player.angle = @bird_angle
      @player.update(@state == :dead ? 0 : dt_ms)

      @bg1.set_position(@bg_x1, 0)
      @bg2.set_position(@bg_x2, 0)
      @bg1.update(0)
      @bg2.update(0)

      @gnd1.set_position(@gnd_x1, @h - GROUND_H)
      @gnd2.set_position(@gnd_x2, @h - GROUND_H)
      @gnd1.update(0)
      @gnd2.update(0)

      @pipes.each do |p|
        # 위 파이프는 180도 원점 회전이라 (x+W, gap_y)에 놓아야 (x, gap_y-H)에 그려진다
        p[:top].set_position(p[:x] + PIPE_W, p[:gap_y])
        p[:bottom].set_position(p[:x], p[:gap_y] + gap)
        p[:top].update(0)
        p[:bottom].update(0)
      end
    end

    def render
      @bg1.draw
      @bg2.draw

      @pipes.each do |p|
        p[:top].draw
        p[:bottom].draw
      end

      @gnd1.draw
      @gnd2.draw

      @player.draw

      return unless $font_ready

      case @state
      when :ready
        Graphics.draw_text(@w / 2 - 200, @h / 2 - 180, "클릭 또는 스페이스로 시작")
        Graphics.draw_text(@w / 2 - 110, @h / 2 - 140, "최고 점수 #{@best}")
      when :play
        Graphics.draw_text(30, 24, "점수 #{@score}")
      when :dead
        Graphics.draw_text(@w / 2 - 90, @h / 2 - 180, "게임 오버")
        Graphics.draw_text(@w / 2 - 130, @h / 2 - 140, "점수 #{@score}  최고 #{@best}")
        if @dead_time > 0.6
          Graphics.draw_text(@w / 2 - 170, @h / 2 - 100, "클릭하면 다시 시작")
          Graphics.draw_text(@w / 2 - 210, @h / 2 - 60, "화면 상단을 누르면 종료")
        end
      end
    end

    def destroy
      [@bg1, @bg2, @gnd1, @gnd2, @player].each(&:dispose)
      @pipes.each do |p|
        p[:top].dispose
        p[:bottom].dispose
      end
      %w[Background Ground pipe Player].each { |id| TextureManager.remove(id) }
    end
  end
end
