# scene_loader_test.rb : 씬 로더 검증, Ruby 판 (R1, docs/plans/r1-scene-loader.md)
# Lua 의 scene_loader_test.lua 에 대응한다 (라벨은 같다). 엔진 VM 에서 돌므로 스프라이트와
# 텍스처는 진짜다. 컴포넌트는 워크 디렉터리의 scripts/ruby/components/ 에 임시 파일로 만들어
# require 와 CamelCase 클래스 찾기까지 실제로 통과시킨다.

require "scripts/ruby/scene_loader"

$rbtest_hooks = []

T.run_case("scene_loader") do |t|
  tileset = "resources/tiles/tileset16-8x13.png"   # 128x208, 16px 타일 8열

  scene_of = lambda do |objects, extra = {}|
    h = { "version" => 1, "name" => "t", "objects" => objects }
    extra.each { |k, v| h[k] = v }
    h
  end
  write_file = lambda do |path, text|
    File.open(path, "w") { |f| f.write(text) }
  end
  ids = lambda { |scene| scene.objects.map(&:id).join(",") }
  # 오류를 기대한다: 메시지를 돌려주고, 안 나면 nil
  fails_with = lambda do |&blk|
    begin
      blk.call
      nil
    rescue SceneLoader::Error => e
      e.message
    end
  end

  t.check(SceneLoader.respond_to?(:open), "SceneLoader.open 존재")
  t.check(SceneLoader.respond_to?(:validate), "SceneLoader.validate 존재")
  t.check_eq(SceneLoader::VERSION, 1, "씬 포맷 버전은 1")

  # [검증] 버전, 중복 id, 모르는 타입, 빈 id, sprite 의 image, 모르는 키
  e = fails_with.call { SceneLoader.validate({ "version" => 2, "objects" => [] }) }
  t.check(e && e.include?("version") && e.include?("2"), "버전 2 는 거부하고 버전을 말한다", e)
  e = fails_with.call { SceneLoader.validate({ "objects" => [] }) }
  t.check(e && e.include?("version"), "버전이 없어도 거부", e)
  e = fails_with.call { SceneLoader.validate("no") }
  t.check(!e.nil?, "표가 아니면 거부")
  e = fails_with.call { SceneLoader.validate(scene_of.call([{ "id" => "a", "type" => "node" }, { "id" => "a", "type" => "node" }])) }
  t.check(e && e.include?("duplicate") && e.include?("'a'"), "중복 id 는 거부하고 id 를 말한다", e)
  e = fails_with.call { SceneLoader.validate(scene_of.call([{ "id" => "g", "type" => "ghost" }])) }
  t.check(e && e.include?("unknown type") && e.include?("ghost"), "모르는 타입은 거부하고 타입을 말한다", e)
  e = fails_with.call { SceneLoader.validate(scene_of.call([{ "id" => "", "type" => "node" }])) }
  t.check(e && e.include?("id"), "빈 id 는 거부", e)
  e = fails_with.call { SceneLoader.validate(scene_of.call([{ "type" => "node" }])) }
  t.check(e && e.include?("id"), "id 가 없으면 거부", e)
  e = fails_with.call { SceneLoader.validate(scene_of.call([{ "id" => "s", "type" => "sprite", "props" => {} }])) }
  t.check(e && e.include?("image"), "sprite 는 props.image 가 필요", e)
  e = fails_with.call { SceneLoader.validate(scene_of.call([{ "id" => "s", "type" => "sprite", "props" => { "image" => "x.png", "opacity" => 300 } }])) }
  t.check(e && e.include?("opacity"), "opacity 는 0..255", e)
  e = fails_with.call { SceneLoader.validate(scene_of.call([{ "id" => "s", "type" => "sprite", "props" => { "image" => "x.png", "frames" => 0 } }])) }
  t.check(e && e.include?("frames"), "frames 는 1 이상", e)
  e = fails_with.call { SceneLoader.validate(scene_of.call([{ "id" => "n", "type" => "node", "x" => "1" }])) }
  t.check(e && e.include?("x"), "x 는 숫자여야 한다", e)
  e = fails_with.call { SceneLoader.validate(scene_of.call([{ "id" => "n", "type" => "node", "scripts" => [3] }])) }
  t.check(e && e.include?("scripts"), "scripts 항목은 문자열이어야 한다", e)
  e = fails_with.call { SceneLoader.validate(scene_of.call([{ "id" => "l", "type" => "text", "props" => { "color" => [1, 2] } }])) }
  t.check(e && e.include?("color"), "color 는 [r, g, b] 나 [r, g, b, a]", e)
  e = fails_with.call { SceneLoader.validate(scene_of.call([{ "id" => "m", "type" => "tilemap", "props" => {} }])) }
  t.check(e && e.include?("map"), "확장 타입의 validate 도 불린다 (tilemap 은 map 이 필요)", e)
  e = fails_with.call do
    SceneLoader.validate(scene_of.call([
      { "id" => "n", "type" => "node", "editorOnly" => { "locked" => true } },
      { "id" => "m", "type" => "tilemap", "props" => { "map" => "resources/maps/sample.json" } },
    ], { "editorOnly" => { "note" => "보존" }, "camera" => { "x" => 1 } }))
  end
  t.check(e.nil?, "모르는 키는 무시하고, 확장 타입 tilemap 은 안다", e)

  # [열기 실패] 없는 컴포넌트, 없는 파일, 없는 이미지
  e = fails_with.call { SceneLoader.from_hash(scene_of.call([{ "id" => "n", "type" => "node", "scripts" => ["components/no_such_component"] }])) }
  t.check(e && e.include?("no_such_component") && e.include?("scripts/ruby/components/no_such_component.rb"),
          "없는 컴포넌트 모듈은 논리 이름과 파일 경로를 말하며 실패", e)
  e = fails_with.call { SceneLoader.open("no_such_scene") }
  t.check(e && e.include?("resources/scenes/no_such_scene.json"), "없는 씬 이름은 찾은 경로를 말하며 실패", e)
  e = fails_with.call { SceneLoader.from_hash(scene_of.call([{ "id" => "s", "type" => "sprite", "props" => { "image" => "resources/no_such.png" } }])) }
  t.check(e && e.include?("no_such.png"), "없는 이미지는 실패", e)
  e = fails_with.call { SceneLoader.from_hash({ "version" => 3 }) }
  t.check(e && e.include?("version"), "fromTable 도 검증한다", e)

  # [기본값] x, y, visible, props, scripts
  scene = SceneLoader.from_hash(scene_of.call([{ "id" => "n", "type" => "node" }]))
  n = scene.find("n")
  t.check(!n.nil?, "find 로 찾는다")
  t.check_eq(n.x, 0, "x 기본 0")
  t.check_eq(n.y, 0, "y 기본 0")
  t.check_eq(n.visible, true, "visible 기본 true")
  t.check(n.props.is_a?(Hash) && n.props.empty?, "props 기본 빈 표")
  t.check(n.scripts.is_a?(Array) && n.scripts.empty?, "scripts 기본 빈 배열")
  t.check_eq(n.sprite, nil, "node 는 sprite 가 없다")
  t.check_eq(n.scene, scene, "obj.scene 은 씬")
  t.check_eq(n.type, "node", "type 이 남는다")
  t.check_eq(scene.name, "t", "scene.name 은 파일의 name")
  t.check(scene.state.is_a?(Hash), "scene.state 는 빈 표")
  t.check_eq(scene.find("nope"), nil, "없는 id 는 nil")
  t.check_eq(n.no_such_field, nil, "정하지 않은 필드는 nil (Lua 표처럼)")
  n.custom = 7
  t.check_eq(n.custom, 7, "아무 필드나 붙일 수 있다")
  scene.close
  t.check(scene.closed?, "close 뒤 isClosed")
  e = fails_with.call { scene.tick(16) }
  t.check(!e.nil?, "닫힌 씬은 tick 할 수 없다")

  # [훅 순서] 임시 컴포넌트 파일로 init -> update -> render -> destroy 가 오브젝트 순서대로
  $rbtest_hooks = []
  write_file.call("./scripts/ruby/components/rbtest_hooks.rb", <<'RUBY')
