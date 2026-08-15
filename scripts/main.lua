-- Initial2D 미니 게임 허브
--
-- 첫 스테이지는 미니 게임 목록(scripts/scenes/menu.lua)이며,
-- 항목을 누르면 해당 미니 게임(scripts/games/*.lua)으로 전환된다.
--
-- 씬 계약: init() / update(elapsedMs) / render() / destroy()
-- 씬 전환: 씬 안에서 SwitchScene("이름") 호출 — 실제 전환은 다음 update 직전에 수행
-- INITIAL2D_AUTOPLAY 환경 변수를 설정하면 자동 시연 모드로 동작한다 (테스트/CI용).

require("scripts/scenes/menu")
require("scripts/games/flappy")
require("scripts/games/tilemap_demo")

local scenes = {
	menu = MenuScene,
	flappy = FlappyScene,
	tilemap = TilemapDemoScene,
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

	-- 폰트·BGM은 씬 공용 자원이라 허브에서 한 번만 준비한다
	FontReady = PreparaFont("./resources/fonts/hangul.fnt")
	Audio.PlayMusic("./resources/audio/bless.ogg", "bgm", true)
	Audio.SetVolume(96)

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
	Audio.ReleaseMusic("bgm")
end
