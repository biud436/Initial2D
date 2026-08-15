-- 해상도 설정 검증 씬 (1단계, docs/plans/01-engine-core.md)
-- 논리 해상도를 출력하고 즉시 종료한다. 러너가 game.json과
-- INITIAL2D_WINDOW 환경 변수의 적용 여부를 stdout으로 확인한다.

function Initialize()
	print("resolution:" .. WindowWidth() .. "x" .. WindowHeight())
	GameExit()
end

function Update(elapsed) end
function Render() end
function Destroy() end
