# 알데바란 인수 시나리오, Ruby 판 (S2). tests/run_engine_tests.py 가 구동한다.
# tests/engine/scenes/aldebaran_scene.lua 를 한 줄씩 옮긴 것이다. 같은 검사와
# **같은 골든**(aldebaran_forest, aldebaran_title, aldebaran_tomb_stars)에 견준다.
#
# 게임이 실제로 여는 파일(scripts/ruby/games/aldebaran/*.rb)을 얹고 입력 재생기로
# 처음부터 끝까지 통과한다:
#
#   타이틀 → 도입 컷씬 → (일부러 맞아 죽어) 게임 오버와 다시 하기
#   → 다섯 구간을 지나며 흔적 다섯을 줍고 힘을 익힌다
#   → 검은 늑대와 짐도둑(두 판) → 배낭 → 에필로그 → 결과 창 → 타이틀
#
# **맵 좌표를 박아 넣지 않는다** (docs/plans/aldebaran-5-stage.md 6.3절).
# 앞이 막히면 뛰고, 발을 헛디디면 공중에서 한 번 더 뛰고, 벨 수 있는 적이 있으면 벤다.
#
# 전투 굴림은 시드 난수(stage 의 seed)라 이 시나리오는 항상 같은 결과를 낸다.
#
# INITIAL2D_ALDEBARAN_STOP=start | title | touch 면 그 화면을 고정한다 (골든용).

require "scripts/ruby/rbtests/input_replay"
require "scripts/ruby/games/aldebaran/title"
require "scripts/ruby/games/aldebaran/game"

