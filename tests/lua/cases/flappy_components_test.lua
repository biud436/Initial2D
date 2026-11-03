-- flappy_components_test.lua : 플래피 컴포넌트(scripts/lua/components/flappy/)의 규칙 검증
-- resources/scenes/flappy.json 으로 진짜 씬을 만들고 컴포넌트 함수를 직접 부른다. 입력, 효과음,
-- 종료, 화면 크기는 가짜로 바꿔 끼운다. 900틱 자동 시연 전체는 scene_flappy_scene 이 본다.

local SceneLoader = require("scripts/lua/scene_loader")
local C = require("scripts/lua/components/flappy/common")
local Bird = require("scripts/lua/components/flappy/bird")
local Pipes = require("scripts/lua/components/flappy/pipes")
local Scroller = require("scripts/lua/components/flappy/scroller")
local Director = require("scripts/lua/components/flappy/director")

local M = {}

local W, H = 768, 896
local GROUND_Y = H - C.GROUND_H + 12   -- 844, 새의 아래 끝이 여기 닿으면 죽는다
local BIRD_REST = H / 2 - C.BIRD_H / 2 -- 416
local TICK = 20                        -- ms, dt 0.02초
local KEY_SPACE, KEY_ESCAPE = 32, 27
local realRandom = math.random

-- 가짜 엔진의 상태. 컴포넌트가 부르는 전역이 이 표를 읽고 쓴다
local fake = {}

local function resetFake()
	fake.keys = {}
	fake.mouseDown = false
	fake.mouseY = 0
	fake.sounds = {}
	fake.exits = 0
end

