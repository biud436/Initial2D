-- 해상도 설정 검증 씬 (1단계, docs/plans/01-engine-core.md)
-- 논리 해상도와 렌더 배율을 출력하고 즉시 종료한다. 러너가 game.json,
-- INITIAL2D_WINDOW, INITIAL2D_SCALE의 적용 여부를 stdout으로 확인한다.

function Initialize()
	print("resolution:" .. WindowWidth() .. "x" .. WindowHeight())
	print("scale:" .. GetRenderScale())

	-- 배율을 바꾸면 논리 해상도가 그만큼 줄어든다 (창 크기는 그대로)
	SetRenderScale(2)
	print("scaled2:" .. WindowWidth() .. "x" .. WindowHeight() .. " scale:" .. GetRenderScale())

	-- 범위 밖 값은 잘린다 (0 이하는 1, 상한은 16)
	SetRenderScale(0)
	print("clampLow:" .. GetRenderScale())
	SetRenderScale(999)
	print("clampHigh:" .. GetRenderScale())

	SetRenderScale(1)
	print("restored:" .. WindowWidth() .. "x" .. WindowHeight())
	GameExit()
end

function Update(elapsed) end
function Render() end
function Destroy() end
