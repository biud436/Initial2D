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

-- 환경 (A7). 스테이지의 기후가 물리를 바꾼다 (docs/plans/aldebaran-7-tomb.md 4절).
-- self.env가 없거나 값이 1이면 **지금까지와 완전히 같게 돈다** — 1-1은 이 길로 간다.
--   friction   1 미만이면 지면에서 곧바로 서지 못하고 미끄러진다 (눈)
--   moveMult   걷기와 대쉬의 속도 배율 (물에 잠기면 느려진다)
--   jumpMult   점프 초속의 배율 (물에 잠기면 낮게 뛴다)
P.GROUND_ACCEL = 900        -- 미끄러운 바닥에서 목표 속도에 다가가는 가속도

--- 목표로 rate만큼 다가간다 (넘어가지 않는다)
local function approach(v, target, rate)
	if v < target then return math.min(target, v + rate) end
	if v > target then return math.max(target, v - rate) end
	return v
end

--- 이 프레임의 환경 (없으면 기본값)
local function envOf(self)
	local e = self.env
	if e == nil then return 1, 1, 1 end
	return e.friction or 1, e.moveMult or 1, e.jumpMult or 1
end

-- 3단 콤보 (기획서 5.1절): 베기 1단 → 2단 → 십자 베기
P.ATTACK_WIND = 0.08        -- 선딜레이
P.ATTACK_ACTIVE = 0.10      -- 판정이 살아 있는 구간
P.ATTACK_RECOVER = 0.16     -- 후딜레이 (이 동안의 입력이 다음 단으로 이어진다)
P.COMBO_GRACE = 0.4         -- 베기가 끝나고도 이 시간 안의 입력은 콤보를 잇는다
P.COMBO_FINISHER = 1.6      -- 십자 베기(3단)의 데미지 배율
P.HURT_TIME = 0.25          -- 피격 경직
P.INVULN_TIME = 1.0         -- 피격 뒤 무적
P.KNOCKBACK_X = 110
P.KNOCKBACK_Y = -140

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
		-- 전투 (2단계)
		attackStage = 0,           -- 0 없음, 1~3 콤보 단
		attackTimer = 0,           -- 남은 베기 시간 (wind+active+recover에서 줄어든다)
		comboQueued = false,       -- 베기 중의 입력이 다음 단을 예약했다
		comboGrace = 0,            -- 베기가 끝난 뒤 콤보가 살아 있는 시간
		attackHit = {},            -- 이번 베기가 이미 때린 몬스터 (씬이 쓴다)
		hurtTimer = 0, invulnTimer = 0,
		-- 이번 프레임에 일어난 일 (씬이 효과음과 연출에 쓴다)
		jumped = false, landed = false, dashed = false, swung = false,
	}
end

-- ---- 전투 ------------------------------------------------------------------

local ATTACK_TOTAL = P.ATTACK_WIND + P.ATTACK_ACTIVE + P.ATTACK_RECOVER

--- 지금 베기의 구간 ("wind" | "active" | "recover" | nil)
function P.attackPhase(self)
	if self.attackStage == 0 or self.attackTimer <= 0 then return nil end
	local t = ATTACK_TOTAL - self.attackTimer
	if t < P.ATTACK_WIND then return "wind" end
	if t < P.ATTACK_WIND + P.ATTACK_ACTIVE then return "active" end
	return "recover"
end

--- 판정이 살아 있는가
function P.attackActive(self)
	return P.attackPhase(self) == "active"
end

--- 베기 판정 상자 (바라보는 방향 앞 22x20)
function P.attackBox(self)
	local x0
	if self.facing > 0 then
		x0 = self.x + P.HALF_W - 2
	else
		x0 = self.x - P.HALF_W + 2 - 22
	end
	return x0, self.y - P.BODY_H, x0 + 22, self.y
end

--- 이번 단의 데미지 배율 (3단 십자 베기는 세다)
function P.attackMult(self)
	return self.attackStage >= 3 and P.COMBO_FINISHER or 1
end

local function startAttack(self, stage)
	self.attackStage = stage
	self.attackTimer = ATTACK_TOTAL
	self.comboQueued = false
	self.comboGrace = 0
	self.attackHit = {}
	self.swung = true
end

--- 맞았다 (데미지 적용은 씬이 한다). 무적이면 false.
function P.applyHit(self, fromX)
	if self.invulnTimer > 0 then return false end
	self.hurtTimer = P.HURT_TIME
	self.invulnTimer = P.INVULN_TIME
	self.vy = P.KNOCKBACK_Y
	self.vx = (self.x < fromX) and -P.KNOCKBACK_X or P.KNOCKBACK_X
	self.onGround = false
	self.attackStage = 0
	self.attackTimer = 0
	self.dashTimer = 0
	return true
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

