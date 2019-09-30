 function Initialize()
	
	-- 배경 이미지 생성
	background = Image("./resources/Ruins4.png", 0, 0, 640, 480, 1, "Ruins4")
	print("background")
	
	-- 캐릭터 생성
	character = Image("./resources/011-Lancer03.png", 0, 0, 32, 48, 4, "character1")
	character.setPosition(10, 50)
	character.setAngle(10.0)
	character.setScale(4.0)
	character.setLoop(true)
	character.setFrameDelay(0.5)
	print("character")
	
	Audio.PlayMusic("./resources/test.ogg", "mainBGM", true)
	print("Audio")

	nanumFont = Font("나눔고딕", 72)
	nanumFont.setText("안녕하세요?")
	nanumFont.setPosition(100, 100)
	nanumFont.setTextColor(255, 0, 0)
	
	myFont = Font("궁서체", 48)
	myFont.setText("반갑습니다.")
	myFont.setPosition(200, 200)
	myFont.setTextColor(56, 128, 110)
	myFont.setOpacity(64)
	
	-- isValid = PreparaFont("./resources/hangul.fnt");
	
end

function Update(elapsed)
	background.update(elapsed)
	character.update(elapsed)
	nanumFont.update(elapsed)
	myFont.update(elapsed)
end

function Render()
	background.draw()
	character.draw()
	nanumFont.draw()
	myFont.draw()
	
	-- if isValid then 
		-- DrawText(100, 50, "아이즈원 - 비올레타")
		-- DrawText(100, 100, [[
-- 눈 감아도 느껴지는 향기 Oh
-- 은은해서 빠져들어
-- 저 멀리 사라진 그 빛을 따라 난
-- 너에게 더 다가가 다가가 Ah ah

-- 날 보는 네 눈빛과 날 비추는 빛깔이
-- 모든 걸 멈추게 해 너를 더 빛나게 해
-- 어느 순간 내게로 조용히 스며들어 
-- 같은 꿈을 꾸게 될 테니까
		-- ]])
		-- frameCount = GetFrameCount()
		-- DrawText(0, 0, tostring(frameCount))
	-- end
	
end

function Destroy()
	background.dispose()
	character.dispose()
	nanumFont.dispose()
	myFont.dispose()
	Audio.ReleaseMusic("mainBGM")
end