class RbtestHooks
  def init(obj, scene)
    $rbtest_hooks.push("init:#{obj.id}")
    obj.props["seen"] = (obj.props["seen"] || 0) + 1
  end
  def update(obj, scene, elapsed); $rbtest_hooks.push("update:#{obj.id}:#{elapsed}"); end
  def render(obj, scene); $rbtest_hooks.push("render:#{obj.id}"); end
  def destroy(obj, scene); $rbtest_hooks.push("destroy:#{obj.id}"); end
end
RUBY
  write_file.call("./scripts/ruby/components/rbtest_tail.rb", <<'RUBY')
class RbtestTail
  def init(obj, scene); $rbtest_hooks.push("tail-init:#{obj.id}"); end
end
RUBY
  scene = SceneLoader.from_hash(scene_of.call([
    { "id" => "a", "type" => "node", "scripts" => ["components/rbtest_hooks", "components/rbtest_tail"] },
    { "id" => "b", "type" => "node", "scripts" => ["components/rbtest_hooks"], "visible" => false },
    { "id" => "c", "type" => "node", "scripts" => ["components/rbtest_hooks"] },
  ]))
  t.check_eq($rbtest_hooks.join(" "), "init:a tail-init:a init:b init:c",
             "init 은 모든 오브젝트를 만든 뒤 오브젝트 순서, 컴포넌트 순서대로")
  t.check_eq(scene.find("a").props["seen"], 1, "init 은 오브젝트당 한 번")
  t.check(scene.find("a").components[0].is_a?(RbtestHooks), "컴포넌트는 CamelCase 클래스의 인스턴스 (rbtest_hooks -> RbtestHooks)")
  t.check(!scene.find("a").components[0].equal?(scene.find("b").components[0]), "오브젝트마다 인스턴스가 따로")
  $rbtest_hooks = []
  next_scene = scene.tick(16)
  t.check_eq(next_scene, scene, "전환이 없으면 tick 은 자기 자신을 돌려준다")
  t.check_eq($rbtest_hooks.join(" "), "update:a:16 update:b:16 update:c:16",
             "update 는 순서대로, elapsed 를 넘긴다 (보이지 않는 오브젝트도 update 는 된다)")
  $rbtest_hooks = []
  scene.draw
  t.check_eq($rbtest_hooks.join(" "), "render:a render:c", "render 는 순서대로, visible=false 인 오브젝트는 건너뛴다")
  $rbtest_hooks = []
  scene.close
  t.check_eq($rbtest_hooks.join(" "), "destroy:a destroy:b destroy:c", "destroy 는 close 때 순서대로")

  # [spawn, remove, find]
  scene = SceneLoader.from_hash(scene_of.call([{ "id" => "a", "type" => "node" }, { "id" => "c", "type" => "node" }]))
  $rbtest_hooks = []
  b = scene.spawn({ "id" => "b", "type" => "node", "scripts" => ["components/rbtest_hooks"] }, "a")
  t.check_eq(ids.call(scene), "a,b,c", "spawn(spec, afterId) 는 그 오브젝트 바로 뒤에 끼운다")
  t.check_eq($rbtest_hooks.join(" "), "init:b", "spawn 은 init 을 바로 부른다")
  t.check_eq(scene.find("b"), b, "spawn 이 돌려준 것이 find 로 찾는 것")
  t.check_eq(b.scene, scene, "spawn 한 오브젝트도 scene 을 안다")
  auto = scene.spawn({ "type" => "node", "props" => { "tag" => 1 } })
  t.check(auto.id.is_a?(String) && !auto.id.empty? && scene.find(auto.id) == auto, "id 가 없으면 만들어 준다", auto.id)
  t.check_eq(ids.call(scene), "a,b,c,#{auto.id}", "afterId 가 없으면 맨 뒤")
  auto2 = scene.spawn({ "type" => "node" })
  t.check(auto2.id != auto.id, "자동 id 는 겹치지 않는다")
  e = fails_with.call { scene.spawn({ "id" => "a", "type" => "node" }) }
  t.check(e && e.include?("'a'"), "이미 있는 id 로 spawn 하면 실패", e)
  e = fails_with.call { scene.spawn({ "id" => "z", "type" => "ghost" }) }
  t.check(e && e.include?("ghost"), "모르는 타입으로 spawn 하면 실패", e)
  e = fails_with.call { scene.spawn({ "id" => "z", "type" => "node" }, "nope") }
  t.check(e && e.include?("nope"), "없는 afterId 는 실패", e)
  t.check_eq(scene.find("z"), nil, "실패한 spawn 은 오브젝트를 남기지 않는다")
  $rbtest_hooks = []
  t.check_eq(scene.remove("b"), true, "remove 는 true")
  t.check_eq($rbtest_hooks.join(" "), "destroy:b", "remove 는 destroy 를 부른다")
  t.check_eq(scene.find("b"), nil, "remove 뒤 find 는 nil")
  t.check_eq(ids.call(scene), "a,c,#{auto.id},#{auto2.id}", "remove 뒤 순서")
  t.check_eq(scene.remove("b"), false, "없는 id 의 remove 는 false")
  t.check_eq(scene.objects.size, 4, "objects() 는 남은 것만")
  # update 도중의 spawn 과 remove
  write_file.call("./scripts/ruby/components/rbtest_spawner.rb", <<'RUBY')
