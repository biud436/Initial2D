-- sprite_sheet.lua : 스프라이트 시트 파일(시트 포맷 v1)을 읽고 이름 있는 클립을 재생한다
-- (엔진 2, docs/plans/engine2-sprite-sheets.md). Ruby 판은 scripts/ruby/sprite_sheet.rb 이고 같은 파일을
-- 같은 규칙으로 읽는다. 씬 로더는 sprite 의 props.sheet 를 이 모듈로 연다.
--
--   local SpriteSheet = require("scripts/lua/sprite_sheet")
--   local sheet = SpriteSheet.load("resources/bird.sprite.json")
--   local anim = sheet:animator()
--   anim:play("fly")
--   anim:update(elapsed)      -- ms
--   anim:apply(sprite)        -- 지금 프레임의 칸과 기준점을 Sprite 핸들에 옮긴다
--
-- 프레임 번호는 0 부터 왼쪽에서 오른쪽, 위에서 아래로 센다. 열과 행의 수는 이미지 크기에서 나온다.

local SpriteSheet = {}

SpriteSheet.VERSION = 1
SpriteSheet.DEFAULT_DURATION = 100   -- ms. 씬 로더의 frameDelay 기본값과 같다
SpriteSheet.LOOP_MODES = { "loop", "once", "pingpong" }

local LOOP = { loop = true, once = true, pingpong = true }

local cache = {}   -- 경로 -> 읽은 시트. 시트는 읽은 뒤 바뀌지 않으므로 오브젝트끼리 나눠 쓴다

local Sheet = {}
Sheet.__index = Sheet

local Animator = {}
Animator.__index = Animator

-- ---------------------------------------------------------------------------
-- 도우미
-- ---------------------------------------------------------------------------

-- 프로젝트 루트 기준 상대 경로에 "./" 를 붙인다 (절대 경로와 이미 "./" 인 것은 그대로)
local function resolvePath(p)
	if p:sub(1, 1) == "/" or p:sub(1, 2) == "./" or p:match("^%a:") then return p end
	return "./" .. p
end

-- PNG 헤더(IHDR)에서 이미지 크기를 읽는다
local function pngSize(path)
	local f = io.open(path, "rb")
	if not f then return nil end
	local head = f:read(24)
	f:close()
	if not head or #head < 24 or head:sub(1, 8) ~= "\137PNG\r\n\26\n" then return nil end
	local b = { head:byte(17, 24) }
	local w = ((b[1] * 256 + b[2]) * 256 + b[3]) * 256 + b[4]
	local h = ((b[5] * 256 + b[6]) * 256 + b[7]) * 256 + b[8]
	return w, h
end

local function isInteger(v)
	return type(v) == "number" and v == math.floor(v)
end

-- JSON 객체인가: 키가 전부 문자열인 표. 빈 표도 된다 (Json.Load 는 [] 과 {} 를 같은 빈 표로 읽는다).
local function isObject(v)
	if type(v) ~= "table" then return false end
	for k in pairs(v) do
		if type(k) ~= "string" then return false end
	end
	return true
end

-- JSON 배열인가: 키가 정확히 1..n 인 표. 빈 표도 된다.
local function isArray(v)
	if type(v) ~= "table" then return false end
	local n = 0
	for k in pairs(v) do
		if math.type(k) ~= "integer" or k < 1 then return false end
		n = n + 1
	end
	return n == #v
end

local function isPivot(v)
	return isArray(v) and #v == 2 and type(v[1]) == "number" and type(v[2]) == "number"
end

