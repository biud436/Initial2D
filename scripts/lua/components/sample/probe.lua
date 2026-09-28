-- components/sample/probe.lua : 받은 params 를 오브젝트에 적어 두는 컴포넌트 (씬 로더 params 픽스처)
--
-- 선언(scripts/components/sample/probe.json)에 필드 타입 일곱이 다 있다. init 에서 받은 params 표를
-- obj.probes 에 모으고, 훅마다 받은 params 의 title 을 obj.probeLog 에 "훅=제목" 으로 적는다.

local M = {}

local function log(obj, hook, params)
	obj.probeLog = obj.probeLog or {}
	obj.probeLog[#obj.probeLog + 1] = hook .. "=" .. tostring(params and params.title)
end

function M.init(obj, scene, params)
	obj.probes = obj.probes or {}
	obj.probes[#obj.probes + 1] = params
	log(obj, "init", params)
end

function M.update(obj, scene, elapsed, params)
	if not obj.probeUpdated then
		obj.probeUpdated = true
		log(obj, "update", params)
	end
end

function M.render(obj, scene, params)
	if not obj.probeRendered then
		obj.probeRendered = true
		log(obj, "render", params)
	end
end

function M.destroy(obj, scene, params)
	log(obj, "destroy", params)
end

return M