class RbtestSpawner
  def update(obj, scene, elapsed)
    return if obj.props["done"]
    obj.props["done"] = true
    scene.spawn({ "id" => "child", "type" => "node", "scripts" => ["components/rbtest_hooks"] })
    scene.remove("c")
  end
end
RUBY
  scene.spawn({ "id" => "sp", "type" => "node", "scripts" => ["components/rbtest_spawner"] })
  $rbtest_hooks = []
  scene.tick(16)
  t.check(!scene.find("child").nil? && scene.find("c").nil?, "update 안에서 spawn 과 remove 가 된다")
  t.check_eq($rbtest_hooks.join(" "), "init:child", "이번 틱에 만든 것은 init 만 (update 는 다음 틱부터)")
  $rbtest_hooks = []
  scene.tick(16)
  t.check_eq($rbtest_hooks.join(" "), "update:child:16", "다음 틱부터 update")
  scene.close

  # [switch] tick 이 새 씬을 돌려주고 옛 씬은 닫힌다 (경로로도 연다)
  write_file.call("./rbtest_next.json", '{ "version": 1, "name": "next", "objects": [ { "id": "n2", "type": "node" } ] }')
  scene = SceneLoader.from_hash(scene_of.call([{ "id" => "a", "type" => "node", "scripts" => ["components/rbtest_hooks"] }]))
  old = scene
  scene.switch("./rbtest_next.json")
  $rbtest_hooks = []
  scene = scene.tick(16)
  t.check(!scene.equal?(old), "switch 뒤 tick 은 새 씬을 돌려준다")
  t.check_eq(scene.name, "next", "새 씬의 이름")
  t.check(!scene.find("n2").nil?, "새 씬의 오브젝트")
  t.check(old.closed?, "옛 씬은 닫혔다")
  t.check_eq($rbtest_hooks.join(" "), "update:a:16 destroy:a", "전환 틱: 옛 씬의 update 뒤 destroy")
  scene.close
  File.delete("./rbtest_next.json")

  # [스크립트 이름 풀기] 언어별 폴더와 CamelCase 클래스
  t.check_eq(SceneLoader.component_path("components/bird"), "scripts/ruby/components/bird.rb", "논리 이름 -> Ruby 파일")
  t.check_eq(SceneLoader.component_class_name("components/pipe_spawner"), "PipeSpawner", "논리 이름 -> CamelCase 클래스 (마지막 조각)")
  t.check_eq(SceneLoader.component_class_name("components/flappy/bird"), "Bird", "폴더는 클래스 이름에 들어가지 않는다")
  t.check_eq(SceneLoader.scene_path("flappy"), "./resources/scenes/flappy.json", "씬 이름 -> 경로")
  t.check_eq(SceneLoader.scene_path("fixtures/scenes/sample_v1.json"), "./fixtures/scenes/sample_v1.json", "경로는 그대로")
  t.check_eq(SceneLoader.resolve_type("node"), :core, "코어 타입")
  t.check_eq(SceneLoader.resolve_type("tilemap"), SceneTypes::Tilemap, "확장 타입은 scene_types/ 에서 게으르게 읽는다 (SceneTypes::Tilemap)")
  t.check_eq(SceneLoader.resolve_type("ghost"), nil, "모르는 타입은 nil")
  ext = Module.new
  ext.define_singleton_method(:create) { |obj, scene| obj.created = true }
  ext.define_singleton_method(:draw_below) { |obj, scene| $rbtest_hooks.push("below:#{obj.id}") }
  ext.define_singleton_method(:draw_above) { |obj, scene| $rbtest_hooks.push("above:#{obj.id}") }
  ext.define_singleton_method(:destroy) { |obj, scene| obj.created = false }
  SceneLoader.register_type("rbtest_ext", ext)
  scene = SceneLoader.from_hash(scene_of.call([
    { "id" => "e", "type" => "rbtest_ext" },
    { "id" => "n", "type" => "node", "scripts" => ["components/rbtest_hooks"] },
  ]))
  t.check_eq(scene.find("e").created, true, "코드로 등록한 확장 타입의 create")
  $rbtest_hooks = []
  scene.draw
  t.check_eq($rbtest_hooks.join(" "), "below:e render:n above:e", "확장 타입의 아래 층 -> 오브젝트 -> 위 층")
  scene.close
  t.check_eq(scene.find("e"), nil, "close 뒤 find 는 nil")

  # [sprite props -> Sprite API]
  scene = SceneLoader.from_hash(scene_of.call([
    { "id" => "sp", "type" => "sprite", "x" => 10, "y" => 20, "props" => {
      "image" => tileset, "width" => 16, "height" => 16, "frames" => 4, "scale" => 2, "angle" => 45,
      "opacity" => 128, "loop" => false, "startFrame" => 1, "endFrame" => 3, "frameDelay" => 60 } },
    { "id" => "one", "type" => "sprite", "props" => { "image" => tileset, "width" => 16, "height" => 16, "frames" => 4, "startFrame" => 2 } },
    { "id" => "whole", "type" => "sprite", "props" => { "image" => tileset } },
    { "id" => "strip", "type" => "sprite", "props" => { "image" => tileset, "frames" => 4 } },
  ]))
  sp = scene.find("sp")
  t.check(sp.sprite.is_a?(Sprite), "sprite 핸들이 있다")
  t.check_eq(sp.sprite.width, 16, "width -> 프레임 폭")
  t.check_eq(sp.sprite.height, 16, "height -> 프레임 높이")
  t.check_eq(sp.frame_width, 16, "obj.frameWidth")
  t.check_eq(sp.sprite.start_frame, 1, "startFrame -> SetFrames 의 시작")
  t.check_eq(sp.sprite.end_frame, 3, "endFrame 3 -> 엔진의 끝 프레임 3 (SetFrames 에는 4 를 넘긴다)")
  t.check_eq(sp.sprite.current_frame, 1, "현재 프레임은 startFrame")
  r = sp.sprite.rect
  t.check(r[:x] == 16 && r[:y] == 0, "frames 4 는 가로 한 줄 (프레임 1 = x 16, y 0)", "#{r[:x]},#{r[:y]}")
  t.check_eq(sp.sprite.scale, 2.0, "scale")
  t.check_eq(sp.sprite.angle, 45.0, "angle (도)")
  t.check_eq(sp.sprite.opacity, 128, "opacity")
  t.check_eq(sp.sprite.frame_delay, 60.0, "frameDelay (ms)")
  t.check_eq(sp.sprite.visible?, true, "visible")
  one = scene.find("one")
  t.check_eq(one.sprite.start_frame, 2, "endFrame 0: 시작 프레임 2")
  t.check_eq(one.sprite.end_frame, 2, "endFrame 0 은 한 프레임 (끝 = 시작)")
  t.check_eq(one.sprite.current_frame, 2, "endFrame 0: 현재 프레임도 startFrame")
  t.check_eq(one.sprite.frame_delay, 100.0, "frameDelay 기본 100ms")
  whole = scene.find("whole")
  t.check_eq(whole.sprite.width, 128, "width 0 은 이미지 폭 전체 (PNG 헤더에서 읽는다)")
  t.check_eq(whole.sprite.height, 208, "height 0 은 이미지 높이 전체")
  t.check_eq(scene.find("strip").sprite.width, 32, "width 0 에 frames 4 면 폭을 4 로 나눈다")
  t.check_eq(TextureManager.valid?("./" + tileset), true, "텍스처 id 는 이미지 경로")
  # 매 틱 obj -> 스프라이트
  sp.x = 33
  sp.y = 44
  sp.visible = false
  sp.props["opacity"] = 200.7
  sp.props["scale"] = 3
  sp.props["angle"] = 90
  scene.tick(0)
  pos = sp.sprite.position
  t.check(pos[0] == 33.0 && pos[1] == 44.0, "tick 이 obj.x, obj.y 를 스프라이트에 옮긴다", pos.inspect)
  t.check_eq(sp.sprite.visible?, false, "tick 이 obj.visible 을 옮긴다")
  t.check_eq(sp.sprite.opacity, 200, "tick 이 props.opacity 를 옮긴다 (정수로)")
  t.check_eq(sp.sprite.scale, 3.0, "tick 이 props.scale 을 옮긴다")
  t.check_eq(sp.sprite.angle, 90.0, "tick 이 props.angle 을 옮긴다")
  handle = sp.sprite
  scene.close
  t.check_eq(TextureManager.valid?("./" + tileset), false, "close 가 텍스처를 놓는다")
  t.check_eq(handle.disposed?, true, "close 가 스프라이트를 놓는다")

  # [text] 폰트 준비와 그리기 (엔진 API 호출이 깨지지 않는다)
  scene = SceneLoader.from_hash(scene_of.call([
    { "id" => "l", "type" => "text", "x" => 5, "y" => 6, "props" => { "text" => "한 줄\n두 줄", "font" => "resources/fonts/hangul.fnt", "color" => [255, 0, 0] } },
    { "id" => "num", "type" => "text", "props" => { "text" => 12 } },
  ]))
  t.check_eq(scene.find("l").props["text"], "한 줄\n두 줄", "text 는 줄바꿈과 한글을 그대로 든다")
  t.check_eq(scene.find("num").props["font"], "", "font 기본 빈 문자열 (게임이 준비한 폰트를 쓴다)")
  t.check_eq(scene.find("l").props["color"][0], 255, "color 는 props 에 보존된다")
  e = fails_with.call { scene.draw }
  t.check(e.nil?, "text 오브젝트를 그릴 수 있다", e)
  scene.close
  e = fails_with.call { SceneLoader.from_hash(scene_of.call([{ "id" => "l", "type" => "text", "props" => { "font" => "resources/fonts/none.fnt" } }])) }
  t.check(e && e.include?("none.fnt"), "없는 폰트는 실패", e)

  # [픽스처 파일] tests/fixtures/scenes/sample_v1.json (에디터와 공유)
  scene = SceneLoader.open("fixtures/scenes/sample_v1.json")
  t.check_eq(scene.name, "sample", "픽스처의 name")
  t.check_eq(ids.call(scene), "map,tile,anim,mover,label", "픽스처의 오브젝트 순서")
  t.check_eq(scene.source["editorOnly"]["note"], "보존", "루트의 모르는 키는 source 에 남는다")
  t.check_eq(scene.find("tile").spec["editorOnly"]["locked"], true, "오브젝트의 모르는 키는 spec 에 남는다")
  t.check(!scene.find("map").tilemap.nil? && scene.find("map").layer_count == 2, "tilemap 이 만들어졌다")
  t.check_eq(scene.find("tile").frame_width, 48, "tile1.png 의 폭 48 (width 0)")
  t.check_eq(scene.find("anim").sprite.current_frame, scene.find("anim").props["startFrame"], "anim 은 startFrame 에 멈춰 있다")
  scene.tick(16)
  t.check_eq(scene.find("tile").x, 198, "mover 컴포넌트가 tile 을 102 옮겼다")
  scene.tick(16)
  scene.tick(16)
  t.check_eq(scene.find("tile").x, 300, "limit 300 에서 멈춘다")
  e = fails_with.call { scene.draw }
  t.check(e.nil?, "픽스처 씬을 그릴 수 있다", e)
  scene.close
  t.check_eq(scene.find("map"), nil, "close 뒤 tilemap 오브젝트도 없다")

  # [params] 선언 파일, 기본값, 덮어쓰기, 컴포넌트마다 따로 만든 Hash, 선언 없는 컴포넌트, 검사 (계획 문서 5.4절)
  t.check_eq(SceneLoader.declaration_path("components/sample/probe"), "scripts/components/sample/probe.json",
             "논리 이름 -> 선언 파일 경로 (scripts/ 아래, 언어 중립)")
  pdecl = SceneLoader.declaration("components/sample/probe")
  t.check(!pdecl.nil? && pdecl["fields"].size == 7, "선언 파일을 읽는다 (필드 일곱)")
  t.check_eq(SceneLoader.declaration("components/sample/loose"), nil, "선언 파일이 없으면 nil")
  pdecl["fields"][0]["default"] = "바꿈"
  t.check_eq(SceneLoader.declaration("components/sample/probe")["fields"][0]["default"], "제목", "declaration 은 복사본을 돌려준다")

  write_file.call("./scripts/components/rbtest_params.json", <<'JSON')
{ "version": 1, "editorOnly": { "group": "이동" }, "fields": [
  { "key": "speed", "type": "number", "label": "속도", "default": 60, "min": 0, "max": 100.5 },
  { "key": "kind", "type": "enum", "values": ["ground", "pipes"], "default": "ground" },
  { "key": "target", "type": "object", "label": "대상" },
  { "key": "name", "type": "string", "default": "새" },
  { "key": "note", "type": "text" },
  { "key": "count", "type": "integer", "default": 2, "min": -1, "max": 9 },
  { "key": "on", "type": "boolean", "default": false, "editorOnly": true }
] }
JSON
  $rbtest_params = []
  recorder = <<'RUBY'