local function install()
	local saved = {
		WindowWidth = WindowWidth, WindowHeight = WindowHeight, GameExit = GameExit,
		PlaySound = Audio.PlaySound, IsKeyDown = Input.IsKeyDown,
		IsMouseDown = Input.IsMouseDown, GetMouseY = Input.GetMouseY,
		random = math.random,
	}
	WindowWidth = function() return W end
	WindowHeight = function() return H end
	GameExit = function() fake.exits = fake.exits + 1 end
	Audio.PlaySound = function(_, id)
		fake.sounds[#fake.sounds + 1] = id
		return true
	end
	Input.IsKeyDown = function(key) return fake.keys[key] == true end
	Input.IsMouseDown = function(button) return button == 0 and fake.mouseDown end
	Input.GetMouseY = function() return fake.mouseY end
	return saved
end

local function restore(saved)
	WindowWidth, WindowHeight, GameExit = saved.WindowWidth, saved.WindowHeight, saved.GameExit
	Audio.PlaySound = saved.PlaySound
	Input.IsKeyDown, Input.IsMouseDown, Input.GetMouseY = saved.IsKeyDown, saved.IsMouseDown, saved.GetMouseY
	math.random = saved.random
end

local opened = {}

-- 새 판: 씬 파일로 씬을 만들고 상태 표를 돌려준다 (자동 시연은 끈다)
local function newGame()
	resetFake()
	local scene = SceneLoader.open("flappy")
	opened[#opened + 1] = scene
	local st = C.state(scene)
	st.autoplay = false
	return scene, st
end

-- fn 을 부르는 동안 print 를 모은다 (감독의 stdout 알림)
local function quiet(fn, ...)
	local lines = {}
	local savedPrint = print
	print = function(s) lines[#lines + 1] = s end
	local ok, err = pcall(fn, ...)
	print = savedPrint
	if not ok then error(err, 0) end
	return lines
end

local function directorTick(scene, elapsed)
	return quiet(Director.update, scene:find("director"), scene, elapsed or TICK)
end

local function count(list, item)
	local n = 0
	for _, v in ipairs(list) do
		if v == item then n = n + 1 end
	end
	return n
end

local function indexOf(scene, id)
	for i, o in ipairs(scene:objects()) do
		if o.id == id then return i end
	end
	return nil
end

local function checkNear(t, actual, expected, label)
	t.check(type(actual) == "number" and math.abs(actual - expected) < 1e-6, label,
		string.format("실제 %s, 기대 %s", tostring(actual), tostring(expected)))
end

local function cases(t)
	-- [공용] 시간, 속도, 간격 ----------------------------------------------------
	checkNear(t, C.dt(20), 0.02, "dt: 20ms 는 0.02초")
	checkNear(t, C.dt(100), 0.05, "dt: 50ms 를 넘는 틱은 0.05초로 자른다")
	t.check_eq(C.speed({ score = 0 }), 210.0, "speed: 0점은 기본 속도 210")
	t.check_eq(C.speed({ score = 10 }), 240.0, "speed: 1점마다 3씩 빨라진다")
	t.check_eq(C.speed({ score = 37 }), 320.0, "speed: 320 에서 멈춘다")
	t.check_eq(C.gap({ score = 0 }), 280, "gap: 0점은 280")
	t.check_eq(C.gap({ score = 21 }), 196, "gap: 1점마다 4씩 좁아진다")
	t.check_eq(C.gap({ score = 22 }), 195, "gap: 195 아래로는 좁아지지 않는다")

	-- [공용] 파이프 높이: 200 부터 200 + (H - 지면 - 간격 - 340) 까지, 양 끝 포함
	local tall = { H = H, score = 0 }
	local lo, hi = 200, 200 + (H - C.GROUND_H - 280 - 340)   -- 200..412
	local inRange = true
	for _ = 1, 300 do
		local g = C.randomGap(tall)
		if g < lo or g > hi or g ~= math.floor(g) then inRange = false end
	end
	t.check(inRange, "randomGap: 300번 모두 200..412 의 정수")
	math.random = function(_, b) return b end
	t.check_eq(C.randomGap(tall), hi, "randomGap: 위 끝 412 를 포함한다")
	t.check_eq(C.randomGap({ H = 600, score = 0 }), 201, "randomGap: 남는 높이가 없으면 200 이나 201")
	math.random = function(a) return a end
	t.check_eq(C.randomGap(tall), lo, "randomGap: 아래 끝 200 을 포함한다")
	math.random = realRandom
	local scene, st = newGame()
	local bird = scene:find("bird")

	-- [공용] 충돌 판정: 새의 판정 상자는 (182, y+10)..(246, y+54), 그림보다 작다 -----------
	local p = { x = 190, gapY = 300 }   -- 위 파이프 29..300, 아래 파이프 580..851 (간격 280)
	bird.y = 400
	t.check_eq(C.hitPipe(st, p), false, "충돌: 간격 한가운데는 부딪치지 않는다")
	bird.y = 290
	t.check_eq(C.hitPipe(st, p), false, "충돌: 위 파이프 끝에 닿기만 하면 부딪치지 않는다")
	bird.y = 289
	t.check_eq(C.hitPipe(st, p), true, "충돌: 위 파이프로 1px 들어가면 부딪친다")
	bird.y = 526
	t.check_eq(C.hitPipe(st, p), false, "충돌: 아래 파이프 끝에 닿기만 하면 부딪치지 않는다")
	bird.y = 527
	t.check_eq(C.hitPipe(st, p), true, "충돌: 아래 파이프로 1px 들어가면 부딪친다")
	bird.y = 100
	t.check_eq(C.hitPipe(st, { x = 246, gapY = 300 }), false, "충돌: 파이프 왼쪽 끝 246 은 부딪치지 않는다")
	t.check_eq(C.hitPipe(st, { x = 245, gapY = 300 }), true, "충돌: 파이프 왼쪽 끝 245 는 부딪친다")
	t.check_eq(C.hitPipe(st, { x = 130, gapY = 300 }), false, "충돌: 파이프 오른쪽 끝 182 는 부딪치지 않는다")
	t.check_eq(C.hitPipe(st, { x = 131, gapY = 300 }), true, "충돌: 파이프 오른쪽 끝 183 은 부딪친다")
	bird.y = 450
	t.check_eq(C.hitPipe(st, p), false, "충돌: 0점(간격 280)에서는 같은 자리가 안전하다")
	st.score = 20
	t.check_eq(C.hitPipe(st, p), true, "충돌: 20점(간격 200)에서는 같은 자리가 부딪친다")

	-- [공용] 죽음과 최고 점수
	st.score, st.best, st.deadTime = 3, 5, 1
	C.die(st)
	t.check_eq(st.state, "dead", "die: 상태는 dead")
	t.check_eq(st.deadTime, 0, "die: 죽은 뒤 시간을 0 부터 센다")
	t.check_eq(st.best, 5, "die: 최고 점수보다 낮으면 최고 점수는 그대로")
	st.score = 7
	C.die(st)
	t.check_eq(st.best, 7, "die: 최고 점수를 넘으면 갱신한다")
	t.check_eq(count(fake.sounds, "hit"), 2, "die: 죽을 때마다 hit 효과음")

	-- [공용] 새 판으로 되돌리기: 최고 점수만 남는다
	st.score, st.best, st.readyTime, st.birdVy, st.birdAngle = 9, 9, 3, 300, 45
	bird.y = 10
	C.resetGame(st)
	t.check_eq(bird.y, BIRD_REST, "resetGame: 새는 화면 세로 가운데 416")
	t.check_eq(st.birdVy, 0, "resetGame: 속도 0")
	t.check_eq(st.birdAngle, 0, "resetGame: 기울기 0")
	t.check_eq(st.score, 0, "resetGame: 점수 0")
	t.check_eq(st.readyTime, 0, "resetGame: 대기 시간 0")
	t.check_eq(st.best, 9, "resetGame: 최고 점수는 남는다")
	t.check_eq(#st.pipes, 3, "resetGame: 파이프는 3쌍")
	for i, pp in ipairs(st.pipes) do
		local x = W + 160 + (i - 1) * C.PIPE_SPACING
		t.check_eq(pp.x, x, "resetGame: " .. i .. "번 파이프는 화면 밖 " .. x)
		t.check_eq(pp.passed, false, "resetGame: " .. i .. "번 파이프는 아직 안 지나갔다")
		t.check(pp.gapY >= lo and pp.gapY <= hi, "resetGame: " .. i .. "번 파이프 높이는 범위 안", pp.gapY)
		-- 위 파이프는 원점 기준 180도 회전이라 (x + 폭, gapY) 에 놓아야 (x, gapY - 높이) 에 그려진다
		t.check_eq(pp.top.x, x + C.PIPE_W, "placePipes: " .. i .. "번 위 파이프 x 는 x + 52")
		t.check_eq(pp.top.y, pp.gapY, "placePipes: " .. i .. "번 위 파이프 y 는 gapY")
		t.check_eq(pp.bottom.x, x, "placePipes: " .. i .. "번 아래 파이프 x 는 x")
		t.check_eq(pp.bottom.y, pp.gapY + 280, "placePipes: " .. i .. "번 아래 파이프 y 는 gapY + 간격")
	end

	-- [새] 대기: 가운데에서 위아래로 뜬다 (대기 시간은 감독이 센다) --------------------
	scene, st = newGame()
	bird = scene:find("bird")
	t.check_eq(bird.x, C.BIRD_X, "bird.init: x 는 170")
	t.check_eq(bird.y, BIRD_REST, "bird.init: y 는 416")
	st.readyTime = math.pi / 8   -- sin(4t) = 1
	Bird.update(bird, scene, TICK)
	checkNear(t, bird.y, BIRD_REST + 14, "대기: 사인 꼭대기에서 14px 위아래")
	checkNear(t, st.birdAngle, 6, "대기: 기울기는 6도까지")
	checkNear(t, bird.props.angle, 6, "대기: 기울기가 스프라이트 각도로 간다")
	t.check_eq(st.readyTime, math.pi / 8, "대기: 새는 대기 시간을 늘리지 않는다")
	t.check_eq(bird.animate, true, "대기: 날갯짓 애니메이션은 돈다")

	-- [새] 플레이: 중력, 최대 낙하 속도, 천장
	st.state = "play"
	bird.y, st.birdVy = 400, 0
	Bird.update(bird, scene, TICK)
	checkNear(t, st.birdVy, 30, "중력: 한 틱(0.02초)에 속도 +30")
	checkNear(t, bird.y, 400.6, "중력: 위치는 새 속도로 움직인다")
	checkNear(t, st.birdAngle, 2.25, "중력: 기울기는 속도 x 0.075")
	st.birdVy = 810
	Bird.update(bird, scene, TICK)
	t.check_eq(st.birdVy, C.MAX_FALL, "최대 낙하: 속도는 820 에서 멈춘다")
	t.check_eq(st.birdAngle, 60.0, "최대 낙하: 기울기는 60도까지")
	bird.y, st.birdVy = 1, -480
	Bird.update(bird, scene, TICK)
	t.check_eq(bird.y, 0, "천장: 화면 위로 나가지 않는다")
	t.check_eq(st.birdVy, 0, "천장: 닿으면 속도 0")

	-- [새] 날갯짓: 스페이스나 마우스 왼쪽
	bird.y, st.birdVy = 400, 200
	fake.keys[KEY_SPACE] = true
	Bird.update(bird, scene, TICK)
	fake.keys[KEY_SPACE] = nil
	t.check_eq(st.birdVy, C.FLAP, "날갯짓: 스페이스면 속도 -480")
	checkNear(t, bird.y, 404.6, "날갯짓: 이번 틱의 이동은 날갯짓 전 속도로 한다")
	t.check_eq(st.birdAngle, -22.0, "날갯짓: 기울기는 -22도까지")
	t.check_eq(count(fake.sounds, "flap"), 1, "날갯짓: flap 효과음")
	bird.y, st.birdVy = 400, 200
	fake.mouseDown = true
	Bird.update(bird, scene, TICK)
	fake.mouseDown = false
	t.check_eq(st.birdVy, C.FLAP, "날갯짓: 마우스 왼쪽도 된다")

	-- [새] 자동 시연: 입력을 무시하고, 화면 가운데 아래로 떨어지면 스스로 난다
	st.autoplay = true
	bird.y, st.birdVy = 500, 100
	Bird.update(bird, scene, TICK)
	t.check_eq(st.birdVy, C.FLAP, "자동 시연: 가운데(448) 아래에서 떨어지면 난다")
	bird.y, st.birdVy = 400, 100
	Bird.update(bird, scene, TICK)
	checkNear(t, st.birdVy, 130, "자동 시연: 가운데 위에서는 날지 않는다")
	bird.y, st.birdVy = 400, 0
	fake.keys[KEY_SPACE] = true
	Bird.update(bird, scene, TICK)
	fake.keys[KEY_SPACE] = nil
	checkNear(t, st.birdVy, 30, "자동 시연: 스페이스를 무시한다")
	st.autoplay = false

	-- [새] 지면: 아래 끝이 844 에 닿는 순간 죽는다
	bird.y, st.birdVy = 779, -30
	Bird.update(bird, scene, TICK)
	t.check_eq(st.state, "play", "지면: 843 에서는 아직 산다")
	bird.y, st.birdVy = 780, -30
	Bird.update(bird, scene, TICK)
	t.check_eq(st.state, "dead", "지면: 844 에 닿으면 죽는다")
	t.check_eq(bird.y, GROUND_Y - C.BIRD_H, "지면: 새는 지면 위 780 에 놓인다")
	t.check_eq(bird.animate, false, "지면: 죽으면 날갯짓 애니메이션을 멈춘다")

	-- [새] 게임 오버: 고꾸라지며 지면까지 떨어지고, 거기서 멈춘다
	bird.y, st.birdVy, st.birdAngle = 600, 0, 0
	Bird.update(bird, scene, TICK)
	checkNear(t, st.birdVy, 30, "추락: 중력을 받는다")
	checkNear(t, bird.y, 600.6, "추락: 떨어진다")
	checkNear(t, st.birdAngle, 4.4, "추락: 초당 220도씩 고꾸라진다")
	st.birdAngle = 89
	Bird.update(bird, scene, TICK)
	t.check_eq(st.birdAngle, 90.0, "추락: 기울기는 90도까지")
	bird.y, st.birdVy = 779, 500
	Bird.update(bird, scene, TICK)
	t.check_eq(bird.y, GROUND_Y - C.BIRD_H, "추락: 지면을 뚫지 않고 780 에 멈춘다")
	Bird.update(bird, scene, TICK)
	t.check_eq(bird.y, GROUND_Y - C.BIRD_H, "추락: 지면에 닿은 뒤로는 움직이지 않는다")

	-- [파이프] spawn: 배경(bg2) 바로 뒤, 지면 앞에 그린다 ---------------------------
	scene, st = newGame()
	bird = scene:find("bird")
	local pipesObj = scene:find("pipes")
	local bg2, ground1 = indexOf(scene, "bg2"), indexOf(scene, "ground1")
	local between = true
	for i = 1, 3 do
		for _, id in ipairs({ "pipe_top_" .. i, "pipe_bottom_" .. i }) do
			local at = indexOf(scene, id)
			if at == nil or at <= bg2 or at >= ground1 then between = false end
		end
		t.check(st.pipes[i].top == scene:find("pipe_top_" .. i), "spawn: " .. i .. "번 위 파이프가 씬에 있다")
		t.check(st.pipes[i].bottom == scene:find("pipe_bottom_" .. i), "spawn: " .. i .. "번 아래 파이프가 씬에 있다")
	end
	t.check(between, "spawn: 파이프 6장은 모두 bg2 뒤, ground1 앞에 그린다")
	t.check_eq(st.pipes[1].top.props.angle, 180, "spawn: 위 파이프는 180도 돌려 그린다")
	t.check(st.pipes[1].bottom.props.angle ~= 180, "spawn: 아래 파이프는 돌리지 않는다")

	-- [파이프] 대기와 게임 오버에는 멈춰 있다
	local function setPipes(x1, x2, x3)
		for i, x in ipairs({ x1, x2, x3 }) do
			st.pipes[i].x, st.pipes[i].gapY, st.pipes[i].passed = x, 300, false
		end
	end
	bird.y = 400   -- 간격 안
	setPipes(600, 940, 1280)
	Pipes.update(pipesObj, scene, TICK)
	t.check_eq(st.pipes[1].x, 600, "파이프: 대기 중에는 움직이지 않는다")
	st.state = "dead"
	Pipes.update(pipesObj, scene, TICK)
	t.check_eq(st.pipes[1].x, 600, "파이프: 게임 오버에는 움직이지 않는다")

	-- [파이프] 플레이: 속도만큼 흐르고 스프라이트가 따라간다
	st.state = "play"
	Pipes.update(pipesObj, scene, TICK)
	checkNear(t, st.pipes[1].x, 595.8, "파이프: 0점은 한 틱에 4.2px")
	checkNear(t, st.pipes[3].x, 1275.8, "파이프: 3쌍이 함께 흐른다")
	checkNear(t, st.pipes[1].bottom.x, 595.8, "파이프: 스프라이트가 자료를 따라간다")
	st.score = 10
	Pipes.update(pipesObj, scene, TICK)
	checkNear(t, st.pipes[1].x, 591.0, "파이프: 10점은 한 틱에 4.8px")

	-- [파이프] 점수: 파이프 오른쪽 끝이 새의 x(170) 를 지나면 1점, 한 번만
	st.score = 0
	fake.sounds = {}
	setPipes(130, 940, 1280)
	Pipes.update(pipesObj, scene, TICK)
	t.check_eq(st.score, 0, "점수: 오른쪽 끝 177.8 은 아직 안 지났다")
	setPipes(70, 940, 1280)
	Pipes.update(pipesObj, scene, TICK)
	t.check_eq(st.score, 1, "점수: 오른쪽 끝 117.8 은 지났다")
	t.check_eq(st.pipes[1].passed, true, "점수: 지난 파이프에 표시한다")
	Pipes.update(pipesObj, scene, TICK)
	t.check_eq(st.score, 1, "점수: 같은 파이프로 두 번 세지 않는다")
	t.check_eq(count(fake.sounds, "point"), 1, "점수: point 효과음 한 번")

	-- [파이프] 되돌리기: 화면 왼쪽으로 다 나가면 3 x 340 만큼 오른쪽으로 간다
	st.score = 0
	setPipes(-50, 940, 1280)
	st.pipes[1].passed = true
	math.random = function(a, b) return b end
	Pipes.update(pipesObj, scene, TICK)
	checkNear(t, st.pipes[1].x, -54.2 + 3 * C.PIPE_SPACING, "되돌리기: x 에 1020 을 더한다")
	t.check_eq(st.pipes[1].passed, false, "되돌리기: 다시 지나갈 수 있다")
	t.check_eq(st.pipes[1].gapY, 200 + (H - C.GROUND_H - C.gap(st) - 340), "되돌리기: 높이를 새로 뽑는다")

	math.random = realRandom

	-- [파이프] 충돌: 부딪치면 죽고, 그 뒤로 파이프는 멈춘다
	bird.y = 289
	setPipes(194.2, 940, 1280)
	Pipes.update(pipesObj, scene, TICK)
	t.check_eq(st.state, "dead", "충돌: 파이프에 부딪치면 죽는다")
	local frozen = st.pipes[1].x
	Pipes.update(pipesObj, scene, TICK)
	t.check_eq(st.pipes[1].x, frozen, "충돌: 죽은 뒤로 파이프는 멈춘다")

	-- [배경과 지면] ----------------------------------------------------------------
	scene, st = newGame()
	local bg1, ground = scene:find("bg1"), scene:find("ground1")
	Scroller.update(bg1, scene, TICK)
	checkNear(t, bg1.x, -0.6, "배경: 초당 30px")
	st.state = "dead"
	Scroller.update(bg1, scene, TICK)
	checkNear(t, bg1.x, -1.2, "배경: 게임 오버에도 흐른다")
	st.state = "ready"
	Scroller.update(ground, scene, TICK)
	checkNear(t, ground.x, -1.68, "지면: 대기 중에는 기본 속도의 0.4배(84px/초)")
	ground.x = 0
	st.state = "play"
	Scroller.update(ground, scene, TICK)
	checkNear(t, ground.x, -4.2, "지면: 플레이 중에는 파이프와 같은 속도")
	ground.x = 0
	st.state = "dead"
	Scroller.update(ground, scene, TICK)
	t.check_eq(ground.x, 0, "지면: 게임 오버에는 멈춘다")
	st.state = "play"
	ground.x = -767
	Scroller.update(ground, scene, TICK)
	checkNear(t, ground.x, -771.2 + 2 * W, "지면: -768 을 넘으면 1536 만큼 오른쪽으로")
	bg1.x = -767.5
	Scroller.update(bg1, scene, TICK)
	checkNear(t, bg1.x, -768.1 + 2 * W, "배경: -768 을 넘으면 1536 만큼 오른쪽으로")

	-- 두 장은 오래 흘러도 768 간격으로 이어진다
	local g1, g2 = scene:find("ground1"), scene:find("ground2")
	g1.x, g2.x = 0, W
	for _ = 1, 2000 do
		Scroller.update(g1, scene, TICK)
		Scroller.update(g2, scene, TICK)
	end
	checkNear(t, math.abs(g1.x - g2.x), W, "이어붙이기: 40초 뒤에도 두 장의 간격은 768")
	t.check(g1.x > -W and g1.x <= W and g2.x > -W and g2.x <= W, "이어붙이기: 두 장 모두 -768..768 안",
		g1.x .. ", " .. g2.x)

	-- [감독] 시작 화면 ---------------------------------------------------------------
	scene, st = newGame()
	local function shown(id) return scene:find(id).visible end
	t.check_eq(st.state, "ready", "감독: 처음은 ready")
	t.check(shown("title") and shown("best"), "감독: 대기 화면은 title, best 를 보인다")
	t.check(not (shown("score") or shown("over") or shown("result") or shown("hint1") or shown("hint2")),
		"감독: 대기 화면은 점수와 게임 오버 글자를 숨긴다")
	t.check_eq(scene:find("best").props.text, "최고 점수 0", "감독: 최고 점수 글자")

	-- [감독] ready: 입력이 없으면 기다린다
	local lines = directorTick(scene)
	t.check_eq(st.state, "ready", "감독: 입력이 없으면 ready 에 머문다")
	checkNear(t, st.readyTime, 0.02, "감독: 대기 시간을 센다")
	t.check_eq(table.concat(lines, "|"), "flappy:state:ready|flappy:score:0", "감독: 첫 틱에 상태와 점수를 알린다")
	lines = directorTick(scene)
	t.check_eq(#lines, 0, "감독: 바뀐 것이 없으면 알리지 않는다")

	-- [감독] ready -> play
	fake.keys[KEY_SPACE] = true
	lines = directorTick(scene)
	fake.keys[KEY_SPACE] = nil
	t.check_eq(st.state, "play", "감독: 날갯짓으로 시작한다")
	t.check_eq(st.birdVy, C.FLAP, "감독: 시작하면서 한 번 난다")
	t.check_eq(count(fake.sounds, "flap"), 1, "감독: 시작 flap 효과음")
	t.check_eq(table.concat(lines, "|"), "flappy:state:play", "감독: 상태가 바뀌면 알린다")
	t.check(shown("score") and not shown("title"), "감독: 플레이 중에는 점수만 보인다")
	st.score = 1
	lines = directorTick(scene)
	t.check_eq(table.concat(lines, "|"), "flappy:score:1", "감독: 점수가 바뀌면 알린다")
	t.check_eq(scene:find("score").props.text, "점수 1", "감독: 점수 글자")

	-- [감독] 자동 시연은 1초 기다린 뒤 시작한다
	scene, st = newGame()
	st.autoplay = true
	st.readyTime = 0.97
	directorTick(scene)
	t.check_eq(st.state, "ready", "자동 시연: 0.99초에는 아직 기다린다")
	directorTick(scene)
	t.check_eq(st.state, "play", "자동 시연: 1초를 넘으면 시작한다")

	-- [감독] 게임 오버 화면
	scene, st = newGame()
	st.state, st.deadTime, st.score, st.best = "dead", 0, 3, 5
	directorTick(scene)
	t.check(shown("over") and shown("result") and not shown("score"), "게임 오버: over, result 를 보인다")
	t.check_eq(scene:find("result").props.text, "점수 3  최고 5", "게임 오버: 점수와 최고 점수 글자")
	t.check(not (shown("hint1") or shown("hint2")), "게임 오버: 0.6초 전에는 안내를 숨긴다")
	fake.keys[KEY_SPACE] = true
	directorTick(scene)
	fake.keys[KEY_SPACE] = nil
	t.check_eq(st.state, "dead", "게임 오버: 0.6초 전의 날갯짓은 무시한다")
	st.deadTime = 0.59
	directorTick(scene)
	t.check(shown("hint1") and shown("hint2"), "게임 오버: 0.6초가 지나면 안내를 보인다")

	-- [감독] 다시 시작: 최고 점수만 남기고 새 판
	scene:find("bird").y = 700
	fake.keys[KEY_SPACE] = true
	lines = directorTick(scene)
	fake.keys[KEY_SPACE] = nil
	t.check_eq(st.state, "ready", "다시 시작: 날갯짓하면 ready 로")
	t.check_eq(st.score, 0, "다시 시작: 점수 0")
	t.check_eq(st.best, 5, "다시 시작: 최고 점수는 남는다")
	t.check_eq(scene:find("bird").y, BIRD_REST, "다시 시작: 새는 가운데로")
	t.check_eq(table.concat(lines, "|"), "flappy:state:ready|flappy:score:0", "다시 시작: 상태와 점수를 알린다")
	t.check(shown("title") and not shown("over"), "다시 시작: 대기 화면으로 돌아간다")

	-- [감독] 게임 오버에서 화면 위 1/3 을 누르면 끝낸다 (아래는 다시 시작)
	st.state, st.deadTime = "dead", 0.3
	fake.mouseDown, fake.mouseY = true, 100
	directorTick(scene)
	t.check_eq(fake.exits, 0, "종료: 0.6초 전에는 화면 위를 눌러도 끝내지 않는다")
	t.check_eq(st.state, "dead", "종료: 0.6초 전에는 다시 시작도 하지 않는다")
	st.deadTime = 0.7
	directorTick(scene)
	t.check_eq(fake.exits, 1, "종료: 화면 위 1/3 을 누르면 끝낸다")
	t.check_eq(st.state, "dead", "종료: 다시 시작하지 않는다")
	fake.exits = 0
	fake.mouseY = 400
	directorTick(scene)
	fake.mouseDown = false
	t.check_eq(fake.exits, 0, "종료: 화면 아래쪽 클릭은 끝내지 않는다")
	t.check_eq(st.state, "ready", "종료: 화면 아래쪽 클릭은 다시 시작이다")

	-- [감독] 자동 시연의 게임 오버: 클릭을 무시하고 1.5초 뒤 다시 시작
	st.state, st.deadTime, st.autoplay = "dead", 0.7, true
	fake.mouseDown, fake.mouseY = true, 100
	directorTick(scene)
	fake.mouseDown = false
	t.check_eq(fake.exits, 0, "자동 시연: 화면 위 클릭으로 끝내지 않는다")
	t.check_eq(st.state, "dead", "자동 시연: 1.5초 전에는 다시 시작하지 않는다")
	st.deadTime = 1.49
	directorTick(scene)
	t.check_eq(st.state, "ready", "자동 시연: 1.5초를 넘으면 다시 시작한다")

	-- [감독] ESC 는 어느 상태에서든 끝내고, 그 틱은 세지 않는다
	st.autoplay = false
	st.state = "play"
	local ticksBefore = st.ticks
	fake.keys[KEY_ESCAPE] = true
	directorTick(scene)
	fake.keys[KEY_ESCAPE] = nil
	t.check_eq(fake.exits, 1, "ESC: 플레이 중에도 끝낸다")
	t.check_eq(st.ticks, ticksBefore, "ESC: 그 틱은 세지 않는다")

	-- [감독] 자동 시연은 900틱에 결과를 찍고 끝낸다
	scene, st = newGame()
	st.autoplay, st.ticks, st.best = true, C.TICK_BUDGET - 2, 4
	directorTick(scene)
	t.check_eq(fake.exits, 0, "틱 예산: 899틱에는 끝내지 않는다")
	lines = directorTick(scene)
	t.check_eq(fake.exits, 1, "틱 예산: 900틱에 끝낸다")
	t.check_eq(lines[#lines], "flappyFinal state=ready score=0 best=4 ticks=900", "틱 예산: 결과 한 줄")
	scene, st = newGame()
	st.ticks = C.TICK_BUDGET
	directorTick(scene)
	t.check_eq(fake.exits, 0, "틱 예산: 사람이 할 때는 끝내지 않는다")

	-- [씬] 진짜 씬의 틱: 한 번 날고 두면 땅에 떨어져 끝난다 -----------------------------
	scene, st = newGame()
	bird = scene:find("bird")
	fake.keys[KEY_SPACE] = true
	quiet(function() scene = scene:tick(TICK) end)
	fake.keys[KEY_SPACE] = nil
	t.check_eq(st.state, "play", "씬: 첫 틱의 스페이스로 시작한다")
	local ticks = 0
	quiet(function()
		while st.state == "play" and ticks < 200 do
			scene = scene:tick(TICK)
			ticks = ticks + 1
		end
	end)
	t.check_eq(st.state, "dead", "씬: 날갯짓 없이 두면 죽는다")
	t.check_eq(ticks, 56, "씬: 56틱(약 1.1초) 만에 땅에 닿는다")
	t.check_eq(bird.y, GROUND_Y - C.BIRD_H, "씬: 새는 지면 위에 멈춘다")
	t.check_eq(st.score, 0, "씬: 파이프에 닿기 전이라 0점")
	checkNear(t, st.pipes[1].x, W + 160 - 55 * 4.2, "씬: 파이프는 새가 살아 있던 55틱만큼 흘렀다")
	quiet(function() scene = scene:tick(TICK) end)
	t.check(shown("over") and shown("result"), "씬: 다음 틱에 게임 오버 화면")
end

function M.run(t)
	local saved = install()
	local ok, err = pcall(cases, t)
	restore(saved)
	for _, scene in ipairs(opened) do
		if not scene:isClosed() then scene:close() end
	end
	opened = {}
	if not ok then error(err, 0) end
end

return M
