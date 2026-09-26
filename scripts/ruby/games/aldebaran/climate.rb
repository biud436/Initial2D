# 알데바란, 기후 (docs/plans/aldebaran-7-tomb.md 4절). scripts/lua/games/aldebaran/climate.lua 의 Ruby 판.
#
# 원안 4.2.2.4절 표 19: **황제의 무덤의 온도와 습도는 파괴의 신 아포피스의 힘에
# 의해 좌우된다. 어떤 방에는 눈이 오고 어떤 복도에는 우박 또는 비가 내리고
# 폭풍우가 몰아치고, 홍수가 발생한다.**
#
# 그것을 연출이 아니라 **조작을 바꾸는 규칙**으로 만든 것이 이 모듈이다. 방이
# 다르다는 것이 눈이 아니라 손에 남아야 한다.
#
# 엔진에 닿지 않는 순수 모듈이다. 씬은 상태를 만들어 흘리고, 그 결과를 읽어
# 플레이어의 환경과 우박의 판정에 쓴다. 수치는 전부 스테이지의 표에 있다
# (stages/tomb.rb 의 Tomb::CLIMATE).
#
#   require "scripts/ruby/games/aldebaran/climate"
#   c = Aldebaran::Climate.create(stage.climate[:moon])
#   Aldebaran::Climate.update(c, dt, { x: player.x, floor_y: 400, rng: rng })
#   player.env = Aldebaran::Climate.env(c)
#
# 종류 넷:
#   snow   지면 마찰이 준다. 멈추려면 미리 놓아야 한다
#   light  빛기둥이 켜지고 꺼진다. 그늘의 영혼은 실체가 아니라 베이지 않는다
#   hail   천장에서 우박이 떨어진다. 떨어질 자리에 그림자가 먼저 뜬다
#   flood  수위가 오르내린다. 잠기면 느려지고 낮게 뛴다
#
# Lua 의 Climate.new(def) 는 nil 을 돌려줄 수 있어 클래스 new 로 옮길 수 없다.
# 그래서 모듈 함수 create(spec) 로 두고, 나머지 함수는 nil 상태를 그대로 받는다
# (docs/plans/s2-ruby-aldebaran.md 3.1절). 표를 가리키던 def 는 spec 이다.

