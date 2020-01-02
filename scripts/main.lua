 function Initialize()
	
	-- Create background image
	background = Image("./resources/titles/title.png", 0, 0, 640, 480, 1, "Title")

	-- Create button text
	buttonText = Image("./resources/titles/start_button.png" , 0, 0, 256, 30, 1, "buttonText")
	
	-- Create Image
	mx = WindowWidth() / 2 - buttonText.getWidth() / 2
	my = WindowHeight() / 2 - buttonText.getHeight() + WindowHeight() / 4
	buttonText.setPosition(mx, my)
	buttonText.setAngle(0.0)
	buttonText.setScale(1.0)
	buttonText.setLoop(false)
	
	-- Play background music
	Audio.PlayMusic("./resources/audio/bless.ogg", "mainBGM", true)
	
	isValid = PreparaFont("./resources/fonts/hangul.fnt")
	
end

function Update(elapsed)
	background.update(elapsed)
	
	buttonText.setAngle(Input.GetMouseY())
	
	buttonText.update(elapsed)
end

function DrawTempText()
	-- Create a text
	local text = "2020년입니다~ 하하"
	myFont = Font("나눔고딕", 32)
	myFont.setText(text)
	-- myFont.setPosition(WindowWidth() - myFont.getTextWidth(text), 0)	
	myFont.setPosition(WindowWidth() / 2, WindowHeight() / 2)
	
	myFont.setTextColor(math.floor(math.random() * 255), math.floor(math.random() * 255), math.floor(math.random() * 255))
	myFont.setOpacity( 255 )
	myFont.update(0.0)
	myFont.draw()
	myFont.dispose()	
end

function Render()
	background.draw()
	buttonText.draw()
		
	DrawTempText()
		
	if isValid then 
		DrawText(100, 0, "테스트")
		frameCount = GetFrameCount()
		DrawText(0, 0, tostring(frameCount))
	end
		
end

function Destroy()
	background.dispose()
	buttonText.dispose()
	Audio.ReleaseMusic("mainBGM")
end