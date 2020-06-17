
function Tilemap(width, height)

    local self = {}
    
    self.width = width
    self.height = height
    self.data = {}
    self.children = {}   
    self.config = {}     
    
    function self.create(width, height)
        self.width = width
        self.height = height 
    end

    function self.init()
        local w = self.width
        local h = self.height
    
        for y = 0, w, 1 do 
            for x = 0, h, 1 do
                self.data[y * w + x] = 0
            end
        end
    
        self.loadConfig()
        self.createTiles()
    end

    function self.loadConfig()		
		self.config = require("resources/maps/map")
		
        for k, v in pairs(self.config) do
            print(string.format("%s - %s", k, v))
        end

    end
    
    function self.createTiles()
    
        local w = self.width
        local h = self.height 
        local id = 0

        for y = 0, h, 1 do
            for x = 0, w, 1 do
                local tileId = self.data[y * w + x] or 0
                
                    local path = "./resources/tiles/tile1.png"
                    local tile = Image(path, 0, 0, 48, 48, 1, "tile"..id)
                    local x = x * 48
                    local y = y * 48
    
                    tile.setLoop(false)
                    tile.setPosition(x, y)
                    tile.setOpacity(128)
                    tile.setAngle(12.0 * (x + y))
    
                    table.insert(self.children, tile)

                    id = id + 1
            end
        end
    
    end
    
    function self.update(elapsed)
        for k, child in pairs(self.children) do
            if child then
                child.update(elapsed)
            end
        end
    end

    function self.rotate(degree)
        for k, child in pairs(self.children) do
            if child then
                child.setAngle(degree)
            end
        end        
    end
    
    function self.draw()
        for k, child in pairs(self.children) do
            if child then
                child.draw()
            end
        end    
    end
    
    function self.dispose()
        for k, child in pairs(self.children) do
            if child then
                child.dispose()
            end
        end        
    end
    
    self.create(width, height)
	
    return self

end

return Tilemap