--- 이동 의도: 대쉬, 걷기, 점프 (피격도 베기도 아닐 때만 불린다)
local function updateMovement(self, input, dt)
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
	local friction, moveMult, jumpMult = envOf(self)
	local prevVx = self.vx
	if self.dashTimer > 0 then
		self.vx = self.dashDir * P.DASH_SPEED * moveMult
		self.facing = self.dashDir
	elseif input.left and not input.right then
		self.vx = -P.WALK_SPEED * moveMult
		self.facing = -1
	elseif input.right and not input.left then
		self.vx = P.WALK_SPEED * moveMult
		self.facing = 1
	elseif self.onGround then
		self.vx = 0
	end

	-- 미끄러운 바닥(눈): 목표 속도로 곧바로 갈아타지 않고 다가간다. 멈추는 것도
	-- 돌아서는 것도 시간이 걸린다. friction이 1이면 위의 결과를 그대로 쓴다 —
	-- 그래야 1-1의 물리가 한 픽셀도 달라지지 않는다.
	if friction < 1 and self.onGround then
		self.vx = approach(prevVx, self.vx, P.GROUND_ACCEL * friction * dt)
	end
	if self.vx ~= 0 then
		self.runVx = self.vx
		self.runTimer = P.RUN_GRACE
	end

	-- 점프와 2단 점프
	if input.jumpEdge then
		if self.onGround then
			self.vy = P.JUMP_V * jumpMult
			self.onGround = false
			self.airJumps = 1
			self.jumped = true
			if self.vx == 0 and self.runTimer > 0 then
				self.vx = self.runVx      -- 달리기 기억을 잇는다
				self.facing = self.vx < 0 and -1 or 1
			end
		elseif self.airJumps > 0 then
			self.vy = P.AIR_JUMP_V * jumpMult
			self.airJumps = self.airJumps - 1
			self.jumped = true
		end
	end
end

function P.update(self, input, dt, probe)
	self.jumped, self.landed, self.dashed, self.swung = false, false, false, false
	self.invulnTimer = math.max(0, self.invulnTimer - dt)

	-- 콤보 유예: 베기가 끝나고 이 시간이 지나면 콤보가 처음으로 돌아간다
	if self.comboGrace > 0 and self.attackTimer <= 0 then
		self.comboGrace = math.max(0, self.comboGrace - dt)
		if self.comboGrace <= 0 then self.attackStage = 0 end
	end

	if self.hurtTimer > 0 then
		-- 피격 경직: 입력을 받지 않고 넉백만 이어진다
		self.hurtTimer = math.max(0, self.hurtTimer - dt)

	elseif self.attackTimer > 0 then
		-- 베기 중: 활성 이후의 입력이 다음 단을 예약한다 (기획서 5.1절)
		if input.attackEdge and P.attackPhase(self) ~= "wind" then
			self.comboQueued = true
		end
		self.attackTimer = math.max(0, self.attackTimer - dt)
		if self.attackTimer <= 0 then
			if self.comboQueued and self.attackStage < 3 then
				startAttack(self, self.attackStage + 1)
			elseif self.attackStage < 3 then
				self.comboGrace = P.COMBO_GRACE
			else
				self.attackStage = 0        -- 십자 베기 뒤에는 처음부터
			end
		end
		-- 베는 동안에는 방향 전환도 점프도 없다. 지상에서는 제자리에 선다.
		if self.onGround then self.vx = 0 end
		self.tapTimer = 0

	elseif input.attackEdge then
		-- 베기 시작 (유예 안의 입력은 다음 단으로)
		if self.attackStage > 0 and self.attackStage < 3 and self.comboGrace > 0 then
			startAttack(self, self.attackStage + 1)
		else
			startAttack(self, 1)
		end
		if self.onGround then self.vx = 0 end

	else
		updateMovement(self, input, dt)
	end

	-- 중력과 이동 (모든 상태 공통). 경직이 끝난 뒤의 넉백 잔속은 다음 프레임의
	-- updateMovement가 지상 무입력 규칙으로 정리한다.
	self.vy = math.min(self.vy + P.GRAVITY * dt, P.MAX_FALL)
	P.moveX(self, self.vx * dt, probe)
	P.moveY(self, self.vy * dt, probe)
	self.animTime = self.animTime + dt
end

--- 지금 자세의 시트 칸 (karto.png, 그리드 12x2).
-- 칸: 0 서기A, 1 서기B, 2~5 걷기, 6 점프(상승), 7 낙하, 8~10 베기, 11 피격
function P.frame(self)
	local col
	if self.hurtTimer > 0 then
		col = 11
	elseif self.attackTimer > 0 then
		col = 7 + math.min(3, math.max(1, self.attackStage))
	elseif not self.onGround then
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
