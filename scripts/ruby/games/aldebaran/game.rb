# 알데바란, 스테이지 씬 (docs/plans/aldebaran-1-core.md 7절, -2-combat.md, -3-content.md)
# scripts/lua/games/aldebaran/game.lua 의 Ruby 판 (S2, docs/plans/s2-ruby-aldebaran.md).
#
# 횡스크롤 액션. 기획서는 docs/design/aldebaran.md.
#   ← → : 이동 (같은 방향 빠르게 두 번 = 대쉬)
#   Z 또는 스페이스: 점프 (공중에서 한 번 더 = 2단 점프), 대화 넘기기
#   X: 공격 (연타로 3단 콤보)         C: 버서커 (MP 10, 4초)
#   ESC 또는 P (Android 뒤로가기): 일시 정지. 계속 하기 / 다시 하기 / 끝내기
#   터치: 좌하단 조이스틱(잡고 끌기), 우하단 점프와 공격과 폭주와 검기 버튼,
#         우상단 정지 버튼. 멀티터치라 달리면서 누를 수 있고, 배치와 크기는
#         화면 크기에 비례한다 (T1, scripts/ruby/ui/layout.rb)
#
# 흐름 (기획서 4절): 도입 컷씬(짐도둑이 배낭을 지고 달아난다) → 숲 주파와 전투 →
# 공터의 짐도둑을 쓰러뜨리고 배낭을 주우면 에필로그와 결과 창 → 타이틀로.
# 목숨을 다 잃으면 게임 오버. 다시 하기 / 타이틀로.
#
# 16px 타일을 768x896 화면에 1:1로 그리면 너무 작아 렌더 배율 2를 켠다
# (논리 384x448). 씬을 나갈 때 되돌린다. rpgdemo 와 같은 규칙.
#
# 몬스터 배치와 종별 표와 이야기 글은 stages/, 수식은 combat.rb, 상태 기계는 monster.rb.
#
# 환경 변수
#   INITIAL2D_DEBUG        좌표와 FPS 표시
#   INITIAL2D_VPAD         데스크톱에서도 터치 UI 표시
#   INITIAL2D_SKIP_INTRO   도입 컷씬 생략 (검증용)

require "scripts/ruby/image"
require "scripts/ruby/ui/vpad"
require "scripts/ruby/ui/buttons"
require "scripts/ruby/ui/layout"
require "scripts/ruby/rpg/assets"
require "scripts/ruby/bgm"
require "scripts/ruby/rpg/rng"
require "scripts/ruby/rpg/window"
require "scripts/ruby/rpg/choice"
require "scripts/ruby/rpg/message"
require "scripts/ruby/games/aldebaran/player"
require "scripts/ruby/games/aldebaran/monster"
require "scripts/ruby/games/aldebaran/combat"
require "scripts/ruby/games/aldebaran/stages/init"
require "scripts/ruby/games/aldebaran/climate"
require "scripts/ruby/games/aldebaran/data/monsters"
require "scripts/ruby/games/aldebaran/hud"
require "scripts/ruby/rpg/text"

