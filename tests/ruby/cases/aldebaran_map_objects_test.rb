# aldebaran_map_objects_test.rb : 알데바란 맵 오브젝트의 단위 테스트
# (docs/plans/m1-map-objects.md)
#
# 스테이지 배치(시작 지점, 체크포인트, 몬스터, 흔적, 구간, 빛기둥)는 맵 파일의
# objects에 있고, 오브젝트의 타입과 칸은 resources/schema/map-objects.json이 정한다.
#   [A] 스키마 파일이 에디터가 읽는 형식을 지킨다
#   [B] 두 맵의 오브젝트가 스키마를 지킨다 (검사기가 실제로 잡는지도 본다)
#   [C] 스키마의 목록이 게임 데이터(몬스터 종, 힘, 구간 이름)와 같다
#   [D] 스테이지 모듈이 맵에서 만든 표가 아래의 고정값과 같다 (Integer와 Float의 구분까지)
#   [E] INITIAL2D_ALDEBARAN_STAGE가 스테이지 id, 맵 이름, 맵 파일 경로를 모두 받는다
#   [F] INITIAL2D_ALDEBARAN_AT으로 옮긴 시작 x가 지면 속이면 지면 위로 올린다
#
# 섞는 비율의 기댓값은 `29.0 / 192`처럼 나눗셈으로 적는다. 이 엔진의 mruby는 몇몇 실수
# 리터럴을 1 ulp 어긋나게 읽는다 (docs/plans/s2-ruby-aldebaran.md 6절).

require "scripts/ruby/games/aldebaran/data/monsters"
require "scripts/ruby/games/aldebaran/combat"
require "scripts/ruby/games/aldebaran/stages/init"
require "scripts/ruby/games/aldebaran/stages/placement"

