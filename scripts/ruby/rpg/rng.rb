# rng.rb : 시드를 주입하는 결정적 난수 (docs/plans/09-testing.md 4절). scripts/lua/rpg/rng.lua 의 Ruby 판.
#
# 게임 로직에서 rand 를 직접 쓰지 않는 이유는 하나다. 전역 난수는 누가 언제 몇 번
# 뽑았는지에 따라 수열이 달라져서, 시나리오 재생이 같은 결과를 내지 못한다. 이
# 클래스는 인스턴스마다 자기 상태를 들고 있으므로 시드만 같으면 항상 같은 수열이 나온다.
#
# 사용:
#   r = Rpg::Rng.new(1234)
#   r.int(1, 4)      # 1..4 정수 (양끝 포함)
#   r.float          # [0, 1)
#   r.pick(list)     # 목록에서 하나
#   r.chance(0.25)   # 25% 확률로 true
#
# 알고리즘은 32비트 선형 합동 생성기(glibc 계수)다. Lua 판과 같은 수열을 낸다.
# 낮은 비트의 주기가 짧으므로 정수 범위는 나머지가 아니라 상위 비트(float)로 만든다.

module Rpg
  class Rng
    MOD = 2147483648 # 2^31
    MUL = 1103515245
    INC = 12345

    attr_reader :state, :count

    # 새 난수 생성기. seed 를 생략하면 0 (완전히 고정된 수열)
    def initialize(seed = 0)
      reseed(seed)
    end

    def reseed(seed)
      raise ArgumentError, "rng: 시드는 숫자여야 한다" unless seed.is_a?(Numeric)
      @state = seed.floor % MOD
      @count = 0 # 뽑은 횟수 (테스트에서 소비량을 볼 때 쓴다)
      self
    end

    # 다음 원시 난수 (0 .. 2^31-1)
    def next
      @state = (MUL * @state + INC) % MOD
      @count += 1
      @state
    end

    # [0, 1) 실수
    def float
      self.next.to_f / MOD
    end

    # a..b 정수, 양끝 포함
    def int(a, b)
      raise ArgumentError, "rng: int(a, b)는 b >= a 여야 한다" unless b >= a
      n = b - a + 1
      v = a + (float * n).floor
      v = b if v > b # 부동소수 경계 보호
      v
    end

    # 목록에서 하나 (빈 목록이면 nil)
    def pick(list)
      return nil if list.nil? || list.empty?
      list[int(0, list.size - 1)]
    end

    # p 확률로 true (p 는 0..1)
    def chance(p)
      float < p
    end
  end
end
