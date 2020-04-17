function Initialize()
	
	-- -- Create background image
	-- background = Image("./resources/titles/title.png", 0, 0, 640, 480, 1, "Title")

	-- -- Create button text
	buttonText = Image("./resources/titles/start_button.png" , 0, 0, 256, 30, 1, "buttonText")
	
	-- -- Create Image
	mx = WindowWidth() / 2 - buttonText.getWidth() / 2
	my = WindowHeight() / 2 - buttonText.getHeight() + WindowHeight() / 4
	buttonText.setPosition(mx, my)
	buttonText.setAngle(0.0)
	buttonText.setScale(1.0)
	buttonText.setLoop(false)
	
	-- Play background music
	Audio.PlayMusic("./resources/audio/bless.ogg", "mainBGM", true)
	
	isValid = PreparaFont("./resources/fonts/hangul.fnt")

	myElapsed = 0.0
	tt = 0

	print("hi...",  "안녕하십니까")

	tilemap = Tilemap(17, 13)
	tilemap.init()
	
end

function Update(elapsed)
	-- background.update(elapsed)
	
	buttonText.setAngle(Input.GetMouseY())
	buttonText.update(elapsed)
	
	tilemap.rotate(tt % 360)
	tilemap.update(elapsed)

	tt = tt + 1
	if tt > WindowWidth() then
		tt = 0
	end

	myElapsed = elapsed
end

function DrawTempText()
	-- Create a text
	local text = "2020년입니다~ 하하"
	myFont = Font("나눔고딕", 32, 400, 440)
	myFont.setText(text)
	
	-- myFont.setPosition(WindowWidth() - myFont.getTextWidth(text), 0)	
	myFont.setTextColor(math.floor(math.random() * 255), math.floor(math.random() * 255), math.floor(math.random() * 255))
	myFont.setOpacity( 200 )
	myFont.setAngle(tt % 360)
	myFont.setPosition(WindowWidth() / 2 - myFont.getTextWidth(text) / 2, WindowHeight() / 4)
		
	myFont.update(myElapsed)

	myFont.draw()
	myFont.dispose()
end

function Render()
	-- background.draw()
	buttonText.draw()

	tilemap.draw()
		
	DrawTempText()
		
	if isValid then 
		DrawText(100, 0, "테스트")
		frameCount = GetFrameCount()
		DrawText(0, 0, tostring(frameCount))
	end
		
end

function Destroy()
	-- background.dispose()
	buttonText.dispose()

	tilemap.dispose()

	Audio.ReleaseMusic("mainBGM")	
end