class %s
  def initialize(%s)
    @params = params
  end
  def init(obj, scene); $rbtest_params.push(["init", obj.id, "%s", @params]); end
  def update(obj, scene, elapsed); $rbtest_params.push(["update", obj.id, "%s", @params]); end
  def render(obj, scene); $rbtest_params.push(["render", obj.id, "%s", @params]); end
  def destroy(obj, scene); $rbtest_params.push(["destroy", obj.id, "%s", @params]); end
end
RUBY
  write_file.call("./scripts/ruby/components/rbtest_params.rb", format(recorder, "RbtestParams", "params", "params", "params", "params", "params"))
  write_file.call("./scripts/ruby/components/rbtest_loose.rb", format(recorder, "RbtestLoose", "params = {}", "loose", "loose", "loose", "loose"))
  pn = "components/rbtest_params"
  ln = "components/rbtest_loose"
  recorded = lambda do |hook, id, name|
    r = $rbtest_params.find { |x| x[0] == hook && x[1] == id && x[2] == name }
    r.nil? ? nil : r[3]
  end
  scene = SceneLoader.from_hash(scene_of.call([
    { "id" => "a", "type" => "node", "scripts" => [pn] },
    { "id" => "b", "type" => "node", "scripts" => [pn, ln], "params" => {
      pn => { "speed" => 5, "target" => "c", "note" => "첫 줄\n둘째 줄" },
      ln => { "anything" => [1, 2], "deep" => { "x" => 1 }, "not an identifier" => true } } },
    { "id" => "c", "type" => "node", "scripts" => [pn, pn], "params" => { pn => { "count" => 9 } } },
  ]))
  pa = recorded.call("init", "a", "params")
  t.check(!pa.nil? && pa["speed"] == 60 && pa["kind"] == "ground" && pa["name"] == "새" && pa["count"] == 2 &&
          pa["on"] == false, "기본값만: 선언의 default 가 params 가 된다")
  t.check(!pa.key?("target") && !pa.key?("note"), "default 가 없고 파일에도 없는 키는 nil")
  pb = recorded.call("init", "b", "params")
  t.check(pb["speed"] == 5 && pb["target"] == "c" && pb["note"] == "첫 줄\n둘째 줄" && pb["kind"] == "ground" && pb["count"] == 2,
          "덮어쓰기: 파일의 값이 기본값 위에 온다 (object 는 id 문자열 그대로, 뒤의 오브젝트도 된다)")
  lb = recorded.call("init", "b", "loose")
  t.check(!lb.nil? && lb["anything"][1] == 2 && lb["deep"]["x"] == 1 && lb["not an identifier"] == true,
          "선언이 없는 컴포넌트는 params 항목을 검사 없이 그대로 받는다")
  t.check(!lb.equal?(pb) && !lb.key?("speed") && !pb.key?("anything"), "한 오브젝트의 두 컴포넌트는 표를 따로 받는다")
  t.check(!pa.equal?(pb), "같은 컴포넌트를 붙인 두 오브젝트도 표를 따로 받는다")
  t.check(!lb["deep"].equal?(scene.find("b").spec["params"][ln]["deep"]), "params 는 파일 항목의 깊은 복사")
  cs = $rbtest_params.select { |x| x[0] == "init" && x[1] == "c" }.map { |x| x[3] }
  t.check(cs.size == 2 && !cs[0].equal?(cs[1]) && cs[0]["count"] == 9 && cs[1]["count"] == 9,
          "같은 컴포넌트가 한 오브젝트에 두 번이면 예전처럼 둘 다 만들고 표는 따로")
  pa["speed"] = 1
  pa["kind"] = "pipes"
  scene.tick(16)
  scene.draw
  t.check(recorded.call("update", "a", "params").equal?(pa) && recorded.call("render", "a", "params").equal?(pa),
          "update 와 render 는 init 과 같은 표를 받는다")
  t.check_eq(recorded.call("init", "c", "params")["speed"], 60, "한 표를 고쳐도 다른 오브젝트의 기본값은 그대로")
  spawned = scene.spawn({ "type" => "node", "scripts" => [pn], "params" => { pn => { "target" => "a" } } })
  ps = recorded.call("init", spawned.id, "params")
  t.check(!ps.nil? && ps["speed"] == 60 && ps["kind"] == "ground" && ps["target"] == "a",
          "spawn 도 params 를 만든다 (고친 표가 선언의 기본값에 번지지 않았다)")
  self_ref = scene.spawn({ "id" => "me", "type" => "node", "scripts" => [pn], "params" => { pn => { "target" => "me" } } })
  t.check(!self_ref.nil? && recorded.call("init", "me", "params")["target"] == "me", "spawn 의 object 값은 자기 id 도 된다")
  e = fails_with.call { scene.spawn({ "id" => "s", "type" => "node", "scripts" => [pn], "params" => { pn => { "target" => "nope" } } }) }
  t.check_eq(e, "scene: params 'components/rbtest_params': target names no object 'nope' (s)", "spawn 도 params 를 검사한다")
  t.check_eq(scene.find("s"), nil, "params 가 틀린 spawn 은 오브젝트를 남기지 않는다")
  scene.close
  t.check(recorded.call("destroy", "a", "params").equal?(pa), "destroy 도 같은 표를 받는다")

  # JSON 의 null 은 없는 것, 빈 배열은 빈 객체 (Lua 와 같은 결과)
  write_file.call("./rbtest_nulls.json", <<'JSON')
{ "version": 1, "objects": [
  { "id": "n", "type": "node", "scripts": ["components/rbtest_params"],
    "params": { "components/rbtest_params": { "speed": null, "bogus": null }, "components/not_there": null } },
  { "id": "e", "type": "node", "scripts": ["components/rbtest_params"], "params": [] },
  { "id": "f", "type": "node", "scripts": ["components/rbtest_params"], "params": { "components/rbtest_params": [] } }
] }
JSON
  $rbtest_params = []
  nulls = nil
  e = fails_with.call { nulls = SceneLoader.open("./rbtest_nulls.json") }
  t.check(e.nil?, "null 값과 빈 배열은 오류가 아니다", e)
  unless nulls.nil?
    t.check_eq(recorded.call("init", "n", "params")["speed"], 60, "null 값은 없는 것 (기본값이 남는다)")
    t.check_eq(recorded.call("init", "e", "params")["speed"], 60, "params 의 빈 배열은 빈 객체")
    t.check_eq(recorded.call("init", "f", "params")["speed"], 60, "항목의 빈 배열은 빈 객체")
    nulls.close
  end
  File.delete("./rbtest_nulls.json")

  # [Ruby 클래스] initialize 가 위치 인자를 받으면 new(params), 아니면 new
  write_file.call("./scripts/ruby/components/rbtest_kinds.rb", <<'RUBY')
