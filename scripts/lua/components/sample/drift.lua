-- components/sample/drift.lua : params.target 이 가리키는 오브젝트를 매 틱 (dx, dy) 만큼 옮기는 컴포넌트
--
-- 선언은 scripts/components/sample/drift.json (target 은 object, dx 기본 1, dy 기본 0).

local M = {}

function M.update(obj, scene, elapsed, params)
	local target = params.target and scene:find(params.target)
	if target == nil then return end
	target.x = target.x + params.dx
	target.y = target.y + params.dy
end

return M
