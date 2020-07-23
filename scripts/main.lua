local Font = require("scripts/Font")
local Image = require("scripts/image")
local Tilemap = require("scripts/tilemap")

function Initialize()
	
	-- -- Create background image
	background = Image("./resources/background_768x896.png", 0, 0, 768, 896, 1, "Background")

	children = {}
	math.randomseed(os.time())
	
	for i=1, 3 do
		children[i] = Image("./resources/object_52x271.png", 0, 0, 52, 271, 1, "pipe")
		children[i].setPosition(math.random(1,WindowHeight()), WindowHeight() / 2.0)
		children[i].setAngle(180.0)
	end

	player = Image("./resources/bird_276x64.png", 0, 0, 276 / 3.0, 64, 3, "Player")
	player.setPosition(0, WindowHeight() / 2 - player.getHeight() / 2)
	player.setLoop(true)
	player.setFrames(0, 3)
	player.setAnimComplete(false)
	player.setFrameDelay(15.0)

	t = 0.0
	player_power = 2.5

end

function Update(elapsed)
	t = elapsed

	background.update(t)		

	if Input.IsMousePress(0) then
		player_power = -2.5
	else
		player_power = 2.5
	end

	px, py = player.getPosition()
	player.setPosition(px, py + t * player_power)
	player.update(t)		

	for i=1, 3 do
		x, y = children[i].getPosition()
		children[i].setPosition(x + t, y)	
		children[i].update(t)			
	end	

end

function Render()
	background.draw()

	for i=1, 3 do	
		children[i].draw()
	end

	player.draw()
end

function Destroy()
	background.dispose()
	for i=1, 3 do
		children[i].dispose()
	end

	player.dispose()
end