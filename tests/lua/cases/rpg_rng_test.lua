-- rpg_rng_test.lua : 시드 주입 난수(scripts/rpg/rng.lua) 검증.
-- 결정적 재생의 토대라 "같은 시드는 같은 수열"이 여기서 깨지면 5단계 이후의
-- 모든 시나리오 테스트가 흔들린다 (docs/plans/09-testing.md 4절).

local M = {}

function M.run(t)
	local Rng = require("scripts/rpg/rng")

	-- [1] 같은 시드는 같은 수열, 다른 시드는 다른 수열
	local a, b = Rng.new(42), Rng.new(42)
	local same = true
	for _ = 1, 50 do
		if a:next() ~= b:next() then same = false end
	end
	t.check(same, "같은 시드는 같은 수열 50개")

	local c = Rng.new(43)
	local d = Rng.new(43)
	local differs = false
	local a2 = Rng.new(42)
	for _ = 1, 50 do
		if a2:next() ~= c:next() then differs = true end
	end
	t.check(differs, "다른 시드는 다른 수열")
	t.check_eq(d:next(), Rng.new(43):next(), "새 인스턴스는 항상 같은 첫 값")

	-- [2] reseed로 수열을 되감는다
	local r = Rng.new(7)
	local first = { r:next(), r:next(), r:next() }
	r:reseed(7)
	t.check(r:next() == first[1] and r:next() == first[2] and r:next() == first[3],
		"reseed는 수열을 처음으로 되돌린다")
	t.check_eq(r.count, 3, "reseed 후 count가 다시 센다")

	-- [3] float은 [0, 1)
	local rf = Rng.new(99)
	local minV, maxV = 2, -1
	for _ = 1, 500 do
		local v = rf:float()
		if v < minV then minV = v end
		if v > maxV then maxV = v end
	end
	t.check(minV >= 0 and maxV < 1, "float은 [0,1) 범위",
		string.format("min=%.6f max=%.6f", minV, maxV))
	t.check(maxV > 0.9 and minV < 0.1, "float이 범위 전체에 퍼진다",
		string.format("min=%.3f max=%.3f", minV, maxV))

	-- [4] int은 양끝을 포함하고 범위를 넘지 않는다
	local ri = Rng.new(5)
	local seen = {}
	local outOfRange = false
	for _ = 1, 800 do
		local v = ri:int(1, 4)
		if v < 1 or v > 4 or math.type(v) ~= "integer" then outOfRange = true end
		seen[v] = true
	end
	t.check(not outOfRange, "int(1,4)는 1..4 정수만 준다")
	t.check(seen[1] and seen[2] and seen[3] and seen[4], "int(1,4)가 네 값을 모두 낸다")
	t.check_eq(Rng.new(3):int(9, 9), 9, "int(a, a)는 항상 a")

	local negOk = true
	local rn = Rng.new(11)
	for _ = 1, 200 do
		local v = rn:int(-3, -1)
		if v < -3 or v > -1 then negOk = false end
	end
	t.check(negOk, "음수 범위도 정상")
	t.check(pcall(function() Rng.new(1):int(5, 2) end) == false, "뒤집힌 범위는 오류")

	-- [5] pick과 chance
	local rp = Rng.new(1234)
	local list = { "up", "right", "down", "left" }
	local picked = {}
	for _ = 1, 400 do
		picked[rp:pick(list)] = true
	end
	t.check(picked.up and picked.right and picked.down and picked.left,
		"pick이 목록의 모든 항목을 낸다")
	t.check_eq(rp:pick({}), nil, "빈 목록 pick은 nil")
	t.check_eq(rp:pick(nil), nil, "nil 목록 pick은 nil")

	local rc = Rng.new(2)
	local hits = 0
	for _ = 1, 1000 do
		if rc:chance(0.25) then hits = hits + 1 end
	end
	t.check(hits > 180 and hits < 320, "chance(0.25)가 대략 1/4 (1000회)", tostring(hits))
	t.check_eq(Rng.new(8):chance(0), false, "chance(0)은 항상 false")
	t.check_eq(Rng.new(8):chance(1), true, "chance(1)은 항상 true")

	-- [6] 인스턴스끼리 상태를 공유하지 않는다 (전역 math.random을 안 쓰는 이유)
	local x, y = Rng.new(77), Rng.new(77)
	x:next(); x:next()          -- x만 두 번 더 소비
	t.check_eq(y:next(), Rng.new(77):next(), "다른 인스턴스의 소비가 영향을 주지 않는다")
end

return M
