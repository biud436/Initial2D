-- components/sample/mover.lua : 다른 오브젝트를 매 틱 옮기는 작은 컴포넌트 (씬 로더 픽스처의 예제)
--
-- node 에 붙어 props.target 이 가리키는 오브젝트를 틱마다 (dx, dy) 만큼 옮기고,
-- x 가 props.limit 에 닿으면 거기서 멈춘다. "컴포넌트는 obj.x 를 바꾸는 것으로 움직인다"의 최소 예다.

local M = {}

function M.init(obj, scene)
	obj.target = scene:find(obj.props.target)
	if obj.target == nil then
		error(string.format("mover '%s': no target '%s'", obj.id, tostring(obj.props.target)), 0)
	end
end

function M.update(obj, scene, elapsed)
	local t = obj.target
	local limit = obj.props.limit
	t.x = t.x + (obj.props.dx or 0)
	t.y = t.y + (obj.props.dy or 0)
	if limit ~= nil and t.x >= limit then t.x = limit end
end

return M
