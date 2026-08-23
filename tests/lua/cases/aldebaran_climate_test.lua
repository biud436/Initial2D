-- aldebaran_climate_test.lua : 기후의 단위 테스트
-- (docs/plans/aldebaran-7-tomb.md 4절)
--
-- 기후는 연출이 아니라 규칙이다. 그러니 규칙으로 검사한다 — 눈은 멈추는 것을
-- 늦추는가, 빛은 언제 켜지는가, 우박은 예고 뒤에 떨어지는가, 물은 잠기게
-- 하는가. 그림은 골든이 본다.

local Climate = require("scripts/games/aldebaran/climate")
local Stages = require("scripts/games/aldebaran/stages/init")

local M = {}

local DT = 1 / 60

local function step(c, seconds, ctx)
	for _ = 1, math.floor(seconds / DT) do
		Climate.update(c, DT, ctx or { x = 0, floorY = 400, ceilY = 100 })
	end
end

function M.run(t)
	-- [A] 기후가 없는 방: 무엇을 물어도 기본값이다
	do
		t.check_eq(Climate.new(nil), nil, "표가 없으면 기후도 없다")
		local env = Climate.env(nil, 300)
		t.check_eq(env.friction, 1, "마찰은 기본값")
		t.check_eq(env.moveMult, 1, "이동 배율은 기본값")
		t.check_eq(env.jumpMult, 1, "점프 배율은 기본값")
		t.check_eq(Climate.lit(nil, 100), true, "빛기둥이 없으면 늘 벨 수 있다")
		t.check_eq(Climate.lightOn(nil), false, "켜져 있지 않다")
		t.check_eq(Climate.waterY(nil), nil, "수면이 없다")
		t.check_eq(#Climate.hazards(nil), 0, "위험이 없다")
	end

	-- [B] 눈: 마찰만 낮춘다. 이동과 점프는 그대로다
	do
		local c = Climate.new{ kind = "snow", friction = 0.34 }
		local env = Climate.env(c, 300)
		t.check_eq(env.friction, 0.34, "지면 마찰이 준다")
		t.check_eq(env.moveMult, 1, "걷는 속도는 그대로")
		t.check_eq(env.jumpMult, 1, "점프 높이도 그대로")
		t.check_eq(Climate.lit(c, 0), true, "눈은 벨 수 있고 없고와 무관하다")
	end

	-- [C] 빛기둥: 주기의 앞부분만 켜지고, 켜진 동안에도 기둥 안만 벤다
	do
		local c = Climate.new{ kind = "light", period = 4.0, lit = 2.2,
			pillars = { 100, 300 }, halfW = 40 }
		t.check_eq(Climate.lightOn(c), true, "처음에는 켜져 있다")
		t.check_eq(Climate.lit(c, 100), true, "기둥 한가운데는 빛 안")
		t.check_eq(Climate.lit(c, 139), true, "기둥의 가장자리도 빛 안")
		t.check_eq(Climate.lit(c, 200), false, "기둥 사이는 그늘")
		t.check_eq(Climate.lit(c, 300), true, "두 번째 기둥도 빛 안")

		step(c, 2.5)                     -- 켜진 구간(2.2초)을 지나면
		t.check_eq(Climate.lightOn(c), false, "2.2초가 지나면 꺼진다")
		t.check_eq(Climate.lit(c, 100), false, "꺼져 있으면 기둥 안도 그늘")

		step(c, 2.0)                     -- 주기 4.0초를 돌아 다시 켜진다
		t.check_eq(Climate.lightOn(c), true, "주기가 돌면 다시 켜진다")
	end

	-- [D] 우박: 예고가 먼저다. 예고 중에는 아프지 않다
	do
		local c = Climate.new{ kind = "hail", interval = 1.6, first = 0.5,
			warn = 0.5, damage = 9, speed = 320, halfW = 5, count = 1 }
		local ctx = { x = 200, floorY = 400, ceilY = 100 }

		t.check_eq(#c.drops, 0, "처음에는 떨어지는 것이 없다")
		step(c, 0.55, ctx)
		t.check_eq(#c.drops, 1, "첫 알이 당겨 떨어진다 (방을 배우게)")
		t.check_eq(#Climate.hazards(c), 0, "예고 중에는 아직 아프지 않다")
		t.check(c.drops[1].y == nil, "예고 중에는 위치가 없다 (그림자만 있다)")

		step(c, 0.55, ctx)
		t.check(c.drops[1].y ~= nil, "예고가 끝나면 떨어지기 시작한다")
		local hz = Climate.hazards(c)
		t.check_eq(#hz, 1, "이제 아프다")
		t.check_eq(hz[1].damage, 9, "데미지는 표에서 온다")
		t.check(hz[1].x1 - hz[1].x0 == 10, "상자는 halfW의 두 배")

		-- 맞으면 그 알은 사라진다 (한 알이 두 번 아프면 안 된다)
		Climate.consume(c, 1)
		t.check_eq(#Climate.hazards(c), 0, "맞은 알은 지워진다")

		-- 바닥에 닿으면 스스로 사라진다
		local c2 = Climate.new{ kind = "hail", interval = 1e9, first = 0.1,
			warn = 0.1, speed = 400 }
		step(c2, 0.25, ctx)
		t.check_eq(#c2.drops, 1, "한 알이 떨어지고 있다")
		step(c2, 1.5, ctx)
		t.check_eq(#c2.drops, 0, "바닥에 닿으면 사라진다")

		-- 보스가 밖에서 떨구는 길
		local c3 = Climate.new{ kind = "hail", interval = 1e9, first = 1e9, warn = 0.2 }
		Climate.drop(c3, 500, 400)
		t.check_eq(#c3.drops, 1, "밖에서도 한 알을 떨굴 수 있다 (보스의 패턴)")
	end

	-- [E] 홍수: 수위가 사다리꼴로 오르내리고, 잠기면 느려진다
	do
		local c = Climate.new{ kind = "flood", period = 9.0, low = 400, high = 336,
			moveMult = 0.55, jumpMult = 0.72 }
		t.check_eq(c.waterY, 400, "처음에는 낮다")
		t.check_eq(Climate.env(c, 380).moveMult, 1, "수면 위에서는 그대로")
		t.check_eq(Climate.env(c, 420).moveMult, 0.55, "수면 아래면 느려진다")
		t.check_eq(Climate.env(c, 420).jumpMult, 0.72, "수면 아래면 낮게 뛴다")

		step(c, 5.0)                     -- 주기의 절반쯤이면 최고 수위다
		t.check_eq(c.waterY, 336, "수위가 올라 있다")
		t.check_eq(Climate.env(c, 380).moveMult, 0.55, "아까 마른 자리가 잠겼다")
		t.check_eq(Climate.waterY(c), 336, "수면을 물어볼 수 있다")

		-- 머무는 구간이 있어야 판단할 시간이 있다 (사인이 아니라 사다리꼴이다)
		local c2 = Climate.new{ kind = "flood", period = 9.0, low = 400, high = 336 }
		step(c2, 1.0)
		t.check_eq(c2.waterY, 400, "처음 3분의 1은 낮은 채로 머문다")
		step(c2, 1.5)
		t.check_eq(c2.waterY, 400, "아직 머문다")

		-- 보스가 밀어 올리면 그동안은 최고 수위로 고정된다
		local c3 = Climate.new{ kind = "flood", period = 9.0, low = 400, high = 336 }
		Climate.surge(c3, 1.0)
		step(c3, 0.5)
		t.check_eq(c3.waterY, 336, "보스가 밀어 올린 동안은 최고 수위")
		step(c3, 1.0)
		t.check_eq(c3.waterY, 400, "밀어 올린 시간이 끝나면 제 주기로 돌아온다")
	end

	-- [F] 스테이지의 표가 실제로 이 모듈이 아는 종류인가
	do
		local tomb = Stages.get("tomb")
		t.check(tomb ~= nil, "1-2가 있다")
		local known = { snow = true, light = true, hail = true, flood = true }
		local count = 0
		for name, def in pairs(tomb.CLIMATE or {}) do
			count = count + 1
			t.check(known[def.kind], name .. "의 기후 '" .. tostring(def.kind) .. "'을 안다")
			t.check(Climate.new(def) ~= nil, name .. "의 기후를 만들 수 있다")
		end
		t.check_eq(count, 4, "기후가 걸린 방은 넷이다 (입구는 없다)")
		t.check_eq(tomb.CLIMATE.chest, nil, "가슴부 입구에는 기후가 없다 (배우는 방)")

		-- 구간 이름과 기후 표의 열쇠가 어긋나면 기후가 조용히 사라진다
		for _, sec in ipairs(tomb.SECTIONS) do
			if sec.name ~= "chest" then
				t.check(tomb.CLIMATE[sec.name] ~= nil,
					"구간 " .. sec.name .. "에 기후가 있다")
			end
		end
	end

	-- [G] 1-1에는 기후가 없다 (A7이 숲을 건드리지 않았다는 회귀 검사)
	do
		local forest = Stages.get("forest")
		t.check_eq(forest.CLIMATE, nil, "검은 안개의 숲에는 기후 표가 없다")
	end
end

return M
