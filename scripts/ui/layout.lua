-- 터치 컨트롤의 화면 크기 비례 배치 — 범용 UI 모듈 (T1, 순수 함수)
--
-- 기준은 화면 높이 H다. Android에서는 논리 높이가 고정(기준 높이/배율)이고
-- 가로만 기기 비율대로 늘어나므로, H 비례 크기는 곧 "화면에 비례하는 물리
-- 크기"다. DPI 조회 없이도 폰과 태블릿에서 손가락 크기가 화면과 함께 커진다.
--
-- 배치 규칙 (횡스크롤 기본형):
--   좌하단: 가상 패드 (높이의 30%)
--   우하단: 주 버튼 줄(높이의 15%, 모서리부터 안쪽으로)과 그 위 보조 버튼
--           줄(높이의 11%, 주 버튼과 세로 중심 정렬)
--   우상단: 시스템 버튼 (높이의 10%)
-- 화면이 좁아 패드와 버튼 무리가 겹칠 상황이면 전체를 같은 비율로 줄인다.
--
-- 사용:
--   local Layout = require("scripts/ui/layout")
--   local c = Layout.controls(W, H, {
--       main = { { id = "jump", label = "점프" }, { id = "attack", label = "공격" } },
--       sub  = { { id = "skill", label = "폭주" } },
--       sys  = { { id = "pause", label = "II" } },
--   })
--   pad = VirtualPad.new(c.pad)          -- { x, y, size }
--   buttons = Buttons.new{ items = c.buttons }

local M = {}

local function round(v)
	return math.floor(v + 0.5)
end

--- 화면 크기에서 컨트롤 치수를 계산한다 (전부 논리 픽셀).
function M.metrics(W, H)
	local u = H
	return {
		margin = round(0.030 * u),    -- 화면 가장자리 여백
		gap = round(0.020 * u),       -- 컨트롤 사이 간격
		pad = round(0.300 * u),       -- 가상 패드 한 변
		btnMain = round(0.150 * u),   -- 주 버튼 (점프, 공격)
		btnSub = round(0.110 * u),    -- 보조 버튼 (스킬류)
		btnSys = round(0.100 * u),    -- 시스템 버튼 (일시 정지)
	}
end

--- 컨트롤 배치. defs의 main/sub/sys는 { id, label } 목록이다 (2.1절 주석 참조).
-- 반환: { pad = { x, y, size }, buttons = { { id, label, x, y, size }, ... } }
function M.controls(W, H, defs)
	defs = defs or {}
	local main = defs.main or {}
	local sub = defs.sub or {}
	local sys = defs.sys or {}
	local m = M.metrics(W, H)

	-- 좁은 화면 방어: 패드와 주 버튼 줄이 한 줄에 다 안 들어가면 전체 축소
	local mainW = #main * m.btnMain + math.max(0, #main - 1) * m.gap
	local need = 2 * m.margin + m.pad + 2 * m.gap + mainW
	if need > W then
		local f = W / need
		for k, v in pairs(m) do
			m[k] = math.max(1, math.floor(v * f))
		end
	end

	local out = {
		pad = { x = m.margin, y = H - m.margin - m.pad, size = m.pad },
		buttons = {},
		metrics = m,
	}

	-- 주 버튼 줄: 오른쪽 모서리부터 안쪽으로
	local mainY = H - m.margin - m.btnMain
	local x = W - m.margin
	local mainCenters = {}
	for _, def in ipairs(main) do
		x = x - m.btnMain
		out.buttons[#out.buttons + 1] = {
			id = def.id, label = def.label, x = x, y = mainY, size = m.btnMain,
		}
		mainCenters[#mainCenters + 1] = x + m.btnMain / 2
		x = x - m.gap
	end

	-- 보조 버튼 줄: main[i]와 세로 중심 정렬, 남으면 이어서 왼쪽으로
	local subY = mainY - m.gap - m.btnSub
	for i, def in ipairs(sub) do
		local cx = mainCenters[i]
		if cx == nil then
			cx = (mainCenters[#mainCenters] or (W - m.margin - m.btnMain / 2))
				- (i - #mainCenters) * (m.btnMain + m.gap)
		end
		out.buttons[#out.buttons + 1] = {
			id = def.id, label = def.label,
			x = round(cx - m.btnSub / 2), y = subY, size = m.btnSub,
		}
	end

	-- 시스템 버튼: 우상단 모서리부터 안쪽으로
	x = W - m.margin
	for _, def in ipairs(sys) do
		x = x - m.btnSys
		out.buttons[#out.buttons + 1] = {
			id = def.id, label = def.label, x = x, y = m.margin, size = m.btnSys,
		}
		x = x - m.gap
	end

	return out
end

return M
