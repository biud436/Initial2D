# sprite_sheet_file_test.rb : 스프라이트 시트 파일과 클립 재생 검증 (엔진 2, docs/plans/engine2-sprite-sheets.md)
# 픽스처는 tests/fixtures/sprites/ (러너가 ./fixtures/ 로 복사). frames.png 는 16x16 칸 8개(4열 2행, 여백 2,
# 간격 2)이고 칸마다 단색이다. Lua 의 sprite_sheet_file_test.lua 와 라벨이 같다.

require "scripts/ruby/sprite_sheet"
require "scripts/ruby/scene_loader"

T.run_case("sprite_sheet_file") do |t|
  sample = "fixtures/sprites/sample.sprite.json"

  # 오류를 기대한다: 메시지를 돌려주고, 안 나면 nil
  error_of = lambda do |&blk|
    begin
      blk.call
      nil
    rescue SpriteSheet::Error, SceneLoader::Error => e
      e.message
    end
  end
  # 재생기의 상태를 "클립:프레임" 으로 (끝난 once 는 ",done")
  state = lambda do |anim|
    "#{anim.clip.nil? ? 'nil' : anim.clip}:#{anim.frame}#{anim.done? ? ',done' : ''}"
  end

  t.check_eq(SpriteSheet::VERSION, 1, "시트 포맷 버전은 1")
  t.check_eq(SpriteSheet::DEFAULT_DURATION, 100, "프레임 시간 기본값은 100ms")

  # [읽기] 칸 수는 이미지 크기와 여백, 간격에서 나온다
  SpriteSheet.clear_cache
  sheet = SpriteSheet.load(sample)
  t.check_eq(sheet.path, sample, "path 는 읽은 경로")
  t.check_eq(sheet.image, "fixtures/sprites/frames.png", "image 는 파일에 적힌 그대로")
  t.check_eq("#{sheet.image_width}x#{sheet.image_height}", "74x38", "이미지 크기는 PNG 헤더에서")
  t.check_eq("#{sheet.columns}x#{sheet.rows}", "4x2", "열과 행: (74 - 4 + 2) / 18 = 4, (38 - 4 + 2) / 18 = 2")
  t.check_eq(sheet.frame_count, 8, "프레임 수 8")
  t.check_eq("#{sheet.frame_width}x#{sheet.frame_height}", "16x16", "칸 크기")
  t.check_eq(sheet.default_clip, "walk", "defaultClip")
  t.check_eq(sheet.pivot.join(","), "0.5,1", "시트의 pivot")
  t.check_eq(sheet.clip_names.join(","), "hit,walk,wave", "클립 이름은 정렬해서")
  t.check_eq(sheet.source["editorOnly"], "보존", "모르는 키는 source 에 남는다")
  t.check(SpriteSheet.load(sample).equal?(sheet), "같은 경로는 한 번만 읽는다")
  SpriteSheet.clear_cache
  t.check(!SpriteSheet.load(sample).equal?(sheet), "clearCache 뒤에는 다시 읽는다")

  # [칸] 0 부터 왼쪽에서 오른쪽, 위에서 아래로
  t.check_eq(sheet.frame_rect(0).join(","), "2,2,16,16", "프레임 0 은 여백 안쪽 (2, 2)")
  t.check_eq(sheet.frame_rect(3)[0, 2].join(","), "56,2", "프레임 3 은 첫 행 끝 (2 + 3 x 18)")
  t.check_eq(sheet.frame_rect(5)[0, 2].join(","), "20,20", "프레임 5 는 둘째 행 둘째 칸")
  err = error_of.call { sheet.frame_rect(8) }
  t.check_eq(err, "sheet: frame 8 is outside the sheet (8 frames) (#{sample})", "시트 밖의 프레임은 오류")

  # [클립] 정규화한 값
  walk = sheet.clip("walk")
  t.check_eq(walk.durations.join(","), "100,50,100,50", "duration 배열은 프레임마다")
  t.check_eq(walk.loop, "loop", "loop 기본값은 loop")
  t.check_eq(sheet.clip("wave").durations.join(","), "80,80,80", "duration 숫자는 모든 프레임에")
  t.check_eq(sheet.clip("hit").durations.join(","), "100,100", "duration 이 없으면 100")
  t.check_eq(sheet.clip("run"), nil, "없는 클립은 nil")

  # [재생] 클립 없음: 0 번 프레임, 시트의 기준점
  anim = sheet.animator
  t.check_eq(state.call(anim), "nil:0", "처음에는 클립이 없고 프레임 0")
  t.check_eq(anim.pivot.join(","), "0.5,1", "클립이 없으면 시트의 pivot")
  anim.update(1000)
  t.check_eq(state.call(anim), "nil:0", "클립이 없으면 시간을 보내도 그대로")

  # loop: 프레임 시간이 다 차는 순간 다음 프레임으로
  anim.play("walk")
  t.check_eq(state.call(anim), "walk:0", "play 는 첫 프레임에서 시작")
  anim.update(99)
  t.check_eq(anim.frame, 0, "99ms 는 아직 프레임 0")
  anim.update(1)
  t.check_eq(anim.frame, 1, "100ms 가 차면 프레임 1")
  anim.update(50)
  t.check_eq(anim.frame, 2, "다음 50ms 로 프레임 2")
  anim.update(150)
  t.check_eq(anim.frame, 0, "한 번에 두 프레임을 넘어 처음으로 돌아온다")
  anim.update(300 * 1000 + 100)
  t.check_eq(anim.frame, 1, "긴 시간도 바퀴 수를 덜고 같은 자리로 (300 x 1000 + 100ms)")
  anim.update(0)
  anim.update(-5)
  t.check_eq(anim.frame, 1, "0 이나 음수는 시간을 보내지 않는다")
  t.check_eq(anim.done?, false, "loop 는 끝나지 않는다")
  t.check_eq(anim.pivot.join(","), "0.5,1", "pivot 이 없는 클립은 시트의 pivot")

  # pingpong: 4 5 6 5 4 5 ... 양 끝을 두 번 보이지 않는다
  anim.play("wave")
  seen = [anim.frame]
  6.times do
    anim.update(80)
    seen.push(anim.frame)
  end
  t.check_eq(seen.join(","), "4,5,6,5,4,5,6", "pingpong 순서")
  t.check_eq(anim.pivot.join(","), "0,0", "클립의 pivot 이 시트의 것보다 먼저")

  # once: 마지막 프레임의 시간이 다 차면 끝나고 그 프레임에 머문다
  anim.play("hit")
  anim.update(100)
  t.check_eq(state.call(anim), "hit:3", "once: 100ms 뒤 둘째 프레임")
  anim.update(99)
  t.check_eq(state.call(anim), "hit:3", "once: 마지막 프레임 시간이 차기 전에는 끝나지 않는다")
  anim.update(1)
  t.check_eq(state.call(anim), "hit:3,done", "once: 마지막 프레임 시간이 차면 끝난다")
  anim.update(1000)
  t.check_eq(state.call(anim), "hit:3,done", "once: 끝난 뒤에는 그대로")
  anim.restart
  t.check_eq(state.call(anim), "hit:7", "restart 는 처음부터")
  anim.update(50)
  anim.play("hit")
  anim.update(60)
  t.check_eq(state.call(anim), "hit:7", "같은 클립을 play 해도 처음부터 (50 + 60 이 아니라 60)")

  err = error_of.call { anim.play("run") }
  t.check_eq(err, "sheet: no clip 'run' (#{sample})", "없는 클립을 play 하면 이름과 파일을 말한다")
  t.check_eq(state.call(anim), "hit:7", "실패한 play 는 상태를 바꾸지 않는다")
  anim.play(nil)
  t.check_eq(state.call(anim), "nil:0", "play(nil) 은 클립을 내린다")

  # 재생기는 오브젝트마다 따로다
  a = sheet.animator
  b = sheet.animator
  a.play("walk")
  b.play("wave")
  a.update(100)
  t.check_eq("#{state.call(a)} #{state.call(b)}", "walk:1 wave:4", "재생기 둘은 서로의 시간을 나누지 않는다")

  # [apply] 칸과 기준점을 스프라이트에
  t.check(TextureManager.load("./fixtures/sprites/frames.png", "sheet_test"), "시트 그림 로드")
  sp = Sprite.new(0, 0, 16, 16, 1, "sheet_test")
  a.apply(sp)
  r = sp.rect
  t.check(r[:x] == 20 && r[:y] == 2, "apply: 프레임 1 의 칸 (20, 2)", "#{r[:x]},#{r[:y]}")
  t.check_eq(sp.pivot.join(","), "0.5,1.0", "apply: 시트의 pivot")
  sp.dispose
  TextureManager.remove("sheet_test")

  # [검사] 공유 픽스처의 잘못된 시트마다 정해진 문장 (에디터와 Lua 판이 같은 문장을 낸다)
  cases = Json.load("./fixtures/sprites/invalid_sheets.json")
  t.check(cases.is_a?(Array) && cases.size >= 30, "잘못된 시트 픽스처를 읽었다", cases.inspect[0, 80])
  cases.each do |c|
    t.check_eq(error_of.call { SpriteSheet.from_hash(c["sheet"]) }, c["error"], "검사: #{c['name']}")
  end
  verr = error_of.call { SpriteSheet.validate({ "version" => 2 }) }
  t.check(verr == "sheet: unsupported version 2 (expected 1)", "validate 는 첫 문제를 말한다", verr)
  t.check(SpriteSheet.validate(Json.load("./" + sample)), "샘플은 검사를 통과한다")
  err = error_of.call { SpriteSheet.from_hash({ "version" => 3 }, "x.sprite.json") }
  t.check_eq(err, "sheet: unsupported version 3 (expected 1) (x.sprite.json)", "fromTable 의 path 는 문장 끝에")
  err = error_of.call { SpriteSheet.load("fixtures/sprites/none.sprite.json") }
  t.check(!err.nil? && err.start_with?("sheet: cannot open fixtures/sprites/none.sprite.json ("),
          "없는 파일은 경로를 말한다", err)
  t.check_eq(error_of.call { SpriteSheet.load("") }, "sheet: load needs a path", "빈 경로는 오류")

  # [씬 검사] sprite 의 sheet 와 clip
  sprite = lambda { |props| { "version" => 1, "objects" => [{ "id" => "s", "type" => "sprite", "props" => props }] } }
  verr = error_of.call { SceneLoader.validate(sprite.call({ "sheet" => sample })) }
  t.check(verr.nil?, "sheet 가 있으면 image 가 없어도 된다", verr)
  verr = error_of.call { SceneLoader.validate(sprite.call({ "sheet" => 3 })) }
  t.check_eq(verr, "scene: props.sheet must be a string (s)", "sheet 는 문자열")
  verr = error_of.call { SceneLoader.validate(sprite.call({ "sheet" => "" })) }
  t.check_eq(verr, "scene: sprite 's' needs props.image", "빈 sheet 는 없는 것과 같다")
  verr = error_of.call { SceneLoader.validate(sprite.call({ "sheet" => sample, "clip" => 1 })) }
  t.check_eq(verr, "scene: props.clip must be a string (s)", "clip 은 문자열")
  verr = error_of.call { SceneLoader.validate(sprite.call({ "image" => "x.png", "clip" => "fly" })) }
  t.check(verr.nil?, "sheet 가 없는 clip 은 쓰이지 않는다", verr)

  # [씬 열기] 오류는 오브젝트와 시트 파일을 말한다
  err = error_of.call { SceneLoader.from_hash(sprite.call({ "sheet" => sample, "clip" => "run" })) }
  t.check_eq(err, "scene: sprite 's': sheet: no clip 'run' (#{sample})", "없는 클립으로 열면 오류")
  err = error_of.call { SceneLoader.from_hash(sprite.call({ "sheet" => "fixtures/sprites/none.sprite.json" })) }
  t.check(!err.nil? && err.start_with?("scene: sprite 's': sheet: cannot open fixtures/sprites/none.sprite.json"),
          "없는 시트 파일로 열면 오류", err)

  # [씬 실행] 매 틱: props.clip 이 바뀌면 처음부터, animate false 면 멈춤, 칸과 기준점이 스프라이트에
  scene = SceneLoader.from_hash(sprite.call({ "sheet" => sample, "scale" => 2 }))
  s = scene.find("s")
  t.check(s.sheet.equal?(SpriteSheet.load(sample)), "obj.sheet 는 읽은 시트")
  t.check_eq(state.call(s.animator), "walk:0", "clip 이 없으면 defaultClip")
  t.check_eq("#{s.frame_width}x#{s.frame_height}", "16x16", "frameWidth, frameHeight 는 칸 크기")
  t.check_eq(s.texture, "./fixtures/sprites/frames.png", "텍스처 id 는 시트 그림의 경로")
  r = s.sprite.rect
  t.check(r[:x] == 2 && r[:y] == 2, "만들 때 첫 프레임의 칸 (2, 2)", "#{r[:x]},#{r[:y]}")
  scene.tick(100)
  r = s.sprite.rect
  t.check(state.call(s.animator) == "walk:1" && r[:x] == 20 && r[:y] == 2, "틱이 클립을 진행하고 칸을 옮긴다 (20, 2)",
          "#{state.call(s.animator)} #{r[:x]},#{r[:y]}")
  t.check_eq(s.sprite.pivot.join(","), "0.5,1.0", "시트의 pivot 이 스프라이트에")
  s.props["clip"] = "wave"
  scene.tick(100)
  t.check_eq(state.call(s.animator), "wave:4", "clip 을 바꾸면 그 틱에는 시간을 보내지 않고 처음부터")
  t.check_eq(s.sprite.pivot.join(","), "0.0,0.0", "클립의 pivot")
  s.props["pivot"] = [1, 0]
  scene.tick(80)
  t.check_eq("#{state.call(s.animator)} #{s.sprite.pivot.join(',')}", "wave:5 1.0,0.0", "props.pivot 이 클립의 것보다 먼저")
  s.animate = false
  scene.tick(1000)
  t.check_eq(state.call(s.animator), "wave:5", "animate false 면 멈춘다")
  s.animate = true
  s.props["clip"] = ""
  scene.tick(20)
  t.check_eq(state.call(s.animator), "walk:0", "clip 을 비우면 defaultClip")
  s.props["clip"] = "run"
  err = error_of.call { scene.tick(20) }
  t.check_eq(err, "scene: sprite 's': sheet: no clip 'run' (#{sample})", "실행 중 없는 클립도 오류")
  s.props["clip"] = "walk"
  spawned = scene.spawn({ "type" => "sprite", "props" => { "sheet" => sample, "clip" => "hit" } })
  t.check_eq(state.call(spawned.animator), "hit:7", "spawn 한 시트 스프라이트도 클립을 튼다")
  scene.close
  t.check(scene.closed?, "close 뒤 닫힘")
end
