-- 알데바란 — 몬스터 상태 기계 (docs/plans/aldebaran-2-combat.md 4절)
--
-- 원안(기획서 6절)의 세 상태: 기본(순찰) → 추적 → 공격. 판정은 거리다.
-- 엔진에 닿지 않는 순수 모듈이며, 종별 차이는 코드가 아니라 표(def)다
-- (scripts/games/aldebaran/stage.lua).
--
--   local Monster = require("scripts/games/aldebaran/monster")
--   local m = Monster.new(def, { x = 480, y = 352, minX = 420, maxX = 560 })
--   Monster.update(m, dt, probe, playerX, playerY)
--
-- def가 들고 있는 것:
--   hp, atk, def, exp, gold          능력치와 보상
--   walkSpeed, chaseSpeed            이동 속도 (px/초)
--   alertRange, attackRange          경계와 공격 거리 (수평 px)
--   windup, active, recover          공격의 선딜레이, 판정, 후딜레이 (초)
--   halfW, bodyH                     몸통 상자
--   special                          "sting" | "charge" | "throw" | nil
--   chargeSpeed, chargeTime          돌격형 전용
--   regen                            비전투 회복 (원안: 4초마다 최대 HP의 1/20)
--   cols, frames                     시트 열 수와 상태별 칸 번호
--
-- 씬이 하는 일: strike 상태의 공격 상자와 플레이어의 겹침 판정, 데미지 계산,
-- Monster.hurt 호출. 여기는 움직임과 상태 전이만 안다.

local M = {}

M.GRAVITY = 980
M.MAX_FALL = 480
M.HOP_V = -250              -- 추적 중 한 타일 턱을 뛰어넘는 힘 (원안 6.2.3절)
M.HURT_TIME = 0.25
M.DYING_TIME = 0.5
M.REGEN_TICK = 4

function M.new(def, opts)
	return {
		def = def,
		x = opts.x, y = opts.y, vx = 0, vy = 0,
		dir = opts.dir or -1,
		onGround = false,
		minX = opts.minX or (opts.x - 64), maxX = opts.maxX or (opts.x + 64),
		state = "patrol",
		hp = def.hp,
		timer = 0,
		animTime = 0,
		chargeUsed = false,
		regenTimer = 0,
		strikeHit = false,       -- 이번 공격의 판정을 이미 썼는가 (씬이 세운다)
		dead = false, fade = 0,
	}
end

-- ---- 이동 (플레이어와 같은 방식의 타일 충돌) --------------------------------

local function moveX(m, dx, probe)
	if dx == 0 then return false end
	local sign = dx > 0 and 1 or -1
	local nx = m.x + dx
	local edge = nx + sign * m.def.halfW
	for _, oy in ipairs({ -1, -math.floor(m.def.bodyH / 2), -m.def.bodyH + 1 }) do
		if probe(edge, m.y + oy) then
			local tile = math.floor(edge / 16)
			if sign > 0 then
				nx = tile * 16 - m.def.halfW - 0.01
			else
				nx = (tile + 1) * 16 + m.def.halfW + 0.01
			end
			m.x = nx
			return true          -- 벽에 막혔다
		end
	end
	m.x = nx
	return false
end

local function standing(m, probe, y)
	return probe(m.x - m.def.halfW + 1, y) or probe(m.x + m.def.halfW - 1, y)
end

local function moveY(m, dy, probe)
	local ny = m.y + dy
	if dy >= 0 then
		if standing(m, probe, ny) then
			m.y = math.floor(ny / 16) * 16
			m.vy = 0
			m.onGround = true
			return
		end
		m.y = ny
		if not standing(m, probe, m.y + 1) then m.onGround = false end
	else
		m.y = ny
		m.onGround = false
	end
end

--- 진행 방향 바로 앞이 벼랑인가 (순찰이 스스로 떨어지지 않게)
local function cliffAhead(m, probe)
	local ahead = m.x + m.dir * (m.def.halfW + 3)
	return not probe(ahead, m.y + 4)
end

local function wallAhead(m, probe)
	local ahead = m.x + m.dir * (m.def.halfW + 2)
	return probe(ahead, m.y - math.floor(m.def.bodyH / 2))
end

-- ---- 상태 기계 -------------------------------------------------------------

