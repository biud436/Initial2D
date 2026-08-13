-- Initial2D 데모 게임 — Flappy Bird 스타일
--
-- 조작: 마우스 클릭 또는 스페이스 바로 날갯짓
-- 상태: ready(대기) → play(플레이) → dead(게임 오버) → ready
--
-- 물리는 elapsed(ms)를 초로 정규화한 px/초 단위라 프레임레이트에 독립적이다.
-- INITIAL2D_AUTOPLAY 환경 변수를 설정하면 자동 시연 모드로 동작한다 (테스트/CI용).

local Image = require("scripts/image")

-- 화면 크기
local W = 768
local H = 896

-- 튜닝 상수 (px/초)
local GRAVITY     = 1500.0   -- 중력 가속도
local FLAP        = -480.0   -- 날갯짓 순간 속도
local MAX_FALL    = 820.0    -- 최대 낙하 속도
local PIPE_SPEED  = 210.0    -- 파이프 이동 속도
local SCROLL      = 40.0     -- 배경 스크롤 속도
local PIPE_GAP    = 260      -- 파이프 상하 간격
local PIPE_SPACING= 340      -- 파이프 수평 간격
local PIPE_W      = 52
local PIPE_H      = 271
local GROUND_Y    = 856      -- 지면 높이 (배경 이미지 기준)
local BIRD_X      = 170
local BIRD_W      = 92
local BIRD_H      = 64

local autoplay = false

-- 게임 상태
local state = "ready"
local score = 0
local best = 0
local birdY = 0
local birdVy = 0
local readyTime = 0
local deadTime = 0
local bgX1 = 0
local bgX2 = 0
local pipes = {}   -- { x, gapY, top(Image), bottom(Image), passed }

local function flapPressed()
	if autoplay then
		return false -- 자동 시연은 별도 로직에서 처리
	end
	return Input.IsMouseDown(0) or Input.IsKeyDown(32) -- 마우스 왼쪽 / 스페이스
end

local function resetPipes()
	for i, p in ipairs(pipes) do
		p.x = W + 120 + (i - 1) * PIPE_SPACING
		p.gapY = 220 + math.random(0, 280)   -- 위 파이프 하단(=간격 시작) 높이
		p.passed = false
	end
end

local function resetGame()
	birdY = H / 2 - BIRD_H / 2
	birdVy = 0
	score = 0
	readyTime = 0
	resetPipes()
end

function Initialize()
	W = WindowWidth()
	H = WindowHeight()

	autoplay = (os.getenv ~= nil) and (os.getenv("INITIAL2D_AUTOPLAY") ~= nil)
	math.randomseed(os.time())

	-- 스크롤 배경 2장 (이어붙여 좌측으로 흐름)
	bg1 = Image("./resources/background_768x896.png", 0, 0, W, H, 1, "Background")
	bg2 = Image("./resources/background_768x896.png", 0, 0, W, H, 1, "Background")
	bgX1 = 0
	bgX2 = W
	bg1.setPosition(bgX1, 0)
	bg2.setPosition(bgX2, 0)

	-- 파이프 3쌍 (위 파이프는 180도 회전 — 원점 회전이므로 위치를 보정한다)
	pipes = {}
	for i = 1, 3 do
		local top = Image("./resources/object_52x271.png", 0, 0, PIPE_W, PIPE_H, 1, "pipe")
		local bottom = Image("./resources/object_52x271.png", 0, 0, PIPE_W, PIPE_H, 1, "pipe")
		top.setAngle(180.0)
		pipes[i] = { x = 0, gapY = 0, top = top, bottom = bottom, passed = false }
	end

	-- 새 (3프레임 날갯짓 애니메이션)
	player = Image("./resources/bird_276x64.png", 0, 0, BIRD_W, BIRD_H, 3, "Player")
	player.setLoop(true)
	player.setFrames(0, 3)
	player.setFrameDelay(110.0)
	player.setAnimComplete(false)

	-- 폰트와 BGM
	fontReady = PreparaFont("./resources/fonts/hangul.fnt")
	Audio.PlayMusic("./resources/audio/bless.ogg", "bgm", -1)
	Audio.SetVolume(110)

	resetGame()
end

local function birdRect()
	-- 충돌 판정은 그림보다 약간 작게
	return BIRD_X + 12, birdY + 10, BIRD_X + BIRD_W - 16, birdY + BIRD_H - 10
end

local function overlap(l1, t1, r1, b1, l2, t2, r2, b2)
	return l1 < r2 and r1 > l2 and t1 < b2 and b1 > t2
end

local function hitPipe(p)
	local left, top, right, bottom = birdRect()

	-- 위 파이프: (x, gapY-PIPE_H)..(x+PIPE_W, gapY)
	if overlap(left, top, right, bottom, p.x, p.gapY - PIPE_H, p.x + PIPE_W, p.gapY) then
		return true
	end
	-- 아래 파이프: (x, gapY+PIPE_GAP)..(x+PIPE_W, gapY+PIPE_GAP+PIPE_H)
	if overlap(left, top, right, bottom, p.x, p.gapY + PIPE_GAP, p.x + PIPE_W, p.gapY + PIPE_GAP + PIPE_H) then
		return true
	end
	return false