module AldebaranScene
  Player = Aldebaran::Player
  Monster = Aldebaran::Monster
  Combat = Aldebaran::Combat
  Stages = Aldebaran::Stages
  Climate = Aldebaran::Climate
  Monsters = Aldebaran::Monsters

  BG_DIR = "./resources/aldebaran/"
  KARTO_PATH = "./resources/aldebaran/karto.png"
  AURA_PATH = "./resources/aldebaran/aura.png"
  STONE_PATH = "./resources/aldebaran/stone.png"
  BAG_PATH = "./resources/aldebaran/bag.png"
  CLIMATE_PATH = "./resources/aldebaran/climate.png"
  BEAM_PATH = "./resources/aldebaran/beam.png"
  WATER_PATH = "./resources/aldebaran/water.png"
  FADE_PATH = "./resources/ui/fade.png"
  UI_FONT = "./resources/fonts/hangul16.fnt"
  BASE_FONT = "./resources/fonts/hangul.fnt"
  BGM_FALLBACK = "./resources/audio/bless.ogg"

  SE = {
    jump: "./resources/audio/aldebaran_jump.wav",
    swing: "./resources/audio/aldebaran_swing.wav",
    hit: "./resources/audio/hit.wav",
    hurt: "./resources/audio/aldebaran_hurt.wav",
    kill: "./resources/audio/aldebaran_kill.wav",
    level: "./resources/audio/aldebaran_level.wav",
    berserk: "./resources/audio/aldebaran_berserk.wav",
    pick: "./resources/audio/aldebaran_pick.wav",
    throw: "./resources/audio/aldebaran_throw.wav",
    cursor: "./resources/audio/ui_cursor.wav",
    decision: "./resources/audio/ui_decision.wav",
    text: "./resources/audio/ui_text.wav",
  }

  SCALE = 2
  # 원경 두 겹: 먼 숲은 느리게, 가까운 숲은 그보다 빠르게 흐른다 (깊이).
  PARALLAX_FAR = 0.25
  PARALLAX_NEAR = 0.5
  SIGN_SECONDS = 4.0
  STONE_SPEED = 140
  STONE_TOSS = -170
  STONE_GRAVITY = 720

  # 기후 조각들 (tools/generate_aldebaran_tomb.py). 엔진의 scale= 은 균등 배율뿐이라
  # 늘여 쓸 수 없다. 빛기둥과 물은 쓸 크기 그대로 구워 뒀다.
  CLIP = {
    hail: [CLIMATE_PATH, 0, 0, 8, 8],
    warn: [CLIMATE_PATH, 8, 0, 16, 8],
    flake: [CLIMATE_PATH, 56, 0, 8, 8],
    beam: [BEAM_PATH, 0, 0, 88, 448],
    water: [WATER_PATH, 0, 0, 384, 128],
    # 물결 없는 몸통만 (수면 아래를 이어 채울 때. 물결이 반복되면 줄무늬가 진다)
    waterbody: [WATER_PATH, 0, 64, 384, 64],
  }

  PAUSE_ITEMS = ["계속 하기", "다시 하기", "끝내기"]
  GAMEOVER_ITEMS = ["다시 하기", "타이틀로"]

  class << self
    # 스테이지를 넘어갈 때 들고 가는 것 (원안 7.2절: 레벨은 이어진다).
    # 씬은 전환할 때 destroy 되고 다시 init 되므로 지역 변수로는 남지 않는다.
    # 타이틀로 돌아가면 지운다. 한 회차가 끝난 것이다.
    attr_accessor :carry

    # 지금 무대. 씬을 열기 전에 AldebaranScene.set_stage(id) 로 바꾼다 (타이틀과
    # 결과 창이 그렇게 한다). 기본은 목록의 첫 스테이지다.
    def stage
      @stage ||= Stages.first
    end

    # 다음에 열 스테이지를 정한다. init 전에 불러야 한다. [true, nil] 또는 [false, 이유].
    def set_stage(id)
      st, why = Stages.get(id)
      return [false, why] if st.nil?
      @stage = st
      [true, nil]
    end

    # 지금 무대의 id (진행 저장과 결과 창이 쓴다)
    def stage_id
      stage ? stage.id : nil
    end

    def clear_carry
      @carry = nil
    end

    def env(name)
      System.env(name)
    end

    # Lua 의 tonumber(env or "") 에 해당. 이 mruby 에는 Regexp 가 없어 손으로 본다.
    def numeric?(s)
      return false if s.nil? || s.empty?
      s.each_char.all? { |c| "0123456789.-".include?(c) } && s.count("0123456789") > 0
    end

    def play_se(name)
      Audio.play_sound(SE[name], "aldebaran:#{name}", 0)
    end

    # ---- 충돌 조회 -------------------------------------------------------------

    def probe(px, py)
      return true if px < 0 || px >= @world_w
      return false if py >= @world_h
      return false if py < 0
      !@map.passable?((px / @tile_w).floor, (py / @tile_h).floor)
    end

    def overlap?(l1, t1, r1, b1, l2, t2, r2, b2)
      l1 < r2 && r1 > l2 && t1 < b2 && b1 > t2
    end

    # ---- 입력 ------------------------------------------------------------------

    def poll_input
      input = {
        left: Input.key_press?(:left) || Input.key_down?(:left),
        right: Input.key_press?(:right) || Input.key_down?(:right),
        left_edge: Input.key_down?(:left),
        right_edge: Input.key_down?(:right),
        jump_edge: Input.key_down?(:z) || Input.key_down?(:space),
        attack_edge: Input.key_down?(:x),
        skill_edge: Input.key_down?(:c),
        bolt_edge: Input.key_down?(:v),
        pause_edge: Input.key_down?(:escape) || Input.key_down?(:p),
      }

      if @pad
        @pad.update
        l = @pad.pressed?(:left)
        r = @pad.pressed?(:right)
        input[:left] = input[:left] || l
        input[:right] = input[:right] || r
        input[:left_edge] = input[:left_edge] || (l && !@pad_was_left)
        input[:right_edge] = input[:right_edge] || (r && !@pad_was_right)
        @pad_was_left = l
        @pad_was_right = r
      end
      if @buttons
        @buttons.update
        input[:jump_edge] = input[:jump_edge] || @buttons.pressed?(:jump)
        input[:attack_edge] = input[:attack_edge] || @buttons.pressed?(:attack)
        input[:skill_edge] = input[:skill_edge] || @buttons.pressed?(:skill)
        input[:bolt_edge] = input[:bolt_edge] || @buttons.pressed?(:bolt)
        input[:pause_edge] = input[:pause_edge] || @buttons.pressed?(:pause)
      end
      input
    end

    # 몬스터 하나를 목록에 더한다 (배치와 보스의 소환이 함께 쓴다)
    def add_monster(spawn)
      spec = stage.species[spawn[:species]]
      return nil if spec.nil?
      model = Monster.new(spec, spawn)
      img = Image.create(spec[:sheet], 0, 0, spec[:frame_w], spec[:frame_h],
                         spec[:cols] * spec[:rows], "Aldebaran:#{spawn[:species]}")
      img.set_sheet_grid(spec[:cols], spec[:rows])
      img.loop = false
      e = { model: model, img: img, boss: spawn[:boss] }
      @monsters.push(e)
      e
    end

    # 대화창(나레이션)이 보는 결정키. 화면 탭도 결정으로 친다.
    def poll_confirm
      confirm = Input.key_down?(:z) || Input.key_down?(:return) ||
                Input.key_down?(:space) || Input.mouse_down?(:left)
      { confirm: confirm }
    end

    # ---- 스테이지 세우기 --------------------------------------------------------

    def spawn_monsters
      @monsters.each { |e| e[:img].release if e[:img] }
      @monsters = []
      stage.spawns.each { |s| add_monster(s) }
    end

    # 레벨 반영. 레벨이 오르면 전량 회복이 규칙이다 (기획서 7.2절)
    def apply_level(new_level)
      @level = new_level
      s = Combat.stats_at(@level)
      @stats = { hp: s[:hp], mp: s[:mp], atk: s[:atk], defense: s[:defense], luck: s[:luck],
                 max_hp: s[:hp], max_mp: s[:mp] }
    end

    # 스테이지를 처음부터 (첫 진입, 그리고 다시 하기)
    def reset_stage
      @rng = Rpg::Rng.new(stage.seed)
      @player = Player.new(@start_at || stage.start[:x], stage.start[:y])
      # 앞 스테이지에서 이어 온 경험치와 골드. 첫 스테이지면 0 이다.
      # 다시 하기에서도 유지된다. 잃는 것은 이 판의 진행이지 지난 판이 아니다.
      @exp = @carried_exp
      @gold = @carried_gold
      @lives = stage.lives
      apply_level(Combat.level_for(@exp))
      @berserk_timer = 0
      @checkpoint = nil
      @checkpoint_hit = false
      stage.checkpoints.each { |cp| cp[:taken] = false }
      @hallucination = 0
      @skills = Combat.new_skills
      @found = {}
      @found_order = []
      @bolts = []
      @learned_text = nil
      @learned_timer = 0
      spawn_monsters
      @stones = []
      @bag = nil
      @boss_clear = nil
      @ending = nil
      @game_over = nil
      @stage_time = 0
      @sign_seen = {}
      @sign_text = nil
      @sign_timer = 0
      @cam_x = 0
    end

    # 목숨 하나를 잃었다 (HP 0 또는 낭떠러지)
    def lose_life
      @deaths += 1
      @lives -= 1
      if @lives <= 0
        @game_overs += 1
        @game_over = { phase: :text }
        @dialogue.show_message(stage.gameover_text)
        return
      end
      at = @checkpoint || stage.start
      @player = Player.new(at[:x], at[:y])
      @player.invuln_timer = 1.5
      @stats[:hp] = @stats[:max_hp]
      @berserk_timer = 0
      @stones = []
    end

    # ---- 전투 -------------------------------------------------------------------

    def berserk_active?
      @berserk_timer > 0
    end

    def gain_reward(spec)
      @exp += spec[:exp]
      @gold += spec[:gold]
      play_se(:kill)
      new_level = Combat.level_for(@exp)
      if new_level > @level
        apply_level(new_level)
        play_se(:level)
      end
    end

    # 보스가 쓰러졌다. 무엇으로 끝나는가는 스테이지가 정한다.
    #   숲: 짐도둑이 배낭을 떨구고, 그것을 주워야 끝난다 (기획서 4.3절).
    #   그 밖: 쓰러뜨린 것으로 끝난다. 죽는 연출을 보여 주고 잠시 뒤 에필로그.
    def boss_down(m)
      if stage.boss[:drops] == :bag
        @bag = { x: m.x, y: m.y }
      else
        @boss_clear = 1.2
      end
    end

    # 날린 검기. 몬스터에 닿으면 터지고, 벽이나 화면 밖에서 사라진다.
    def update_bolts(dt)
      spec = Combat::SKILLS[:bolt]
      (@bolts.size - 1).downto(0) do |i|
        b = @bolts[i]
        b[:x] += b[:vx] * dt
        gone = probe(b[:x], b[:y]) || b[:x] < @cam_x - 32 || b[:x] > @cam_x + @w + 32
        unless gone
          @monsters.each do |e|
            m = e[:model]
            next if m.dead || m.state == :dying
            bx0, by0, bx1, by1 = m.body
            if overlap?(b[:x] - 5, b[:y] - 4, b[:x] + 5, b[:y] + 4, bx0, by0, bx1, by1)
              play_se(:hit)
              if m.hurt(spec[:damage], b[:vx] > 0 ? 1 : -1)
                gain_reward(m.spec)
                boss_down(m) if e[:boss]
              end
              gone = true
              break
            end
          end
        end
        @bolts.delete_at(i) if gone
      end
    end

    # ---- 보스의 패턴 (docs/plans/aldebaran-7-tomb.md 6절) -----------------------
    # 페이즈 표는 data/monsters.rb 의 BOSS_PHASES 에 있다. 여기는 그 표를 읽어
    # 도는 코드일 뿐이다.
    #
    # 패턴은 **후딜에 들어서는 순간** 하나씩 나간다. 후딜이 곧 플레이어의 펀치
    # 윈도우이므로, 그때 다음 위협을 예고하면 "때릴까 피할까"가 선택이 된다.

    def boss_fire_hail(m, count)
      return if @boss_hail.nil?
      floor_y = m.y
      ((m.y / 16).floor..(@map_h - 1)).each do |ty|
        if probe(m.x, ty * 16 + 1)
          floor_y = ty * 16
          break
        end
      end
      (1..count).each do |i|
        # 보스 앞뒤로 고르게. 플레이어의 머리 위만 노리면 피할 수 없다
        spread = 60 + (i - 1) * 46
        side = (i % 2 == 0) ? 1 : -1
        Climate.drop(@boss_hail, @player.x + side * spread * @rng.float, floor_y)
      end
    end

    def boss_summon(m, count)
      (1..count).each do |i|
        side = (i % 2 == 0) ? 1 : -1
        add_monster({ species: :soul, x: m.x + side * 70, y: m.y - 60,
                      min_x: m.x - 150, max_x: m.x + 150 })
      end
    end

    # 보스 하나의 한 프레임. e 는 @monsters 의 항목이다.
    def update_boss_pattern(e, dt)
      m = e[:model]
      return if m.spec[:phases].nil? || m.dead || m.state == :dying
      ph = Monsters::BOSS_PHASES[(m.phase || 1) - 1]
      return if ph.nil?
      m.recover_time = ph[:recover]

      if m.state == :recover
        unless m.pattern_fired
          m.pattern_fired = true
          # Lua 는 1 기준 순환 번호를 들고 있었다. 여기서는 지금까지 낸 횟수를 세고
          # 그 나머지로 패턴을 고른다 (같은 순서다).
          fired = m.cycle_index || 0
          pattern = ph[:cycle][fired % ph[:cycle].size]
          m.cycle_index = fired + 1
          if pattern == :hail
            boss_fire_hail(m, ph[:hail] || 3)
          elsif pattern == :summon
            boss_summon(m, ph[:summon] || 2)
          elsif pattern == :flood
            Climate.surge(@climate, 4.0)
          end
          # :charge 는 상태 기계가 스스로 한다 (spec[:charge_repeat]). 사이클에
          # 남겨 둔 것은 박자를 세기 위해서다.
        end
      else
        m.pattern_fired = false
      end
    end

    def resolve_player_attack
      return unless @player.attack_active?
      ax0, ay0, ax1, ay1 = @player.attack_box
      @monsters.each do |e|
        m = e[:model]
        next if m.dead || m.state == :dying || @player.attack_hit[m]
        bx0, by0, bx1, by1 = m.body
        next unless overlap?(ax0, ay0, ax1, ay1, bx0, by0, bx1, by1)
        @player.attack_hit[m] = true
        # 별들의 방: 빛 안의 영혼만 실체가 된다. 그늘에서는 칼이
        # 그냥 지나간다 (원안 표 16의 '빛의 축제'를 규칙으로 삼았다).
        solid = !m.spec[:flies] || Climate.lit(@climate, m.x)
        next unless solid
        atk = @stats[:atk] * @player.attack_mult
        atk += Combat::SKILLS[:edge][:atk_bonus] if @skills[:edge]
        atk *= Combat::BERSERK[:atk_mult] if berserk_active?
        r = Combat.resolve(atk, m.spec[:defense], @rng, @stats[:luck])
        if r[:dmg] > 0
          play_se(:hit)
          if m.hurt(r[:dmg], @player.facing)
            gain_reward(m.spec)
            boss_down(m) if e[:boss]
          end
        end
      end
    end

    # 플레이어가 데미지를 받는다 (내리찍기, 돌격, 돌팔매 공통)
    def damage_player(base, from_x, sting)
      r = Combat.resolve(base, @stats[:defense], @rng, 0)
      return false if r[:kind] == :miss
      dmg = r[:dmg]
      dmg += sting[:bonus] if sting && @rng.chance(sting[:chance])
      dmg = (dmg * Combat::BERSERK[:taken_mult]).floor if berserk_active?
      return false unless @player.apply_hit(from_x)
      @stats[:hp] = [0, @stats[:hp] - dmg].max
      play_se(:hurt)
      lose_life if @stats[:hp] <= 0
      true
    end

    def resolve_monster_attacks
      return if @player.invuln_timer > 0
      px0 = @player.x - Player::HALF_W
      py0 = @player.y - Player::BODY_H
      px1 = @player.x + Player::HALF_W
      py1 = @player.y
      @monsters.each do |e|
        m = e[:model]
        next if m.dead || m.state == :dying || m.strike_hit
        box = m.attack_box
        next if box.nil?
        bx0, by0, bx1, by1 = box
        next unless overlap?(px0, py0, px1, py1, bx0, by0, bx1, by1)
        charging = (m.state == :charge)
        base = charging ? (m.spec[:charge_atk] || m.spec[:atk]) : m.spec[:atk]
        sting = nil
        if m.spec[:special] == :sting
          sting = { chance: m.spec[:sting_chance], bonus: m.spec[:sting_bonus] }
        end
        m.strike_hit = true # 회피당해도 그 공격은 끝났다
        if damage_player(base, m.x, sting) && charging
          m.charge_used = !m.spec[:charge_repeat]
          m.timer = 0
        end
        return if @game_over
      end
    end

    # ---- 돌팔매 (짐도둑의 투사체) ------------------------------------------------

    def update_stones(dt)
      # 짐도둑의 strike 가 돌을 만든다 (monster.rb 는 thrown 깃발만 세운다)
      @monsters.each do |e|
        m = e[:model]
        next unless m.spec[:special] == :throw && m.state == :strike && !m.thrown
        m.thrown = true
        # 두 번째 판에서는 돌을 두 개씩 던진다 (기획서 4.3.4절)
        shots = m.phase2 ? 2 : 1
        (1..shots).each do |k|
          @stones.push({
            x: m.x + m.dir * 12, y: m.y - 24 - (k - 1) * 6,
            vx: m.dir * STONE_SPEED, vy: STONE_TOSS + (k - 1) * 40,
          })
        end
        play_se(:throw)
      end

      px0 = @player.x - Player::HALF_W
      py0 = @player.y - Player::BODY_H
      px1 = @player.x + Player::HALF_W
      py1 = @player.y
      (@stones.size - 1).downto(0) do |i|
        s = @stones[i]
        s[:vy] += STONE_GRAVITY * dt
        s[:x] += s[:vx] * dt
        s[:y] += s[:vy] * dt
        gone = false
        if probe(s[:x], s[:y]) || s[:y] > @world_h + 40
          gone = true
        elsif @player.invuln_timer <= 0 &&
              overlap?(s[:x] - 4, s[:y] - 4, s[:x] + 4, s[:y] + 4, px0, py0, px1, py1)
          damage_player(stage.species[stage.boss[:species]][:atk], s[:x], nil)
          gone = true
        end
        @stones.delete_at(i) if gone
        return if @game_over
      end
    end

    # ---- 씬 --------------------------------------------------------------------

    # 터치 컨트롤의 중심 좌표 표 (status 용). { pad: {cx, cy, size}, id => {cx, cy, size} }
    def control_centers
      return nil if @controls.nil?
      out = {
        pad: {
          cx: @controls[:pad][:x] + @controls[:pad][:size] / 2.0,
          cy: @controls[:pad][:y] + @controls[:pad][:size] / 2.0,
          size: @controls[:pad][:size],
        },
      }
      @controls[:buttons].each do |b|
        out[b[:id]] = { cx: b[:x] + b[:size] / 2.0, cy: b[:y] + b[:size] / 2.0, size: b[:size] }
      end
      out
    end

    def status
      ms = []
      @monsters.each do |e|
        m = e[:model]
        next if m.dead
        ms.push({ species: m.spec[:name], x: m.x.floor, y: m.y.floor, hp: m.hp, state: m.state,
                  boss: e[:boss] || false, phase2: m.phase2 || false, phase: m.phase || 1 })
      end
      {
        x: @player ? @player.x : nil,
        y: @player ? @player.y : nil,
        on_ground: @player ? @player.on_ground : false,
        invuln: @player ? @player.invuln_timer > 0 : false,
        attacking: @player ? @player.attack_timer > 0 : false,
        hp: @stats ? @stats[:hp] : nil,
        mp: @stats ? @stats[:mp] : nil,
        max_hp: @stats ? @stats[:max_hp] : nil,
        exp: @exp, gold: @gold, level: @level, lives: @lives,
        stage: stage ? stage.id : nil,
        climate: @climate ? @climate.kind : nil,
        water_y: Climate.water_y(@climate),
        light_on: Climate.light_on(@climate),
        berserk: berserk_active?,
        paused: @paused,
        checkpoint: @checkpoint_hit,
        falls: @falls, deaths: @deaths, game_overs: @game_overs,
        cam_x: @cam_x,
        monsters: ms,
        stones: @stones.size,
        intro: !@intro.nil?,
        # 창이 화면에 남아 있는가 (닫히는 중도 포함). 컷씬이 끝난 뒤 이것이
        # 참으로 남으면 "대화창이 안 꺼진다" 버그다 (2026-08-23 사용자 보고)
        dialogue_shown: (@dialogue && @dialogue.window && !@dialogue.window.closed?) || false,
        bag: !@bag.nil?,
        ending: @ending ? @ending[:phase] : nil,
        game_over: @game_over ? @game_over[:phase] : nil,
        sign: @sign_text,
        time: @stage_time,
        found: @found_order,
        skills: @skills,
        bolts: @bolts.size,
        hallucination: @hallucination > 0,
        # 터치 컨트롤 배치 (T1). 인수 시나리오가 좌표를 하드코딩하지 않고
        # 계산된 중심을 누르게 한다. 터치 UI 가 없으면 nil.
        touch_controls: control_centers,
      }
    end

    def init
      Graphics.render_scale = SCALE
      @w = Graphics.width
      @h = Graphics.height
      @debug_hud = !env("INITIAL2D_DEBUG").nil?
      Graphics.prepare_font(UI_FONT) if $font_ready

      @map = nil
      @map_error = nil
      @map_w = 0
      @map_h = 0
      @tile_w = 16
      @tile_h = 16
      @layer_count = 0
      @world_w = 0
      @world_h = 0
      @layers = {}
      @monsters = []
      @stones = []
      @bolts = []
      @fps_avg = 0.0
      @cam_x = 0
      @stage_time = 0
      @intro = nil
      @ending = nil
      @game_over = nil

      # 검수용: 어느 스테이지를 열지 밖에서 지정한다 (INITIAL2D_ALDEBARAN_STAGE=tomb)
      carry = @carry
      @carried_exp = carry ? carry[:exp] : 0
      @carried_gold = carry ? carry[:gold] : 0

      want = env("INITIAL2D_ALDEBARAN_STAGE")
      if want
        ok, why = set_stage(want)
        puts "알데바란: #{why}" unless ok
      end
      # 검수용: 시작 x 를 옮긴다 (INITIAL2D_ALDEBARAN_AT=2200). 방마다의 기후를
      # 눈으로 확인하려면 그 방까지 걸어가지 않고 바로 서 볼 수 있어야 한다.
      at = env("INITIAL2D_ALDEBARAN_AT")
      @start_at = numeric?(at) ? at.to_f : nil

      begin
        @map = Tilemap.new(stage.map)
      rescue RuntimeError => e
        @map = nil
        @map_error = e.message
      end
      if @map
        @map_w, @map_h, @tile_w, @tile_h, @layer_count = @map.size
        @world_w = @map_w * @tile_w
        @world_h = @map_h * @tile_h
      end

      # 구간마다 배경 한 벌. 두 장씩 두는 것은 가로로 이어 붙여 흘리기 위해서다.
      @layers = {}
      stage.sections.each do |s|
        far = "#{BG_DIR}far_#{s[:name]}.png"
        near = "#{BG_DIR}near_#{s[:name]}.png"
        @layers[s[:name]] = {
          far: [Image.create(far, 0, 0, @w, @h, 1, "AldFar:#{s[:name]}"),
                Image.create(far, 0, 0, @w, @h, 1, "AldFar:#{s[:name]}")],
          near: [Image.create(near, 0, 0, @w, @h, 1, "AldNear:#{s[:name]}"),
                 Image.create(near, 0, 0, @w, @h, 1, "AldNear:#{s[:name]}")],
        }
      end
      # 환각 때 겹쳐 보이는 옛 무대. 스테이지마다 있을 수도 없을 수도 있다
      @bright_img = stage.bright ? Image.create(stage.bright, 0, 0, @w, @h, 1, "AldBright:#{stage.id}") : nil
      @hallucination = 0

      # 구간마다 기후 하나 (원안 표 19: 아포피스가 방마다 기후를 좌우한다).
      # 표가 없는 스테이지는 전부 nil 이고, 그러면 아무 규칙도 걸리지 않는다.
      @climates = {}
      stage.sections.each do |sec|
        @climates[sec[:name]] = Climate.create(stage.climate && stage.climate[sec[:name]])
      end
      @climate = nil
      # 보스의 우박은 방의 기후가 아니라 보스의 것이다. 간격을 무한대로 두고
      # 씬이 패턴을 돌 때마다 한 알씩 직접 떨군다.
      @boss_hail = Climate.create({ kind: :hail, interval: 1e9, first: 1e9,
                                    warn: 0.5, damage: 10, speed: 340, half_w: 5, count: 1 })

      @karto = Image.create(KARTO_PATH, 0, 0, 48, 48, 24, "AldebaranKarto")
      @karto.set_sheet_grid(12, 2)
      @karto.loop = false

      @aura = Image.create(AURA_PATH, 0, 0, 48, 48, 2, "AldebaranAura")
      @aura.set_sheet_grid(2, 1)
      @aura.loop = false

      @stone_img = Image.create(STONE_PATH, 0, 0, 8, 8, 1, "AldebaranStone")
      @bag_img = Image.create(BAG_PATH, 0, 0, 16, 16, 1, "AldebaranBag")

      # 기후 조각. 엔진의 스프라이트는 만들 때의 크기를 소스 사각형으로 쓰므로
      # 크기마다 하나씩 둔다 (hud.rb 와 같은 사정).
      @climate_img = {}

      # 도입 컷씬의 짐도둑 (몬스터와 같은 시트, 다른 스프라이트).
      # 컷씬이 없는 스테이지에서는 만들지 않는다.
      if stage.intro == :thief
        mk = stage.species[stage.boss[:species]]
        @thief_img = Image.create(mk[:sheet], 0, 0, mk[:frame_w], mk[:frame_h],
                                  mk[:cols] * mk[:rows], "Aldebaran:#{stage.boss[:species]}")
        @thief_img.set_sheet_grid(mk[:cols], mk[:rows])
        @thief_img.loop = false
      else
        @thief_img = nil
      end

      @fade_img = Image.create(FADE_PATH, 0, 0, 16, 16, 1, "AldebaranFade")
      @fade_img.scale = [@w, @h].max / 16.0

      @hud = Aldebaran::Hud.new
      @falls = 0
      @deaths = 0
      @game_overs = 0
      @paused = false
      @pad_was_left = false
      @pad_was_right = false

      # 창 부품 (일시 정지, 게임 오버, 나레이션. 전부 공용품이다)
      @skin = Rpg::Skin.new(path: Rpg::Assets.windowskin, scale: 1)
      se = {
        cursor: -> { play_se(:cursor) },
        decision: -> { play_se(:decision) },
        text: -> { play_se(:text) },
      }
      measure = ->(text) { Graphics.text_width(text) }
      draw_text = ->(x, y, text) { Graphics.draw_text(x, y, text) }
      @pause_choice = Rpg::Choice.new(
        skin: @skin, measure: measure, draw_text: draw_text,
        line_height: 22, max_visible: 3, min_width: 140, se: se
      )
      @dialogue = Rpg::Dialogue.new(
        skin: @skin, measure: measure, draw_text: draw_text,
        screen_w: @w, screen_h: @h, lines: 3, line_height: 20,
        speed: 3, se: se
      )

      reset_stage

      # 도입 컷씬 (기획서 4.2절): 짐도둑이 배낭을 지고 달아난다 → 나레이션
      if stage.intro.nil? || env("INITIAL2D_SKIP_INTRO")
        @intro = nil
      elsif stage.intro == :thief
        @intro = { phase: :thief, timer: 0.0, x: stage.start[:x] + 40 }
      else
        # 컷씬 없이 나레이션만. 글을 지금 띄우지 않으면 busy? 가 거짓이라
        # 첫 프레임에 그대로 사라진다 (A3 에서 한 번 당한 자리다).
        @intro = { phase: :text, timer: 0.0 }
        @dialogue.show_message(stage.intro_text)
      end

      @pad = nil
      @buttons = nil
      @controls = nil
      if Ui::VirtualPad.should_show?
        # 화면 크기 비례 배치 (T1). 점프가 모서리(엄지가 쉬는 자리), 공격이 그 안쪽,
        # 폭주와 검기는 그 윗줄, 정지는 우상단.
        @controls = Ui::Layout.controls(@w, @h, {
          main: [
            { id: :jump, label: "점프" },
            { id: :attack, label: "공격" },
          ],
          sub: [
            { id: :skill, label: "폭주" },
            { id: :bolt, label: "검기" },
          ],
          sys: [{ id: :pause, label: "II" }],
        })
        @pad = Ui::VirtualPad.new(@controls[:pad])
        @buttons = Ui::Buttons.new(items: @controls[:buttons])
      end

      slot = stage.bgm_slot
      Bgm.play((slot && Rpg::Assets.exists?(slot)) ? slot : BGM_FALLBACK, { volume: 64 })
    end

    # ---- 일시 정지 (기획서 8.3절) ----------------------------------------------

    def open_pause
      @paused = true
      play_se(:decision)
      @pause_choice.show(PAUSE_ITEMS, {
        x: (@w / 2.0 - 80).floor, y: (@h / 2.0 - 40).floor, index: 0,
      })
    end

    def poll_menu_input
      input = {
        confirm: Input.key_down?(:z) || Input.key_down?(:return) || Input.key_down?(:space),
        up: Input.key_down?(:up),
        down: Input.key_down?(:down),
        cancel: Input.key_down?(:x) || Input.key_down?(:escape) || Input.key_down?(:p),
      }
      if Input.mouse_down?(:left)
        index = @pause_choice.index_at(Input.mouse_x, Input.mouse_y)
        if index
          @pause_choice.index = index
          input[:confirm] = true
        end
      end
      input
    end

    def update_pause
      input = poll_menu_input
      if @buttons
        @buttons.update
        input[:cancel] = true if @buttons.pressed?(:pause)
      end

      @pause_choice.update(input)
      unless @pause_choice.active?
        picked = @pause_choice.result
        @paused = false
        if picked == 1
          reset_stage
        elsif picked == 2
          clear_carry
          switch_scene("aldebaran_title")
        end
      end
    end

    # ---- 컷씬과 끝 --------------------------------------------------------------

    def update_intro(dt)
      if @intro[:phase] == :thief
        @intro[:timer] += dt
        @intro[:x] += 150 * dt # 화면 밖으로 달아난다
        if @intro[:timer] >= 1.6
          @intro[:phase] = :text
          @dialogue.show_message(stage.intro_text)
        end
      else
        @dialogue.update(poll_confirm, false)
        @intro = nil unless @dialogue.busy? # 조작이 풀린다
      end
    end

    # 에필로그의 쪽 목록. 흔적을 다 모은 플레이어만 마지막 한 줄을 읽는다.
    def epilogue_pages
      pages = stage.epilogue.dup
      pages.push(stage.epilogue_full) if @found_order.size >= stage.landmarks.size
      pages
    end

    def start_ending
      play_se(:pick)
      @bag = nil
      @ending = { phase: :epilogue, page: 0, pages: epilogue_pages }
      Bgm.stop
      @dialogue.show_message(@ending[:pages][0])
    end

    def update_ending
      if @ending[:phase] == :epilogue
        @dialogue.update(poll_confirm, false)
        unless @dialogue.busy?
          @ending[:page] += 1
          if @ending[:pages][@ending[:page]]
            @dialogue.show_message(@ending[:pages][@ending[:page]])
          else
            @ending[:phase] = :result
            @ending[:wait] = 0
            play_se(:decision)
          end
        end
      else
        # 결과 창 (기획서 4.4절). 결정키로 닫으면 **다음 스테이지로 이어진다**.
        # 다음이 없으면 거기서 한 회차가 끝난 것이라 타이틀로 돌아간다.
        @dialogue.update({}, false) # 에필로그 창이 닫히는 것을 마저 본다
        @ending[:wait] += 1
        if @ending[:wait] > 10 && poll_confirm[:confirm]
          next_stage = Stages.after(stage.id)
          if next_stage
            @carry = { exp: @exp, gold: @gold }
            set_stage(next_stage.id)
            switch_scene("aldebaran") # 같은 씬을 새 무대로 다시 연다
          else
            clear_carry
            switch_scene("aldebaran_title")
          end
        end
      end
    end

    def update_game_over
      if @game_over[:phase] == :text
        @dialogue.update(poll_confirm, false)
        unless @dialogue.busy?
          @game_over[:phase] = :choice
          @pause_choice.show(GAMEOVER_ITEMS, {
            x: (@w / 2.0 - 70).floor, y: (@h / 2.0 - 20).floor, index: 0,
          })
        end
      else
        @dialogue.update({}, false) # 게임 오버 글의 창이 닫히는 것을 마저 본다
        @pause_choice.update(poll_menu_input)
        unless @pause_choice.active?
          picked = @pause_choice.result
          if picked == 1
            clear_carry
            switch_scene("aldebaran_title")
          else
            reset_stage # 취소를 포함해 기본은 다시 하기
          end
        end
      end
    end

    # ---- 갱신 -------------------------------------------------------------------

    def player_box
      [@player.x - Player::HALF_W, @player.y - Player::BODY_H,
       @player.x + Player::HALF_W, @player.y]
    end

    def update(elapsed)
      @fps_avg = @fps_avg * (95.0 / 100) + (1000.0 / elapsed) * 0.05 if elapsed > 0
      if @map.nil?
        switch_scene("aldebaran_title") if Input.key_down?(:escape)
        return
      end

      dt = [elapsed, 50].min / 1000.0

      if @paused
        update_pause
        return
      end
      if @game_over
        update_game_over
        return
      end
      if @ending
        update_ending
        return
      end
      if @intro
        update_intro(dt)
        return
      end

      # 대화창은 한가할 때도 매 프레임 돌린다. busy? 는 마지막 쪽을 넘긴 즉시
      # 거짓이 되고 창이 닫히는 것은 그 뒤의 update 가 하는 일이라, 컷씬이
      # 끝났다고 갱신을 멈추면 창이 열린 채로 화면에 남는다.
      @dialogue.update({}, false)

      @stage_time += dt
      @hallucination = [0, @hallucination - dt].max
      input = poll_input

      if input[:pause_edge]
        open_pause
        return
      end

      # 힘 (기획서 5.3절): 익힌 것만 쓸 수 있고, 쓰면 쿨타임이 돈다
      @berserk_timer = [0, @berserk_timer - dt].max
      Combat.tick_cooldowns(@skills, dt)

      if input[:skill_edge] && !berserk_active? && Combat.can_use?(@skills, :berserk, @stats[:mp])
        spec = Combat::SKILLS[:berserk]
        @stats[:mp] -= spec[:mp]
        @skills[:cooldown][:berserk] = spec[:cooldown]
        @berserk_timer = spec[:time]
        play_se(:berserk)
      end
      if input[:bolt_edge] && Combat.can_use?(@skills, :bolt, @stats[:mp])
        spec = Combat::SKILLS[:bolt]
        @stats[:mp] -= spec[:mp]
        @skills[:cooldown][:bolt] = spec[:cooldown]
        @bolts.push({
          x: @player.x + @player.facing * 10, y: @player.y - 12,
          vx: @player.facing * spec[:speed],
        })
        play_se(:swing)
      end

      # ---- 기후 (원안 표 19) --------------------------------------------------
      # 지금 선 방의 기후를 흘리고, 그 결과를 플레이어의 환경으로 씌운다.
      here = stage.section_at(@player.x)[0]
      @climate = @climates[here]
      if @climate
        # 발밑 지면과 천장을 찾아 우박이 떨어질 구간을 정한다
        floor_y = @player.y
        ceil_y = 0
        ((@player.y / 16).floor..(@map_h - 1)).each do |ty|
          if probe(@player.x, ty * 16 + 1)
            floor_y = ty * 16
            break
          end
        end
        ((@player.y / 16).floor - 1).downto(0) do |ty|
          if probe(@player.x, ty * 16 + 8)
            ceil_y = ty * 16 + 16
            break
          end
        end
        Climate.update(@climate, dt, { x: @player.x, floor_y: floor_y, ceil_y: ceil_y, rng: @rng })
      end
      @player.env = Climate.env(@climate, @player.y)

      @player.update(input, dt, @probe)
      play_se(:jump) if @player.jumped
      play_se(:swing) if @player.swung

      # 우박에 맞았는가 (예고를 지나 실제로 떨어지는 것만 아프다)
      if @climate && @player.invuln_timer <= 0
        px0, py0, px1, py1 = player_box
        Climate.hazards(@climate).each_with_index do |hz, i|
          if overlap?(px0, py0, px1, py1, hz[:x0], hz[:y0], hz[:x1], hz[:y1])
            Climate.consume(@climate, i)
            damage_player(hz[:damage], hz[:x0], nil)
            break
          end
        end
        return if @game_over
      end

      if @player.y > @world_h + 60
        @falls += 1
        lose_life
        return if @game_over
      end

      stage.checkpoints.each do |cp|
        if !cp[:taken] && @player.x >= cp[:x]
          cp[:taken] = true
          @checkpoint_hit = true
          @checkpoint = { x: cp[:x], y: cp[:y] }
          play_se(:pick)
        end
      end

      # 흔적 (기획서 4.3.1절): 밟으면 글이 뜨고, 기록에 남고, 힘을 하나 준다
      @sign_timer = [0, @sign_timer - dt].max
      @sign_text = nil if @sign_timer <= 0
      @learned_timer = [0, @learned_timer - dt].max
      @learned_text = nil if @learned_timer <= 0
      stage.landmarks.each do |mark|
        next unless !@found[mark[:id]] && @player.x >= mark[:x0] && @player.x <= mark[:x1]
        @found[mark[:id]] = true
        @found_order.push(mark[:title])
        @sign_text = mark[:text]
        @sign_timer = SIGN_SECONDS
        play_se(:pick)
        if mark[:skill] && @skills[mark[:skill]] == false
          @skills[mark[:skill]] = true
          spec = Combat::SKILLS[mark[:skill]]
          @learned_text = Rpg::Text.with(spec[:name], "을", "를") + " 익혔다"
          @learned_timer = SIGN_SECONDS
        end
        @hallucination = mark[:hallucination] if mark[:hallucination]
      end

      @monsters.each do |e|
        next if e[:model].dead
        e[:model].update(dt, @probe, @player.x, @player.y)
        update_boss_pattern(e, dt) if e[:boss]
      end

      # 보스가 부른 우박은 방의 기후와 따로 흐른다
      if @boss_hail && @boss_hail.drops.size > 0
        Climate.update(@boss_hail, dt, { x: @player.x, floor_y: @player.y, ceil_y: 96, rng: @rng })
        if @player.invuln_timer <= 0
          px0, py0, px1, py1 = player_box
          Climate.hazards(@boss_hail).each_with_index do |hz, i|
            if overlap?(px0, py0, px1, py1, hz[:x0], hz[:y0], hz[:x1], hz[:y1])
              Climate.consume(@boss_hail, i)
              damage_player(hz[:damage], hz[:x0], nil)
              break
            end
          end
          return if @game_over
        end
      end

      update_bolts(dt)
      resolve_player_attack
      resolve_monster_attacks
      return if @game_over
      update_stones(dt)
      return if @game_over

      # 배낭 줍기 → 에필로그 (기획서 4.4절)
      if @bag && (@player.x - @bag[:x]).abs < 14 && (@player.y - @bag[:y]).abs < 24
        start_ending
        return
      end

      # 배낭이 없는 무대는 보스를 쓰러뜨린 것으로 끝난다
      if @boss_clear
        @boss_clear -= dt
        if @boss_clear <= 0
          @boss_clear = nil
          start_ending
          return
        end
      end

      @cam_x = [0, [@player.x - @w / 2.0, @world_w - @w].min].max
    end

    # ---- 그리기 ----------------------------------------------------------------

    def climate_piece(name, x, y, opacity = nil)
      c = CLIP[name]
      unless @climate_img[name]
        img = Image.create(c[0], 0, 0, c[3], c[4], 1, "AldClimate:#{name}")
        img.loop = false
        @climate_img[name] = img
      end
      img = @climate_img[name]
      img.set_rect(c[1], c[2], c[3], c[4])
      img.set_position(x.floor, y.floor)
      img.opacity = opacity || 255
      img.update(0)
      img.draw
    end

    # 우박 알과 예고를 그린다 (방의 기후와 보스의 것이 같은 그림을 쓴다)
    def draw_drops(state, cx)
      return if state.nil? || state.drops.nil?
      state.drops.each do |dp|
        if dp[:warn] > 0
          a = 1 - dp[:warn] / (state.spec[:warn] || 0.5)
          climate_piece(:warn, dp[:x] - 8 - cx, dp[:floor_y] - 6, (70 + 150 * a).floor)
        elsif dp[:y]
          climate_piece(:hail, dp[:x] - 4 - cx, dp[:y] - 4)
        end
      end
    end

    def draw_climate(cx)
      draw_drops(@boss_hail, cx)
      return if @climate.nil?

      if @climate.kind == :light
        # 빛기둥 셋. 켜져 있는 동안만 영혼이 실체가 된다
        if Climate.light_on(@climate)
          (@climate.spec[:pillars] || []).each do |px|
            climate_piece(:beam, px - 44 - cx, 0, 115)
          end
        end

      elsif @climate.kind == :hail
        draw_drops(@climate, cx)

      elsif @climate.kind == :flood
        wy = @climate.water_y
        if wy && wy < @h
          # 조각은 384 폭이라 화면 폭만큼 옆으로 잇는다. 모바일은 논리 폭이
          # 384 보다 넓어, 한 장만 그리면 물이 화면 왼쪽에만 보였다
          # (2026-08-24 실기 검수). 수면 아래가 조각(128)보다 깊으면
          # 몸통 조각으로 마저 채운다.
          # (이 mruby 에는 Range#step 이 없어 while 로 센다)
          tx = 0
          while tx <= @w - 1
            climate_piece(:water, tx, wy, 150)
            tx += 384
          end
          ty = wy + 128
          while ty <= @h - 1
            tx = 0
            while tx <= @w - 1
              climate_piece(:waterbody, tx, ty, 150)
              tx += 384
            end
            ty += 64
          end
        end

      elsif @climate.kind == :snow
        # 눈: 규칙은 마찰이고 이것은 그 표시다. 좌표 해시라 흔들리지 않는다
        24.times do |i|
          fx = (i * 79 + (cx * 0.5).floor) % (@w + 32) - 16
          fy = ((i * 137 + (@climate.t * 40).floor) % (@h + 32)) - 16
          climate_piece(:flake, fx, fy, 150)
        end
      end
    end

    def draw_monsters(cx)
      @monsters.each do |e|
        m = e[:model]
        next if m.dead
        sx = m.x.floor - m.spec[:anchor_x] - cx
        next unless sx > -m.spec[:frame_w] && sx < @w
        f = m.frame
        e[:img].set_frames(f, f)
        e[:img].current_frame = f
        e[:img].set_position(sx, m.y.floor - m.spec[:anchor_y])
        if m.state == :dying
          e[:img].opacity = (255 * (1 - m.fade / Monster::DYING_TIME)).floor
        else
          e[:img].opacity = 255
        end
        e[:img].update(0)
        e[:img].draw
      end
    end

    def draw_hud
      @hud.bar(6, 6, :hp, @stats[:hp].to_f / @stats[:max_hp])
      @hud.bar(6, 14, :mp, @stats[:mp].to_f / @stats[:max_mp])
      @hud.bar(6, 22, :exp, Combat.exp_ratio(@exp))
      (1..stage.lives).each do |i|
        @hud.icon(76 + (i - 1) * 12, 5, i <= @lives ? :star : :star_empty)
      end
      @hud.icon(76, 18, :coin)
      if $font_ready
        Graphics.draw_text(88, 16, @gold.to_s)
        Graphics.draw_text(76, 30, "Lv #{@level}")
      end

      # 스킬 슬롯 (원안 8.2절의 스킬 1~3 자리). 쿨타임이 슬롯에서 줄어든다.
      sx = @w - 8
      [:bolt, :berserk].each do |id|
        spec = Combat::SKILLS[id]
        sx -= 20
        left = @skills[:cooldown][id] || 0
        ratio = spec[:cooldown] > 0 ? (left.to_f / spec[:cooldown]) : 0
        @hud.skill_slot(sx, 6, 18, @skills[id], ratio, Combat.can_use?(@skills, id, @stats[:mp]))
        Graphics.draw_text(sx + 6, 8, spec[:key]) if $font_ready && @skills[id]
      end
    end

    def draw_centered_text(y, text)
      w = Graphics.text_width(text)
      Graphics.draw_text(((@w - w) / 2.0).floor, y, text)
    end

    # 결과 창 (기획서 4.4절)
    def draw_result
      bw = 280
      bh = 190
      bx = ((@w - bw) / 2.0).floor
      by = ((@h - bh) / 2.0).floor
      @skin.draw_pieces(Rpg::Window.slices(bw, bh), bx, by)
      return unless $font_ready
      draw_centered_text(by + 10, "#{stage.number} #{stage.title}, 끝")
      Graphics.draw_text(bx + 16, by + 34, "레벨 #{@level}   경험치 #{@exp}   골드 #{@gold}")
      Graphics.draw_text(bx + 16, by + 52, format("걸린 시간 %d초", @stage_time.floor))
      # 알아낸 것: 흔적을 밟은 만큼만 남는다 (기획서 4.3.1절)
      Graphics.draw_text(bx + 16, by + 76, format("알아낸 것  %d / %d", @found_order.size, stage.landmarks.size))
      @found_order.each_with_index do |title, i|
        Graphics.draw_text(bx + 26, by + 94 + i * 18, "- #{title}")
      end
      if @found_order.size < stage.landmarks.size
        Graphics.draw_text(bx + 26, by + 94 + @found_order.size * 18, "...")
      end
    end

    # 스프라이트의 트랜스폼은 update 에서 커밋된다. 위치를 render 에서 정하므로
    # 그리기 직전에 update(0) 을 불러야 한다. 그러지 않으면 한 프레임 늦고,
    # 컷씬처럼 update 가 일찍 반환하는 동안에는 아예 반영되지 않는다.
    def draw_layer(pair, factor, opacity)
      return if pair.nil? || opacity <= 0
      bx = -(@cam_x * factor).floor % @w
      pair.each_with_index do |img, i|
        img.set_position(bx - @w + i * @w, 0)
        img.opacity = [0, [255, opacity].min].max.floor
        img.update(0)
        img.draw
      end
    end

    def render
      if @map.nil?
        if $font_ready
          Graphics.draw_text(20, @h / 2 - 20, "맵 로드 실패:")
          Graphics.draw_text(20, @h / 2 + 4, @map_error.to_s)
        end
        return
      end

      cx = @cam_x.floor

      # 구간 둘을 겹쳐 서서히 바꾼다 (문이 열리는 것이 아니라 어느새 다른 곳)
      cur, nxt, blend = stage.section_at(@cam_x)
      a = @layers[cur]
      b = @layers[nxt]
      draw_layer(a && a[:far], PARALLAX_FAR, 255)
      draw_layer(b && b[:far], PARALLAX_FAR, 255 * blend) if blend > 0 && nxt != cur
      draw_layer(a && a[:near], PARALLAX_NEAR, 255)
      draw_layer(b && b[:near], PARALLAX_NEAR, 255 * blend) if blend > 0 && nxt != cur

      # 안개에 취하면 잠깐 옛 숲이 겹쳐 보인다
      if @hallucination > 0 && @bright_img
        fade = [1, @hallucination / (6.0 / 10)].min # 0.6 을 나눗셈으로 쓰는 이유: mruby 가 이 리터럴을 1ulp 다르게 읽는다
        @bright_img.set_position(0, 0)
        @bright_img.opacity = (200 * fade).floor
        @bright_img.update(0)
        @bright_img.draw
      end

      @map.draw(0, @layer_count - 1, cx, 0)

      draw_climate(cx)
      draw_monsters(cx)

      # 떨어진 배낭
      if @bag
        @bag_img.set_position(@bag[:x].floor - 8 - cx, @bag[:y].floor - 16)
        @bag_img.update(0)
        @bag_img.draw
      end

      # 돌팔매
      @stones.each do |s|
        @stone_img.set_position(s[:x].floor - 4 - cx, s[:y].floor - 4)
        @stone_img.update(0)
        @stone_img.draw
      end

      # 도입 컷씬의 짐도둑
      if @intro && @intro[:phase] == :thief
        mk = stage.species[stage.boss[:species]]
        f = (@intro[:timer] * 8).floor % 2
        @thief_img.set_frames(f, f)
        @thief_img.current_frame = f
        @thief_img.set_position(@intro[:x].floor - mk[:anchor_x] - cx, stage.start[:y] - mk[:anchor_y])
        @thief_img.update(0)
        @thief_img.draw
      end

      if berserk_active?
        af = (@player.anim_time * 8).floor % 2
        @aura.set_frames(af, af)
        @aura.current_frame = af
        @aura.set_position(@player.x.floor - 24 - cx, @player.y.floor - 46)
        @aura.update(0)
        @aura.draw
      end

      f = @player.frame
      @karto.set_frames(f, f)
      @karto.current_frame = f
      @karto.set_position(@player.x.floor - 24 - cx, @player.y.floor - 46)
      if @player.invuln_timer > 0 && (@player.invuln_timer * 10).floor % 2 == 0
        @karto.opacity = 110
      else
        @karto.opacity = 255
      end
      @karto.update(0)
      @karto.draw

      draw_hud

      # 흔적의 글과 익힌 힘 (상단 가운데). HUD 가 왼쪽 위 y 46 까지 쓰므로 그 아래에 둔다.
      draw_centered_text(58, @sign_text) if @sign_text && $font_ready
      draw_centered_text(78, @learned_text) if @learned_text && $font_ready

      # 날린 검기
      @bolts.each do |b|
        next if @stone_img.nil?
        @stone_img.set_position(b[:x].floor - 4 - cx, b[:y].floor - 4)
        @stone_img.opacity = 255
        @stone_img.update(0)
        @stone_img.draw
      end

      if @debug_hud && $font_ready
        Graphics.draw_text(4, 40, format("FPS %d  x %d y %d  %s", (@fps_avg + 0.5).floor,
                                         @player.x.floor, @player.y.floor,
                                         @player.on_ground ? "지상" : "공중"))
      end

      @pad.draw if @pad
      @buttons.draw if @buttons

      # 나레이션 (도입, 에필로그, 게임 오버의 글)
      if @game_over
        @fade_img.set_position(0, 0)
        @fade_img.opacity = 170
        @fade_img.update(0)
        @fade_img.draw
        if $font_ready && @game_over[:phase] == :choice
          draw_centered_text((@h / 2.0 - 56).floor, "게임 오버")
        end
      end
      @dialogue.draw
      @pause_choice.draw if @game_over && @game_over[:phase] == :choice

      draw_result if @ending && @ending[:phase] == :result

      if @paused
        @fade_img.set_position(0, 0)
        @fade_img.opacity = 150
        @fade_img.update(0)
        @fade_img.draw
        @pause_choice.draw
        Graphics.draw_text((@w / 2.0 - 40).floor, (@h / 2.0 - 64).floor, "일시 정지") if $font_ready
      end
    end

    def destroy
      if @map
        @map.dispose
        @map = nil
      end
      @monsters.each { |e| e[:img].release if e[:img] }
      @monsters = []
      @layers.each_value do |set|
        set.each_value do |pair|
          pair.each { |img| img.release }
        end
      end
      @layers = {}
      [@bright_img, @karto, @aura, @fade_img, @stone_img, @bag_img, @thief_img].each do |img|
        img.release if img
      end
      @climate_img.each_value { |img| img.release }
      @climate_img = {}
      @bright_img = nil
      @karto = nil
      @aura = nil
      @fade_img = nil
      @stone_img = nil
      @bag_img = nil
      @thief_img = nil
      if @hud
        @hud.dispose
        @hud = nil
      end
      if @dialogue
        @dialogue.dispose
        @dialogue = nil
      end
      if @pause_choice
        @pause_choice.dispose
        @pause_choice = nil
      end
      if @skin
        @skin.dispose
        @skin = nil
      end
      if @pad
        @pad.dispose
        @pad = nil
      end
      if @buttons
        @buttons.dispose
        @buttons = nil
      end
      @controls = nil
      Graphics.prepare_font(BASE_FONT) if $font_ready
      Graphics.render_scale = 1
    end
  end

  # 충돌 조회를 Proc 으로 (Player 와 Monster 가 probe.call(px, py) 로 부른다)
  @probe = ->(px, py) { AldebaranScene.probe(px, py) }
end