function M.update(m, dt, probe, px, py)
	if m.dead then return end
	m.animTime = m.animTime + dt

	if m.state == "dying" then
		m.fade = m.fade + dt
		if m.fade >= M.DYING_TIME then m.dead = true end
		return
	end

	local dx = px - m.x
	local dist = math.abs(dx)
	local near = dist <= m.def.alertRange and math.abs(py - m.y) <= 48

	m.timer = math.max(0, m.timer - dt)
	m.vx = 0

	if m.state == "hurt" then
		m.vx = m.dir * -60          -- 밀려난다 (바라보는 반대쪽으로)
		if m.timer <= 0 then m.state = "chase" end

	elseif m.state == "patrol" then
		m.vx = m.dir * m.def.walkSpeed
		-- 비전투 회복 (원안: 전투 중이 아닌 경우 4초마다 최대 HP/20)
		if m.def.regen then
			m.regenTimer = m.regenTimer + dt
			if m.regenTimer >= M.REGEN_TICK then
				m.regenTimer = 0
				m.hp = math.min(m.def.hp, m.hp + math.max(1, math.floor(m.def.hp / 20)))
			end
		end
		if near then
			if m.def.special == "charge" and not m.chargeUsed then
				m.state = "charge"
				m.timer = m.def.chargeTime
				m.dir = dx > 0 and 1 or -1
			else
				m.state = "chase"
			end
		end

	elseif m.state == "charge" then
		-- 돌격 (원안: 첫 발동 뒤로는 다시 쓰지 않는다). 벽이나 시간에서 끝난다.
		m.vx = m.dir * m.def.chargeSpeed
		if m.timer <= 0 then
			-- 검은 늑대는 돌격을 다시 쓴다 (chargeRepeat). 늑대는 한 번뿐이다.
			m.chargeUsed = not m.def.chargeRepeat
			m.state = "chase"
		end

	elseif m.state == "chase" then
		-- 투척형(짐도둑): 가까우면 달아나고, 거리가 벌어지면 돌을 던진다.
		-- 구간 끝에 몰리면 더 물러나지 않는다 (기획서 6절).
		if m.def.special == "throw" then
			local away = dx > 0 and -1 or 1
			local cornered = (away > 0 and m.x >= m.maxX - 4)
				or (away < 0 and m.x <= m.minX + 4)
			if dist < m.def.fleeRange and not cornered then
				m.dir = away
				m.vx = away * m.def.chaseSpeed
			elseif dist <= m.def.attackRange and m.onGround then
				m.state = "windup"
				m.timer = m.def.windup
				m.dir = dx > 0 and 1 or -1
			else
				m.dir = dx > 0 and 1 or -1
				m.vx = m.dir * m.def.walkSpeed
			end
		elseif dist > m.def.alertRange * 1.5 then
			m.state = "patrol"
			m.dir = dx > 0 and 1 or -1
		elseif dist <= m.def.attackRange and m.onGround then
			m.state = "windup"
			m.timer = m.def.windup
			m.dir = dx > 0 and 1 or -1
		else
			m.dir = dx > 0 and 1 or -1
			m.vx = m.dir * m.def.chaseSpeed
		end

	elseif m.state == "windup" then
		m.dir = dx > 0 and 1 or -1      -- 움츠리는 동안 상대를 계속 본다
		if m.timer <= 0 then
			m.state = "strike"
			m.timer = m.def.active
			m.strikeHit = false
			m.thrown = false             -- 투척형: 씬이 이 판을 보고 돌을 만든다
		end

	elseif m.state == "strike" then
		if m.timer <= 0 then
			m.state = "recover"
			m.timer = m.def.recover
		end

	elseif m.state == "recover" then
		if m.timer <= 0 then m.state = "chase" end
	end

	-- 이동과 중력
	local blocked = moveX(m, m.vx * dt, probe)
	if blocked then
		if m.state == "patrol" then
			m.dir = -m.dir
		elseif m.state == "chase" and m.onGround then
			m.vy = M.HOP_V              -- 추적 중에는 턱을 뛰어넘는다
		elseif m.state == "charge" then
			m.timer = 0                 -- 벽에 부딪히면 돌격이 끝난다
		end
	end
	if m.state == "patrol" then
		if cliffAhead(m, probe) and m.onGround then
			m.dir = -m.dir              -- 순찰은 벼랑에서 돌아선다
		end
		if m.x <= m.minX then m.dir = 1 end
		if m.x >= m.maxX then m.dir = -1 end
	end
	if m.def.special == "throw" then
		-- 투척형은 어느 상태에서든 제 구간(공터)을 벗어나지 않는다
		m.x = math.max(m.minX, math.min(m.maxX, m.x))
	end
	m.vy = math.min(m.vy + M.GRAVITY * dt, M.MAX_FALL)
	moveY(m, m.vy * dt, probe)
end

-- ---- 씬이 쓰는 조회 ---------------------------------------------------------

--- 몸통 상자 (x0, y0, x1, y1)
function M.body(m)
	return m.x - m.def.halfW, m.y - m.def.bodyH, m.x + m.def.halfW, m.y
end

--- 공격 판정 상자. strike(또는 돌격 중)일 때만 있다.
-- 투척형은 몸이 아니라 돌(씬의 투사체)이 아프므로 상자가 없다.
function M.attackBox(m)
	if m.def.special == "throw" then return nil end
	if m.state == "strike" then
		local reach = m.def.attackRange + 6
		if m.dir > 0 then
			return m.x, m.y - m.def.bodyH, m.x + reach, m.y
		else
			return m.x - reach, m.y - m.def.bodyH, m.x, m.y
		end
	elseif m.state == "charge" then
		return M.body(m)
	end
	return nil
end

--- 맞았다. 죽으면 true를 돌려준다 (보상은 씬이 준다).
function M.hurt(m, dmg, fromDir)
	if m.dead or m.state == "dying" then return false end
	m.hp = m.hp - dmg
	-- 보스는 절반에서 두 번째 판으로 넘어간다 (기획서 4.3.4절)
	if m.def.special == "throw" and not m.phase2 and m.hp <= m.def.hp / 2 then
		m.phase2 = true
	end
	m.regenTimer = 0
	if m.hp <= 0 then
		m.state = "dying"
		m.fade = 0
		return true
	end
	m.state = "hurt"
	m.timer = M.HURT_TIME
	m.dir = fromDir > 0 and -1 or 1     -- 때린 쪽을 돌아본다
	return false
end

--- 시트 칸 (def.cols 열, 위 오른쪽 아래 왼쪽 두 줄)
function M.frame(m)
	local f = m.def.frames
	local col
	if m.state == "dying" or m.state == "hurt" then
		col = f.hurt
	elseif m.state == "windup" or m.state == "strike" then
		col = f.attack
	elseif m.state == "charge" then
		col = f.charge or f.attack
	else
		col = f.walk[1 + math.floor(m.animTime * 6) % #f.walk]
	end
	return (m.dir < 0 and m.def.cols or 0) + col
end

return M
