-- auto 이벤트 여럿 사이의 조작 잠금 (M2, docs/plans/m2-rpg-events.md 5.3절)
--
-- tests/run_engine_tests.py 의 test_rpg_auto_chain 이 항구 마을 맵 파일에 auto 둘(auto1 은 AAA,
-- auto2 는 BBB 한 줄)을 더해 이 씬을 띄운다. 진짜 데모 맵 씬(game.lua)에 입력 재생기로 위쪽을
-- 누른 채 40 프레임마다 결정키를 눌러, BBB 가 닫힐 때까지 플레이어가 한 칸도 움직이지 않는지 본다.
--
--   autoA:true / autoB:true   두 auto 의 대사가 떴다
--   lockedUntilDone:true      BBB 가 닫힐 때까지 시작 칸에서 움직이지 않았다
--   movedAfter:true           그 뒤에는 위쪽으로 걸었다 (입력이 실제로 들어가고 있었다)

local Replay = require("scripts/lua/luatests/input_replay")
require("scripts/lua/games/rpgdemo/game")

function SwitchScene() end

local FRAMES = 400

local function has(lines, needle)
	for _, line in ipairs(lines or {}) do
		if tostring(line):find(needle, 1, true) ~= nil then return true end
	end
	return false
end

function Initialize()
	local replay = Replay.new({})
	replay:install()
	RpgDemoScene.init()

	local start = RpgDemoScene.status()
	print(string.format("start:%s,%s", tostring(start.tx), tostring(start.ty)))

	local seenA, seenB, done = false, false, false
	local locked, movedAfter = true, false
	local brokeAt = nil
	replay:press("UP")
	for i = 1, FRAMES do
		if i % 40 == 0 then replay:tap("Z") end
		replay:tick()
		RpgDemoScene.update(16)
		local st = RpgDemoScene.status()
		seenA = seenA or has(st.lines, "AAA")
		seenB = seenB or has(st.lines, "BBB")
		local away = st.tx ~= start.tx or st.ty ~= start.ty
		if not done then
			if st.moving or away then
				if locked then brokeAt = string.format("f%d tile=%s,%s moving=%s busy=%s", i,
					tostring(st.tx), tostring(st.ty), tostring(st.moving), tostring(st.busy)) end
				locked = false
			end
			done = seenB and not st.busy and not st.talking
		elseif away then
			movedAfter = true
		end
	end

	print("autoA:" .. tostring(seenA))
	print("autoB:" .. tostring(seenB))
	print("lockedUntilDone:" .. tostring(locked and done))
	if brokeAt ~= nil then print("brokeAt:" .. brokeAt) end
	print("movedAfter:" .. tostring(movedAfter))
	GameExit()
end

function Update() end
function Render() end
function Destroy() end
