-- text.lua : 글자 단위 분할과 자동 줄바꿈 (6단계에서 필요해져 먼저 만듦, 7단계가 쓴다)
--
-- 비트맵 폰트는 글자마다 폭이 다르므로 줄바꿈은 "몇 글자"가 아니라 "몇 픽셀"로
-- 재야 한다. 폭 측정 함수(엔진의 GetTextWidth)는 주입받는다 — 그래야 이 모듈이
-- 엔진 없이 단위 테스트로 검증된다 (09-testing.md 3.2절).
--
--   local Text = require("scripts/rpg/text")
--   local lines = Text.wrap("어서 오시게. 처음 보는 얼굴이군.", 360, GetTextWidth)

local M = {}

-- UTF-8 한 글자 패턴: 선두 바이트 하나 + 뒤따르는 바이트들
local CHAR_PATTERN = "[\0-\127\194-\244][\128-\191]*"

--- 문자열을 UTF-8 글자 배열로 나눈다 (한글 한 글자는 3바이트다).
function M.chars(s)
	local out = {}
	for c in tostring(s):gmatch(CHAR_PATTERN) do
		out[#out + 1] = c
	end
	return out
end

--- UTF-8 글자 수 (바이트 수가 아니다)
function M.length(s)
	local n = 0
	for _ in tostring(s):gmatch(CHAR_PATTERN) do n = n + 1 end
	return n
end

--- 앞에서 n글자만 잘라낸다 (타자 효과가 쓴다, 7단계).
function M.sub(s, n)
	if n <= 0 then return "" end
	local out, i = {}, 0
	for c in tostring(s):gmatch(CHAR_PATTERN) do
		i = i + 1
		if i > n then break end
		out[#out + 1] = c
	end
	return table.concat(out)
end

--- maxWidth 픽셀에 맞춰 줄을 나눈다.
-- 띄어쓰기에서 끊는 것을 우선하되, 한 낱말이 통째로 폭을 넘으면 글자에서 끊는다
-- (한국어는 띄어쓰기 없이 길게 이어지는 경우가 흔하다).
-- 원문의 개행(\n)은 그대로 유지한다.
-- @param measure function(text) -> 픽셀 폭
-- @return 줄 문자열 배열
function M.wrap(text, maxWidth, measure)
	assert(type(measure) == "function", "text.wrap: 폭 측정 함수가 필요하다")
	local lines = {}

	for paragraph in (tostring(text) .. "\n"):gmatch("(.-)\n") do
		if paragraph == "" then
			lines[#lines + 1] = ""
		else
			local line = ""
			local lastBreak = nil    -- 이번 줄에서 마지막으로 본 띄어쓰기 위치

			for _, c in ipairs(M.chars(paragraph)) do
				local candidate = line .. c
				if line ~= "" and maxWidth > 0 and measure(candidate) > maxWidth then
					if lastBreak ~= nil and lastBreak > 0 then
						-- 띄어쓰기까지만 이번 줄에 남기고 나머지를 다음 줄로 넘긴다
						local head = line:sub(1, lastBreak - 1)
						local tail = line:sub(lastBreak + 1)
						lines[#lines + 1] = head
						line = tail .. c
					else
						lines[#lines + 1] = line
						line = c
					end
					lastBreak = nil
					-- 새 줄의 시작에 있는 띄어쓰기는 버린다
					if line == " " then line = "" end
				else
					line = candidate
				end
				if c == " " then
					lastBreak = #line   -- 바이트 위치 (방금 붙인 공백)
				end
			end

			lines[#lines + 1] = line
		end
	end

	return lines
end

return M
