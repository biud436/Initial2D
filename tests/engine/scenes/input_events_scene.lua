-- 입력 경로 검증 씬 (tests/run_engine_tests.py 의 test_input_events_lua 가 구동)
--
-- 러너가 INITIAL2D_TEST_EVENTS 로 SDL 마우스 이벤트 다섯 개를 넣는다. 이 씬은 입력이 있는 틱마다
-- 한 줄을 찍고, 다섯 번째 뒤에 SetMouseZ 를 확인한 다음 끝낸다.

local tick = 0
local seen = 0
local setTick = nil

function Initialize() end

function Update(elapsed)
	tick = tick + 1
	local anyMouse = Input.IsAnyMouseDown()
	local left = Input.IsMouseDown(0)
	local anyKey = Input.IsAnyKeyDown()
	local wheel = Input.GetMouseZ()
	if anyMouse or left or anyKey or wheel ~= 0 then
		seen = seen + 1
		print(string.format("input:any_mouse=%s left=%s any_key=%s wheel=%d",
			tostring(anyMouse), tostring(left), tostring(anyKey), wheel))
		return
	end

	if setTick == nil and seen >= 5 then
		setTick = tick
		Input.SetMouseZ(7)
		print("input:set_wheel=" .. Input.GetMouseZ())
	elseif setTick ~= nil and tick == setTick + 1 then
		print("input:after_set_wheel=" .. Input.GetMouseZ())
		GameExit()
	end
end

function Render() end
function Destroy() end