local function sortedKeys(t)
	local keys = {}
	for k in pairs(t) do keys[#keys + 1] = k end
	table.sort(keys)
	return keys
end

-- 메시지 속의 값: 정수 값이면 정수로, 다른 숫자는 유효 숫자 14자리, 숫자가 아니면 tostring
local function valueText(v)
	if type(v) ~= "number" then return tostring(v) end
	if v == math.floor(v) and math.abs(v) < 1e15 then return string.format("%d", v) end
	return string.format("%.14g", v)
end

-- 오류 메시지 끝에 붙이는 파일 경로
local function where(path)
	return path and (" (" .. path .. ")") or ""
end

local function fail(path, fmt, ...)
	error("sheet: " .. string.format(fmt, ...) .. where(path), 0)
end

-- ---------------------------------------------------------------------------
-- 검사 (파일을 열지 않는 모양 검사. 이미지 크기가 드는 검사는 fromTable 이 한다)
-- ---------------------------------------------------------------------------

local function checkClip(name, c)
	local label = string.format("clip '%s'", name)
	if not isObject(c) then return label .. " must be an object" end
	local frames = c.frames
	if not isArray(frames) or #frames == 0 then
		return label .. " needs frames (a non-empty array)"
	end
	for i, f in ipairs(frames) do
		if not isInteger(f) or f < 0 then
			return string.format("%s frames[%d] must be an integer >= 0", label, i)
		end
	end
	local d = c.duration
	if d ~= nil then
		if type(d) == "number" then
			if d <= 0 then return label .. " duration must be a number > 0 or an array of them" end
		elseif isArray(d) and #d > 0 then
			if #d ~= #frames then
				return string.format("%s duration needs %d values (one per frame), got %d", label, #frames, #d)
			end
			for i, x in ipairs(d) do
				if type(x) ~= "number" or x <= 0 then
					return string.format("%s duration[%d] must be a number > 0", label, i)
				end
			end
		else
			return label .. " duration must be a number > 0 or an array of them"
		end
	end
	if c.loop ~= nil and not LOOP[c.loop] then
		return label .. ' loop must be "loop", "once" or "pingpong"'
	end
	if c.pivot ~= nil and not isPivot(c.pivot) then
		return label .. " pivot must be [x, y]"
	end
	return nil
end

-- 시트 표를 검사한다. ok, err 를 돌려준다 (err 는 "sheet: ..." 으로 시작한다).
function SpriteSheet.validate(tbl)
	if not isObject(tbl) then return false, "sheet: not an object" end
	if tbl.version ~= SpriteSheet.VERSION then
		return false, string.format("sheet: unsupported version %s (expected %d)",
			valueText(tbl.version), SpriteSheet.VERSION)
	end
	if type(tbl.image) ~= "string" or tbl.image == "" then
		return false, "sheet: image must be a non-empty string"
	end
	for _, k in ipairs({ "frameWidth", "frameHeight" }) do
		local v = tbl[k]
		if not isInteger(v) or v < 1 then return false, "sheet: " .. k .. " must be an integer >= 1" end
	end
	for _, k in ipairs({ "margin", "spacing" }) do
		local v = tbl[k]
		if v ~= nil and (not isInteger(v) or v < 0) then
			return false, "sheet: " .. k .. " must be an integer >= 0"
		end
	end
	if tbl.pivot ~= nil and not isPivot(tbl.pivot) then
		return false, "sheet: pivot must be [x, y]"
	end
	if tbl.clips ~= nil and not isObject(tbl.clips) then
		return false, "sheet: clips must be an object"
	end
	local clips = tbl.clips or {}
	for _, name in ipairs(sortedKeys(clips)) do
		if name == "" then return false, "sheet: clip names must not be empty" end
		local err = checkClip(name, clips[name])
		if err then return false, "sheet: " .. err end
	end
	local dc = tbl.defaultClip
	if dc ~= nil then
		if type(dc) ~= "string" then return false, "sheet: defaultClip must be a string" end
		if dc ~= "" and clips[dc] == nil then
			return false, string.format("sheet: defaultClip '%s' is not a clip", dc)
		end
	end
	return true
end

-- ---------------------------------------------------------------------------
-- 읽기
-- ---------------------------------------------------------------------------

-- 이미 읽은 표에서 시트를 만든다. path 는 오류 메시지와 sheet.path 에만 쓴다 (없어도 된다).
-- 이미지 크기는 image 의 PNG 헤더에서 읽는다.
function SpriteSheet.fromTable(tbl, path)
	local ok, err = SpriteSheet.validate(tbl)
	if not ok then error(err .. where(path), 0) end

	local iw, ih = pngSize(resolvePath(tbl.image))
	if not iw then fail(path, "cannot read the size of %s", tbl.image) end
	local fw, fh = math.floor(tbl.frameWidth), math.floor(tbl.frameHeight)
	local margin, spacing = math.floor(tbl.margin or 0), math.floor(tbl.spacing or 0)
	local columns = (iw - 2 * margin + spacing) // (fw + spacing)
	local rows = (ih - 2 * margin + spacing) // (fh + spacing)
	if columns < 1 or rows < 1 then
		fail(path, "%s is %dx%d, too small for one %dx%d frame", tbl.image, iw, ih, fw, fh)
	end
	local count = columns * rows

	local clips = {}
	for _, name in ipairs(sortedKeys(tbl.clips or {})) do
		local c = tbl.clips[name]
		local frames, durations = {}, {}
		for i, f in ipairs(c.frames) do
			if f >= count then
				fail(path, "clip '%s' frames[%d] is %s, but the sheet has %d frames", name, i, valueText(f), count)
			end
			frames[i] = math.floor(f)
			if type(c.duration) == "table" then
				durations[i] = c.duration[i]
			else
				durations[i] = c.duration or SpriteSheet.DEFAULT_DURATION
			end
		end
		local loop = c.loop or "loop"
		-- 재생 순서 (frames 의 자리). pingpong 은 끝에서 돌아오되 양 끝을 두 번 보이지 않는다: 0 1 2 1 0 1 2 1 ...
		local order = {}
		for i = 1, #frames do order[i] = i end
		if loop == "pingpong" then
			for i = #frames - 1, 2, -1 do order[#order + 1] = i end
		end
		local cycle = 0
		for _, i in ipairs(order) do cycle = cycle + durations[i] end
		clips[name] = {
			name = name, frames = frames, durations = durations, loop = loop, order = order, cycle = cycle,
			pivotX = c.pivot and c.pivot[1] or nil, pivotY = c.pivot and c.pivot[2] or nil,
		}
	end

	local dc = tbl.defaultClip
	return setmetatable({
		path = path,
		image = tbl.image,
		imageWidth = iw,
		imageHeight = ih,
		frameWidth = fw,
		frameHeight = fh,
		margin = margin,
		spacing = spacing,
		columns = columns,
		rows = rows,
		frameCount = count,
		pivotX = tbl.pivot and tbl.pivot[1] or 0,
		pivotY = tbl.pivot and tbl.pivot[2] or 0,
		defaultClip = (dc ~= nil and dc ~= "") and dc or nil,
		clips = clips,
		source = tbl,
	}, Sheet)
end

-- 시트 파일을 읽는다. 같은 경로는 한 번만 읽는다 (SpriteSheet.clearCache 로 비운다).
function SpriteSheet.load(path)
	if type(path) ~= "string" or path == "" then error("sheet: load needs a path", 0) end
	local sheet = cache[path]
	if sheet then return sheet end
	local data, err = Json.Load(resolvePath(path))
	if data == nil then
		error(string.format("sheet: cannot open %s (%s)", path, tostring(err)), 0)
	end
	sheet = SpriteSheet.fromTable(data, path)
	cache[path] = sheet
	return sheet
end

function SpriteSheet.clearCache()
	cache = {}
end

-- ---------------------------------------------------------------------------
-- 시트
-- ---------------------------------------------------------------------------

-- 프레임 n 의 칸: x, y, w, h (이미지 픽셀)
function Sheet:frameRect(n)
	if not isInteger(n) or n < 0 or n >= self.frameCount then
		fail(self.path, "frame %s is outside the sheet (%d frames)", valueText(n), self.frameCount)
	end
	n = math.floor(n)
	local col, row = n % self.columns, n // self.columns
	return self.margin + col * (self.frameWidth + self.spacing),
		self.margin + row * (self.frameHeight + self.spacing),
		self.frameWidth, self.frameHeight
end

-- 클립 표 (name, frames, durations, loop, pivotX, pivotY). 없으면 nil
function Sheet:clip(name)
	return self.clips[name]
end

-- 클립 이름 목록 (정렬)
function Sheet:clipNames()
	return sortedKeys(self.clips)
end

-- 이 시트의 클립을 트는 재생기. 오브젝트마다 하나씩 만든다 (시트는 나눠 쓰고 재생 상태만 따로 둔다).
function Sheet:animator()
	return setmetatable({ sheet = self, _clip = nil, _step = 1, _time = 0, _done = false }, Animator)
end

-- ---------------------------------------------------------------------------
-- 재생기
-- ---------------------------------------------------------------------------

-- 클립을 처음부터 튼다. 같은 클립이어도 처음으로 돌아간다. nil 이면 클립을 내리고 0 번 프레임을 보인다.
function Animator:play(name)
	if name == nil then
		self._clip = nil
	else
		local c = self.sheet.clips[name]
		if c == nil then fail(self.sheet.path, "no clip '%s'", tostring(name)) end
		self._clip = c
	end
	self._step, self._time, self._done = 1, 0, false
	return self
end

-- 지금 클립을 처음부터 다시 튼다
function Animator:restart()
	self._step, self._time, self._done = 1, 0, false
	return self
end

-- 시간을 ms 만큼 보낸다. 프레임 시간이 다 차면 다음 프레임으로 가고, 한 번에 여러 프레임을 넘을 수 있다.
-- once 는 마지막 프레임의 시간이 다 차면 끝나고(isDone) 그 프레임에 머문다.
function Animator:update(ms)
	local c = self._clip
	if c == nil or self._done or type(ms) ~= "number" or ms <= 0 then return self end
	self._time = self._time + ms
	if c.loop ~= "once" and self._time >= c.cycle then
		self._time = self._time % c.cycle   -- 한 바퀴는 같은 자리로 돌아온다
	end
	local n = #c.order
	while true do
		local d = c.durations[c.order[self._step]]
		if self._time < d then break end
		if self._step < n then
			self._time = self._time - d
			self._step = self._step + 1
		elseif c.loop == "once" then
			self._time = d
			self._done = true
			break
		else
			self._time = self._time - d
			self._step = 1
		end
	end
	return self
end

-- 지금 클립 이름 (없으면 nil)
function Animator:clip()
	return self._clip and self._clip.name or nil
end

-- 지금 보이는 시트의 프레임 번호 (클립이 없으면 0)
function Animator:frame()
	local c = self._clip
	if c == nil then return 0 end
	return c.frames[c.order[self._step]]
end

-- once 클립이 끝났는가 (loop, pingpong 은 늘 false)
function Animator:isDone()
	return self._done
end

-- 기준점: 클립의 pivot, 없으면 시트의 pivot, 그것도 없으면 0, 0
function Animator:pivot()
	local c = self._clip
	if c and c.pivotX ~= nil then return c.pivotX, c.pivotY end
	return self.sheet.pivotX, self.sheet.pivotY
end

-- 지금 프레임의 칸: x, y, w, h
function Animator:rect()
	return self.sheet:frameRect(self:frame())
end

-- 지금 프레임의 칸과 기준점을 스프라이트에 옮긴다. 스프라이트는 프레임 크기로 만든 것이어야 한다.
function Animator:apply(sprite)
	local x, y, w, h = self:rect()
	Sprite.SetRect(sprite, x, y, w, h)
	Sprite.SetPivot(sprite, self:pivot())
	return self
end

return SpriteSheet