class RbtestNoInit; end
class RbtestZero; def initialize; @made = true; end; end
class RbtestOpt; def initialize(params = {}); end; end
class RbtestRest; def initialize(*args); end; end
class RbtestChild < RbtestParams; end
class RbtestKinds; end
RUBY
  require "./scripts/ruby/components/rbtest_kinds.rb"
  t.check_eq(SceneLoader.takes_params?(RbtestParams), true, "initialize(params) 는 new(params)")
  t.check_eq(SceneLoader.takes_params?(RbtestOpt), true, "initialize(params = {}) 도 new(params)")
  t.check_eq(SceneLoader.takes_params?(RbtestRest), true, "initialize(*args) 도 new(params)")
  t.check_eq(SceneLoader.takes_params?(RbtestChild), true, "상속한 initialize(params) 도 new(params)")
  t.check_eq(SceneLoader.takes_params?(RbtestNoInit), false, "initialize 가 없으면 new")
  t.check_eq(SceneLoader.takes_params?(RbtestZero), false, "인자 없는 initialize 면 new")
  $rbtest_hooks = []
  scene = SceneLoader.from_hash(scene_of.call([
    { "id" => "h", "type" => "node", "scripts" => ["components/rbtest_hooks"],
      "params" => { "components/rbtest_hooks" => { "ignored" => 1 } } },
  ]))
  t.check(scene.find("h").components[0].is_a?(RbtestHooks) && $rbtest_hooks.include?("init:h"),
          "initialize 가 없는 예전 클래스는 params 가 있어도 new 로 만들고 훅은 그대로")
  scene.close

  # [Ruby 클래스 찾기] 논리 이름 전체의 모듈 경로가 먼저, 없으면 마지막 조각
  t.check_eq(SceneLoader.component_class_path("components/flappy/bird"), "Components::Flappy::Bird", "논리 이름 -> 모듈 경로")
  write_file.call("./scripts/ruby/components/sample/rbtest_twin.rb", <<'RUBY')
