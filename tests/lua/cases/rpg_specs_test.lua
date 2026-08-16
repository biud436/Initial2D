-- rpg_specs_test.lua : R2K3 리소스 규격 데이터(scripts/rpg/specs.lua) 검증.
-- 엔진 없이 도는 순수 로직이다. 규격 값이 서로 어긋나거나(시트 크기와 분할이
-- 맞지 않는 등) 프레임 좌표 계산이 틀어지면 여기서 잡힌다.

local M = {}

function M.run(t)
	local S = require("scripts/rpg/specs")

	-- [1] 시트 크기와 분할의 정합성 — 하나만 바꿔도 여기서 깨진다
	local c = S.charset
	t.check_eq(c.sheetCols * c.blockW, c.sheetW, "CharSet: 블록 4열이 시트 폭과 같다")
	t.check_eq(c.sheetRows * c.blockH, c.sheetH, "CharSet: 블록 2행이 시트 높이와 같다")
	t.check_eq(c.sheetCols * c.sheetRows, c.perSheet, "CharSet: 시트당 캐릭터 8명")
	t.check_eq(c.patterns * c.frameW, c.blockW, "CharSet: 3프레임이 블록 폭과 같다")
	t.check_eq(c.dirs * c.frameH, c.blockH, "CharSet: 4방향이 블록 높이와 같다")
	t.check_eq(c.sheetW / c.frameW, c.gridCols, "CharSet: 24x32 격자는 12열")
	t.check_eq(c.sheetH / c.frameH, c.gridRows, "CharSet: 24x32 격자는 8행")

	local f = S.faceset
	t.check_eq(f.cols * f.size, f.sheetW, "FaceSet: 4열이 시트 폭과 같다")
	t.check_eq(f.rows * f.size, f.sheetH, "FaceSet: 4행이 시트 높이와 같다")
	t.check_eq(f.cols * f.rows, f.perSheet, "FaceSet: 시트당 얼굴 16개")

	local cs = S.chipset
	t.check_eq(cs.columns * cs.tile, cs.sheetW, "ChipSet: 30열이 시트 폭과 같다")
	t.check_eq(cs.rows * cs.tile, cs.sheetH, "ChipSet: 16행이 시트 높이와 같다")

	-- [2] 방향 행: 이름 4개가 0..3에 하나씩 배정된다
	local seen = {}
	local count = 0
	for name, row in pairs(c.dirRows) do
		t.check(row >= 0 and row < c.dirs, "방향 행 범위: " .. name, tostring(row))
		t.check(seen[row] == nil, "방향 행 중복 없음: " .. name, tostring(row))
		seen[row] = name
		count = count + 1
	end
	t.check_eq(count, c.dirs, "방향은 4개")
	t.check_eq(seen[0], "up", "0행은 위 (뒤통수)")
	t.check_eq(seen[2], "down", "2행은 아래 (정면)")

	-- [3] 프레임 좌표: 손으로 계산한 값과 대조
	local x, y, w, h = S.charsetFrameRect(0, "down", 1)
	t.check_eq(x, 24, "0번 캐릭터 아래 방향 가운데 프레임 x")
	t.check_eq(y, 64, "0번 캐릭터 아래 방향 가운데 프레임 y")
	t.check_eq(w, 24, "프레임 폭")
	t.check_eq(h, 32, "프레임 높이")

	-- 5번 캐릭터 = 2행 2열 블록 → (72*1, 128*1) 기준
	x, y = S.charsetFrameRect(5, "left", 2)
	t.check_eq(x, 72 + 48, "5번 캐릭터 왼쪽 방향 세 번째 프레임 x")
	t.check_eq(y, 128 + 96, "5번 캐릭터 왼쪽 방향 세 번째 프레임 y")

	-- 시트 안의 모든 프레임이 시트 밖으로 나가지 않는다
	for i = 0, c.perSheet - 1 do
		for _, dir in ipairs({ "up", "right", "down", "left" }) do
			for p = 0, c.patterns - 1 do
				local fx, fy = S.charsetFrameRect(i, dir, p)
				t.check(fx >= 0 and fx + c.frameW <= c.sheetW and
					fy >= 0 and fy + c.frameH <= c.sheetH,
					string.format("프레임이 시트 안에 있다 (%d,%s,%d)", i, dir, p),
					fx .. "," .. fy)
			end
		end
	end

	-- [4] 격자 프레임 번호: 좌표와 같은 칸을 가리킨다
	t.check_eq(S.charsetFrameIndex(0, "down", 1), 25, "0번 아래 가운데 = 2행 1열 = 25")
	t.check_eq(S.charsetFrameIndex(0, "up", 0), 0, "0번 위 첫 프레임 = 0")
	-- 7번 캐릭터는 블록 (3열, 1행) → 픽셀 (216,128), 왼쪽(3행) 세 번째 프레임 → (264,224)
	-- 격자로는 (224/32)행 (264/24)열 = 7행 11열 = 95
	t.check_eq(S.charsetFrameIndex(7, "left", 2), 95, "7번 왼쪽 마지막 프레임 = 95")
	for i = 0, c.perSheet - 1 do
		for _, dir in ipairs({ "up", "right", "down", "left" }) do
			for p = 0, c.patterns - 1 do
				local idx = S.charsetFrameIndex(i, dir, p)
				t.check(math.type(idx) == "integer" and idx >= 0 and idx < c.gridCols * c.gridRows,
					string.format("격자 번호가 정수 범위 (%d,%s,%d)", i, dir, p), tostring(idx))
			end
		end
	end

	-- [5] 걷기 열 순서: 0,1,2,1 이 반복되고 가운데(서기)로 돌아온다
	t.check_eq(S.walkPatternAt(0), 0, "걸음 0")
	t.check_eq(S.walkPatternAt(1), 1, "걸음 1 (서기)")
	t.check_eq(S.walkPatternAt(2), 2, "걸음 2")
	t.check_eq(S.walkPatternAt(3), 1, "걸음 3 (서기로 복귀)")
	t.check_eq(S.walkPatternAt(4), 0, "걸음 4는 다시 처음")
	t.check_eq(S.walkPatternAt(103), S.walkPatternAt(3), "큰 값도 주기가 같다")

	-- [6] FaceSet과 ChipSet 좌표
	local fx, fy, fw = S.facesetRect(0)
	t.check(fx == 0 and fy == 0 and fw == 48, "0번 얼굴은 좌상단 48x48")
	fx, fy = S.facesetRect(15)
	t.check(fx == 144 and fy == 144, "15번 얼굴은 우하단")
	local tx, ty = S.chipsetTileRect(30)
	t.check(tx == 0 and ty == 16, "30번 타일은 두 번째 줄 처음")

	-- [7] 글자색 견본 20개가 팔레트 영역 안에 있다
	local W = S.window
	for i = 0, W.textColors.count - 1 do
		local cx, cy, cw, ch = S.textColorRect(i)
		t.check(cx >= 0 and cx + cw <= W.skinW and cy >= 0 and cy + ch <= W.skinH,
			"글자색 견본이 스킨 안에 있다: " .. i, cx .. "," .. cy)
	end

	-- [8] 잘못된 입력은 조용히 틀린 값을 주는 대신 오류를 낸다
	t.check(pcall(S.charsetFrameRect, 8, "down", 0) == false, "캐릭터 번호 범위 밖은 오류")
	t.check(pcall(S.charsetFrameRect, 0, "diagonal", 0) == false, "모르는 방향은 오류")
	t.check(pcall(S.charsetFrameRect, 0, "down", 3) == false, "프레임 번호 범위 밖은 오류")
	t.check(pcall(S.facesetRect, 16) == false, "얼굴 번호 범위 밖은 오류")
end

return M
