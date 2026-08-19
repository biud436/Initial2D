-- bgm_test.lua : 배경음 층(scripts/bgm.lua) 검증 (8단계).
-- 곡이 바뀔 때만 다시 걸리는가가 핵심이다 — 이게 깨지면 맵을 오갈 때마다
-- 같은 곡이 처음부터 다시 시작한다.

local M = {}

--- 호출을 기록하는 가짜 Audio
local function fakeAudio()
	local a = { calls = {} }
	function a.PlayMusic(path, id, loop)
		a.calls[#a.calls + 1] = { "play", path, id, loop }
	end
	function a.SetVolume(v) a.calls[#a.calls + 1] = { "volume", v } end
	function a.StopMusic() a.calls[#a.calls + 1] = { "stop" } end
	function a.ReleaseMusic(id) a.calls[#a.calls + 1] = { "release", id } end
	function a.count(kind)
		local n = 0
		for _, c in ipairs(a.calls) do
			if c[1] == kind then n = n + 1 end
		end
		return n
	end
	return a
end

function M.run(t)
	local Bgm = require("scripts/bgm")

	-- [1] 같은 곡을 여러 번 걸어도 한 번만 재생된다
	local a = fakeAudio()
	Bgm.bind(a)
	Bgm.forget()

	t.check_eq(Bgm.play("./a.ogg"), true, "처음 거는 곡은 재생된다")
	t.check_eq(Bgm.play("./a.ogg"), false, "같은 곡은 다시 걸지 않는다")
	t.check_eq(Bgm.play("./a.ogg"), false, "몇 번을 불러도 마찬가지")
	t.check_eq(a.count("play"), 1, "PlayMusic은 한 번만")
	t.check_eq(Bgm.current(), "./a.ogg", "현재 곡을 기억한다")

	-- [2] 다른 곡이면 다시 건다
	t.check_eq(Bgm.play("./b.ogg"), true, "곡이 바뀌면 재생한다")
	t.check_eq(a.count("play"), 2, "두 번째 PlayMusic")
	t.check_eq(Bgm.current(), "./b.ogg", "현재 곡 갱신")

	-- [3] force면 같은 곡도 처음부터
	t.check_eq(Bgm.play("./b.ogg", { force = true }), true, "force는 같은 곡도 다시 건다")
	t.check_eq(a.count("play"), 3, "force로 세 번째 PlayMusic")

	-- [4] nil 경로는 무동작 (곡 없는 맵)
	t.check_eq(Bgm.play(nil), false, "곡이 없으면 아무것도 하지 않는다")
	t.check_eq(a.count("play"), 3, "PlayMusic이 늘지 않는다")
	t.check_eq(Bgm.current(), "./b.ogg", "걸려 있던 곡은 그대로")

	-- [5] 인자 전달: id, loop, volume
	local a2 = fakeAudio()
	Bgm.bind(a2)
	Bgm.forget()
	Bgm.play("./c.ogg", { id = "town", loop = false, volume = 64 })
	local call = a2.calls[1]
	t.check_eq(call[2], "./c.ogg", "경로 전달")
	t.check_eq(call[3], "town", "id 전달")
	t.check_eq(call[4], false, "loop 전달")
	t.check_eq(a2.calls[2][2], 64, "볼륨 전달")

	-- 같은 곡이어도 볼륨만 바꿀 수 있다
	Bgm.play("./c.ogg", { volume = 100 })
	t.check_eq(a2.calls[3][1], "volume", "같은 곡에는 볼륨만 다시 준다")
	t.check_eq(a2.calls[3][2], 100, "새 볼륨")
	t.check_eq(a2.count("play"), 1, "재생은 늘지 않는다")

	-- [6] id가 바뀌면 앞 곡을 놓아 준다
	Bgm.play("./d.ogg", { id = "field" })
	t.check_eq(a2.count("release"), 1, "id가 바뀌면 앞 곡을 해제한다")

	-- [7] stop은 멈추고 해제하고 기억을 지운다
	Bgm.stop()
	t.check_eq(a2.count("stop"), 1, "StopMusic 호출")
	t.check_eq(a2.count("release"), 2, "정지할 때도 해제")
	t.check_eq(Bgm.current(), nil, "정지 뒤에는 걸린 곡이 없다")

	-- [8] 오디오가 없는 환경에서도 죽지 않고 조용히 넘어간다
	Bgm.bind({})   -- PlayMusic이 없는 백엔드
	Bgm.forget()
	t.check_eq(Bgm.play("./e.ogg"), false, "재생할 수 없으면 false를 돌려준다")
	t.check_eq(Bgm.current(), nil, "걸리지 않은 곡을 기억하지 않는다")

	Bgm.bind(nil)
	Bgm.forget()
end

return M
