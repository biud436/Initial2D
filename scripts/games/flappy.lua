-- 엔진 데모: Flappy Bird 스타일
--
-- 조작: 마우스 클릭/터치 또는 스페이스 바로 날갯짓
-- 상태: ready(대기) → play(플레이) → dead(게임 오버) → ready
-- 게임 오버 화면에서 화면 상단(1/3)을 누르면 게임을 끝낸다.
--
-- 물리는 elapsed(ms)를 초로 정규화한 px/초 단위라 프레임레이트에 독립적이다.

local Image = require("scripts/image")

local VK_ESCAPE = 27

FlappyScene = {}

-- 화면 크기
local W = 768
local H = 896

-- 튜닝 상수 (px/초)
local GRAVITY      = 1500.0   -- 중력 가속도
local FLAP         = -480.0   -- 날갯짓 순간 속도
local MAX_FALL     = 820.0    -- 최대 낙하 속도
local BASE_SPEED   = 210.0    -- 파이프·지면 기본 속도
local SCROLL       = 30.0     -- 배경(원경) 스크롤 속도
local BASE_GAP     = 280      -- 파이프 상하 간격(시작값)
local MIN_GAP      = 195      -- 파이프 간격 하한
local PIPE_SPACING = 340      -- 파이프 수평 간격
local PIPE_W       = 52
local PIPE_H       = 271
local GROUND_H     = 64
local GROUND_Y     = H - GROUND_H + 12  -- 충돌 기준(잔디 약간 아래)
local BIRD_X       = 170
local BIRD_W       = 92
local BIRD_H       = 64

-- 게임 상태
local state = "ready"
local score = 0
local best = 0
local birdY = 0
local birdVy = 0
local birdAngle = 0
local readyTime = 0
local deadTime = 0
local bgX1, bgX2 = 0, 0
local gndX1, gndX2 = 0, 0
local pipes = {}   -- { x, gapY, top(Image), bottom(Image), passed }
local bg1, bg2, gnd1, gnd2, player

local function speed()
	return math.min(BASE_SPEED + score * 3.0, 320.0)
end

local function gap()
	return math.max(BASE_GAP - score * 4, MIN_GAP)
end

local function sfx(name)
	-- loop에 숫자를 주면 추가 반복 횟수다 (1 = 2회 연속 재생).
	-- 효과음 파일이 절반 길이로 만들어져 있어 2회 재생이 정상 길이가 된다.
	Audio.PlaySound("./resources/audio/" .. name .. ".wav", name, 1)
end

local function flapPressed()
	if AUTOPLAY then
		return false -- 자동 시연은 별도 로직에서 처리
	end
	return Input.IsMouseDown(0) or Input.IsKeyDown(32) -- 마우스 왼쪽 / 스페이스
end

local function randomGap()
	return 200 + math.random(0, math.max(1, math.floor(H - GROUND_H - gap() - 340)))
end

local function resetPipes()
	for i, p in ipairs(pipes) do
		p.x = W + 160 + (i - 1) * PIPE_SPACING
		p.gapY = randomGap()
		p.passed = false
	end
end

local function resetGame()
	birdY = H / 2 - BIRD_H / 2
	birdVy = 0
	birdAngle = 0
	score = 0
	readyTime = 0
	resetPipes()
end

function FlappyScene.init()
	W = WindowWidth()
	H = WindowHeight()
	GROUND_Y = H - GROUND_H + 12

	state = "ready" -- 메뉴에서 재진입 시 이전 상태가 남지 않도록 명시적으로 초기화

	-- 스크롤 배경 2장 (이어붙여 좌측으로 흐름)
	bg1 = Image("./resources/background_768x896.png", 0, 0, W, H, 1, "Background")
	bg2 = Image("./resources/background_768x896.png", 0, 0, W, H, 1, "Background")

	-- 지면 2장 (파이프와 같은 속도로 흘러 속도감을 준다)
	gnd1 = Image("./resources/ground_768x64.png", 0, 0, W, GROUND_H, 1, "Ground")
	gnd2 = Image("./resources/ground_768x64.png", 0, 0, W, GROUND_H, 1, "Ground")

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

	bgX1, bgX2 = 0, W
	gndX1, gndX2 = 0, W
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
	-- 아래 파이프: (x, gapY+gap)..(x+PIPE_W, gapY+gap+PIPE_H)
	if overlap(left, top, right, bottom, p.x, p.gapY + gap(), p.x + PIPE_W, p.gapY + gap() + PIPE_H) then
		return true
	end
	return false
end

local function die()
	state = "dead"
	deadTime = 0
	if score > best then best = score end
	sfx("hit")
end

