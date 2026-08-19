-- Initial2D 미니 게임 허브
--
-- 첫 스테이지는 미니 게임 목록(scripts/scenes/menu.lua)이며,
-- 항목을 누르면 해당 미니 게임(scripts/games/*.lua)으로 전환된다.
--
-- 씬 계약: init() / update(elapsedMs) / render() / destroy()
-- 씬 전환: 씬 안에서 SwitchScene("이름") 호출 — 실제 전환은 다음 update 직전에 수행
-- INITIAL2D_AUTOPLAY 환경 변수를 설정하면 자동 시연 모드로 동작한다 (테스트/CI용).

local Bgm = require("scripts/bgm")

require("scripts/scenes/menu")
require("scripts/games/flappy")
require("scripts/games/tilemap_demo")
require("scripts/games/rpgdemo/title")
require("scripts/games/rpgdemo/game")

local scenes = {
	menu = MenuScene,
	flappy = FlappyScene,
	tilemap = TilemapDemoScene,
	title = RpgDemoTitleScene,
	rpg = RpgDemoScene,
}

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

	-- 폰트는 씬 공용 자원이라 허브에서 한 번만 준비한다. BGM은 씬마다 다를 수
	-- 있으므로 scripts/bgm.lua 가 "지금 걸린 곡"을 들고 있다 (곡이 같으면 다시
	-- 틀지 않아 씬을 오갈 때 음악이 끊기지 않는다).
	FontReady = PreparaFont("./resources/fonts/hangul.fnt")
	Bgm.play("./resources/audio/bless.ogg", { volume = 96 })

	-- 시작 씬은 메뉴. INITIAL2D_SCENE 으로 특정 씬을 바로 열 수 있다 (검증과 스크린샷용)
	local startScene = (os.getenv ~= nil) and os.getenv("INITIAL2D_SCENE") or nil
	current = (startScene ~= nil and scenes[startScene]) or scenes.menu
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
