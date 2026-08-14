-- 엔진 검증 씬 (픽셀 검증용 — tests/run_engine_tests.py가 구동)
-- 커밋된 리소스만 사용한다. 게임 코드는 Lua 원칙에 따라 씬 전체가 Lua로 작성됨.
local Image = require("scripts/image")

function Initialize()
	-- [A] BMFont 텍스트: 단색 배경판 위에 흰 글리프 (hangul.fnt: lineHeight=32 → scale=1)
	backdrop = Image("./resources/tiles/tile1.png", 0, 0, 48, 48, 1, "backdrop")
	backdrop.setPosition(32, 150)
	backdrop.setScale(8)

	-- 참고: 엔진의 커스텀 print(l_wcsprint)는 불리언을 출력하지 못하므로 tostring으로 변환
	fontReady = PreparaFont("./resources/fonts/hangul.fnt")
	print("fontReady:" .. tostring(fontReady))

	-- [B] 프레임 애니메이션: tileset 상단 행 4프레임 (16x16, scale 4)
	anim = Image("./resources/tiles/tileset16-8x13.png", 0, 0, 16, 16, 4, "anim")
	anim.setPosition(500, 200)
	anim.setScale(4)
	anim.setLoop(true)
	anim.setFrames(0, 4)
	anim.setFrameDelay(60.0)

	-- [C] 회전: 45도 (원점 기준 회전 — GDI SetWorldTransform 동작)
	rot = Image("./resources/tiles/tile1.png", 0, 0, 48, 48, 1, "rot")
	rot.setPosition(600, 500)
	rot.setAngle(45.0)

	-- [D] 반투명: opacity 128
	half = Image("./resources/tiles/tile1.png", 0, 0, 48, 48, 1, "half")
	half.setPosition(500, 700)
	half.setOpacity(128)

	-- [E] 오디오: BGM + SE (둘 다 ogg)
	Audio.PlayMusic("./resources/audio/bless.ogg", "bgm", -1)
	Audio.PlaySound("./resources/audio/bless.ogg", "se", 0)
	print("volume:", Audio.GetVolume())
end

function Update(elapsed)
	backdrop.update(0)
	anim.update(elapsed)
	rot.update(0)
	half.update(0)

	-- [F] 입력 API 호출 검증 (크래시 없이 동작해야 함)
	local dummy = Input.IsKeyDown(90) or Input.IsAnyKeyDown() or Input.IsMousePress(0)
	local mx = Input.GetMouseX()
	local my = Input.GetMouseY()
end

function Render()
	backdrop.draw()
	anim.draw()
	rot.draw()
	half.draw()

	if fontReady then
		DrawText(60, 180, "한글 폰트 렌더링")
	end

	-- [G] 프리미티브: 빨간 점 블록
	draw_set_color(255, 0, 0, 255)
	for i = 0, 7 do
		for j = 0, 7 do
			draw_point(700 + i, 60 + j)
		end
	end
end

function Destroy()
end