local function updatePlay(dt)
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
		sfx("flap")
	end
	if AUTOPLAY and birdVy > 0 and birdY > H * 0.5 then
		birdVy = FLAP -- 자동 시연: 일정 높이 아래로 떨어지면 날갯짓
	end

	-- 속도에 따른 기울기 (상승 시 -22도, 낙하 시 최대 60도)
	birdAngle = math.max(-22.0, math.min(60.0, birdVy * 0.075))

	-- 파이프 이동·리사이클·점수
	for _, p in ipairs(pipes) do
		p.x = p.x - speed() * dt

		if p.x + PIPE_W < 0 then
			p.x = p.x + #pipes * PIPE_SPACING
			p.gapY = randomGap()
			p.passed = false
		end

		if (not p.passed) and (p.x + PIPE_W < BIRD_X) then
			p.passed = true
			score = score + 1
			sfx("point")
		end

		if hitPipe(p) then
			die()
		end
	end

	-- 지면 충돌
	if birdY + BIRD_H >= GROUND_Y then
		birdY = GROUND_Y - BIRD_H
		die()
	end
end

function FlappyScene.update(elapsed)
	local dtMs = math.min(elapsed, 50)  -- 스파이크 방어
	local dt = dtMs / 1000.0

	-- ESC (Android 뒤로가기): 어느 상태에서든 게임 종료 (단독 진입점이다)
	if Input.IsKeyDown(VK_ESCAPE) then
		GameExit()
		return
	end

	-- 배경(원경)은 느리게, 지면은 파이프와 같은 속도로 스크롤
	local groundSpeed = (state == "play") and speed() or BASE_SPEED * 0.4
	bgX1 = bgX1 - SCROLL * dt
	bgX2 = bgX2 - SCROLL * dt
	if bgX1 <= -W then bgX1 = bgX1 + W * 2 end
	if bgX2 <= -W then bgX2 = bgX2 + W * 2 end

	if state ~= "dead" then
		gndX1 = gndX1 - groundSpeed * dt
		gndX2 = gndX2 - groundSpeed * dt
		if gndX1 <= -W then gndX1 = gndX1 + W * 2 end
		if gndX2 <= -W then gndX2 = gndX2 + W * 2 end
	end

	if state == "ready" then
		readyTime = readyTime + dt
		-- 대기 중엔 새가 상하로 부유
		birdY = (H / 2 - BIRD_H / 2) + math.sin(readyTime * 4.0) * 14.0
		birdAngle = math.sin(readyTime * 4.0) * 6.0
		if flapPressed() or (AUTOPLAY and readyTime > 1.0) then
			state = "play"
			birdVy = FLAP
			sfx("flap")
		end
	elseif state == "play" then
		updatePlay(dt)
	elseif state == "dead" then
		deadTime = deadTime + dt
		-- 게임 오버 후 새는 고꾸라지며 지면까지 낙하
		if birdY + BIRD_H < GROUND_Y then
			birdVy = birdVy + GRAVITY * dt
			birdY = birdY + birdVy * dt
			birdAngle = math.min(90.0, birdAngle + 220.0 * dt)
			if birdY + BIRD_H > GROUND_Y then birdY = GROUND_Y - BIRD_H end
		end
		if deadTime > 0.6 and (not AUTOPLAY) and Input.IsMouseDown(0) and Input.GetMouseY() < H / 3 then
			GameExit() -- 화면 상단 터치: 종료
		elseif (deadTime > 0.6 and flapPressed()) or (AUTOPLAY and deadTime > 1.5) then
			state = "ready"
			resetGame()
		end
	end

	-- 스프라이트 갱신 (트랜스폼·애니메이션)
	player.setPosition(BIRD_X, birdY)
	player.setAngle(birdAngle)
	player.update((state == "dead") and 0 or dtMs)

	bg1.setPosition(bgX1, 0)
	bg2.setPosition(bgX2, 0)
	bg1.update(0)
	bg2.update(0)

	gnd1.setPosition(gndX1, H - GROUND_H)
	gnd2.setPosition(gndX2, H - GROUND_H)
	gnd1.update(0)
	gnd2.update(0)

	for _, p in ipairs(pipes) do
		-- 위 파이프는 180도 원점 회전이라 (x+W, gapY)에 놓아야 (x, gapY-H)에 그려진다
		p.top.setPosition(p.x + PIPE_W, p.gapY)
		p.bottom.setPosition(p.x, p.gapY + gap())
		p.top.update(0)
		p.bottom.update(0)
	end
end

function FlappyScene.render()
	bg1.draw()
	bg2.draw()

	for _, p in ipairs(pipes) do
		p.top.draw()
		p.bottom.draw()
	end

	gnd1.draw()
	gnd2.draw()

	player.draw()

	if FontReady then
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
				DrawText(W / 2 - 210, H / 2 - 60, "화면 상단을 누르면 종료")
			end
		end
	end
end

function FlappyScene.destroy()
	bg1.dispose()
	bg2.dispose()
	gnd1.dispose()
	gnd2.dispose()
	player.dispose()
	for _, p in ipairs(pipes) do
		p.top.dispose()
		p.bottom.dispose()
	end
end

return FlappyScene
