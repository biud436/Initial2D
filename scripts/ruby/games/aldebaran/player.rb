# 알데바란, 카르토의 이동 물리 (docs/plans/aldebaran-1-core.md 6절).
# scripts/lua/games/aldebaran/player.lua 의 Ruby 판 (docs/plans/s2-ruby-aldebaran.md).
#
# 엔진에 닿지 않는 순수 클래스다. 씬이 매 프레임 입력과 충돌 조회 함수를 넘긴다.
#
#   require "scripts/ruby/games/aldebaran/player"
#   p = Aldebaran::Player.new(56, 384)
#   p.update(input, dt, probe)
#
# input: { left:, right: (누르고 있음), left_edge:, right_edge:, jump_edge:, attack_edge: (이번 프레임) }
#        (없는 키는 거짓. {} 도 된다)
# probe.call(px, py) -> true/false : 그 픽셀이 막혀 있는가 (씬이 map.passable? 을 감싼다)
# 좌표 (x, y)는 발 가운데다. 몸통 상자는 x-6..x+6, y-20..y-1 (기획서 4.1절의 12x20).
#
# 단위는 픽셀/초, dt는 초. 프레임레이트에 독립적이다 (flappy와 같은 방식).

module Aldebaran
  class Player
    WALK_SPEED = 90
    DASH_SPEED = 190
    DASH_TIME = 0.28          # 대쉬 지속
    TAP_WINDOW = 0.25         # 더블탭 판정 창
    GRAVITY = 980
    JUMP_V = -330             # 최고점 약 53px (이산 적분 기준), 3타일 턱을 넘는다
    AIR_JUMP_V = -270         # 2단 점프. 합쳐 약 87px, 5타일까지
    MAX_FALL = 480
    HALF_W = 6                # 몸통 절반 폭
    BODY_H = 20               # 몸통 높이
    RUN_GRACE = 0.18          # 달리기 기억: 손을 뗀 직후의 점프가 앞으로 나아가는 유예

    # 환경 (A7). 스테이지의 기후가 물리를 바꾼다 (docs/plans/aldebaran-7-tomb.md 4절).
    # self.env 가 없거나 값이 1이면 **지금까지와 완전히 같게 돈다** (1-1은 이 길로 간다).
    #   friction    1 미만이면 지면에서 곧바로 서지 못하고 미끄러진다 (눈)
    #   move_mult   걷기와 대쉬의 속도 배율 (물에 잠기면 느려진다)
    #   jump_mult   점프 초속의 배율 (물에 잠기면 낮게 뛴다)
    GROUND_ACCEL = 900        # 미끄러운 바닥에서 목표 속도에 다가가는 가속도

    # 3단 콤보 (기획서 5.1절): 베기 1단, 2단, 십자 베기
    ATTACK_WIND = 0.08        # 선딜레이
    ATTACK_ACTIVE = 0.10      # 판정이 살아 있는 구간
    ATTACK_RECOVER = 0.16     # 후딜레이 (이 동안의 입력이 다음 단으로 이어진다)
    COMBO_GRACE = 0.4         # 베기가 끝나고도 이 시간 안의 입력은 콤보를 잇는다
    COMBO_FINISHER = 1.6      # 십자 베기(3단)의 데미지 배율
    HURT_TIME = 0.25          # 피격 경직
    INVULN_TIME = 1.0         # 피격 뒤 무적
    KNOCKBACK_X = 110
    KNOCKBACK_Y = -140

    attr_accessor :x, :y, :vx, :vy,
                  :facing,          # 1 오른쪽, -1 왼쪽
                  :on_ground,
                  :air_jumps,       # 공중에서 남은 점프 (땅에 닿으면 1로)
                  :dash_timer, :dash_dir,
                  :tap_timer, :tap_dir,
                  :run_vx, :run_timer, # 직전 달리기 기억 (RUN_GRACE 참고)
                  :anim_time,
                  # 전투 (2단계)
                  :attack_stage,    # 0 없음, 1~3 콤보 단
                  :attack_timer,    # 남은 베기 시간 (wind+active+recover에서 줄어든다)
                  :combo_queued,    # 베기 중의 입력이 다음 단을 예약했다
                  :combo_grace,     # 베기가 끝난 뒤 콤보가 살아 있는 시간
                  :attack_hit,      # 이번 베기가 이미 때린 몬스터 (씬이 쓴다)
                  :hurt_timer, :invuln_timer,
                  # 이번 프레임에 일어난 일 (씬이 효과음과 연출에 쓴다)
                  :jumped, :landed, :dashed, :swung,
                  # 환경 (위의 GROUND_ACCEL 설명). nil 이면 기본값
                  :env

    def initialize(x, y)
      @x = x
      @y = y
      @vx = 0
      @vy = 0
      @facing = 1
      @on_ground = false
      @air_jumps = 1
      @dash_timer = 0
      @dash_dir = 0
      @tap_timer = 0
      @tap_dir = 0
      @run_vx = 0
      @run_timer = 0
      @anim_time = 0
      @attack_stage = 0
      @attack_timer = 0
      @combo_queued = false
      @combo_grace = 0
      @attack_hit = {}
      @hurt_timer = 0
      @invuln_timer = 0
      @jumped = false
      @landed = false
      @dashed = false
      @swung = false
      @env = nil
    end

    # ---- 전투 ------------------------------------------------------------------

    ATTACK_TOTAL = ATTACK_WIND + ATTACK_ACTIVE + ATTACK_RECOVER

    # 지금 베기의 구간 (:wind | :active | :recover | nil)
    def attack_phase
      return nil if @attack_stage == 0 || @attack_timer <= 0
      t = ATTACK_TOTAL - @attack_timer
      return :wind if t < ATTACK_WIND
      return :active if t < ATTACK_WIND + ATTACK_ACTIVE
      :recover
    end

    # 판정이 살아 있는가
    def attack_active?
      attack_phase == :active
    end

    # 베기 판정 상자 (바라보는 방향 앞 22x20). [x0, y0, x1, y1]
    def attack_box
      if @facing > 0
        x0 = @x + HALF_W - 2
      else
        x0 = @x - HALF_W + 2 - 22
      end
      [x0, @y - BODY_H, x0 + 22, @y]
    end

    # 이번 단의 데미지 배율 (3단 십자 베기는 세다)
    def attack_mult
      @attack_stage >= 3 ? COMBO_FINISHER : 1
    end

    # 맞았다 (데미지 적용은 씬이 한다). 무적이면 false.
    def apply_hit(from_x)
      return false if @invuln_timer > 0
      @hurt_timer = HURT_TIME
      @invuln_timer = INVULN_TIME
      @vy = KNOCKBACK_Y
      @vx = @x < from_x ? -KNOCKBACK_X : KNOCKBACK_X
      @on_ground = false
      @attack_stage = 0
      @attack_timer = 0
      @dash_timer = 0
      true
    end

    # 수평 이동과 벽 충돌. 한 프레임 이동량이 타일(16px)보다 작아 터널링이 없다.
    def move_x(dx, probe)
      return if dx == 0
      sign = dx > 0 ? 1 : -1
      nx = @x + dx
      edge = nx + sign * HALF_W
      [-1, -10, -BODY_H + 1].each do |oy|
        if probe.call(edge, @y + oy)
          tile = (edge / 16.0).floor
          if sign > 0
            nx = tile * 16 - HALF_W - 0.01
          else
            nx = (tile + 1) * 16 + HALF_W + 0.01
          end
          @vx = 0
          @dash_timer = 0
          break
        end
      end
      @x = nx
    end

    # 수직 이동. 내려가면 착지, 올라가면 천장.
    def move_y(dy, probe)
      ny = @y + dy
      if dy >= 0
        if standing(probe, ny)
          @y = (ny / 16.0).floor * 16   # 발을 타일 윗면에
          @vy = 0
          @landed = true unless @on_ground
          @on_ground = true
          @air_jumps = 1
          return
        end
        @y = ny
        @on_ground = false unless standing(probe, @y + 1)
      else
        head = ny - BODY_H
        if probe.call(@x - HALF_W + 1, head) || probe.call(@x + HALF_W - 1, head)
          @y = ((head / 16.0).floor + 1) * 16 + BODY_H
          @vy = 0
        else
          @y = ny
        end
        @on_ground = false
      end
    end

    def update(input, dt, probe)
      @jumped = false
      @landed = false
      @dashed = false
      @swung = false
      @invuln_timer = [0, @invuln_timer - dt].max

      # 콤보 유예: 베기가 끝나고 이 시간이 지나면 콤보가 처음으로 돌아간다
      if @combo_grace > 0 && @attack_timer <= 0
        @combo_grace = [0, @combo_grace - dt].max
        @attack_stage = 0 if @combo_grace <= 0
      end

      if @hurt_timer > 0
        # 피격 경직: 입력을 받지 않고 넉백만 이어진다
        @hurt_timer = [0, @hurt_timer - dt].max

      elsif @attack_timer > 0
        # 베기 중: 활성 이후의 입력이 다음 단을 예약한다 (기획서 5.1절)
        if input[:attack_edge] && attack_phase != :wind
          @combo_queued = true
        end
        @attack_timer = [0, @attack_timer - dt].max
        if @attack_timer <= 0
          if @combo_queued && @attack_stage < 3
            start_attack(@attack_stage + 1)
          elsif @attack_stage < 3
            @combo_grace = COMBO_GRACE
          else
            @attack_stage = 0         # 십자 베기 뒤에는 처음부터
          end
        end
        # 베는 동안에는 방향 전환도 점프도 없다. 지상에서는 제자리에 선다.
        @vx = 0 if @on_ground
        @tap_timer = 0

      elsif input[:attack_edge]
        # 베기 시작 (유예 안의 입력은 다음 단으로)
        if @attack_stage > 0 && @attack_stage < 3 && @combo_grace > 0
          start_attack(@attack_stage + 1)
        else
          start_attack(1)
        end
        @vx = 0 if @on_ground

      else
        update_movement(input, dt)
      end

      # 중력과 이동 (모든 상태 공통). 경직이 끝난 뒤의 넉백 잔속은 다음 프레임의
      # update_movement 가 지상 무입력 규칙으로 정리한다.
      @vy = [@vy + GRAVITY * dt, MAX_FALL].min
      move_x(@vx * dt, probe)
      move_y(@vy * dt, probe)
      @anim_time = @anim_time + dt
    end

    # 지금 자세의 시트 칸 (karto.png, 그리드 12x2).
    # 칸: 0 서기A, 1 서기B, 2~5 걷기, 6 점프(상승), 7 낙하, 8~10 베기, 11 피격
    def frame
      if @hurt_timer > 0
        col = 11
      elsif @attack_timer > 0
        col = 7 + [3, [1, @attack_stage].max].min
      elsif !@on_ground
        col = @vy < 0 ? 6 : 7
      elsif @vx != 0
        fps = @dash_timer > 0 ? 14 : 9
        col = 2 + (@anim_time * fps).floor % 4
      else
        col = (@anim_time * 2).floor % 2
      end
      (@facing < 0 ? 12 : 0) + col
    end

    private

    # 목표로 rate 만큼 다가간다 (넘어가지 않는다)
    def approach(v, target, rate)
      return [target, v + rate].min if v < target
      return [target, v - rate].max if v > target
      v
    end

    # 이 프레임의 환경 (없으면 기본값). [friction, move_mult, jump_mult]
    def env_of
      e = @env
      return [1, 1, 1] if e.nil?
      [e[:friction] || 1, e[:move_mult] || 1, e[:jump_mult] || 1]
    end

    def start_attack(stage)
      @attack_stage = stage
      @attack_timer = ATTACK_TOTAL
      @combo_queued = false
      @combo_grace = 0
      @attack_hit = {}
      @swung = true
    end

    # 발 밑 두 점 중 하나라도 막혀 있는가
    def standing(probe, y)
      probe.call(@x - HALF_W + 1, y) || probe.call(@x + HALF_W - 1, y)
    end

    # 이동 의도: 대쉬, 걷기, 점프 (피격도 베기도 아닐 때만 불린다)
    def update_movement(input, dt)
      # 더블탭 대쉬 (기획서 5.1절: 같은 방향을 빠르게 두 번)
      @tap_timer = [0, @tap_timer - dt].max
      tap = 0
      if input[:left_edge]
        tap = -1
      elsif input[:right_edge]
        tap = 1
      end
      if tap != 0
        if @tap_timer > 0 && @tap_dir == tap && @on_ground
          @dash_timer = DASH_TIME
          @dash_dir = tap
          @dashed = true
        end
        @tap_dir = tap
        @tap_timer = TAP_WINDOW
      end

      # 수평 속도.
      # 터치는 단일 터치라(vpad) 패드와 점프 버튼을 동시에 누를 수 없다.
      # 그래서 두 가지 관성을 둔다: (1) 공중에서 입력이 없으면 속도를 유지하고,
      # (2) 지상에서 손을 뗀 직후(RUN_GRACE)의 점프는 직전 달리기 속도를 잇는다.
      # "달리다 손을 떼고 점프"가 앞으로 나아가는 점프가 되는 조건이다.
      @dash_timer = [0, @dash_timer - dt].max
      @run_timer = [0, @run_timer - dt].max
      friction, move_mult, jump_mult = env_of
      prev_vx = @vx
      if @dash_timer > 0
        @vx = @dash_dir * DASH_SPEED * move_mult
        @facing = @dash_dir
      elsif input[:left] && !input[:right]
        @vx = -WALK_SPEED * move_mult
        @facing = -1
      elsif input[:right] && !input[:left]
        @vx = WALK_SPEED * move_mult
        @facing = 1
      elsif @on_ground
        @vx = 0
      end

      # 미끄러운 바닥(눈): 목표 속도로 곧바로 갈아타지 않고 다가간다. 멈추는 것도
      # 돌아서는 것도 시간이 걸린다. friction 이 1이면 위의 결과를 그대로 쓴다
      # (그래야 1-1의 물리가 한 픽셀도 달라지지 않는다).
      if friction < 1 && @on_ground
        @vx = approach(prev_vx, @vx, GROUND_ACCEL * friction * dt)
      end
      if @vx != 0
        @run_vx = @vx
        @run_timer = RUN_GRACE
      end

      # 점프와 2단 점프
      if input[:jump_edge]
        if @on_ground
          @vy = JUMP_V * jump_mult
          @on_ground = false
          @air_jumps = 1
          @jumped = true
          if @vx == 0 && @run_timer > 0
            @vx = @run_vx      # 달리기 기억을 잇는다
            @facing = @vx < 0 ? -1 : 1
          end
        elsif @air_jumps > 0
          @vy = AIR_JUMP_V * jump_mult
          @air_jumps = @air_jumps - 1
          @jumped = true
        end
      end
    end
  end
end
