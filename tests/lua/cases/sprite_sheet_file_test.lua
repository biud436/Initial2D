-- sprite_sheet_file_test.lua : 스프라이트 시트 파일과 클립 재생 검증 (엔진 2, docs/plans/engine2-sprite-sheets.md)
-- 픽스처는 tests/fixtures/sprites/ (러너가 ./fixtures/ 로 복사). frames.png 는 16x16 칸 8개(4열 2행, 여백 2,
-- 간격 2)이고 칸마다 단색이다. Ruby 의 sprite_sheet_file_test.rb 가 같은 라벨로 같은 것을 본다.

local M = {}

local SpriteSheet = require("scripts/lua/sprite_sheet")
local SceneLoader = require("scripts/lua/scene_loader")

local SAMPLE = "fixtures/sprites/sample.sprite.json"

local function errorOf(fn, ...)
	local ok, err = pcall(fn, ...)
	if ok then return nil end
	return tostring(err)
end

-- 재생기의 상태를 "클립:프레임" 으로 (끝난 once 는 ",done")
local function state(anim)
	return tostring(anim:clip()) .. ":" .. tostring(anim:frame()) .. (anim:isDone() and ",done" or "")
end

function M.run(t)
	t.check_eq(SpriteSheet.VERSION, 1, "시트 포맷 버전은 1")
	t.check_eq(SpriteSheet.DEFAULT_DURATION, 100, "프레임 시간 기본값은 100ms")

	-- [읽기] 칸 수는 이미지 크기와 여백, 간격에서 나온다
	SpriteSheet.clearCache()
	local sheet = SpriteSheet.load(SAMPLE)
	t.check_eq(sheet.path, SAMPLE, "path 는 읽은 경로")
	t.check_eq(sheet.image, "fixtures/sprites/frames.png", "image 는 파일에 적힌 그대로")
	t.check_eq(sheet.imageWidth .. "x" .. sheet.imageHeight, "74x38", "이미지 크기는 PNG 헤더에서")
	t.check_eq(sheet.columns .. "x" .. sheet.rows, "4x2", "열과 행: (74 - 4 + 2) / 18 = 4, (38 - 4 + 2) / 18 = 2")
	t.check_eq(sheet.frameCount, 8, "프레임 수 8")
	t.check_eq(sheet.frameWidth .. "x" .. sheet.frameHeight, "16x16", "칸 크기")
	t.check_eq(sheet.defaultClip, "walk", "defaultClip")
	t.check_eq(sheet.pivotX .. "," .. sheet.pivotY, "0.5,1", "시트의 pivot")
	t.check_eq(table.concat(sheet:clipNames(), ","), "hit,walk,wave", "클립 이름은 정렬해서")
	t.check_eq(sheet.source.editorOnly, "보존", "모르는 키는 source 에 남는다")
	t.check(SpriteSheet.load(SAMPLE) == sheet, "같은 경로는 한 번만 읽는다")
	SpriteSheet.clearCache()
	t.check(SpriteSheet.load(SAMPLE) ~= sheet, "clearCache 뒤에는 다시 읽는다")

	-- [칸] 0 부터 왼쪽에서 오른쪽, 위에서 아래로
	local x, y, w, h = sheet:frameRect(0)
	t.check_eq(table.concat({ x, y, w, h }, ","), "2,2,16,16", "프레임 0 은 여백 안쪽 (2, 2)")
	x, y = sheet:frameRect(3)
	t.check_eq(x .. "," .. y, "56,2", "프레임 3 은 첫 행 끝 (2 + 3 x 18)")
	x, y = sheet:frameRect(5)
	t.check_eq(x .. "," .. y, "20,20", "프레임 5 는 둘째 행 둘째 칸")
	local err = errorOf(sheet.frameRect, sheet, 8)
	t.check_eq(err, "sheet: frame 8 is outside the sheet (8 frames) (" .. SAMPLE .. ")", "시트 밖의 프레임은 오류")

	-- [클립] 정규화한 값
	local walk = sheet:clip("walk")
	t.check_eq(table.concat(walk.durations, ","), "100,50,100,50", "duration 배열은 프레임마다")
	t.check_eq(walk.loop, "loop", "loop 기본값은 loop")
	t.check_eq(table.concat(sheet:clip("wave").durations, ","), "80,80,80", "duration 숫자는 모든 프레임에")
	t.check_eq(table.concat(sheet:clip("hit").durations, ","), "100,100", "duration 이 없으면 100")
	t.check_eq(sheet:clip("run"), nil, "없는 클립은 nil")

	-- [재생] 클립 없음: 0 번 프레임, 시트의 기준점
	local anim = sheet:animator()
	t.check_eq(state(anim), "nil:0", "처음에는 클립이 없고 프레임 0")
	local px, py = anim:pivot()
	t.check_eq(px .. "," .. py, "0.5,1", "클립이 없으면 시트의 pivot")
	anim:update(1000)
	t.check_eq(state(anim), "nil:0", "클립이 없으면 시간을 보내도 그대로")

	-- loop: 프레임 시간이 다 차는 순간 다음 프레임으로
	anim:play("walk")
	t.check_eq(state(anim), "walk:0", "play 는 첫 프레임에서 시작")
	anim:update(99)
	t.check_eq(anim:frame(), 0, "99ms 는 아직 프레임 0")
	anim:update(1)
	t.check_eq(anim:frame(), 1, "100ms 가 차면 프레임 1")
	anim:update(50)
	t.check_eq(anim:frame(), 2, "다음 50ms 로 프레임 2")
	anim:update(150)
	t.check_eq(anim:frame(), 0, "한 번에 두 프레임을 넘어 처음으로 돌아온다")
	anim:update(300 * 1000 + 100)
	t.check_eq(anim:frame(), 1, "긴 시간도 바퀴 수를 덜고 같은 자리로 (300 x 1000 + 100ms)")
	anim:update(0)
	anim:update(-5)
	t.check_eq(anim:frame(), 1, "0 이나 음수는 시간을 보내지 않는다")
	t.check_eq(anim:isDone(), false, "loop 는 끝나지 않는다")
	px, py = anim:pivot()
	t.check_eq(px .. "," .. py, "0.5,1", "pivot 이 없는 클립은 시트의 pivot")

	-- pingpong: 4 5 6 5 4 5 ... 양 끝을 두 번 보이지 않는다
	anim:play("wave")
	local seen = { anim:frame() }
	for _ = 1, 6 do
		anim:update(80)
		seen[#seen + 1] = anim:frame()
	end
	t.check_eq(table.concat(seen, ","), "4,5,6,5,4,5,6", "pingpong 순서")
	px, py = anim:pivot()
	t.check_eq(px .. "," .. py, "0,0", "클립의 pivot 이 시트의 것보다 먼저")

	-- once: 마지막 프레임의 시간이 다 차면 끝나고 그 프레임에 머문다
	anim:play("hit")
	anim:update(100)
	t.check_eq(state(anim), "hit:3", "once: 100ms 뒤 둘째 프레임")
	anim:update(99)
	t.check_eq(state(anim), "hit:3", "once: 마지막 프레임 시간이 차기 전에는 끝나지 않는다")
	anim:update(1)
	t.check_eq(state(anim), "hit:3,done", "once: 마지막 프레임 시간이 차면 끝난다")
	anim:update(1000)
	t.check_eq(state(anim), "hit:3,done", "once: 끝난 뒤에는 그대로")
	anim:restart()
	t.check_eq(state(anim), "hit:7", "restart 는 처음부터")
	anim:update(50)
	anim:play("hit")
	anim:update(60)
	t.check_eq(state(anim), "hit:7", "같은 클립을 play 해도 처음부터 (50 + 60 이 아니라 60)")

	err = errorOf(anim.play, anim, "run")
	t.check_eq(err, "sheet: no clip 'run' (" .. SAMPLE .. ")", "없는 클립을 play 하면 이름과 파일을 말한다")
	t.check_eq(state(anim), "hit:7", "실패한 play 는 상태를 바꾸지 않는다")
	anim:play(nil)
	t.check_eq(state(anim), "nil:0", "play(nil) 은 클립을 내린다")

	-- 재생기는 오브젝트마다 따로다
	local a, b = sheet:animator(), sheet:animator()
	a:play("walk")
	b:play("wave")
	a:update(100)
	t.check_eq(state(a) .. " " .. state(b), "walk:1 wave:4", "재생기 둘은 서로의 시간을 나누지 않는다")

	-- [apply] 칸과 기준점을 스프라이트에
	t.check(TextureManager.Load("./fixtures/sprites/frames.png", "sheet_test"), "시트 그림 로드")
	local sp = Sprite.Create(0, 0, 16, 16, 1, "sheet_test")
	a:apply(sp)
	local r = Sprite.GetRect(sp)
	t.check(r.x == 20 and r.y == 2, "apply: 프레임 1 의 칸 (20, 2)", r.x .. "," .. r.y)
	local spx, spy = Sprite.GetPivot(sp)
	t.check_eq(spx .. "," .. spy, "0.5,1.0", "apply: 시트의 pivot")
	Sprite.Dispose(sp)
	TextureManager.Remove("sheet_test")

	-- [검사] 공유 픽스처의 잘못된 시트마다 정해진 문장 (에디터와 Ruby 판이 같은 문장을 낸다)
	local cases = Json.Load("./fixtures/sprites/invalid_sheets.json")
	t.check(type(cases) == "table" and #cases >= 30, "잘못된 시트 픽스처를 읽었다", #(cases or {}))
	for _, c in ipairs(cases or {}) do
		t.check_eq(errorOf(SpriteSheet.fromTable, c.sheet), c.error, "검사: " .. c.name)
	end
	local ok, verr = SpriteSheet.validate({ version = 2 })
	t.check(not ok and verr == "sheet: unsupported version 2 (expected 1)", "validate 는 첫 문제를 말한다", verr)
	t.check(SpriteSheet.validate(Json.Load("./" .. SAMPLE)), "샘플은 검사를 통과한다")
	err = errorOf(SpriteSheet.fromTable, { version = 3 }, "x.sprite.json")
	t.check_eq(err, "sheet: unsupported version 3 (expected 1) (x.sprite.json)", "fromTable 의 path 는 문장 끝에")
	err = errorOf(SpriteSheet.load, "fixtures/sprites/none.sprite.json")
	t.check(err and err:find("sheet: cannot open fixtures/sprites/none.sprite.json (", 1, true) == 1,
		"없는 파일은 경로를 말한다", err)
	t.check_eq(errorOf(SpriteSheet.load, ""), "sheet: load needs a path", "빈 경로는 오류")

	-- [씬 검사] sprite 의 sheet 와 clip
	local function sprite(props) return { version = 1, objects = { { id = "s", type = "sprite", props = props } } } end
	ok, verr = SceneLoader.validate(sprite({ sheet = SAMPLE }))
	t.check(ok, "sheet 가 있으면 image 가 없어도 된다", verr)
	ok, verr = SceneLoader.validate(sprite({ sheet = 3 }))
	t.check_eq(verr, "scene: props.sheet must be a string (s)", "sheet 는 문자열")
	ok, verr = SceneLoader.validate(sprite({ sheet = "" }))
	t.check_eq(verr, "scene: sprite 's' needs props.image", "빈 sheet 는 없는 것과 같다")
	ok, verr = SceneLoader.validate(sprite({ sheet = SAMPLE, clip = 1 }))
	t.check_eq(verr, "scene: props.clip must be a string (s)", "clip 은 문자열")
	ok, verr = SceneLoader.validate(sprite({ image = "x.png", clip = "fly" }))
	t.check(ok, "sheet 가 없는 clip 은 쓰이지 않는다", verr)

	-- [씬 열기] 오류는 오브젝트와 시트 파일을 말한다
	err = errorOf(SceneLoader.fromTable, sprite({ sheet = SAMPLE, clip = "run" }))
	t.check_eq(err, "scene: sprite 's': sheet: no clip 'run' (" .. SAMPLE .. ")", "없는 클립으로 열면 오류")
	err = errorOf(SceneLoader.fromTable, sprite({ sheet = "fixtures/sprites/none.sprite.json" }))
	t.check(err and err:find("scene: sprite 's': sheet: cannot open fixtures/sprites/none.sprite.json", 1, true) == 1,
		"없는 시트 파일로 열면 오류", err)

	-- [씬 실행] 매 틱: props.clip 이 바뀌면 처음부터, animate false 면 멈춤, 칸과 기준점이 스프라이트에
	local scene = SceneLoader.fromTable(sprite({ sheet = SAMPLE, scale = 2 }))
	local s = scene:find("s")
	t.check(s.sheet == SpriteSheet.load(SAMPLE), "obj.sheet 는 읽은 시트")
	t.check_eq(state(s.animator), "walk:0", "clip 이 없으면 defaultClip")
	t.check_eq(s.frameWidth .. "x" .. s.frameHeight, "16x16", "frameWidth, frameHeight 는 칸 크기")
	t.check_eq(s.texture, "./fixtures/sprites/frames.png", "텍스처 id 는 시트 그림의 경로")
	r = Sprite.GetRect(s.sprite)
	t.check(r.x == 2 and r.y == 2, "만들 때 첫 프레임의 칸 (2, 2)", r.x .. "," .. r.y)
	scene:tick(100)
	r = Sprite.GetRect(s.sprite)
	t.check(state(s.animator) == "walk:1" and r.x == 20 and r.y == 2, "틱이 클립을 진행하고 칸을 옮긴다 (20, 2)",
		state(s.animator) .. " " .. r.x .. "," .. r.y)
	spx, spy = Sprite.GetPivot(s.sprite)
	t.check_eq(spx .. "," .. spy, "0.5,1.0", "시트의 pivot 이 스프라이트에")
	s.props.clip = "wave"
	scene:tick(100)
	t.check_eq(state(s.animator), "wave:4", "clip 을 바꾸면 그 틱에는 시간을 보내지 않고 처음부터")
	spx, spy = Sprite.GetPivot(s.sprite)
	t.check_eq(spx .. "," .. spy, "0.0,0.0", "클립의 pivot")
	s.props.pivot = { 1, 0 }
	scene:tick(80)
	spx, spy = Sprite.GetPivot(s.sprite)
	t.check_eq(state(s.animator) .. " " .. spx .. "," .. spy, "wave:5 1.0,0.0", "props.pivot 이 클립의 것보다 먼저")
	s.animate = false
	scene:tick(1000)
	t.check_eq(state(s.animator), "wave:5", "animate false 면 멈춘다")
	s.animate = true
	s.props.clip = ""
	scene:tick(20)
	t.check_eq(state(s.animator), "walk:0", "clip 을 비우면 defaultClip")
	s.props.clip = "run"
	err = errorOf(scene.tick, scene, 20)
	t.check_eq(err, "scene: sprite 's': sheet: no clip 'run' (" .. SAMPLE .. ")", "실행 중 없는 클립도 오류")
	s.props.clip = "walk"
	local spawned = scene:spawn({ type = "sprite", props = { sheet = SAMPLE, clip = "hit" } })
	t.check_eq(state(spawned.animator), "hit:7", "spawn 한 시트 스프라이트도 클립을 튼다")
	scene:close()
	t.check(scene:isClosed(), "close 뒤 닫힘")
end

return M
