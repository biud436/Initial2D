-- 기본 렌더링 검증 씬 (엔진 1). tests/run_engine_tests.py 의 test_render_basics 가 구동한다.
-- 색 입히기, 뒤집기, 기준점, 혼합 모드, 글자 색과 크기, 도형, 렌더 타깃을 그리고 러너가 픽셀로 확인한다.
-- mruby_render_basics_scene.rb 가 같은 그림을 그린다 (같은 골든).

local TILE = "./resources/tiles/tile1.png"   -- 48x48 단색 (216, 145, 37)

local function sprite(x, y, w, h, tex)
	local s = Sprite.Create(x, y, w, h, 1, tex)
	Sprite.SetSheetGrid(s, 1, 1)
	Sprite.SetCurrentFrame(s, 0)
	return s
end

function Initialize()
	TextureManager.Load(TILE, "tile")
	local tw, th = TextureManager.GetSize("tile")
	print("texsize:" .. tostring(tw) .. "x" .. tostring(th))
	print("nosize:" .. tostring(TextureManager.GetSize("missing")))

	-- 렌더 타깃: 32x16 투명 판 위에 왼쪽 빨강, 오른쪽 파랑 (뒤집기 검사의 그림)
	print("target:" .. tostring(TextureManager.CreateTarget("halves", 32, 16)))
	print("set:" .. tostring(SetRenderTarget("halves")))
	print("current:" .. tostring(GetRenderTarget()))
	draw_set_color(255, 0, 0, 255)
	FillRect(0, 0, 16, 16)
	draw_set_color(0, 0, 255, 255)
	FillRect(16, 0, 16, 16)
	SetRenderTarget(nil)
	print("after:" .. tostring(GetRenderTarget()))
	print("notarget:" .. tostring(SetRenderTarget("tile")))
	local tgw, tgh = TextureManager.GetSize("halves")
	print("targetsize:" .. tgw .. "x" .. tgh)

	-- [A] 색 입히기: 빨강만 남긴다
	tinted = sprite(32, 32, 48, 48, "tile")
	Sprite.SetColor(tinted, 255, 0, 0)
	local r, g, b = Sprite.GetColor(tinted)
	print("color:" .. r .. "," .. g .. "," .. b)

	-- [B] 뒤집기: 렌더 타깃을 2배로. 위는 그대로, 아래는 좌우로
	plain = sprite(32, 120, 32, 16, "halves")
	Sprite.SetScale(plain, 2)
	flipped = sprite(32, 170, 32, 16, "halves")
	Sprite.SetScale(flipped, 2)
	Sprite.SetFlip(flipped, true, false)
	local fx, fy = Sprite.GetFlip(flipped)
	print("flip:" .. tostring(fx) .. "," .. tostring(fy))

	-- [C] 기준점: 가운데 기준으로 (400, 100) 에 놓고 45도 돌린다
	pivoted = sprite(400, 100, 48, 48, "tile")
	Sprite.SetPivot(pivoted, 0.5, 0.5)
	Sprite.SetAngle(pivoted, 45)
	local px, py = Sprite.GetPivot(pivoted)
	print("pivot:" .. px .. "," .. py)

	-- [D] 혼합 모드: 회색 판 위에 더하기와 곱하기
	added = sprite(500, 220, 48, 48, "tile")
	Sprite.SetBlendMode(added, "add")
	multiplied = sprite(600, 220, 48, 48, "tile")
	Sprite.SetBlendMode(multiplied, "multiply")
	print("blend:" .. Sprite.GetBlendMode(added) .. "," .. Sprite.GetBlendMode(multiplied)
		.. "," .. Sprite.GetBlendMode(tinted))
	local ok, err = pcall(Sprite.SetBlendMode, added, "screen")
	print("badblend:" .. tostring(ok) .. ":" .. tostring(err):gsub("^.-: ", "", 1))

	-- [E] 글자
	print("fontReady:" .. tostring(PreparaFont("./resources/fonts/hangul.fnt")))
	print("textsize:" .. GetTextSize())
	local w32 = GetTextWidth("가나다")
	SetTextSize(64)
	print("textsize:" .. GetTextSize())
	local w64 = GetTextWidth("가나다")
	SetTextSize(0)
	print("textwidth:" .. w32 .. ":" .. w64)

	sprites = { tinted, plain, flipped, pivoted, added, multiplied }
	for _, s in ipairs(sprites) do Sprite.Update(s, 0) end
end

function Update(elapsed)
	for _, s in ipairs(sprites) do Sprite.Update(s, 0) end
end

function Render()
	-- [D] 의 회색 판 (곱하기와 더하기가 보이는 바탕)
	draw_set_color(100, 100, 100, 255)
	FillRect(490, 210, 180, 68)

	for _, s in ipairs(sprites) do Sprite.Draw(s) end

	-- [E] 빨간 글자 32px, 파란 글자 64px
	SetTextColor(255, 0, 0)
	DrawText(32, 400, "가나다")
	SetTextColor(0, 0, 255, 255)
	SetTextSize(64)
	DrawText(32, 460, "가나다")
	SetTextSize(0)
	SetTextColor(255, 255, 255)

	-- [F] 도형 (초록)
	draw_set_color(0, 128, 0, 255)
	FillRect(600, 400, 64, 32)
	DrawRect(600, 450, 64, 32)
	DrawLine(600, 500, 664, 500)
	FillCircle(632, 580, 20)
	DrawCircle(712, 580, 20)
	-- 반투명 검정 (흰 바탕 위 절반 회색)
	draw_set_color(0, 0, 0, 128)
	FillRect(600, 640, 64, 32)

	-- [G] 렌더 타깃을 그대로 두고 끝낸다. 엔진이 화면으로 되돌려야 캡처가 화면이다
	SetRenderTarget("halves")
end

function Destroy()
end