module MapObjectsTest
  SCHEMA_PATH = "./resources/schema/map-objects.json"
  MAPS = {
    "forest" => "./resources/maps/aldebaran_forest.json",
    "tomb" => "./resources/maps/aldebaran_tomb.json",
  }

  # ---- 고정값 ----------------------------------------------------------------
  # 스테이지 모듈이 맵에서 만들어야 하는 표. 몬스터 id와 난수 소비가 배치 순서를
  # 따르므로 spawns는 순서까지 같아야 한다.

  FOREST = {
    start: { x: 56, y: 384 },
    checkpoints: [
      { x: 1552, y: 304 },
      { x: 2400, y: 352 },
    ],
    sections: [
      { name: :entrance, x1: 767 },
      { name: :road, x1: 1599 },
      { name: :gorge, x1: 2367 },
      { name: :den, x1: 3263 },
      { name: :altar, x1: 4096 },
    ],
    climate: nil,
    spawns: [
      { species: :spider, x: 224, y: 384, min_x: 180, max_x: 280 },
      { species: :spider, x: 672, y: 352, min_x: 630, max_x: 730 },
      { species: :spider, x: 900, y: 352, min_x: 860, max_x: 960 },
      { species: :spider, x: 1056, y: 336, min_x: 1010, max_x: 1120 },
      { species: :spider, x: 1400, y: 304, min_x: 1370, max_x: 1450 },
      { species: :spider, x: 1470, y: 304, min_x: 1440, max_x: 1520 },
      { species: :spider, x: 1700, y: 304, min_x: 1660, max_x: 1760 },
      { species: :wolf, x: 1990, y: 304, min_x: 1950, max_x: 2030 },
      { species: :spider, x: 2290, y: 320, min_x: 2260, max_x: 2340 },
      { species: :wolf, x: 2760, y: 368, min_x: 2700, max_x: 2820 },
      { species: :wolf, x: 2830, y: 368, min_x: 2770, max_x: 2890 },
      { species: :wolf, x: 3060, y: 368, min_x: 3010, max_x: 3120 },
      { species: :wolf, x: 3120, y: 368, min_x: 3060, max_x: 3180 },
      { species: :blackwolf, x: 3220, y: 368, min_x: 3160, max_x: 3250 },
      { species: :wolf, x: 3450, y: 384, min_x: 3400, max_x: 3520 },
      { species: :monkey, x: 3860, y: 384, min_x: 3640, max_x: 4040, boss: true },
    ],
    landmarks: [
      { id: :tracks, x0: 300, x1: 348, title: "여러 갈래의 발자국",
        text: "발자국이 여럿이다. 그놈은 혼자가 아니었다.", skill: :edge },
      { id: :road, x0: 790, x1: 838, title: "다져진 포석",
        text: "밟혀 다져진 돌길이다. 숲이 나중에 덮은 것이다.", skill: :read },
      { id: :cart, x0: 1640, x1: 1688, title: "버려진 짐수레",
        text: "짐이 그대로 실려 있다. 사람들은 급히 떠났다.", skill: :leap },
      { id: :cage, x0: 2440, x1: 2488, title: "부서진 우리",
        text: "실험실의 우리다. 안개는 저들이 열매를 태워 만든다.",
        hallucination: 3.0, skill: :berserk },
      { id: :altar, x0: 3700, x1: 3748, title: "네 개의 화두",
        text: "고대 문자와 굳은 피. 지도에 그려진 것이 이곳이었다.", skill: :bolt },
    ],
    # [x, 지금 구간, 다음 구간, 섞는 비율]. 비율의 0은 Integer, 나머지는 Float다
    section_at: [
      [0, :entrance, :road, 0],
      [700, :entrance, :road, (96 - 67).to_f / 192],
      [767, :entrance, :road, 96.0 / 192],
      [768, :entrance, :road, 0.5 + 1.0 / 192],
      [800.5, :entrance, :road, 0.5 + 33.5 / 192],
      [1000, :road, :gorge, 0],
      [1550, :road, :gorge, (96 - 49).to_f / 192],
      [3263, :den, :altar, 96.0 / 192],
      [3300, :den, :altar, 0.5 + 37.0 / 192],
      [4096, :altar, :altar, 0],
      [5000, :altar, :altar, 0],
    ],
  }

  TOMB = {
    start: { x: 56, y: 384 },
    checkpoints: [
      { x: 1984, y: 400 },
      { x: 3008, y: 384 },
    ],
    sections: [
      { name: :chest, x1: 895 },
      { name: :moon, x1: 1919 },
      { name: :stars, x1: 2943 },
      { name: :ruin, x1: 4031 },
      { name: :sun, x1: 5119 },
    ],
    climate: {
      moon: { kind: :snow, friction: 0.34, flakes: 40 },
      stars: { kind: :light, period: 4.0, lit: 2.2,
               pillars: [2180, 2420, 2660], half_w: 44 },
      ruin: { kind: :hail, interval: 1.6, warn: 0.5, damage: 9,
              speed: 320, half_w: 5, count: 2 },
      sun: { kind: :flood, period: 9.0, low: 400, high: 336,
             move_mult: 0.55, jump_mult: 0.72 },
    },
    spawns: [
      { species: :sentinel, x: 640, y: 384, min_x: 600, max_x: 700 },
      { species: :soul, x: 1040, y: 336, min_x: 990, max_x: 1120 },
      { species: :soul, x: 1300, y: 300, min_x: 1250, max_x: 1380 },
      { species: :sentinel, x: 1500, y: 400, min_x: 1450, max_x: 1560 },
      { species: :soul, x: 1700, y: 288, min_x: 1640, max_x: 1780 },
      { species: :soul, x: 2200, y: 300, min_x: 2140, max_x: 2280 },
      { species: :soul, x: 2440, y: 268, min_x: 2380, max_x: 2520 },
      { species: :soul, x: 2680, y: 300, min_x: 2620, max_x: 2760 },
      { species: :sentinel, x: 2860, y: 384, min_x: 2800, max_x: 2920 },
      { species: :shard, x: 3120, y: 384, min_x: 3060, max_x: 3180 },
      { species: :sentinel, x: 3440, y: 368, min_x: 3400, max_x: 3500 },
      { species: :shard, x: 3560, y: 368, min_x: 3500, max_x: 3640 },
      { species: :soul, x: 3700, y: 300, min_x: 3650, max_x: 3800 },
      { species: :shard, x: 3900, y: 384, min_x: 3840, max_x: 3980 },
      { species: :sentinel, x: 4180, y: 400, min_x: 4130, max_x: 4240 },
      { species: :soul, x: 4320, y: 300, min_x: 4260, max_x: 4400 },
      { species: :shard, x: 4420, y: 400, min_x: 4360, max_x: 4480 },
      { species: :apophis, x: 4720, y: 400, min_x: 4300, max_x: 5040, boss: true },
    ],
    landmarks: [
      { id: :chest, x0: 300, x1: 348, title: "열려 있는 가슴",
        text: "사자의 가슴이 문이다. 닫힌 적이 없다. 언제든 나올 수 있게 지었다." },
      { id: :moon, x0: 1440, x1: 1488, title: "달의 방",
        text: "달의 기운으로 태양의 방을 고른다고 했다. 눈이 내리는 이유다." },
      { id: :stars, x0: 2360, x1: 2408, title: "별들의 노래",
        text: "별들은 황제의 탄생을 칭송하며 노래를 부르고 빛의 축제를 여느니라." },
      { id: :ruin, x0: 3260, x1: 3308, title: "파괴의 방",
        text: "여기 수호자가 있다. 기후를 쥔 자다. 방마다 다른 하늘은 그의 것이다." },
      { id: :sarc, x0: 4020, x1: 4068, title: "닫히지 않은 석관",
        text: "신하와 자식들을 함께 묻었다. 그들이 아직 이 방을 지킨다." },
    ],
    section_at: [
      [0, :chest, :moon, 0],
      [850, :chest, :moon, (96 - 45).to_f / 192],
      [896, :chest, :moon, 0.5 + 1.0 / 192],
      [1871, :moon, :stars, (96 - 48).to_f / 192],
      [2400, :stars, :ruin, 0],
      [4100, :ruin, :sun, 0.5 + 69.0 / 192],
      [5119, :sun, :sun, 0],
      [6000, :sun, :sun, 0],
    ],
  }

  SHAPES = ["point", "band", "rect"]
  COLORS = ["accent", "danger", "warning", "success", "muted"]
  FIELD_TYPES = ["string", "text", "number", "integer", "boolean", "enum"]

  # 두 값을 끝까지 비교해 다른 자리를 out에 적는다. 값의 클래스(Integer와 Float,
  # Symbol과 String)까지 같아야 한다.
  def self.diff(actual, expected, path, out)
    if expected.is_a?(Hash)
      return out.push("#{path}: #{actual.class}, 기대 Hash") unless actual.is_a?(Hash)
      expected.each do |k, v|
        if actual.key?(k)
          diff(actual[k], v, "#{path}.#{k}", out)
        else
          out.push("#{path}.#{k}: 빠진 칸")
        end
      end
      actual.each_key { |k| out.push("#{path}.#{k}: 기대에 없는 칸") unless expected.key?(k) }
    elsif expected.is_a?(Array)
      return out.push("#{path}: #{actual.class}, 기대 Array") unless actual.is_a?(Array)
      out.push("#{path}: 길이 #{actual.size}, 기대 #{expected.size}") if actual.size != expected.size
      expected.each_with_index { |v, i| diff(actual[i], v, "#{path}[#{i}]", out) }
    elsif actual.class != expected.class || actual != expected
      out.push("#{path}: #{actual.inspect}(#{actual.class}), 기대 #{expected.inspect}(#{expected.class})")
    end
    out
  end

  def self.check_same(t, actual, expected, label)
    out = diff(actual, expected, "", [])
    t.check(out.empty?, label, out.join(" / "))
  end

  def self.type_spec(schema, name)
    schema["types"].find { |spec| spec["type"] == name }
  end

  def self.field_spec(spec, name)
    (spec["fields"] || []).find { |f| f["name"] == name }
  end

  # 오브젝트 목록을 스키마에 대어 보고 문제 문장의 배열을 돌려준다. 에디터의 validateObjects
  # 규칙에 더해 스키마에 없는 props 칸(게임이 조용히 무시하는 오타)과 범위 밖 x도 문제로 친다.
  def self.validate(objects, schema)
    problems = []
    types = {}
    schema["types"].each { |spec| types[spec["type"]] = spec }
    ids = {}
    uniques = {}
    objects.each_with_index do |o, i|
      where = "objects[#{i}]"
      id = o["id"]
      if !id.is_a?(String) || id.empty?
        problems.push("#{where}: id가 없다")
      elsif ids.key?(id)
        problems.push("#{where}: id가 겹친다 (#{id})")
      else
        ids[id] = true
      end
      problems.push("#{where}: x가 숫자가 아니다") unless o["x"].is_a?(Numeric)
      problems.push("#{where}: y가 숫자가 아니다") if o.key?("y") && !o["y"].is_a?(Numeric)
      spec = types[o["type"]]
      if spec.nil?
        problems.push("#{where}: 스키마에 없는 타입 #{o['type']}")
        next
      end
      uniques[o["type"]] = (uniques[o["type"]] || 0) + 1 if spec["unique"] == true
      shape = spec["shape"] || "point"
      if (shape == "band" || shape == "rect") && !(o["width"].is_a?(Numeric) && o["width"] > 0)
        problems.push("#{where}: 폭이 없다")
      end
      if shape == "rect" && !(o["height"].is_a?(Numeric) && o["height"] > 0)
        problems.push("#{where}: 높이가 없다")
      end
      props = o["props"] || {}
      known = {}
      lo = nil
      hi = nil
      (spec["fields"] || []).each do |f|
        known[f["name"]] = true
        lo = f["name"] if f["role"] == "rangeMin"
        hi = f["name"] if f["role"] == "rangeMax"
        at = "#{where}.props.#{f['name']}"
        v = props[f["name"]]
        if v.nil?
          problems.push("#{at}: 비어 있다") if f["required"] == true
          next
        end
        ok = case f["type"]
             when "string", "text" then v.is_a?(String)
             when "number" then v.is_a?(Numeric)
             when "integer" then v.is_a?(Integer)
             when "boolean" then v == true || v == false
             when "enum" then v.is_a?(String) && f["values"].include?(v)
             else false
             end
        problems.push("#{at}: 값 #{v.inspect}이 #{f['type']}이 아니다") unless ok
        if v.is_a?(Numeric)
          problems.push("#{at}: 최솟값보다 작다") if f.key?("min") && v < f["min"]
          problems.push("#{at}: 최댓값보다 크다") if f.key?("max") && v > f["max"]
        end
      end
      props.each_key { |k| problems.push("#{where}.props.#{k}: 스키마에 없는 칸") unless known[k] }
      if lo && hi && props[lo].is_a?(Numeric) && props[hi].is_a?(Numeric)
        if props[lo] > props[hi]
          problems.push("#{where}: 범위가 뒤집혔다")
        elsif o["x"].is_a?(Numeric) && (o["x"] < props[lo] || o["x"] > props[hi])
          problems.push("#{where}: x가 범위 밖이다")
        end
      end
    end
    uniques.each { |type, n| problems.push("#{type}은 하나만 둘 수 있다 (#{n}개)") if n > 1 }
    problems
  end
