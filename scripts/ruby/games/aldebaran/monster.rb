# 알데바란, 몬스터 상태 기계 (docs/plans/aldebaran-2-combat.md 4절).
# scripts/lua/games/aldebaran/monster.lua 의 Ruby 판.
#
# 원안(기획서 6절)의 세 상태: 기본(순찰) → 추적 → 공격. 판정은 거리다.
# 엔진에 닿지 않는 순수 클래스이며, 종별 차이는 코드가 아니라 표(spec)다
# (scripts/ruby/games/aldebaran/data/monsters.rb).
#
#   require "scripts/ruby/games/aldebaran/monster"
#   m = Aldebaran::Monster.new(spec, { x: 480, y: 352, min_x: 420, max_x: 560 })
#   m.update(dt, probe, player_x, player_y)
#
# Lua 의 m.def 는 Ruby 예약어라 spec 이라 부른다. spec 이 들고 있는 것:
#   hp, atk, defense, exp, gold        능력치와 보상
#   walk_speed, chase_speed            이동 속도 (px/초)
#   alert_range, attack_range          경계와 공격 거리 (수평 px)
#   alert_range_y                      경계의 세로 폭 (기본 48. 공중형은 넓다)
#   windup, active, recover            공격의 선딜레이, 판정, 후딜레이 (초)
#   half_w, body_h                     몸통 상자
#   special                            :sting | :charge | :throw | :fuse | nil
#   charge_speed, charge_time          돌격형 전용
#   regen                              비전투 회복 (원안: 4초마다 최대 HP의 1/20)
#   cols, frames                       시트 열 수와 상태별 칸 번호
#
# A7에서 더한 칸 (1-2 황제의 무덤의 적 셋. docs/plans/aldebaran-7-tomb.md 5절):
#   flies, fly_speed, dive_speed       공중형. 중력이 없고 정해진 높이를 떠다닌다
#   rise_speed                         내려찍은 뒤 도로 올라가는 속도
#   guard_front, turn_delay            방패형. 앞은 막고, 돌아서는 데 시간이 걸린다
#   fuse_range, fuse_time, blast_time  자폭형. 붙으면 심지가 타고 터진다
#
# 상태는 여덟이다 (Symbol): :patrol, :chase, :charge, :windup, :strike, :recover,
# :hurt, :dying. A7이 둘을 더했다: :fuse(심지가 탄다)와 :boom(터지는 순간, 판정이
# 있다). 방패형이 막은 직후의 :block 도 있다.
#
# 씬이 하는 일: strike 상태의 공격 상자와 플레이어의 겹침 판정, 데미지 계산,
# hurt 호출. 여기는 움직임과 상태 전이만 안다.
#
# probe 는 Proc 이다: probe.call(px, py) 가 그 픽셀이 막힌 타일이면 true.