end

local function updatePlay(dt, dtMs)
	-- 새 물리
	birdVy = birdVy + GRAVITY * dt
	if birdVy > MAX_FALL then birdVy = MAX_FALL end
	birdY = birdY + birdVy * dt

	if birdY < 0 then
		birdY = 0
		birdVy = 0
	end

	-- 날갯짓
	if flapPressed() then
		birdVy = FLAP
	end
	if autoplay and birdVy > 0 and birdY > H * 0.55 then
		birdVy = FLAP -- 자동 시연: 일정 높이 아래로 떨어지면 날갯짓
	end

	-- 파이프 이동·리사이클·점수
	for _, p in ipairs(pipes) do
		p.x = p.x - PIPE_SPEED * dt

		if p.x + PIPE_W < 0 then
			p.x = p.x + #pipes * PIPE_SPACING
			p.gapY = 220 + math.random(0, 280)
			p.passed = false
		end

		if (not p.passed) and (p.x + PIPE_W < BIRD_X) then
			p.passed = true
			score = score + 1
		end

		if hitPipe(p) then
			state = "dead"
			deadTime = 0
			if score > best then best = score end
		end
	end

	-- 지면 충돌
	if birdY + BIRD_H >= GROUND_Y then
		birdY = GROUND_Y - BIRD_H
		state = "dead"
		deadTime = 0
		if score > best then best = score end
	end
end

function Update(elapsed)
	local dtMs = math.min(elapsed, 50)  -- 스파이크 방어
	local dt = dtMs / 1000.0

	-- 배경 스크롤 (모든 상태에서)
	bgX1 = bgX1 - SCROLL * dt
	bgX2 = bgX2 - SCROLL * dt
	if bgX1 <= -W then bgX1 = bgX1 + W * 2 end
	if bgX2 <= -W then bgX2 = bgX2 + W * 2 end
	bg1.setPosition(bgX1, 0)
	bg2.setPosition(bgX2, 0)

	if state == "ready" then
		readyTime = readyTime + dt
		-- 대기 중엔 새가 상하로 부유
		birdY = (H / 2 - BIRD_H / 2) + math.sin(readyTime * 4.0) * 14.0
		if flapPressed() or (autoplay and readyTime > 1.0) then
			state = "play"
			birdVy = FLAP
		end
	elseif state == "play" then
		updatePlay(dt, dtMs)
	elseif state == "dead" then
		deadTime = deadTime + dt
		-- 게임 오버 후 새는 지면까지 낙하
		if birdY + BIRD_H < GROUND_Y then
			birdVy = birdVy + GRAVITY * dt
			birdY = birdY + birdVy * dt
			if birdY + BIRD_H > GROUND_Y then birdY = GROUND_Y - BIRD_H end
		end
		if (deadTime > 0.6 and flapPressed()) or (autoplay and deadTime > 1.5) then
			state = "ready"
			resetGame()
		end
	end

	-- 스프라이트 갱신 (트랜스폼·애니메이션)
	player.setPosition(BIRD_X, birdY)
	player.update(dtMs)
	bg1.update(0)
	bg2.update(0)

	for _, p in ipairs(pipes) do
		-- 위 파이프는 180도 원점 회전이라 (x+W, gapY)에 놓아야 (x, gapY-H)에 그려진다
		p.top.setPosition(p.x + PIPE_W, p.gapY)
		p.bottom.setPosition(p.x, p.gapY + PIPE_GAP)
		p.top.update(0)
		p.bottom.update(0)
	end
end

function Render()
	bg1.draw()
	bg2.draw()

	for _, p in ipairs(pipes) do
		p.top.draw()
		p.bottom.draw()
	end

	player.draw()

	if fontReady then
		if state == "ready" then
			DrawText(W / 2 - 200, H / 2 - 180, "클릭 또는 스페이스로 시작")
			DrawText(W / 2 - 110, H / 2 - 140, "최고 점수 " .. best)
		elseif state == "play" then
			DrawText(30, 24, "점수 " .. score)
		elseif state == "dead" then
			DrawText(W / 2 - 90, H / 2 - 180, "게임 오버")
			DrawText(W / 2 - 130, H / 2 - 140, "점수 " .. score .. "  최고 " .. best)
			if deadTime > 0.6 then
				DrawText(W / 2 - 170, H / 2 - 100, "클릭하면 다시 시작")
			end
		end
	end
end

function Destroy()
	bg1.dispose()
	bg2.dispose()
	player.dispose()
	for _, p in ipairs(pipes) do
		p.top.dispose()
		p.bottom.dispose()
	end
end