module Components
  module Sample
    class RbtestTwin
      def initialize(params); @params = params; end
      def init(obj, scene); $rbtest_hooks.push("nested:#{@params['n']}"); end
    end
  end
end
RUBY
  write_file.call("./scripts/ruby/components/rbtest_twin.rb", <<'RUBY')
class RbtestTwin
  def init(obj, scene); $rbtest_hooks.push("flat"); end
end
RUBY
  $rbtest_hooks = []
  scene = SceneLoader.from_hash(scene_of.call([
    { "id" => "tw", "type" => "node", "scripts" => ["components/sample/rbtest_twin", "components/rbtest_twin"],
      "params" => { "components/sample/rbtest_twin" => { "n" => 1 } } },
  ]))
  comps = scene.find("tw").components
  t.check(comps[0].is_a?(Components::Sample::RbtestTwin) && comps[1].is_a?(RbtestTwin),
          "마지막 이름이 같은 두 컴포넌트가 함께 있다 (Components::Sample::RbtestTwin 과 RbtestTwin)")
  t.check_eq($rbtest_hooks.join(" "), "nested:1 flat", "모듈 경로 클래스가 params 를 받는다")
  scene.close
  t.check_eq(SceneLoader.load_component("components/sample/mover"), Mover,
             "모듈 경로에 없으면 예전처럼 마지막 조각의 클래스 (Components::Sample 이 있어도)")
  t.check_eq(SceneLoader.load_component("components/sample/probe"), Components::Sample::Probe, "픽스처의 probe 는 모듈 경로 클래스")
  write_file.call("./scripts/ruby/components/sample/rbtest_modonly.rb", <<'RUBY')
module Components
  module Sample
    module RbtestModonly; end
  end
