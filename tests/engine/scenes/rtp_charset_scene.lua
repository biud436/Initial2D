-- RTP 변환 결과 검증 씬 (4단계) — tests/run_engine_tests.py가 구동한다.
--
-- 변환된 CharSet을 단색 배경판 위에 그려서 "팔레트 0번이 정말 투명해졌는가"를
-- 엔진 렌더링 경로로 확인한다. 파일 안의 알파 값이 맞는지는 tests/verify_rtp.py가
-- 따로 보고, 여기서는 그 알파가 화면에서 실제로 비치는지를 본다.
--
-- resources/rtp/ 는 정품 보유자의 로컬 자산이라 커밋되지 않는다. 그래서 이 씬은
-- 러너가 파일이 있을 때만 실행하며, 골든 스크린샷도 두지 않는다 (RTP 그림을
-- 저장소에 남기지 않기 위해서다).

local Image = require("scripts/image")
local Specs = require("scripts/rpg/specs")

local backdrop = nil
local actor = nil

-- 배경판: 32..416, 150..534 (assert_scene과 같은 단색 타일)
local BACK_X, BACK_Y, BACK_SCALE = 32, 150, 8
-- 캐릭터 프레임: 24x32를 8배로 → 192x256, 배경판 안에 들어간다
local CHAR_X, CHAR_Y, CHAR_SCALE = 100, 200, 8

function Initialize()
	backdrop = Image("./resources/tiles/tile1.png", 0, 0, 48, 48, 1, "backdrop")
	backdrop.setPosition(BACK_X, BACK_Y)
	backdrop.setScale(BACK_SCALE)

	local c = Specs.charset
	actor = Image("./resources/rtp/CharSet/Actor1.png", 0, 0,
		c.frameW, c.frameH, c.gridCols * c.gridRows, "rtp_char")
	actor.setSheetGrid(c.gridCols, c.gridRows)
	-- 0번 캐릭터, 정면, 서 있는 자세
	actor.setCurrentFrame(Specs.charsetFrameIndex(0, "down", 1))
	actor.setPosition(CHAR_X, CHAR_Y)
	actor.setScale(CHAR_SCALE)

	print("charsetLoaded:" .. tostring(TextureManager.IsValid("rtp_char")))
	print("charsetFrame:" .. tostring(Specs.charsetFrameIndex(0, "down", 1)))
end

function Update(elapsed)
	backdrop.update(0)
	actor.update(0)
end

function Render()
	backdrop.draw()
	actor.draw()
end

function Destroy()
end
