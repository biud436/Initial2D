
function SceneBase(font_face, font_size, width, height)

	local self = {}
	
	local isReady = false
		
    function self.create()
        isReady = true
	end
	
	function self.update(elapsed)
		if isReady == false then return end		
	end
	
	function self.draw()
		if isReady == false then return end		
	end
	
	function self.dispose()
		if isReady == false then return end
	end
	
	self.create()
	
	return self
	
end

return SceneBase