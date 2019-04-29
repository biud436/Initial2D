 function Initialize()
	
	-- 배경 이미지 생성
	background = Image("./resources/Ruins4.png", 0, 0, 640, 480, 1, "Ruins4")
	
	-- 캐릭터 생성
	character = Image("./resources/011-Lancer03.png", 0, 0, 32, 48, 4, "character1")
	character.setPosition(10, 50)
	character.setAngle(10.0)
	character.setScale(4.0)
	character.setLoop(true)
	character.setFrameDelay(0.5)
	
	Audio.PlayMusic("./resources/test.ogg", "mainBGM", true)
	
	isValid = PreparaFont("./resources/hangul.fnt");
	
end

function Update(elapsed)
	background.update(elapsed)
	character.update(elapsed)
end

function Render()
	background.draw()
	character.draw()
	
	if isValid then 
		DrawText(100, 50, "Hello")
		DrawText(100, 100, "안녕하세요? 러닝은빛입니다.\n반가워요...")
		frameCount = GetFrameCount()
		DrawText(0, 0, tostring(frameCount))
	end
	
end

function Destroy()
	background.dispose()
	character.dispose()
	Audio.ReleaseMusic("mainBGM")
end