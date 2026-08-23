-- 알데바란 — 기후 (docs/plans/aldebaran-7-tomb.md 4절)
--
-- 원안 4.2.2.4절 표 19: **황제의 무덤의 온도와 습도는 파괴의 신 아포피스의 힘에
-- 의해 좌우된다. 어떤 방에는 눈이 오고 어떤 복도에는 우박 또는 비가 내리고
-- 폭풍우가 몰아치고, 홍수가 발생한다.**
--
-- 그것을 연출이 아니라 **조작을 바꾸는 규칙**으로 만든 것이 이 모듈이다. 방이
-- 다르다는 것이 눈이 아니라 손에 남아야 한다.
--
-- 엔진에 닿지 않는 순수 모듈이다. 씬은 상태를 만들어 흘리고, 그 결과를 읽어
-- 플레이어의 환경과 우박의 판정에 쓴다. 수치는 전부 스테이지의 표에 있다
-- (stages/tomb.lua의 M.CLIMATE).
--
--   local Climate = require("scripts/games/aldebaran/climate")
--   local c = Climate.new(Stage.CLIMATE["moon"])
--   Climate.update(c, dt, { x = player.x, floorY = 400, rng = rng })
--   player.env = Climate.env(c)
--
-- 종류 넷:
--   snow   지면 마찰이 준다. 멈추려면 미리 놓아야 한다
--   light  빛기둥이 켜지고 꺼진다. 그늘의 영혼은 실체가 아니라 베이지 않는다
--   hail   천장에서 우박이 떨어진다. 떨어질 자리에 그림자가 먼저 뜬다
--   flood  수위가 오르내린다. 잠기면 느려지고 낮게 뛴다

local M = {}

M.DEFAULT_ENV = { friction = 1, moveMult = 1, jumpMult = 1 }

--- 기후 상태를 만든다. def가 nil이면 기후가 없는 방이다 (nil을 돌려준다).
function M.new(def)
	if def == nil then return nil end
	local s = { kind = def.kind, def = def, t = 0 }
	if def.kind == "hail" then
		s.drops = {}
		-- 첫 알은 당겨 떨군다. 방에 들어서고 1.6초를 아무 일도 없이 걷게 하면
		-- 그 방의 규칙을 배우기 전에 적을 먼저 만난다.
		s.nextDrop = def.first or 0.6
	elseif def.kind == "flood" then
		s.waterY = def.low
	end
	return s
end

--- 우박 한 알을 떨군다. 먼저 그림자만 뜨고, 예고 시간이 지나야 떨어진다.
local function addDrop(s, x, floorY)
	s.drops[#s.drops + 1] = {
		x = x, y = nil, vy = 0,
		warn = s.def.warn or 0.5,
		floorY = floorY,
	}
end

--- 밖에서 우박 한 알을 떨군다 (보스의 패턴이 쓴다. 기후가 hail일 필요는 없다).
function M.drop(s, x, floorY)
	if s == nil or s.drops == nil then return end
	addDrop(s, x, floorY)
end

--- 수위를 잠시 최고로 밀어 올린다 (보스의 2페이즈 패턴)
function M.surge(s, seconds)
	if s == nil or s.kind ~= "flood" then return end
	s.surge = math.max(s.surge or 0, seconds)
end

