# rpg_rng_test.rb : 시드 주입 난수(scripts/ruby/rpg/rng.rb) 검증. rpg_rng_test.lua 의 Ruby 판.
# 결정적 재생의 토대라 "같은 시드는 같은 수열"이 여기서 깨지면 시나리오 테스트가 흔들린다.

require "scripts/ruby/rpg/rng"

T.run_case("rpg_rng") do |t|
  rng = Rpg::Rng

  # [1] 같은 시드는 같은 수열, 다른 시드는 다른 수열
  a = rng.new(42)
  b = rng.new(42)
  same = true
  50.times { same = false if a.next != b.next }
  t.check(same, "같은 시드는 같은 수열 50개")

  c = rng.new(43)
  d = rng.new(43)
  differs = false
  a2 = rng.new(42)
  50.times { differs = true if a2.next != c.next }
  t.check(differs, "다른 시드는 다른 수열")
  t.check_eq(d.next, rng.new(43).next, "새 인스턴스는 항상 같은 첫 값")

  # [2] reseed 로 수열을 되감는다
  r = rng.new(7)
  first = [r.next, r.next, r.next]
  r.reseed(7)
  t.check(r.next == first[0] && r.next == first[1] && r.next == first[2],
          "reseed는 수열을 처음으로 되돌린다")
  t.check_eq(r.count, 3, "reseed 후 count가 다시 센다")

  # [3] float 은 [0, 1)
  rf = rng.new(99)
  min_v = 2.0
  max_v = -1.0
  500.times do
    v = rf.float
    min_v = v if v < min_v
    max_v = v if v > max_v
  end
  t.check(min_v >= 0 && max_v < 1, "float은 [0,1) 범위", format("min=%.6f max=%.6f", min_v, max_v))
  t.check(max_v > 0.9 && min_v < 0.1, "float이 범위 전체에 퍼진다", format("min=%.3f max=%.3f", min_v, max_v))

  # [4] int 은 양끝을 포함하고 범위를 넘지 않는다
  ri = rng.new(5)
  seen = {}
  out_of_range = false
  800.times do
    v = ri.int(1, 4)
    out_of_range = true if v < 1 || v > 4 || !v.is_a?(Integer)
    seen[v] = true
  end
  t.check(!out_of_range, "int(1,4)는 1..4 정수만 준다")
  t.check(seen[1] && seen[2] && seen[3] && seen[4], "int(1,4)가 네 값을 모두 낸다")
  t.check_eq(rng.new(3).int(9, 9), 9, "int(a, a)는 항상 a")

  neg_ok = true
  rn = rng.new(11)
  200.times do
    v = rn.int(-3, -1)
    neg_ok = false if v < -3 || v > -1
  end
  t.check(neg_ok, "음수 범위도 정상")
  flipped = false
  begin
    rng.new(1).int(5, 2)
  rescue ArgumentError
    flipped = true
  end
  t.check(flipped, "뒤집힌 범위는 오류")

  # [5] pick 과 chance
  rp = rng.new(1234)
  list = [:up, :right, :down, :left]
  picked = {}
  400.times { picked[rp.pick(list)] = true }
  t.check(picked[:up] && picked[:right] && picked[:down] && picked[:left], "pick이 목록의 모든 항목을 낸다")
  t.check_eq(rp.pick([]), nil, "빈 목록 pick은 nil")
  t.check_eq(rp.pick(nil), nil, "nil 목록 pick은 nil")

  rc = rng.new(2)
  hits = 0
  1000.times { hits += 1 if rc.chance(0.25) }
  t.check(hits > 180 && hits < 320, "chance(0.25)가 대략 1/4 (1000회)", hits.to_s)
  t.check_eq(rng.new(8).chance(0), false, "chance(0)은 항상 false")
  t.check_eq(rng.new(8).chance(1), true, "chance(1)은 항상 true")

  # [6] 인스턴스끼리 상태를 공유하지 않는다
  x = rng.new(77)
  y = rng.new(77)
  x.next
  x.next # x 만 두 번 더 소비
  t.check_eq(y.next, rng.new(77).next, "다른 인스턴스의 소비가 영향을 주지 않는다")

  # [7] Lua 판과 같은 수열 (glibc LCG: 시드 1의 첫 값 1103527590)
  t.check_eq(rng.new(1).next, 1103527590, "Lua 판과 같은 수열 (시드 1의 첫 값)")
end