module Aldebaran
  module Climate
    # 기후가 없는 방의 환경. 모두가 같은 표를 돌려받으므로 얼려 둔다.
    DEFAULT_ENV = { friction: 1, move_mult: 1, jump_mult: 1 }.freeze

    # LITERAL: 엔진의 mruby 4.0.0 은 소수 리터럴 몇 개(0.3, 0.35, 0.6, 0.7, 0.95)를
    # 마지막 비트 하나 어긋나게 읽는다 (이 VM 에서 0.35 == 35.0 / 100 이 거짓이다).
    # 나눗셈은 IEEE 가 정확히 반올림하므로 Lua 의 strtod 와 같은 값이 나온다. 그래서
    # 이 파일의 0.35 와 0.6 은 나눗셈으로 적는다. 다른 소수(0.5, 0.15, 0.85, ...)는
    # 같은 VM 에서 Lua 와 같은 값으로 읽히는 것을 확인했다.

    # 기후 하나의 상태 (Lua 의 s 표). 필드 이름은 Lua 와 짝이다.
    #   kind       :snow, :light, :hail, :flood
    #   spec       스테이지의 기후 표 (Lua 의 s.def)
    #   t          흐른 시간 (초)
    #   drops      우박 알들 (hail 일 때만. 아니면 nil)
    #   next_drop  다음 알까지 남은 시간 (hail)
    #   water_y    지금 수면의 y (flood)
    #   surge      보스가 밀어 올린 남은 시간 (flood, 없으면 nil)
    class State
      attr_accessor :kind, :spec, :t, :drops, :next_drop, :water_y, :surge

      def initialize(spec)
        @kind = spec[:kind]
        @spec = spec
        @t = 0
        @drops = nil
        @next_drop = nil
        @water_y = nil
        @surge = nil
        if spec[:kind] == :hail
          @drops = []
          # 첫 알은 당겨 떨군다. 방에 들어서고 1.6초를 아무 일도 없이 걷게 하면
          # 그 방의 규칙을 배우기 전에 적을 먼저 만난다.
          @next_drop = spec[:first] || 6.0 / 10     # 0.6 (위의 LITERAL 주석)
        elsif spec[:kind] == :flood
          @water_y = spec[:low]
        end
      end
    end

    # 기후 상태를 만든다. spec 이 nil 이면 기후가 없는 방이다 (nil 을 돌려준다).
    def self.create(spec)
      return nil if spec.nil?
      State.new(spec)
    end

    # 우박 한 알을 떨군다. 먼저 그림자만 뜨고, 예고 시간이 지나야 떨어진다.
    # (Lua 에서는 local 함수다. 밖에서 부를 때는 nil 을 거르는 drop 을 쓴다.)
    def self.add_drop(s, x, floor_y)
      s.drops.push({
        x: x, y: nil, vy: 0,
        warn: s.spec[:warn] || 0.5,
        floor_y: floor_y,
      })
    end

    # 밖에서 우박 한 알을 떨군다 (보스의 패턴이 쓴다. 기후가 hail 일 필요는 없다).
    def self.drop(s, x, floor_y)
      return if s.nil? || s.drops.nil?
      add_drop(s, x, floor_y)
    end

    # 수위를 잠시 최고로 밀어 올린다 (보스의 2페이즈 패턴)
    def self.surge(s, seconds)
      return if s.nil? || s.kind != :flood
      s.surge = [s.surge || 0, seconds].max
    end

    # 한 프레임. ctx 는 { x: 플레이어 x, floor_y: 발밑 지면 y, ceil_y: 천장 y, rng: 시드 난수 }
    def self.update(s, dt, ctx)
      return if s.nil?
      s.t = s.t + dt

      if s.kind == :hail
        s.next_drop = s.next_drop - dt
        if s.next_drop <= 0
          s.next_drop = s.spec[:interval] || 1.6
          n = s.spec[:count] || 1
          (1..n).each do |i|
            # 플레이어 언저리에 떨군다. 정확히 머리 위만 노리면 피할 수
            # 없고, 아무 데나 떨구면 볼 이유가 없다.
            spread = 96
            r = ctx[:rng].nil? ? (i - 1).to_f / n : ctx[:rng].float
            add_drop(s, ctx[:x] + (r * 2 - 1) * spread, ctx[:floor_y])
          end
        end
        (s.drops.size - 1).downto(0) do |i|
          dp = s.drops[i]
          if dp[:warn] > 0
            dp[:warn] = dp[:warn] - dt
            if dp[:warn] <= 0
              dp[:y] = (ctx[:ceil_y] || 0) - 8      # 천장에서 떨어지기 시작
              dp[:vy] = s.spec[:speed] || 320
            end
          else
            dp[:y] = dp[:y] + dp[:vy] * dt
            if dp[:y] > dp[:floor_y] + 8
              s.drops.delete_at(i)
            end
          end
        end

      elsif s.kind == :flood
        # 보스가 밀어 올린 동안은 최고 수위로 고정된다
        if (s.surge || 0) > 0
          s.surge = s.surge - dt
          s.water_y = s.spec[:high]
          return
        end
        # 수위는 사인이 아니라 사다리꼴로 움직인다. 오르내리는 동안이 아니라
        # **멈춰 있는 동안**에 판단할 시간이 있어야 하기 때문이다.
        p = s.spec[:period] || 9
        phase = (s.t % p).to_f / p
        lo = s.spec[:low]
        hi = s.spec[:high]
        if phase < 35.0 / 100                     # 0.35 (LITERAL)
          s.water_y = lo
        elsif phase < 0.5
          s.water_y = lo + (hi - lo) * ((phase - 35.0 / 100) / 0.15)
        elsif phase < 0.85
          s.water_y = hi
        else
          s.water_y = hi + (lo - hi) * ((phase - 0.85) / 0.15)
        end
      end
    end

    # 플레이어에게 씌울 환경. y 를 주면 물에 잠겼는지까지 본다.
    def self.env(s, y = nil)
      return DEFAULT_ENV if s.nil?
      if s.kind == :snow
        return { friction: s.spec[:friction] || 0.34, move_mult: 1, jump_mult: 1 }
      elsif s.kind == :flood
        if !y.nil? && y > s.water_y
          return { friction: 1,
                   move_mult: s.spec[:move_mult] || 0.55,
                   jump_mult: s.spec[:jump_mult] || 0.72 }
        end
      end
      DEFAULT_ENV
    end

    # 이 x 가 빛 안인가 (빛기둥 기후에서만 뜻이 있다).
    # 빛기둥이 아닌 기후에서는 늘 참이다 ("빛이 없으면 다 벨 수 있다").
    def self.lit(s, x)
      return true if s.nil? || s.kind != :light
      period = s.spec[:period] || 4
      if (s.t % period) >= (s.spec[:lit] || 2.2)
        return false                     # 지금은 다 꺼져 있다
      end
      (s.spec[:pillars] || []).each do |px|
        return true if (x - px).abs <= (s.spec[:half_w] || 44)
      end
      false
    end

    # 빛기둥이 켜져 있는가 (그리기용)
    def self.light_on(s)
      return false if s.nil? || s.kind != :light
      (s.t % (s.spec[:period] || 4)) < (s.spec[:lit] || 2.2)
    end

    # 지금 수면의 y (홍수가 아니면 nil)
    def self.water_y(s)
      return nil if s.nil? || s.kind != :flood
      s.water_y
    end

    # 떨어지고 있는 우박의 상자들. 씬이 플레이어와 겹치는지 본다.
    # 예고(그림자)만 뜬 것은 아직 아프지 않다.
    def self.hazards(s)
      return [] if s.nil? || s.kind != :hail
      out = []
      r = s.spec[:half_w] || 5
      s.drops.each do |dp|
        if dp[:warn] <= 0 && !dp[:y].nil?
          out.push({ x0: dp[:x] - r, y0: dp[:y] - r,
                     x1: dp[:x] + r, y1: dp[:y] + r, damage: s.spec[:damage] || 9 })
        end
      end
      out
    end

    # 우박이 맞았다. 같은 알이 두 번 아프지 않게 지운다.
    # index 는 hazards 가 돌려준 배열의 0 기준 번호다 (Lua 는 1 기준).
    def self.consume(s, index)
      return if s.nil? || s.kind != :hail
      n = -1
      s.drops.each_with_index do |dp, i|
        if dp[:warn] <= 0 && !dp[:y].nil?
          n += 1
          if n == index
            s.drops.delete_at(i)
            return
          end
        end
      end
    end
  end
end
