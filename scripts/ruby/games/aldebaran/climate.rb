# 알데바란, 기후 (docs/plans/aldebaran-7-tomb.md 4절).
#
# 원안 4.2.2.4절 표 19: **황제의 무덤의 온도와 습도는 파괴의 신 아포피스의 힘에
# 의해 좌우된다. 어떤 방에는 눈이 오고 어떤 복도에는 우박 또는 비가 내리고
# 폭풍우가 몰아치고, 홍수가 발생한다.**
#
# 방의 기후를 **조작을 바꾸는 규칙**으로 구현한다. 엔진을 호출하지 않는 순수
# 모듈이며, 씬이 상태를 만들어 매 프레임 갱신하고 플레이어의 환경과 우박의
# 판정에 쓴다. 수치는 스테이지의 표(stages/tomb.rb의 Tomb::CLIMATE)에 있다.
#
#   require "scripts/ruby/games/aldebaran/climate"
#   c = Aldebaran::Climate.create(stage.climate[:moon])
#   Aldebaran::Climate.update(c, dt, { x: player.x, floor_y: 400, rng: rng })
#   player.env = Aldebaran::Climate.env(c)
#
# 종류 넷:
#   snow   지면 마찰이 줄어든다. 멈추려면 미리 방향키를 떼어야 한다
#   light  빛기둥이 켜지고 꺼진다. 그늘에 있는 영혼은 실체가 없어 공격이 통하지 않는다
#   hail   천장에서 우박이 떨어진다. 떨어질 자리에 그림자가 먼저 표시된다
#   flood  수위가 오르내린다. 물에 잠기면 이동이 느려지고 점프가 낮아진다
#
# 기후가 없는 방은 상태가 nil이다. 생성은 create(spec)로 하고, 모든 함수는 nil
# 상태를 받으면 기후가 없는 방으로 처리한다.

module Aldebaran
  module Climate
    # 기후가 없는 방의 환경. 모든 호출이 같은 Hash를 돌려받으므로 freeze해 둔다.
    DEFAULT_ENV = { friction: 1, move_mult: 1, jump_mult: 1 }.freeze

    # LITERAL: 엔진의 mruby 4.0.0은 소수 리터럴 0.3, 0.35, 0.6, 0.7, 0.95를 마지막 비트가
    # 어긋난 값으로 읽는다. 나눗셈(35.0 / 100)은 정확한 값을 내므로 이 파일의 0.35와 0.6은
    # 나눗셈으로 적는다. Lua 구현과 같은 값이어야 골든 스크린샷이 같다.

    # 기후 하나의 상태.
    #   kind       :snow, :light, :hail, :flood
    #   spec       스테이지의 기후 표
    #   t          흐른 시간 (초)
    #   drops      우박 알 목록 (hail일 때만. 아니면 nil)
    #   next_drop  다음 알까지 남은 시간 (hail)
    #   water_y    지금 수면의 y (flood)
    #   surge      보스가 수위를 올려 둔 남은 시간 (flood, 없으면 nil)
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
          # 첫 알은 간격보다 일찍 떨어뜨린다 (방의 규칙을 적보다 먼저 보여 주기 위해서다).
          @next_drop = spec[:first] || 6.0 / 10     # 0.6 (위의 LITERAL 주석)
        elsif spec[:kind] == :flood
          @water_y = spec[:low]
        end
      end
    end

    # 기후 상태를 만든다. spec이 nil이면 기후가 없는 방이므로 nil을 돌려준다.
    def self.create(spec)
      return nil if spec.nil?
      State.new(spec)
    end

    # 우박 한 알을 추가한다. 예고 시간(warn) 동안 그림자만 표시되고, 그 뒤에 떨어진다.
    # 내부용이다. 밖에서는 nil 상태를 거르는 drop을 쓴다.
    def self.add_drop(s, x, floor_y)
      s.drops.push({
        x: x, y: nil, vy: 0,
        warn: s.spec[:warn] || 0.5,
        floor_y: floor_y,
      })
    end

    # 우박 한 알을 떨어뜨린다 (보스 패턴용). hail이 아닌 방에서는 아무것도 하지 않는다.
    def self.drop(s, x, floor_y)
      return if s.nil? || s.drops.nil?
      add_drop(s, x, floor_y)
    end

    # 수위를 잠시 최고 높이로 올린다 (보스의 2페이즈 패턴)
    def self.surge(s, seconds)
      return if s.nil? || s.kind != :flood
      s.surge = [s.surge || 0, seconds].max
    end

    # 한 프레임 갱신. ctx는 { x: 플레이어 x, floor_y: 발밑 지면 y, ceil_y: 천장 y, rng: 시드 난수 }
    def self.update(s, dt, ctx)
      return if s.nil?
      s.t = s.t + dt

      if s.kind == :hail
        s.next_drop = s.next_drop - dt
        if s.next_drop <= 0
          s.next_drop = s.spec[:interval] || 1.6
          n = s.spec[:count] || 1
          (1..n).each do |i|
            # 플레이어 주변 spread 픽셀 안에 떨어뜨린다 (머리 위만 노리면 피할 수 없다).
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
        # 보스가 수위를 올려 둔 동안은 최고 수위로 고정된다
        if (s.surge || 0) > 0
          s.surge = s.surge - dt
          s.water_y = s.spec[:high]
          return
        end
        # 수위는 사다리꼴로 움직인다 (멈춰 있는 구간이 있어야 플레이어가 판단할 시간이 생긴다).
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

    # 플레이어에게 적용할 환경. y를 주면 물에 잠겼는지까지 판정한다.
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

    # 이 x가 빛 안에 있는가. 빛기둥 기후가 아니면 항상 true다.
    def self.lit(s, x)
      return true if s.nil? || s.kind != :light
      period = s.spec[:period] || 4
      if (s.t % period) >= (s.spec[:lit] || 2.2)
        return false                     # 지금은 모든 빛기둥이 꺼져 있다
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

    # 떨어지는 중인 우박의 충돌 상자 목록. 예고(그림자) 단계의 우박은 들어가지 않는다.
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

    # hazards가 돌려준 배열의 index번째(0부터) 우박을 지운다 (맞은 알이 두 번 피해를 주지 않게).
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