module Aldebaran
  class Monster
    GRAVITY = 980
    MAX_FALL = 480
    HOP_V = -250              # 추적 중 한 타일 턱을 뛰어넘는 힘 (원안 6.2.3절)
    HURT_TIME = 0.25
    DYING_TIME = 0.5
    REGEN_TICK = 4
    # 0.3 을 나눗셈으로 쓰는 이유: 이 엔진의 mruby 4.0.0 은 0.3, 0.35, 0.6, 0.7, 0.95 리터럴을
    # 1 ulp 어긋나게 읽는다 (0.3 == 3.0 / 10 이 false). IEEE 나눗셈은 바르게 반올림되므로
    # Lua 의 strtod 와 같은 double 이 나온다. 봇이 프레임 단위로 싸우니 이 차이가 곧 파리티다.
    BLOCK_TIME = 3.0 / 10          # 방패형이 막은 뒤 굳어 있는 시간 (반격 창). Lua 의 0.3

    attr_accessor :spec, :x, :y, :vx, :vy, :dir, :on_ground, :min_x, :max_x,
                  :state, :hp, :timer, :anim_time, :charge_used, :regen_timer,
                  :hover_y, :phase, :phase_guard, :recover_time, :turn_timer,
                  :blocked, :strike_hit, :dead, :fade,
                  # Lua 에서는 필요할 때 생기는 칸. 씬(game.rb)과 update/hurt 가 세운다.
                  :thrown, :phase2, :pattern_fired, :cycle_index

    # spec 은 종별 표 하나(Monsters::SPECIES[id]), opts 는 배치 { x:, y:, dir:, min_x:, max_x: }.
    # dir, min_x, max_x 는 생략할 수 있다 (Lua 와 같은 기본값).
    def initialize(spec, opts)
      @spec = spec
      @x = opts[:x]
      @y = opts[:y]
      @vx = 0
      @vy = 0
      @dir = opts[:dir] || -1
      @on_ground = false
      @min_x = opts[:min_x] || (opts[:x] - 64)
      @max_x = opts[:max_x] || (opts[:x] + 64)
      @state = :patrol
      @hp = spec[:hp]
      @timer = 0
      @anim_time = 0
      @charge_used = false
      @regen_timer = 0
      @hover_y = opts[:y]        # 공중형이 떠 있는 높이 (배치한 y가 기준이다)
      @phase = 1                 # 보스의 페이즈 (spec[:phases]가 있을 때만 뜻이 있다. 1부터)
      @phase_guard = 0           # 페이즈가 바뀐 직후의 무적 (초)
      @recover_time = nil        # 씬이 페이즈마다 덮어쓰는 후딜
      @turn_timer = 0            # 방패형이 돌아서기까지 남은 초
      @blocked = 0               # 막은 직후의 짧은 경직 (연출과 반격 창)
      @strike_hit = false        # 이번 공격의 판정을 이미 썼는가 (씬이 세운다)
      @dead = false
      @fade = 0
      # Lua 에서는 처음에 없는(nil) 칸. 이름만 미리 둔다.
      @thrown = nil              # 투척형: 이번 strike 에서 돌을 이미 던졌는가 (씬이 세운다)
      @phase2 = nil              # 짐도둑의 두 번째 판 (hurt 가 세운다)
      @pattern_fired = nil       # 보스: 이번 후딜에서 패턴을 이미 쐈는가 (씬이 세운다)
      @cycle_index = nil         # 보스: 사이클의 몇 번째인가 (씬이 세운다. 1부터)
    end

    # ---- 이동 (플레이어와 같은 방식의 타일 충돌) --------------------------------

    def move_x(dx, probe)
      return false if dx == 0
      sign = dx > 0 ? 1 : -1
      nx = @x + dx
      edge = nx + sign * @spec[:half_w]
      [-1, -((@spec[:body_h].to_f / 2).floor), -@spec[:body_h] + 1].each do |oy|
        if probe.call(edge, @y + oy)
          tile = (edge / 16.0).floor
          if sign > 0
            nx = tile * 16 - @spec[:half_w] - 0.01
          else
            nx = (tile + 1) * 16 + @spec[:half_w] + 0.01
          end
          @x = nx
          return true          # 벽에 막혔다
        end
      end
      @x = nx
      false
    end

    def standing?(probe, y)
      probe.call(@x - @spec[:half_w] + 1, y) || probe.call(@x + @spec[:half_w] - 1, y)
    end

    def move_y(dy, probe)
      ny = @y + dy
      if dy >= 0
        if standing?(probe, ny)
          @y = (ny / 16.0).floor * 16
          @vy = 0
          @on_ground = true
          return
        end
        @y = ny
        @on_ground = false unless standing?(probe, @y + 1)
      else
        @y = ny
        @on_ground = false
      end
    end

    # 그쪽을 보게 한다. spec[:turn_delay]가 있으면 그만큼 뜸을 들인다
    # (방패형의 등이 열리는 시간이 여기서 나온다).
    def face(want, dt)
      if @dir == want
        @turn_timer = 0
        return
      end
      delay = @spec[:turn_delay]
      if delay.nil?
        @dir = want
        return
      end
      @turn_timer += dt
      if @turn_timer >= delay
        @dir = want
        @turn_timer = 0
      end
    end

    # 진행 방향 바로 앞이 벼랑인가 (순찰이 스스로 떨어지지 않게)
    def cliff_ahead?(probe)
      ahead = @x + @dir * (@spec[:half_w] + 3)
      !probe.call(ahead, @y + 4)
    end

    def wall_ahead?(probe)
      ahead = @x + @dir * (@spec[:half_w] + 2)
      probe.call(ahead, @y - (@spec[:body_h].to_f / 2).floor)
    end

    # ---- 상태 기계 -------------------------------------------------------------

    def update(dt, probe, px, py)
      return if @dead
      @anim_time += dt

      if @state == :dying
        @fade += dt
        @dead = true if @fade >= DYING_TIME
        return
      end

      dx = px - @x
      dist = dx.abs
      # 경계 판정 (원안 7.1.1절의 거리 체크). 세로 폭은 종마다 다르다
      # (공중형은 머리 위에 떠 있으므로 48px로는 플레이어를 보지 못한다).
      alert_y = @spec[:alert_range_y] || 48
      near = dist <= @spec[:alert_range] && (py - @y).abs <= alert_y

      @timer = [0, @timer - dt].max
      @vx = 0

      @blocked = [0, @blocked - dt].max
      @phase_guard = [0, @phase_guard - dt].max

      if @state == :hurt
        @vx = @dir * -60          # 밀려난다 (바라보는 반대쪽으로)
        @state = :chase if @timer <= 0

      elsif @state == :fuse
        # 자폭형: 심지가 탄다. 이 동안 베어 쓰러뜨리면 터지지 않는다.
        # 멈춰 서는 것이 예고다 (다가오다 멈추면 물러날 때다).
        if @timer <= 0
          @state = :boom
          @timer = @spec[:blast_time] || 0.15
          @strike_hit = false
        end

      elsif @state == :boom
        if @timer <= 0
          @state = :dying
          @fade = 0
        end

      elsif @state == :block
        # 방패형이 앞을 막은 직후. 굳어 있는 동안이 반격 창이다.
        @state = :chase if @timer <= 0

      elsif @state == :patrol
        @vx = @dir * @spec[:walk_speed]
        # 비전투 회복 (원안: 전투 중이 아닌 경우 4초마다 최대 HP/20)
        if @spec[:regen]
          @regen_timer += dt
          if @regen_timer >= REGEN_TICK
            @regen_timer = 0
            @hp = [@spec[:hp], @hp + [1, (@spec[:hp].to_f / 20).floor].max].min
          end
        end
        if near
          if @spec[:special] == :charge && !@charge_used
            @state = :charge
            @timer = @spec[:charge_time]
            @dir = dx > 0 ? 1 : -1
          else
            @state = :chase
          end
        end

      elsif @state == :charge
        # 돌격 (원안: 첫 발동 뒤로는 다시 쓰지 않는다). 벽이나 시간에서 끝난다.
        @vx = @dir * @spec[:charge_speed]
        if @timer <= 0
          # 검은 늑대는 돌격을 다시 쓴다 (charge_repeat). 늑대는 한 번뿐이다.
          @charge_used = !@spec[:charge_repeat]
          @state = :chase
        end

      elsif @state == :chase
        # 투척형(짐도둑): 가까우면 달아나고, 거리가 벌어지면 돌을 던진다.
        # 구간 끝에 몰리면 더 물러나지 않는다 (기획서 6절).
        if @spec[:special] == :throw
          away = dx > 0 ? -1 : 1
          cornered = (away > 0 && @x >= @max_x - 4) ||
                     (away < 0 && @x <= @min_x + 4)
          if dist < @spec[:flee_range] && !cornered
            @dir = away
            @vx = away * @spec[:chase_speed]
          elsif dist <= @spec[:attack_range] && @on_ground
            @state = :windup
            @timer = @spec[:windup]
            @dir = dx > 0 ? 1 : -1
          else
            @dir = dx > 0 ? 1 : -1
            @vx = @dir * @spec[:walk_speed]
          end
        elsif @spec[:special] == :fuse
          # 자폭형: 물러나지 않는다. 붙으면 심지에 불이 붙는다.
          face(dx > 0 ? 1 : -1, dt)
          if dist <= (@spec[:fuse_range] || @spec[:attack_range])
            @state = :fuse
            @timer = @spec[:fuse_time] || 0.75
          else
            @vx = @dir * @spec[:chase_speed]
          end

        elsif dist > @spec[:alert_range] * 1.5
          @state = :patrol
          face(dx > 0 ? 1 : -1, dt)
        elsif dist <= @spec[:attack_range] && (@on_ground || @spec[:flies])
          @state = :windup
          @timer = @spec[:windup]
          face(dx > 0 ? 1 : -1, dt)
        else
          face(dx > 0 ? 1 : -1, dt)
          @vx = @dir * @spec[:chase_speed]
        end

      elsif @state == :windup
        face(dx > 0 ? 1 : -1, dt)  # 움츠리는 동안 상대를 계속 본다
        if @timer <= 0
          @state = :strike
          @timer = @spec[:active]
          @strike_hit = false
          @thrown = false            # 투척형: 씬이 이 판을 보고 돌을 만든다
        end

      elsif @state == :strike
        if @timer <= 0
          @state = :recover
          # 보스는 페이즈마다 후딜이 다르다 (씬이 recover_time을 세운다).
          # 후딜이 곧 펀치 윈도우이므로 이 값이 난이도의 손잡이다.
          @timer = @recover_time || @spec[:recover]
        end

      elsif @state == :recover
        @state = :chase if @timer <= 0
      end

      # 이동과 중력
      blocked_now = move_x(@vx * dt, probe)
      if blocked_now
        if @state == :patrol
          @dir = -@dir
        elsif @state == :chase && @on_ground
          @vy = HOP_V                # 추적 중에는 턱을 뛰어넘는다
        elsif @state == :charge
          @timer = 0                 # 벽에 부딪히면 돌격이 끝난다
        end
      end
      if @state == :patrol
        if !@spec[:flies] && cliff_ahead?(probe) && @on_ground
          @dir = -@dir               # 순찰은 벼랑에서 돌아선다 (발이 있는 것만)
        end
        @dir = 1 if @x <= @min_x
        @dir = -1 if @x >= @max_x
      end
      if @spec[:special] == :throw
        # 투척형은 어느 상태에서든 제 구간(공터)을 벗어나지 않는다
        @x = [@min_x, [@max_x, @x].min].max
      end
      if @spec[:flies]
        # 공중형에는 중력이 없다. 상태마다 있고 싶은 높이가 있고, 그리로 다가간다.
        #   떠 있을 때  hover_y (배치한 자리)
        #   움츠릴 때   조금 더 위로 (이것이 내려찍기의 예고다)
        #   내려찍을 때 플레이어의 발치까지, 빠르게
        want = @hover_y
        speed = @spec[:fly_speed] || 60
        if @state == :windup
          want = @hover_y - 14
          speed = (@spec[:fly_speed] || 60) * 2     # 홱 떠오르는 것이 눈에 띄어야 한다
        elsif @state == :strike
          want = py
          speed = @spec[:dive_speed] || 260
        elsif @state == :recover
          # 내려간 만큼 도로 올라와야 한다. 후딜 안에 못 올라오면 지면에 붙어
          # 버려서 "공중형"이 아니게 된다.
          speed = @spec[:rise_speed] || ((@spec[:fly_speed] || 60) * 3)
        end
        d = want - @y
        step = speed * dt
        if d.abs <= step
          @y = want
          @vy = 0
        else
          @vy = d > 0 ? speed : -speed
          move_y(@vy * dt, probe)
        end
      else
        @vy = [@vy + GRAVITY * dt, MAX_FALL].min
        move_y(@vy * dt, probe)
      end
    end

    # ---- 씬이 쓰는 조회 ---------------------------------------------------------

    # 몸통 상자 [x0, y0, x1, y1]
    def body
      [@x - @spec[:half_w], @y - @spec[:body_h], @x + @spec[:half_w], @y]
    end

    # 공격 판정 상자 [x0, y0, x1, y1]. strike(또는 돌격 중)일 때만 있고, 아니면 nil.
    # 투척형은 몸이 아니라 돌(씬의 투사체)이 아프므로 상자가 없다.
    def attack_box
      return nil if @spec[:special] == :throw
      if @state == :boom
        # 자폭: 몸이 아니라 터진 반경이 아프다. 위아래로도 퍼진다.
        r = @spec[:blast_radius] || 28
        return [@x - r, @y - @spec[:body_h] - r, @x + r, @y + r.to_f / 2]
      elsif @state == :strike
        if @spec[:flies]
          return body                # 내려찍기는 몸이 곧 판정이다
        end
        reach = @spec[:attack_range] + 6
        if @dir > 0
          return [@x, @y - @spec[:body_h], @x + reach, @y]
        else
          return [@x - reach, @y - @spec[:body_h], @x, @y]
        end
      elsif @state == :charge
        return body
      end
      nil
    end

    # 맞았다. 죽으면 true를 돌려준다 (보상은 씬이 준다).
    def hurt(dmg, from_dir)
      return false if @dead || @state == :dying || @state == :boom
      return false if @phase_guard > 0                # 페이즈 전환 중에는 안 맞는다

      # 방패형: 바라보는 쪽에서 온 것은 막는다. 막으면 잠깐 굳고, 그때가 반격 창이다.
      # 등 뒤로 돌아가는 것이 이 적이 묻는 질문이다 (계획 5절).
      if @spec[:guard_front] && @dir == -from_dir && @state != :block
        @state = :block
        @timer = BLOCK_TIME
        @blocked = BLOCK_TIME
        return false
      end

      @hp -= dmg
      # 짐도둑은 절반에서 두 번째 판으로 넘어간다 (기획서 4.3.4절)
      if @spec[:special] == :throw && !@phase2 && @hp <= @spec[:hp].to_f / 2
        @phase2 = true
      end
      # 페이즈가 있는 보스 (A7의 아포피스). 경계를 넘으면 잠깐 무적이 되고
      # 물러선다 ("지금 판이 바뀌었다"가 눈에 보여야 하기 때문이다).
      if !@spec[:phases].nil? && @hp > 0
        ratio = @hp.to_f / @spec[:hp]
        np = 1
        @spec[:phases].each_with_index do |at, i|
          np = i + 1 if ratio <= at
        end
        if np != @phase
          @phase = np
          @phase_guard = @spec[:phase_guard] || 1.0
          @state = :recover
          @timer = @phase_guard
          @charge_used = false
          return false
        end
      end
      @regen_timer = 0
      if @hp <= 0
        @state = :dying
        @fade = 0
        return true
      end
      @state = :hurt
      @timer = HURT_TIME
      @dir = from_dir > 0 ? -1 : 1      # 때린 쪽을 돌아본다
      false
    end

    # 시트 칸 (spec[:cols] 열, 위 오른쪽 아래 왼쪽 두 줄)
    def frame
      f = @spec[:frames]
      col = nil
      if @state == :dying || @state == :hurt
        col = f[:hurt]
      elsif @state == :boom
        col = f[:boom] || f[:attack]
      elsif @state == :fuse
        col = f[:fuse] || f[:attack]
      elsif @state == :block
        col = f[:block] || f[:attack]
      elsif @state == :windup || @state == :strike
        col = f[:attack]
      elsif @state == :charge
        col = f[:charge] || f[:attack]
      else
        walk = f[:walk]
        col = walk[(@anim_time * 6).floor % walk.size]
      end
      (@dir < 0 ? @spec[:cols] : 0) + col
    end

    private :move_x, :standing?, :move_y, :face, :cliff_ahead?, :wall_ahead?
  end
end
