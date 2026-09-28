# 씬 로더 params 픽스처 씬 (tests/run_engine_tests.py 가 구동, r1-scene-loader.md 5.4절)
#
# tests/fixtures/scenes/params_v1.json 을 Ruby 씬 로더로 열어 scene_params_scene.lua 와 같은 줄을 찍는다.
# 컴포넌트는 new(params) 로 받는 클래스(Components::Sample::Probe, Drift 와 Loose)와 받지 않는
# 클래스(Mover)가 섞여 있다.

require "scripts/ruby/scene_loader"

$scene = nil
$custom = nil
$ticks = 0

# 값을 두 언어가 같은 글자로 찍는다: 문자열은 따옴표와 \n, 배열은 [..], 객체는 키 순서의 {k=v}
def show(v)
  if v.is_a?(String)
    # mruby 의 gsub 은 한글이 든 문자열에서 줄바꿈 뒤를 잃어 split 과 join 으로 바꾼다
    "\"" + v.split("\n", -1).join("\\n") + "\""
  elsif v.is_a?(Array)
    "[" + v.map { |x| show(x) }.join(",") + "]"
  elsif v.is_a?(Hash)
    "{" + v.keys.sort.map { |k| "#{k}=#{show(v[k])}" }.join(",") + "}"
  elsif v.nil?
    "nil"
  else
    v.to_s
  end
end

# params Hash 하나를 "k=v k=v" 로 (키 순서)
def fields(h)
  h.keys.sort.map { |k| "#{k}=#{show(h[k])}" }.join(" ")
end

def init
  $scene = SceneLoader.open("fixtures/scenes/params_v1.json")
  puts "params:order:#{$scene.objects.map(&:id).join(',')}"
  ["plain", "custom", "pair"].each do |id|
    puts "params:#{id}:#{fields($scene.find(id).probes[0])}"
  end
  puts "params:probes:pair=#{$scene.find('pair').probes.size}"
  puts "params:loose:#{fields($scene.find('loose').loose)}"
  # 컴포넌트마다 따로 만든 Hash 다: 한 곳을 고쳐도 다른 오브젝트의 Hash 와 선언의 기본값은 그대로다
  plain = $scene.find("plain").probes[0]
  pair = $scene.find("pair").probes[0]
  plain["title"] = "고침"
  decl = SceneLoader.declaration("components/sample/probe")
  puts "params:separate:#{!plain.equal?(pair) && pair['title'] == '제목' && decl['fields'][0]['default'] == '제목'}"
  # 같은 픽스처에서 custom 의 kind 만 values 밖으로 바꾼 Hash 는 검증이 거부한다
  bad = Json.load("./fixtures/scenes/params_v1.json")
  bad["objects"][1]["params"]["components/sample/probe"]["kind"] = "sky"
  message = nil
  begin
    SceneLoader.validate(bad)
  rescue SceneLoader::Error => e
    message = e.message
  end
  puts "params:error:#{message}"
  $custom = $scene.find("custom")
end

def update(elapsed)
  return if $ticks >= 3
  $scene = $scene.tick(elapsed)
  $ticks += 1
  mark = $scene.find("mark")
  puts "params:tick#{$ticks}:mark=#{mark.x},#{mark.y}"
  System.exit if $ticks == 3
end

def render
  $scene.draw
end

def destroy
  $scene.close
  # 첫 render 와 첫 update 의 순서는 프레임 속도에 달려 있어 정렬해 찍는다
  puts "params:hooks:#{$custom.probe_log.sort.join(',')}"
  puts "params:closed:#{$scene.closed?}"
end