end

T.run_case("aldebaran_map_objects") do |t|
  mt = MapObjectsTest
  stages = Aldebaran::Stages
  schema = Json.load(MapObjectsTest::SCHEMA_PATH)
  maps = {}
  MapObjectsTest::MAPS.each { |id, path| maps[id] = Json.load(path) }

  # [A] 스키마 형식 (schema.ts의 parseObjectSchema가 거절하는 것이 없다)
  begin
    t.check_eq(schema["version"], 1, "스키마 버전은 1")
    seen = {}
    bad = []
    schema["types"].each_with_index do |spec, i|
      where = "types[#{i}]"
      bad.push("#{where}.type") unless spec["type"].is_a?(String) && !spec["type"].empty?
      bad.push("#{where}: 타입이 겹친다") if seen.key?(spec["type"])
      seen[spec["type"]] = true
      bad.push("#{where}.shape") unless MapObjectsTest::SHAPES.include?(spec["shape"] || "point")
      bad.push("#{where}.color") unless MapObjectsTest::COLORS.include?(spec["color"] || "accent")
      bad.push("#{where}.label") unless spec["label"].is_a?(String)
      names = {}
      (spec["fields"] || []).each_with_index do |f, j|
        fw = "#{where}.fields[#{j}]"
        bad.push("#{fw}.name") unless f["name"].is_a?(String) && !f["name"].empty?
        bad.push("#{fw}: 칸이 겹친다") if names.key?(f["name"])
        names[f["name"]] = true
        bad.push("#{fw}.type") unless MapObjectsTest::FIELD_TYPES.include?(f["type"])
        if f["type"] == "enum" && !(f["values"].is_a?(Array) && !f["values"].empty?)
          bad.push("#{fw}.values")
        end
        bad.push("#{fw}.label") unless f["label"].is_a?(String)
      end
    end
    t.check(bad.empty?, "스키마의 타입과 칸이 형식을 지킨다", bad.join(", "))
    t.check_eq(seen.keys, ["start", "checkpoint", "spawn", "landmark", "section", "light"],
               "타입은 여섯이다")
    t.check_eq(mt.type_spec(schema, "start")["unique"], true, "시작 지점은 하나만")
    t.check_eq(mt.type_spec(schema, "landmark")["shape"], "band", "흔적은 띠")
    t.check_eq(mt.type_spec(schema, "section")["shape"], "band", "구간은 띠")
    t.check_eq(mt.type_spec(schema, "spawn")["color"], "danger", "몬스터는 위험색")
    mt.check_same(t, (schema["play"] || {})["env"], {
      "INITIAL2D_SCENE" => "aldebaran",
      "INITIAL2D_SKIP_INTRO" => "1",
      "INITIAL2D_ALDEBARAN_STAGE" => "{map.name}",
      "INITIAL2D_ALDEBARAN_AT" => "{x}",
    }, "실행 환경 변수는 스테이지 씬을 그 맵과 그 x로 연다")
  end

  # [B] 두 맵의 오브젝트가 스키마를 지킨다
  begin
    Aldebaran::Stages::ORDER.each do |id|
      data = maps[id]
      t.check_eq(data["version"], 2, "#{id}: 맵 포맷 v2")
      objects = data["objects"] || []
      problems = mt.validate(objects, schema)
      t.check(problems.empty?, "#{id}: 오브젝트 #{objects.size}개가 스키마를 지킨다", problems.join(" / "))
      t.check_eq(objects.count { |o| o["type"] == "start" }, 1, "#{id}: 시작 지점이 하나 있다")
      t.check_eq(objects.count { |o| o["type"] == "section" }, 5, "#{id}: 구간은 다섯")

      # 구간 띠는 0에서 시작해 빈틈 없이 이어진다 (구간은 오른끝만 보므로 틈은 조용히 묻힌다)
      bands = objects.select { |o| o["type"] == "section" }.sort { |a, b| a["x"] <=> b["x"] }
      edge = 0
      gaps = []
      bands.each do |b|
        gaps.push("#{b['id']}@#{b['x']}") if b["x"] != edge
        edge = b["x"] + b["width"]
      end
      t.check(gaps.empty?, "#{id}: 구간 띠가 0부터 이어진다", gaps.join(", "))
    end
    t.check_eq(maps["forest"]["name"], "aldebaran_forest", "숲 맵의 이름")
    t.check_eq(maps["tomb"]["name"], "aldebaran_tomb", "무덤 맵의 이름")
  end

  # [B2] 검사기가 실제로 잡는가 (통과만 보면 검사기가 망가져도 모른다)
  begin
    caught = lambda do |objects, label|
      t.check(!mt.validate(objects, schema).empty?, "검사기가 잡는다: #{label}")
    end
    ok = { "id" => "s", "type" => "spawn", "x" => 10, "y" => 0,
           "props" => { "species" => "wolf", "minX" => 0, "maxX" => 20 } }
    t.check_eq(mt.validate([ok], schema).size, 0, "검사기가 올바른 몬스터는 통과시킨다")
    spawn = lambda do |x, props|
      [{ "id" => "s", "type" => "spawn", "x" => x, "y" => 0, "props" => props }]
    end
    caught.call(spawn.call(10, { "species" => "dragon", "minX" => 0, "maxX" => 20 }), "모르는 종")
    caught.call(spawn.call(10, { "species" => "wolf", "minX" => 30, "maxX" => 20 }), "뒤집힌 순찰 범위")
    caught.call(spawn.call(50, { "species" => "wolf", "minX" => 0, "maxX" => 20 }), "순찰 범위 밖의 x")
    caught.call(spawn.call(10, { "minX" => 0, "maxX" => 20 }), "빠진 종")
    caught.call(spawn.call(10, { "species" => "wolf", "minX" => 0, "maxX" => 20, "bos" => true }),
                "스키마에 없는 칸")
    caught.call([{ "id" => "a", "type" => "start", "x" => 0, "y" => 0 },
                 { "id" => "b", "type" => "start", "x" => 1, "y" => 0 }], "시작 지점 둘")
    caught.call([{ "id" => "l", "type" => "landmark", "x" => 0, "y" => 0,
                   "props" => { "title" => "t", "text" => "x" } }], "폭이 없는 흔적")
    caught.call([{ "id" => "l", "type" => "landmark", "x" => 0, "y" => 0, "width" => 48,
                   "props" => { "title" => "t", "text" => "x", "skill" => "fly" } }], "모르는 힘")
    caught.call([{ "id" => "q", "type" => "mystery", "x" => 0, "y" => 0 }], "모르는 타입")
    caught.call([ok, ok], "겹치는 id")
  end

  # [C] 스키마의 목록이 게임 데이터와 같다
  begin
    species = mt.field_spec(mt.type_spec(schema, "spawn"), "species")["values"]
    t.check_eq(species, Aldebaran::Monsters::SPECIES.keys.map { |k| k.to_s },
               "종 목록은 종별 표의 키를 정의 순서대로 모은 것")
    skill = mt.field_spec(mt.type_spec(schema, "landmark"), "skill")["values"]
    t.check_eq(skill, Aldebaran::Combat::SKILL_ORDER.map { |k| k.to_s },
               "흔적의 힘 목록은 Combat::SKILL_ORDER")
    names = []
    Aldebaran::Stages::ORDER.each do |id|
      stages.get(id)[0].sections.each { |s| names.push(s[:name].to_s) }
    end
    t.check_eq(mt.field_spec(mt.type_spec(schema, "section"), "name")["values"], names,
               "구간 이름 목록은 두 스테이지의 구간 이름을 순서대로 모은 것")
    t.check_eq(mt.field_spec(mt.type_spec(schema, "spawn"), "minX")["role"], "rangeMin", "minX는 순찰 왼끝")
    t.check_eq(mt.field_spec(mt.type_spec(schema, "spawn"), "maxX")["role"], "rangeMax", "maxX는 순찰 오른끝")
  end

  # [D] 스테이지 모듈이 만든 표가 고정값과 같다
  begin
    { "forest" => MapObjectsTest::FOREST, "tomb" => MapObjectsTest::TOMB }.each do |id, want|
      stage = stages.get(id)[0]
      mt.check_same(t, stage.start, want[:start], "#{id}: start")
      # taken은 씬(과 다른 테스트)이 적는 표시라 비교에서 뺀다
      checkpoints = stage.checkpoints.map { |cp| cp.reject { |k, _| k == :taken } }
      mt.check_same(t, checkpoints, want[:checkpoints], "#{id}: checkpoints")
      mt.check_same(t, stage.sections, want[:sections], "#{id}: sections")
      mt.check_same(t, stage.spawns, want[:spawns], "#{id}: spawns (순서 포함)")
      mt.check_same(t, stage.landmarks, want[:landmarks], "#{id}: landmarks")
      mt.check_same(t, stage.climate, want[:climate], "#{id}: climate")
      mt.check_same(t, stage.signs, [], "#{id}: signs는 비어 있다")
      t.check_eq(stage.section_fade, 96, "#{id}: 구간 경계의 폭")
      bad = []
      want[:section_at].each do |row|
        mt.diff(stage.section_at(row[0]), row[1..3], "@#{row[0]}", bad)
      end
      t.check(bad.empty?, "#{id}: section_at의 결과 #{want[:section_at].size}곳", bad.join(" / "))
    end

    # Integer와 Float: JSON의 3은 Integer가 되므로 원래 Float였던 칸은 모듈이 Float로 바꾼다
    forest = stages.get("forest")[0]
    t.check_type(forest.landmarks[3][:hallucination], Float, "환각 시간은 Float")
    t.check_type(forest.start[:x], Integer, "시작 x는 Integer")
    t.check_type(forest.spawns[0][:min_x], Integer, "순찰 범위는 Integer")
    t.check_type(forest.sections[0][:x1], Integer, "구간 오른끝은 Integer")
    t.check_type(stages.get("tomb")[0].climate[:stars][:pillars][0], Integer, "빛기둥 x는 Integer")
    t.check_type(forest.spawns[0][:species], Symbol, "종은 Symbol")
    t.check_type(forest.landmarks[0][:skill], Symbol, "힘은 Symbol")

    # 표는 한 번 만들어 두고 같은 것을 돌려준다 (씬이 cp[:taken]을 적는다)
    t.check(stages.get("forest")[0].checkpoints.equal?(forest.checkpoints), "체크포인트 표는 같은 배열이다")
  end

  # [E] 스테이지 이름: id, 맵 이름, 맵 파일 경로
  begin
    forest = stages.get("forest")[0]
    tomb = stages.get("tomb")[0]
    t.check_eq(stages.get("aldebaran_forest")[0], forest, "맵 이름 aldebaran_forest는 숲")
    t.check_eq(stages.get("aldebaran_tomb")[0], tomb, "맵 이름 aldebaran_tomb은 무덤")
    t.check_eq(stages.get("resources/maps/aldebaran_tomb.json")[0], tomb, "프로젝트 기준 맵 경로")
    t.check_eq(stages.get("./resources/maps/aldebaran_forest.json")[0], forest, "./로 시작하는 맵 경로")
    t.check_eq(stages.get("/home/me/game/resources/maps/aldebaran_tomb.json")[0], tomb, "절대 경로")
    t.check_eq(stages.get("C:\\game\\resources\\maps\\aldebaran_forest.json")[0], forest, "역슬래시 경로")
    t.check_eq(stages.get("aldebaran_forest.json")[0], forest, "파일 이름만")
    none, why = stages.get("aldebaran_desert")
    t.check_eq(none, nil, "모르는 맵 이름은 nil")
    t.check_eq(why, "모르는 스테이지 'aldebaran_desert'", "모르는 맵 이름의 이유")
    t.check_eq(stages.get("resources/maps/other/aldebaran_forest.json")[0], nil,
               "다른 폴더의 같은 이름 파일은 아니다")
    Aldebaran::Stages::ORDER.each do |id|
      t.check_eq(stages.get(maps[id]["name"])[0].id, id,
                 "#{id}: 맵 파일의 name으로 그 스테이지를 연다 ({map.name})")
    end
  end

  # [F] 옮긴 시작 x의 y: 시작 지점의 y(384)에서 발이 지면 속이면 한 칸씩 올린다
  begin
    placement = Aldebaran::Stages::Placement
    stand_on = lambda do |path, x|
      map = Tilemap.new(path)
      w, h, tw, th, = map.size
      solid = lambda do |px, py|
        next true if px < 0 || px >= w * tw
        next false if py < 0 || py >= h * th
        !map.passable?((px / tw).floor, (py / th).floor)
      end
      y = placement.stand_y(x, 384, solid, th)
      map.dispose
      y
    end
    maps_path = MapObjectsTest::MAPS
    t.check_eq(stand_on.call(maps_path["forest"], 224), 384, "숲 입구의 평지는 그대로 384")
    t.check_eq(stand_on.call(maps_path["forest"], 1400.0), 304, "옛 길의 턱 위(지면 304)로 올린다")
    t.check_eq(stand_on.call(maps_path["forest"], 1990.0), 304, "절벽의 어깨 위(지면 304)로 올린다")
    t.check_eq(stand_on.call(maps_path["tomb"], 2480.0), 384, "별들의 방은 바닥이 더 낮아 그대로 (떨어진다)")
    t.check_eq(placement.stand_y(10, 384, ->(_px, _py) { true }, 16), 384, "위가 끝까지 막혔으면 그대로")
  end
end
