-- 알데바란 — 카르토의 이동 물리 (docs/plans/aldebaran-1-core.md 6절)
--
-- 엔진에 닿지 않는 순수 모듈이다. 씬이 매 프레임 입력과 충돌 조회 함수를 넘긴다.
--
--   local Player = require("scripts/games/aldebaran/player")
--   local p = Player.new(56, 384)
--   Player.update(p, input, dt, probe)
--
-- input: { left, right (누르고 있음), leftEdge, rightEdge, jumpEdge (이번 프레임) }
-- probe(px, py) -> boolean : 그 픽셀이 막혀 있는가 (씬이 Tilemap.IsPassable을 감싼다)
-- 좌표 (x, y)는 발 가운데다. 몸통 상자는 x-6..x+6, y-20..y-1 (기획서 4.1절의 12x20).
--
-- 단위는 픽셀/초, dt는 초. 프레임레이트에 독립적이다 (flappy와 같은 방식).

local P = {}

P.WALK_SPEED = 90
P.DASH_SPEED = 190
P.DASH_TIME = 0.28          -- 대쉬 지속
P.TAP_WINDOW = 0.25         -- 더블탭 판정 창
P.GRAVITY = 980
P.JUMP_V = -330             -- 최고점 약 53px (이산 적분 기준) — 3타일 턱을 넘는다
P.AIR_JUMP_V = -270         -- 2단 점프. 합쳐 약 87px — 5타일까지
P.MAX_FALL = 480
P.HALF_W = 6                -- 몸통 절반 폭
P.BODY_H = 20               -- 몸통 높이
P.RUN_GRACE = 0.18          -- 달리기 기억: 손을 뗀 직후의 점프가 앞으로 나아가는 유예

function P.new(x, y)
	return {
		x = x, y = y, vx = 0, vy = 0,
		facing = 1,             -- 1 오른쪽, -1 왼쪽
		onGround = false,
		airJumps = 1,           -- 공중에서 남은 점프 (땅에 닿으면 1로)
		dashTimer = 0, dashDir = 0,
		tapTimer = 0, tapDir = 0,
		runVx = 0, runTimer = 0,   -- 직전 달리기 기억 (P.RUN_GRACE 참고)
		animTime = 0,
		-- 이번 프레임에 일어난 일 (씬이 효과음과 연출에 쓴다)
		jumped = false, landed = false, dashed = false,
	}
end

--- 발 밑 두 점 중 하나라도 막혀 있는가
local function standing(self, probe, y)
	return probe(self.x - P.HALF_W + 1, y) or probe(self.x + P.HALF_W - 1, y)
end

--- 수평 이동과 벽 충돌. 한 프레임 이동량이 타일(16px)보다 작아 터널링이 없다.
function P.moveX(self, dx, probe)
	if dx == 0 then return end
	local sign = dx > 0 and 1 or -1
	local nx = self.x + dx
	local edge = nx + sign * P.HALF_W
	for _, oy in ipairs({ -1, -10, -P.BODY_H + 1 }) do
		if probe(edge, self.y + oy) then
			local tile = math.floor(edge / 16)
			if sign > 0 then
				nx = tile * 16 - P.HALF_W - 0.01
			else
				nx = (tile + 1) * 16 + P.HALF_W + 0.01
			end
			self.vx = 0
			self.dashTimer = 0
			break
		end
	end
	self.x = nx
end

--- 수직 이동. 내려가면 착지, 올라가면 천장.
function P.moveY(self, dy, probe)
	local ny = self.y + dy
	if dy >= 0 then
		if standing(self, probe, ny) then
			self.y = math.floor(ny / 16) * 16   -- 발을 타일 윗면에
			self.vy = 0
			if not self.onGround then self.landed = true end
			self.onGround = true
			self.airJumps = 1
			return
		end
		self.y = ny
		if not standing(self, probe, self.y + 1) then
			self.onGround = false
		end
	else
		local head = ny - P.BODY_H
		if probe(self.x - P.HALF_W + 1, head) or probe(self.x + P.HALF_W - 1, head) then
			self.y = (math.floor(head / 16) + 1) * 16 + P.BODY_H
			self.vy = 0
		else
			self.y = ny
		end
		self.onGround = false
	end
end

function P.update(self, input, dt, probe)
	self.jumped, self.landed, self.dashed = false, false, false

	-- 더블탭 대쉬 (기획서 5.1절: 같은 방향을 빠르게 두 번)
	self.tapTimer = math.max(0, self.tapTimer - dt)
	local tap = 0
	if input.leftEdge then tap = -1 elseif input.rightEdge then tap = 1 end
	if tap ~= 0 then
		if self.tapTimer > 0 and self.tapDir == tap and self.onGround then
			self.dashTimer = P.DASH_TIME
			self.dashDir = tap
			self.dashed = true
		end
		self.tapDir = tap
		self.tapTimer = P.TAP_WINDOW
	end

	-- 수평 속도.
	-- 터치는 단일 터치라(vpad.lua) 패드와 점프 버튼을 동시에 누를 수 없다.
	-- 그래서 두 가지 관성을 둔다: (1) 공중에서 입력이 없으면 속도를 유지하고,
	-- (2) 지상에서 손을 뗀 직후(P.RUN_GRACE)의 점프는 직전 달리기 속도를 잇는다.
	-- "달리다 손을 떼고 점프"가 앞으로 나아가는 점프가 되는 조건이다.
	self.dashTimer = math.max(0, self.dashTimer - dt)
	self.runTimer = math.max(0, self.runTimer - dt)
	if self.dashTimer > 0 then
		self.vx = self.dashDir * P.DASH_SPEED
		self.facing = self.dashDir
	elseif input.left and not input.right then
		self.vx = -P.WALK_SPEED
		self.facing = -1
	elseif input.right and not input.left then
		self.vx = P.WALK_SPEED
		self.facing = 1
	elseif self.onGround then
		self.vx = 0
	end
	if self.vx ~= 0 then
		self.runVx = self.vx
		self.runTimer = P.RUN_GRACE
	end

	-- 점프와 2단 점프
	if input.jumpEdge then
		if self.onGround then
			self.vy = P.JUMP_V
			self.onGround = false
			self.airJumps = 1
			self.jumped = true
			if self.vx == 0 and self.runTimer > 0 then
				self.vx = self.runVx      -- 달리기 기억을 잇는다
				self.facing = self.vx < 0 and -1 or 1
			end
		elseif self.airJumps > 0 then
			self.vy = P.AIR_JUMP_V
			self.airJumps = self.airJumps - 1
			self.jumped = true
		end
	end

	-- 중력
	self.vy = math.min(self.vy + P.GRAVITY * dt, P.MAX_FALL)

	P.moveX(self, self.vx * dt, probe)
	P.moveY(self, self.vy * dt, probe)
	self.animTime = self.animTime + dt
end

--- 지금 자세의 시트 칸 (karto.png, 그리드 12x2).
-- 칸: 0 서기A, 1 서기B, 2~5 걷기, 6 점프(상승), 7 낙하. 베기와 피격은 2단계.
function P.frame(self)
	local col
	if not self.onGround then
		col = self.vy < 0 and 6 or 7
	elseif self.vx ~= 0 then
		local fps = self.dashTimer > 0 and 14 or 9
		col = 2 + math.floor(self.animTime * fps) % 4
	else
		col = math.floor(self.animTime * 2) % 2
	end
	return (self.facing < 0 and 12 or 0) + col
end

return P