end
class RbtestModonly; end
RUBY
  t.check_eq(SceneLoader.load_component("components/sample/rbtest_modonly"), RbtestModonly,
             "모듈 경로의 상수가 클래스가 아니면 마지막 조각의 클래스")
  write_file.call("./scripts/ruby/components/rbtest_noclass.rb", "# 클래스가 없다\n")
  e = fails_with.call { SceneLoader.load_component("components/rbtest_noclass") }
  t.check_eq(e, "scene: component 'components/rbtest_noclass' must define class Components::RbtestNoclass or RbtestNoclass (scripts/ruby/components/rbtest_noclass.rb)",
             "클래스가 없으면 두 이름과 파일을 말한다")

  # [params 검사] 메시지는 글자 그대로 (에디터가 같은 문장을 쓴다)
  v_err = lambda do |objects|
    msg = fails_with.call { SceneLoader.validate(scene_of.call(objects)) }
    msg.nil? ? "ok" : msg
  end
  one = lambda do |params, extra = []|
    v_err.call([{ "id" => "o", "type" => "node", "scripts" => [pn], "params" => params }] + extra)
  end
  pe = "scene: params 'components/rbtest_params': "
  t.check_eq(one.call("x"), "scene: params must be an object (o)", "params 가 객체가 아니면 거부")
  t.check_eq(one.call([1, 2]), "scene: params must be an object (o)", "params 가 배열이면 거부")
  t.check_eq(one.call({ pn => 3 }), "scene: params 'components/rbtest_params' must be an object (o)", "항목 값이 객체가 아니면 거부")
  t.check_eq(one.call({ pn => [1] }), "scene: params 'components/rbtest_params' must be an object (o)", "항목 값이 배열이면 거부")
  t.check_eq(one.call({ "components/rbtest_other" => {} }), "scene: params 'components/rbtest_other': not in scripts (o)",
             "scripts 에 없는 컴포넌트의 params 는 거부")
  t.check_eq(one.call({ pn => { "speeed" => 1 } }), pe + "unknown key 'speeed' (o)", "선언에 없는 키는 거부")
  t.check_eq(one.call({ pn => { "name" => 3 } }), pe + "name must be a string (o)", "string")
  t.check_eq(one.call({ pn => { "note" => false } }), pe + "note must be a string (o)", "text 도 문자열")
  t.check_eq(one.call({ pn => { "speed" => "fast" } }), pe + "speed must be a number (o)", "number")
  t.check_eq(one.call({ pn => { "speed" => -0.5 } }), pe + "speed must be >= 0 (o)", "number 의 min")
  t.check_eq(one.call({ pn => { "speed" => 101 } }), pe + "speed must be <= 100.5 (o)", "number 의 max (소수는 %.14g)")
  t.check_eq(one.call({ pn => { "count" => 1.5 } }), pe + "count must be an integer (o)", "integer 는 정수 값")
  t.check_eq(one.call({ pn => { "count" => "2" } }), pe + "count must be an integer (o)", "integer 는 숫자")
  t.check_eq(one.call({ pn => { "count" => -2 } }), pe + "count must be >= -1 (o)", "integer 의 min")
  t.check_eq(one.call({ pn => { "count" => 10 } }), pe + "count must be <= 9 (o)", "integer 의 max")
  t.check_eq(one.call({ pn => { "count" => 4.0, "speed" => 100.5 } }), "ok", "정수 값의 실수와 max 와 같은 값은 된다")
  t.check_eq(one.call({ pn => { "on" => "yes" } }), pe + "on must be a boolean (o)", "boolean")
  t.check_eq(one.call({ pn => { "kind" => "sky" } }), pe + "kind must be one of ground, pipes (o)", "enum 은 values 중 하나")
  t.check_eq(one.call({ pn => { "kind" => 1 } }), pe + "kind must be one of ground, pipes (o)", "enum 에 문자열이 아닌 값")
  t.check_eq(one.call({ pn => { "target" => 5 } }), pe + "target must be an object id (o)", "object 는 문자열")
  t.check_eq(one.call({ pn => { "target" => "" } }), pe + "target must be an object id (o)", "object 는 빈 문자열이 아니다")
  t.check_eq(one.call({ pn => { "target" => "ghost" } }), pe + "target names no object 'ghost' (o)", "object 는 씬에 있는 id")
  t.check_eq(one.call({ pn => { "target" => "later" } }, [{ "id" => "later", "type" => "node" }]), "ok", "object 는 뒤의 오브젝트도 가리킨다")
  t.check_eq(one.call({ pn => { "target" => "o" } }), "ok", "object 는 자기 자신도 가리킨다")
  t.check_eq(one.call({ pn => { "speed" => "x", "count" => 1.5 } }), pe + "count must be an integer (o)", "키는 바이트 순서로 본다")
  t.check_eq(one.call({ ln => { "x" => 1 }, "components/a_first" => {} }), "scene: params 'components/a_first': not in scripts (o)",
             "params 의 이름도 바이트 순서로 본다")
  t.check_eq(v_err.call([{ "id" => "p", "type" => "node", "scripts" => [pn], "params" => { pn => { "speed" => "x" } } },
                         { "id" => "p", "type" => "node" }]), "scene: duplicate id 'p'", "params 검사는 3절 검사를 모두 통과한 뒤")
  t.check_eq(v_err.call([{ "id" => "p", "type" => "node" },
                         { "id" => "q", "type" => "node", "scripts" => [pn], "params" => { pn => { "on" => 1 } } }]),
             pe + "on must be a boolean (q)", "메시지는 그 오브젝트의 id 를 말한다")
  e = fails_with.call { SceneLoader.from_hash(scene_of.call([{ "id" => "o", "type" => "node", "scripts" => [pn], "params" => { pn => { "speed" => -1 } } }])) }
  t.check_eq(e, pe + "speed must be >= 0 (o)", "fromTable 도 같은 오류로 멈춘다")

  # [선언 파일 검사] 깨진 선언은 그 파일을 말한다 (params 가 없어도 scripts 에 있으면 읽는다)
  decl_n = 0
  decl_err = lambda do |text|
    decl_n += 1
    write_file.call("./scripts/components/rbtest_decl_#{decl_n}.json", text)
    [v_err.call([{ "id" => "o", "type" => "node", "scripts" => ["components/rbtest_decl_#{decl_n}"] }]),
     "scene: declaration scripts/components/rbtest_decl_#{decl_n}.json: "]
  end
  de, dp = decl_err.call('{ "version": 1, ')
  t.check(de.start_with?(dp + "not valid JSON (") && de.end_with?(")") && de.include?("Line") && !de.include?("\n"),
          "JSON 이 아니면 파일과 파서의 설명 (한 줄)", de)
  de, dp = decl_err.call('[1, 2]')
  t.check_eq(de, dp + "not an object", "루트가 객체가 아니면 거부")
  de, dp = decl_err.call('null')
  t.check_eq(de, dp + "not an object", "루트가 null 이면 거부")
  de, dp = decl_err.call('{ "version": 2, "fields": [] }')
  t.check_eq(de, dp + "unsupported version 2 (expected 1)", "version 2 는 거부")
  de, dp = decl_err.call('{ "fields": [] }')
  t.check_eq(de, dp + "unsupported version nil (expected 1)", "version 이 없으면 거부")
  de, dp = decl_err.call('[]')
  t.check_eq(de, dp + "unsupported version nil (expected 1)", "빈 배열은 빈 객체 (version 이 없다)")
  de, dp = decl_err.call('{ "version": 1, "fields": { "a": 1 } }')
  t.check_eq(de, dp + "fields must be an array", "fields 가 배열이 아니면 거부")
  de, dp = decl_err.call('{ "version": 1, "fields": [ 3 ] }')
  t.check_eq(de, dp + "fields[1] is not an object", "필드가 객체가 아니면 거부")
  de, dp = decl_err.call('{ "version": 1, "fields": [ { "key": "ok", "type": "string" }, { "key": "9lives", "type": "string" } ] }')
  t.check_eq(de, dp + "fields[2] needs a key ([A-Za-z_][A-Za-z0-9_]*)", "key 는 식별자 (번호는 1 부터)")
  de, dp = decl_err.call('{ "version": 1, "fields": [ { "type": "string" } ] }')
  t.check_eq(de, dp + "fields[1] needs a key ([A-Za-z_][A-Za-z0-9_]*)", "key 가 없으면 거부")
  de, dp = decl_err.call('{ "version": 1, "fields": [ { "key": "a", "type": "string" }, { "key": "a", "type": "number" } ] }')
  t.check_eq(de, dp + "duplicate key 'a'", "key 중복은 거부")
  de, dp = decl_err.call('{ "version": 1, "fields": [ { "key": "a" } ] }')
  t.check_eq(de, dp + "field 'a' needs a type", "type 이 없으면 거부")
  de, dp = decl_err.call('{ "version": 1, "fields": [ { "key": "a", "type": "color" } ] }')
  t.check_eq(de, dp + "field 'a': unknown type 'color'", "모르는 type 은 거부")
  de, dp = decl_err.call('{ "version": 1, "fields": [ { "key": "a", "type": "string", "label": 3 } ] }')
  t.check_eq(de, dp + "field 'a': label must be a string", "label 은 문자열")
  de, dp = decl_err.call('{ "version": 1, "fields": [ { "key": "a", "type": "enum" } ] }')
  t.check_eq(de, dp + "field 'a': values must be a non-empty array of strings", "enum 은 values 가 필요")
  de, dp = decl_err.call('{ "version": 1, "fields": [ { "key": "a", "type": "enum", "values": [] } ] }')
  t.check_eq(de, dp + "field 'a': values must be a non-empty array of strings", "enum 의 values 는 비어 있지 않다")
  de, dp = decl_err.call('{ "version": 1, "fields": [ { "key": "a", "type": "enum", "values": ["x", ""] } ] }')
  t.check_eq(de, dp + "field 'a': values must be a non-empty array of strings", "values 에 빈 문자열은 안 된다")
  de, dp = decl_err.call('{ "version": 1, "fields": [ { "key": "a", "type": "enum", "values": ["x", 1] } ] }')
  t.check_eq(de, dp + "field 'a': values must be a non-empty array of strings", "values 는 문자열만")
  de, dp = decl_err.call('{ "version": 1, "fields": [ { "key": "a", "type": "string", "values": ["x"] } ] }')
  t.check_eq(de, dp + "field 'a': values is only for enum", "values 는 enum 에만")
  de, dp = decl_err.call('{ "version": 1, "fields": [ { "key": "a", "type": "number", "min": "0" } ] }')
  t.check_eq(de, dp + "field 'a': min must be a number", "min 은 숫자")
  de, dp = decl_err.call('{ "version": 1, "fields": [ { "key": "a", "type": "integer", "max": true } ] }')
  t.check_eq(de, dp + "field 'a': max must be a number", "max 는 숫자")
  de, dp = decl_err.call('{ "version": 1, "fields": [ { "key": "a", "type": "string", "max": 3 } ] }')
  t.check_eq(de, dp + "field 'a': max is only for number and integer", "max 는 number 와 integer 에만")
  de, dp = decl_err.call('{ "version": 1, "fields": [ { "key": "a", "type": "number", "min": 5, "max": 1 } ] }')
  t.check_eq(de, dp + "field 'a': min must be <= max", "min 은 max 이하")
  de, dp = decl_err.call('{ "version": 1, "fields": [ { "key": "a", "type": "string", "default": 3 } ] }')
  t.check_eq(de, dp + "field 'a': default must be a string", "string 의 default")
  de, dp = decl_err.call('{ "version": 1, "fields": [ { "key": "a", "type": "text", "default": true } ] }')
  t.check_eq(de, dp + "field 'a': default must be a string", "text 의 default")
  de, dp = decl_err.call('{ "version": 1, "fields": [ { "key": "a", "type": "number", "default": "x" } ] }')
  t.check_eq(de, dp + "field 'a': default must be a number", "number 의 default")
  de, dp = decl_err.call('{ "version": 1, "fields": [ { "key": "a", "type": "number", "default": 11, "max": 10 } ] }')
  t.check_eq(de, dp + "field 'a': default must be <= 10", "default 도 min, max 안")
  de, dp = decl_err.call('{ "version": 1, "fields": [ { "key": "a", "type": "integer", "default": 0.5 } ] }')
  t.check_eq(de, dp + "field 'a': default must be an integer", "integer 의 default")
  de, dp = decl_err.call('{ "version": 1, "fields": [ { "key": "a", "type": "boolean", "default": "no" } ] }')
  t.check_eq(de, dp + "field 'a': default must be a boolean", "boolean 의 default")
  de, dp = decl_err.call('{ "version": 1, "fields": [ { "key": "a", "type": "enum", "values": ["x", "y"], "default": "z" } ] }')
  t.check_eq(de, dp + "field 'a': default must be one of x, y", "enum 의 default")
  de, dp = decl_err.call('{ "version": 1, "fields": [ { "key": "a", "type": "object", "default": 3 } ] }')
  t.check_eq(de, dp + "field 'a': default must be an object id", "object 의 default")
  de, dp = decl_err.call('{ "version": 1, "fields": [ { "key": "a", "type": "object", "default": "ghost" } ] }')
  t.check_eq(de, "ok", "object 의 default 는 씬의 id 를 보지 않는다")
  de, dp = decl_err.call('{ "version": 1 }')
  t.check_eq(de, "ok", "fields 가 없으면 빈 배열")
  nofields = "components/rbtest_decl_#{decl_n}"
  t.check_eq(v_err.call([{ "id" => "o", "type" => "node", "scripts" => [nofields], "params" => { nofields => { "x" => 1 } } }]),
             "scene: params '#{nofields}': unknown key 'x' (o)", "선언 파일이 있으면 필드가 없어도 모르는 키는 거부")
  e = fails_with.call { SceneLoader.declaration("components/rbtest_decl_2") }
  t.check_eq(e, "scene: declaration scripts/components/rbtest_decl_2.json: not an object", "SceneLoader.declaration 도 깨진 선언은 오류")
  (1..decl_n).each { |i| File.delete("./scripts/components/rbtest_decl_#{i}.json") }
  File.delete("./scripts/components/rbtest_params.json")
  ["rbtest_params", "rbtest_loose", "rbtest_kinds", "rbtest_twin", "rbtest_noclass", "sample/rbtest_twin", "sample/rbtest_modonly"].each do |f|
    File.delete("./scripts/ruby/components/#{f}.rb")
  end
  $rbtest_params = []

  File.delete("./scripts/ruby/components/rbtest_hooks.rb")
  File.delete("./scripts/ruby/components/rbtest_tail.rb")
  File.delete("./scripts/ruby/components/rbtest_spawner.rb")
  $rbtest_hooks = []
end
