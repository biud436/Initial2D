-- Initial2D — 게임 진입점
--
-- 이 저장소의 게임은 「알데바란」이다. 실행하면 타이틀이 뜨고, 시작하면
-- 검은 안개의 숲이 열린다 (scripts/games/aldebaran/).
--
-- 씬 계약: init() / update(elapsedMs) / render() / destroy()
-- 씬 전환: 씬 안에서 SwitchScene("이름") 호출. 실제 전환은 다음 update 직전에 수행.
-- INITIAL2D_AUTOPLAY 환경 변수를 설정하면 자동 시연 모드로 동작한다 (테스트/CI용).
--
-- 아래의 다른 씬들은 엔진이 장르에 중립이라는 것을 보이는 데모이며 게임의 흐름에
-- 들어 있지 않다. `INITIAL2D_SCENE=flappy` 처럼 이름을 주면 그 씬으로 바로 연다
-- (검증과 스크린샷에도 같은 방법을 쓴다).

local Bgm = require("scripts/bgm")

require("scripts/games/aldebaran/title")
require("scripts/games/aldebaran/game")
require("scripts/games/flappy")
require("scripts/games/tilemap_demo")
require("scripts/games/rpgdemo/title")
require("scripts/games/rpgdemo/game")

local scenes = {
	aldebaran_title = AldebaranTitleScene,
	aldebaran = AldebaranScene,
	-- 엔진 데모 (게임 흐름 밖, INITIAL2D_SCENE 으로만 연다)
	flappy = FlappyScene,
	tilemap = TilemapDemoScene,
	title = RpgDemoTitleScene,
	rpg = RpgDemoScene,
}

local START_SCENE = "aldebaran_title"

local current = nil
local pending = nil

-- 전역: 씬에서 호출하는 씬 전환 요청
function SwitchScene(name)
	if scenes[name] ~= nil then
		pending = name
	end
end

function Initialize()
	AUTOPLAY = (os.getenv ~= nil) and (os.getenv("INITIAL2D_AUTOPLAY") ~= nil)
	math.randomseed(os.time())

	-- 폰트는 씬 공용 자원이라 여기서 한 번만 준비한다. BGM은 씬이 스스로 고른다
	-- (scripts/bgm.lua 가 "지금 걸린 곡"을 들고 있어, 곡이 같으면 다시 틀지 않는다).
	FontReady = PreparaFont("./resources/fonts/hangul.fnt")

	local startScene = (os.getenv ~= nil) and os.getenv("INITIAL2D_SCENE") or nil
	current = (startScene ~= nil and scenes[startScene]) or scenes[START_SCENE]
	current.init()
end

function Update(elapsed)
	if pending ~= nil then
		current.destroy()
		current = scenes[pending]
		pending = nil
		current.init()
	end

	current.update(elapsed)
end

function Render()
	current.render()
end

function Destroy()
	current.destroy()
	Bgm.stop()
end
