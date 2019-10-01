function Font(font_face, font_size)

	local self = {}
	
	self.objectId = nil
	local isReady = false
		
	function self.create(font_face, font_size)
		self.objectId = FontEx.Create(font_face, font_size)
		if self.objectId ~= 0 then
			isReady = true
		end
	end
	
	function self.update(elapsed)
		if isReady == false then return end		
		FontEx.Update(self.objectId, elapsed)
	end
	
	function self.draw()
		if isReady == false then return end		
		FontEx.Draw(self.objectId)
	end
	
	function self.dispose()
		if isReady == false then return end
		FontEx.Dispose(self.objectId)
	end

	function self.setPosition(x, y)
		if isReady == false then return end
		FontEx.SetPosition(self.objectId, x, y)
	end
		
	function self.setText(text)
		if isReady == false then return end
		FontEx.SetText(self.objectId, text)
	end				

	function self.setTextColor(red, green, blue)
		if isReady == false then return end
		FontEx.SetTextColor(self.objectId, red, green, blue)
	end

	function self.setOpacity(value)
		if isReady == false then return end
		FontEx.SetOpacity(self.objectId, value)
	end
	
	self.create(font_face, font_size)
	
	return self
	
end