module Accept
  class << self
    attr_accessor :r, :stop_mode, :scenes, :current, :current_name, :pending

    def tick(n = 1)
      n.times do
        if @pending
          @current.destroy
          @current_name = @pending
          @current = @scenes[@pending]
          @pending = nil
          @current.init
        end
        @r.tick
        @current.update(16)
      end
    end

    def st
      AldebaranScene.status
    end

    def title_st
      AldebaranTitleScene.status
    end

    # 벨 수 있는 거리(수평 34, 수직 24) 안의 살아 있는 몬스터
    def monster_near(s, range = nil)
      best = nil
      best_dist = range || 34
      s[:monsters].each do |m|
        d = (m[:x] - s[:x]).abs
        if d < best_dist && (m[:y] - s[:y]).abs < 24 && m[:state] != :dying
          best = m
          best_dist = d
        end
      end
      best
    end

    def pause_and_resume
      @r.release("RIGHT")
      tick(3)
      @r.tap("ESCAPE")
      tick(10)
      puts "aldebaranPaused:#{st[:paused]}"
      @r.tap("Z")
      tick(10)
      puts "aldebaranResumed:#{!st[:paused]}"
      @r.press("RIGHT")
      tick(2)
    end

    def read_through(max_taps = 40)
      max_taps.times do
        return true if yield
        @r.tap("Z")
        tick(8)
      end
      yield
    end

    # ---- 자동 조종 ---------------------------------------------------------------

    def reset_drive
      @drive = { last: -1, stuck: 0, hop: 0, atk: 0, was_ground: true, saved: false, tick: 0 }
    end

    def auto_step
      s = st
      d = @drive
      d[:tick] += 1
      d[:hop] = [0, d[:hop] - 1].max
      d[:atk] = [0, d[:atk] - 1].max

      # 발을 헛디뎠으면 (뛰지 않았는데 공중이면) 공중 점프로 건넌다
      if d[:was_ground] && !s[:on_ground] && d[:hop] == 0 && !d[:saved]
        @r.tap("Z")
        d[:saved] = true
      end
      d[:saved] = false if s[:on_ground]
      d[:was_ground] = s[:on_ground]

      near = monster_near(s)
      if near && s[:on_ground]
        # 늑대가 붙으면 폭주를 쓴다 (익히지 않았거나 쿨타임이면 먹지 않는다)
        @r.tap("C") if near[:species] != "밀림 전갈거미" && !s[:berserk]
        if d[:atk] == 0
          @r.tap("X")
          d[:atk] = 8
        end
      elsif s[:on_ground] && d[:hop] == 0
        if (s[:x] - d[:last]).abs < 0.2
          d[:stuck] += 1
        else
          d[:stuck] = 0
        end
        if d[:stuck] > 3 || d[:tick] % 22 == 0
          @r.tap("Z")
          @r.schedule({ press: "Z" }, 9) # 2단 점프로 구멍을 넘는다
          @r.schedule({ release: "Z" }, 10)
          d[:hop] = 16
          d[:stuck] = 0
        end
      end
      d[:last] = s[:x]
      tick(1)
    end

    # ---- 터치 조작의 끝-끝 검증 (stop=touch) ------------------------------------

    def run_touch
      # 좌표를 하드코딩하지 않는다. 배치는 화면 크기에서 계산되므로(T1,
      # scripts/ruby/ui/layout.rb) status 가 노출하는 계산된 중심을 누른다.
      c = st[:touch_controls]
      puts "touchControls:#{!c.nil?}"
      press = lambda do |x, y|
        @r.schedule({ mouse: { x: x, y: y } }, 1)
        @r.schedule({ click: 0 }, 2)
        @r.schedule({ unclick: 0 }, 4)
      end

      # 공격을 먼저 본다. 걷다 보면 첫 거미가 붙어 피격 경직에 걸리기 때문이다.
      press.call(c[:attack][:cx], c[:attack][:cy])
      swung = false
      12.times do
        tick(1)
        swung = true if st[:attacking]
      end
      puts "touchAttack:#{swung}"
      tick(24)

      # 패드 중심에서 오른쪽으로 치우친 자리를 눌러 걷는다
      x0 = st[:x]
      @r.schedule({ mouse: { x: c[:pad][:cx] + c[:pad][:size] * 0.3, y: c[:pad][:cy] } }, 1)
      @r.schedule({ click: 0 }, 2)
      tick(30)
      puts "touchWalk:#{st[:x] > x0 + 10}"
      @r.schedule({ unclick: 0 }, 1)
      tick(6)

      press.call(c[:jump][:cx], c[:jump][:cy])
      tick(6)
      puts "touchJump:#{!st[:on_ground]}"
      tick(60)

      press.call(c[:pause][:cx], c[:pause][:cy])
      tick(8)
      puts "touchPause:#{st[:paused]}"
      press.call(160, 208)
      tick(8)
      puts "touchResume:#{!st[:paused]}"

      # 동시 입력 (T1): 손가락 1로 패드를 잡아 왼쪽으로 달리는 채로
      # 손가락 2로 점프 버튼을 누른다. 단일 터치(마우스)로는 불가능하던 것.
      @r.schedule({ touchdown: { id: 1, x: c[:pad][:cx] - c[:pad][:size] * 0.3, y: c[:pad][:cy] } }, 1)
      tick(10)
      sx = st[:x]
      @r.schedule({ touchdown: { id: 2, x: c[:jump][:cx], y: c[:jump][:cy] } }, 1)
      @r.schedule({ touchup: { id: 2 } }, 3)
      tick(6)
      airborne = !st[:on_ground]
      x1 = st[:x]
      tick(14)
      x2 = st[:x]
      puts "touchSimul:#{airborne && x1 < sx && x2 < x1}"
      @r.schedule({ touchup: { id: 1 } }, 1)
      tick(6)
    end

    # ---- 시나리오 ----------------------------------------------------------------

    def run_title
      puts "titleScene:#{@current_name}"
      tick(6)
      ts = title_st
      puts "titleMenuOpen:#{ts[:menu_open]}"
      # Ruby 의 선택지 번호는 0 부터라 Lua 와 같은 표기(1 부터)로 찍는다
      puts "titleItems:#{ts[:items]} index:#{ts[:index] ? ts[:index] + 1 : 'nil'}"

      @r.tap("DOWN")
      tick(4)
      @r.tap("Z")
      tick(8)
      puts "titleHelpOpen:#{title_st[:help_open]}"
      read_through { !title_st[:help_open] }
      puts "titleHelpClosed:#{!title_st[:help_open]}"

      @r.tap("UP")
      tick(4)
      @r.tap("Z")
      tick(20)
      puts "sceneAfterStart:#{@current_name}"
    end

    def run_intro
      puts "introActive:#{st[:intro]}"
      tick(110)
      puts "introWindow:#{st[:dialogue_shown]}"
      read_through { !st[:intro] }
      puts "introDone:#{!st[:intro]}"
      tick(30)
      puts "introWindowClosed:#{!st[:dialogue_shown]}"
    end

    # 첫 거미 앞에 서서 맞기만 한다. 목숨 둘이 다하면 게임 오버.
    def run_game_over
      @r.press("RIGHT")
      400.times do
        break if monster_near(st, 40)
        tick(1)
      end
      @r.release("RIGHT")
      first_loss = false
      3000.times do
        s = st
        if !first_loss && s[:lives] < 2
          first_loss = true
          puts "firstDeathLives:#{s[:lives]}"
        end
        break if s[:game_over]
        tick(1)
      end
      read_through { st[:game_over] == :choice }
      s = st
      puts "gameOverChoice:#{s[:game_over] == :choice}"
      puts "gameOvers:#{s[:game_overs]}"
      @r.tap("Z")
      tick(8)
      s = st
      puts "retryLives:#{s[:lives]}"
      puts "retryAtStart:#{s[:x] < 100}"
    end

    def run_stage
      # 더블탭 대쉬
      @r.press("RIGHT")
      tick(2)
      @r.release("RIGHT")
      tick(2)
      @r.press("RIGHT")
      tick(2)
      x0 = st[:x]
      tick(1)
      puts "aldebaranDash:#{st[:x] - x0 > 2.5}"

      seen = []
      paused = false
      first_kill = false
      hurt_seen = false
      berserk_on = false
      level_seen = false
      stone_seen = false
      boss_down = false
      black_down = false
      phase2 = false

      30000.times do
        s = st
        break if s[:ending]

        if s[:found].size > seen.size
          (seen.size...s[:found].size).each do |i|
            seen[i] = s[:found][i]
            puts "aldebaranFound#{i + 1}:#{s[:found][i]}"
          end
        end
        if !level_seen && s[:level] >= 2
          level_seen = true
          puts "aldebaranLevelUp:#{s[:level]}"
          puts "aldebaranLevelHeal:#{s[:hp] == s[:max_hp]}"
        end
        if !first_kill && s[:exp] >= 5
          first_kill = true
          puts format("aldebaranFirstKill:exp=%d,gold=%d", s[:exp], s[:gold])
        end
        if !hurt_seen && s[:hp] < s[:max_hp]
          hurt_seen = true
          puts "aldebaranHurt:#{s[:hp]}"
          puts "aldebaranHurtInvuln:#{s[:invuln]}"
        end
        if !berserk_on && s[:berserk]
          berserk_on = true
          puts "aldebaranBerserk:true"
        end
        if !stone_seen && s[:stones] > 0
          stone_seen = true
          puts "aldebaranStone:true"
        end
        if !paused && s[:checkpoint]
          paused = true
          pause_and_resume
        end

        black = nil
        boss = nil
        s[:monsters].each do |m|
          black = m if m[:species] == "검은 늑대"
          boss = m if m[:boss]
        end
        if !black_down && black.nil? && s[:x] > 3260
          black_down = true
          puts "aldebaranBlackWolfDown:true"
        end
        if !phase2 && boss && boss[:phase2]
          phase2 = true
          puts "aldebaranBossPhase2:true"
        end
        if !boss_down && s[:bag]
          boss_down = true
          puts "aldebaranBossDown:true"
        end
        auto_step
      end
      @r.release("RIGHT")
      tick(2)

      s = st
      puts "aldebaranFoundCount:#{s[:found].size}"
      if s[:ending]
        puts "aldebaranDeaths:#{s[:deaths]}"
        puts "aldebaranEpilogue:#{s[:ending]}"
      else
        puts format("aldebaranTimeout x:%d y:%d hp:%s 몬스터:%d 흔적:%d",
                    s[:x].floor, s[:y].floor, s[:hp].to_s, s[:monsters].size, s[:found].size)
      end
    end

    def run_ending
      read_through(60) { st[:ending] == :result }
      s = st
      puts "aldebaranResult:#{s[:ending] == :result}"
      puts format("aldebaranResultStats:level=%d gold=%d", s[:level], s[:gold])
      puts "aldebaranStageAtEnd:#{s[:stage]}"
      tick(15)
      @r.tap("Z")
      tick(6)
      # A7: 1-1 의 결과 창을 닫으면 **타이틀이 아니라 1-2 로 이어진다**.
      # 씬 이름은 그대로 aldebaran 이고 무대만 바뀐다.
      puts "finalScene:#{@current_name}"
      after = st
      puts "aldebaranNextStage:#{after[:stage]}"
      puts format("aldebaranCarry:level=%d gold=%d", after[:level], after[:gold])
      puts "aldebaranTombClimate:#{after[:climate] || 'nil'}"
      puts "aldebaranAcceptDone:true"
    end

    # 1-2 주파. 방마다의 기후가 실제로 걸리는지, 새 적 셋을 만나는지를 본다.
    def run_tomb
      s0 = st
      puts format("tombStart:%d,%d stage:%s level:%d", s0[:x], s0[:y], s0[:stage].to_s, s0[:level])

      seen = {} # 겪은 기후
      met = {}  # 만난 적
      max_x = s0[:x]
      hurt = 0
      last_hp = s0[:hp]

      @r.press("RIGHT")
      # 맵이 5120px 라 걷는 데만 60초 가까이 걸린다. CI 에서는 150초를 쓰고,
      # 보스까지 보고 싶을 때 INITIAL2D_ALDEBARAN_TICKS 로 늘린다.
      budget = (System.env("INITIAL2D_ALDEBARAN_TICKS") || "").to_i
      budget = 9000 if budget <= 0
      budget.times do
        s = st
        break if s[:ending] || s[:game_over]
        seen[s[:climate]] = true if s[:climate]
        s[:monsters].each { |m| met[m[:species]] = true }
        max_x = s[:x] if s[:x] > max_x
        hurt += 1 if s[:hp] && last_hp && s[:hp] < last_hp
        last_hp = s[:hp]
        # 흔적의 글이 뜨면 넘긴다 (대화창이 열려 있으면 조작이 잠긴다)
        @r.tap("Z") if s[:dialogue_shown]
        auto_step
      end
      @r.release("RIGHT")

      s = st
      puts format("tombReach:%d", max_x.floor)
      [:snow, :light, :hail, :flood].each do |kind|
        puts "tombClimate:#{kind}:#{seen[kind] == true}"
      end
      ["무덤 번병", "순장된 영혼", "파괴의 조각"].each do |name|
        puts "tombMet:#{name}:#{met[name] == true}"
      end
      puts "tombHurt:#{hurt}"
      puts "tombAlive:#{!s[:hp].nil? && s[:hp] > 0}"
      puts "tombDeaths:#{s[:deaths]} gameOvers:#{s[:game_overs]}"
      puts "tombEnding:#{s[:ending] || 'nil'}"
      puts "tombDone:true"
    end

    def run
      @stop_mode = System.env("INITIAL2D_ALDEBARAN_STOP")
      reset_drive

      @scenes = { "aldebaran_title" => AldebaranTitleScene, "aldebaran" => AldebaranScene }
      $font_ready = Graphics.prepare_font("./resources/fonts/hangul.fnt")

      if @stop_mode == "touch"
        @current_name = "aldebaran"
        @current = AldebaranScene
        @r = InputReplay.new([])
        @r.install
        @current.init
        run_touch
        @r.restore
        @stop_mode = "start"
        return
      end

      # A7: 1-2 황제의 무덤을 자율 봇이 주파한다. 1-1 과 같은 봇이며 좌표를 박지
      # 않는다. 무대가 달라도 "막히면 뛰고 적이 있으면 벤다"는 같기 때문이다.
      if @stop_mode == "tomb"
        @current_name = "aldebaran"
        @current = AldebaranScene
        # 1-1 을 거쳐 온 것과 같은 상태로 연다 (1-1 주파의 실측이 레벨 4에 골드 115였다).
        AldebaranScene.carry = { exp: 70, gold: 115 }
        AldebaranScene.set_stage("tomb")
        @r = InputReplay.new([])
        @r.install
        @current.init
        run_tomb
        @r.restore
        return
      end

      # 회귀 (T1 후속, 2026-08-24 실기 검수): 넓은 창으로 태양의 방을 열어 수면이
      # 화면 폭 전체에 있는지 픽셀로 본다 (판정은 run_engine_tests.py).
      # 결정성을 위해 수위를 고정하고 배치를 비운다. 그리기 경로는 실물 그대로다.
      if @stop_mode == "flood"
        stage, = Aldebaran::Stages.get("tomb")
        stage.climate[:sun] = { kind: :flood, period: 9.0, low: 356, high: 356,
                                move_mult: 0.55, jump_mult: 0.72 }
        stage.spawns.clear
        @current_name = "aldebaran"
        @current = AldebaranScene
        AldebaranScene.set_stage("tomb")
        @r = InputReplay.new([])
        @r.install
        @current.init
        tick(30)
        s = st
        puts "floodY:#{s[:water_y]}"
        puts "floodStage:#{s[:stage]} x:#{s[:x].floor}"
        @r.restore
        return
      end

      if @stop_mode == "title"
        @current_name = "aldebaran_title"
        @current = AldebaranTitleScene
        @current.init
        30.times { @current.update(16) }
        return
      elsif @stop_mode
        @current_name = "aldebaran"
        @current = AldebaranScene
        @current.init
        s = st
        puts format("aldebaranStart:%d,%d", s[:x], s[:y])
        return
      end

      @r = InputReplay.new([])
      @r.install

      @current_name = "aldebaran_title"
      @current = AldebaranTitleScene
      @current.init
      puts format("aldebaranView:%dx%d", Graphics.width, Graphics.height)

      run_title
      puts "aldebaranMonsters:#{st[:monsters].size}"
      run_intro
      run_game_over
      run_stage
      run_ending

      @r.restore
    end
  end
end

def switch_scene(name)
  Accept.pending = name
end

def init
  Accept.run
end

def update(elapsed)
  # 타이틀은 얼려 둔다. update 마다 메뉴 커서의 깜빡임이 한 칸 가서, 캡처 프레임까지 든 틱 수(기계마다 다르다)에 따라 커서가 바뀐다
  Accept.current.update(0) if Accept.stop_mode && Accept.stop_mode != "title"
end

def render
  Accept.current.render if Accept.current
end

def destroy
  Accept.current.destroy if Accept.current
  Accept.r.restore if Accept.r
end
