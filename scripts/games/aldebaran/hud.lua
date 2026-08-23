-- 알데바란 — HUD (기획서 8.2절): HP/MP/EXP 막대, 레벨, 목숨, 골드
--
-- 막대는 hud.png의 채움 띠를 원하는 폭만큼 잘라 그린다. 엔진의 스프라이트는
-- 만들 때의 크기를 소스 사각형 크기로 쓰므로(window.lua의 Skin과 같은 사정)
-- 폭마다 스프라이트를 하나씩 캐시한다 — 텍스처는 한 장을 같이 쓴다.

local Image = require("scripts/image")

local M = {}

local PATH = "./resources/aldebaran/hud.png"
-- hud.png의 띠와 아이콘 좌표 (tools/generate_aldebaran_assets.py의 make_hud)
local STRIP_Y = { hp = 0, mp = 8, exp = 16, bg = 24 }
local ICON = { star = { x = 66, y = 0 }, starEmpty = { x = 66, y = 12 },
	coin = { x = 66, y = 24 } }

M.BAR_W, M.BAR_H = 64, 6
M.ICON_SIZE = 10

function M.new(opts)
	opts = opts or {}
	local self = {}
	local factory = opts.imageFactory or Image
	local cache = {}

	local function image(w, h)
		local key = w .. "x" .. h
		if cache[key] == nil then
			local img = factory(PATH, 0, 0, w, h, 1, "AldebaranHud")
			img.setLoop(false)
			cache[key] = img
		end
		return cache[key]
	end

	local function piece(sx, sy, w, h, x, y, opacity)
		local img = image(w, h)
		img.setRect(sx, sy, w, h)
		img.setPosition(x, y)
		img.setOpacity(opacity or 255)
		img.update(0)
		img.draw()
	end

	--- 막대 하나: 바탕 위에 비율만큼의 채움 (0이 아니면 최소 1px)
	function self.bar(x, y, kind, ratio)
		piece(0, STRIP_Y.bg, M.BAR_W, M.BAR_H, x, y)
		local w = math.floor(math.max(0, math.min(1, ratio)) * M.BAR_W)
		if w == 0 and ratio > 0 then w = 1 end
		if w > 0 then
			piece(0, STRIP_Y[kind], w, M.BAR_H, x, y)
		end
	end

	--- 아이콘 하나 (목숨 별, 동전)
	function self.icon(x, y, name)
		local r = ICON[name]
		piece(r.x, r.y, M.ICON_SIZE, M.ICON_SIZE, x, y)
	end

	function self.dispose()
		for _, img in pairs(cache) do
			img.dispose()
			break              -- 텍스처 한 장을 같이 쓴다. 해제는 한 번만
		end
		cache = {}
	end

	return self
end

return M