--- 한 프레임. ctx는 { x = 플레이어 x, floorY = 발밑 지면 y, rng = 시드 난수 }
function M.update(s, dt, ctx)
	if s == nil then return end
	s.t = s.t + dt

	if s.kind == "hail" then
		s.nextDrop = s.nextDrop - dt
		if s.nextDrop <= 0 then
			s.nextDrop = s.def.interval or 1.6
			local n = s.def.count or 1
			for i = 1, n do
				-- 플레이어 언저리에 떨군다. 정확히 머리 위만 노리면 피할 수
				-- 없고, 아무 데나 떨구면 볼 이유가 없다.
				local spread = 96
				local r = (ctx.rng ~= nil) and ctx.rng:float() or ((i - 1) / n)
				addDrop(s, ctx.x + (r * 2 - 1) * spread, ctx.floorY)
			end
		end
		for i = #s.drops, 1, -1 do
			local dp = s.drops[i]
			if dp.warn > 0 then
				dp.warn = dp.warn - dt
				if dp.warn <= 0 then
					dp.y = (ctx.ceilY or 0) - 8      -- 천장에서 떨어지기 시작
					dp.vy = s.def.speed or 320
				end
			else
				dp.y = dp.y + dp.vy * dt
				if dp.y > dp.floorY + 8 then
					table.remove(s.drops, i)
				end
			end
		end

	elseif s.kind == "flood" then
		-- 보스가 밀어 올린 동안은 최고 수위로 고정된다
		if (s.surge or 0) > 0 then
			s.surge = s.surge - dt
			s.waterY = s.def.high
			return
		end
		-- 수위는 사인이 아니라 사다리꼴로 움직인다. 오르내리는 동안이 아니라
		-- **멈춰 있는 동안**에 판단할 시간이 있어야 하기 때문이다.
		local p = s.def.period or 9
		local phase = (s.t % p) / p
		local lo, hi = s.def.low, s.def.high
		if phase < 0.35 then
			s.waterY = lo
		elseif phase < 0.5 then
			s.waterY = lo + (hi - lo) * ((phase - 0.35) / 0.15)
		elseif phase < 0.85 then
			s.waterY = hi
		else
			s.waterY = hi + (lo - hi) * ((phase - 0.85) / 0.15)
		end
	end
end

--- 플레이어에게 씌울 환경. y를 주면 물에 잠겼는지까지 본다.
function M.env(s, y)
	if s == nil then return M.DEFAULT_ENV end
	if s.kind == "snow" then
		return { friction = s.def.friction or 0.34, moveMult = 1, jumpMult = 1 }
	elseif s.kind == "flood" then
		if y ~= nil and y > s.waterY then
			return { friction = 1,
				moveMult = s.def.moveMult or 0.55,
				jumpMult = s.def.jumpMult or 0.72 }
		end
	end
	return M.DEFAULT_ENV
end

--- 이 x가 빛 안인가 (빛기둥 기후에서만 뜻이 있다).
-- 빛기둥이 아닌 기후에서는 늘 참이다 — "빛이 없으면 다 벨 수 있다".
function M.lit(s, x)
	if s == nil or s.kind ~= "light" then return true end
	local period = s.def.period or 4
	if (s.t % period) >= (s.def.lit or 2.2) then
		return false                     -- 지금은 다 꺼져 있다
	end
	for _, px in ipairs(s.def.pillars or {}) do
		if math.abs(x - px) <= (s.def.halfW or 44) then return true end
	end
	return false
end

--- 빛기둥이 켜져 있는가 (그리기용)
function M.lightOn(s)
	if s == nil or s.kind ~= "light" then return false end
	return (s.t % (s.def.period or 4)) < (s.def.lit or 2.2)
end

--- 지금 수면의 y (홍수가 아니면 nil)
function M.waterY(s)
	if s == nil or s.kind ~= "flood" then return nil end
	return s.waterY
end

--- 떨어지고 있는 우박의 상자들. 씬이 플레이어와 겹치는지 본다.
-- 예고(그림자)만 뜬 것은 아직 아프지 않다.
function M.hazards(s)
	if s == nil or s.kind ~= "hail" then return {} end
	local out = {}
	local r = s.def.halfW or 5
	for _, dp in ipairs(s.drops) do
		if dp.warn <= 0 and dp.y ~= nil then
			out[#out + 1] = { x0 = dp.x - r, y0 = dp.y - r,
				x1 = dp.x + r, y1 = dp.y + r, damage = s.def.damage or 9 }
		end
	end
	return out
end

--- 우박이 맞았다. 같은 알이 두 번 아프지 않게 지운다.
function M.consume(s, index)
	if s == nil or s.kind ~= "hail" then return end
	local n = 0
	for i, dp in ipairs(s.drops) do
		if dp.warn <= 0 and dp.y ~= nil then
			n = n + 1
			if n == index then
				table.remove(s.drops, i)
				return
			end
		end
	end
end

return M
