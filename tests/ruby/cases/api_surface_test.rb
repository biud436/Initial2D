# api_surface_test.rb : 엔진이 mruby 에 노출하는 API 표면의 계약 검증.
# 바인딩이 실수로 빠지거나 이름이 바뀌면 여기서 잡힌다.
# Lua 쪽 api_surface_test.lua 에 대응하며, 새 바인딩을 추가하면 이 목록도 갱신할 것.
#
# 아래의 명시적 목록은 두 번째 의견이다. 기준은 API 명세
# resources/api/initial2d-api.json (R2, docs/plans/r2-api-stubs.md)이고, 끝의
# api_surface_spec 케이스가 명세와 VM 을 양방향으로 대조한다. 바인딩을 더하거나 바꾸면
# 명세도 고치고 python3 tools/gen_api_stubs.py 로 스텁을 다시 만든다.

MODULES = {
  Graphics: %i[width height render_scale render_scale= frame_count prepare_font
               draw_text text_width set_color draw_point],
  System: %i[platform exit current_directory resource_files message_box app_icon= env script],
  Input: %i[key_down? key_up? key_press? any_key_down? trigger? press? release?
            mouse_x mouse_y mouse_down? mouse_up? mouse_press? any_mouse_down?
            mouse_z mouse_z= touch_count touch touches],
  Audio: %i[play_music play_sound insert_next_music volume volume= pause_music stop_music
            resume_music playing_music? fade_out_music music_position= release_music],
  TextureManager: %i[load remove valid?],
  Json: %i[load parse],
}

CLASSES = {
  Sprite: %i[update draw x y position set_position x= y= position= scale scale= width height
             angle angle= radians radians= visible? visible= opacity opacity=
             frame_delay frame_delay= set_frames start_frame end_frame current_frame
             current_frame= loop= anim_complete? anim_complete= set_sheet_grid
             rect set_rect dispose disposed?],
  Tilemap: %i[draw width height tile_width tile_height layer_count size tile_id
              set_tile_id passable? dispose disposed?],
  FontEx: %i[update draw text= set_position set_text_color opacity= angle= text_width
             dispose disposed?],
}

T.run_case("api_surface") do |t|
  MODULES.each do |name, methods|
    mod = Object.const_get(name)
    t.check_type(mod, Module, "모듈 #{name}")
    methods.each do |m|
      t.check(mod.respond_to?(m), "#{name}.#{m}")
    end
  end

  CLASSES.each do |name, methods|
    klass = Object.const_get(name)
    t.check_type(klass, Class, "클래스 #{name}")
    methods.each do |m|
      t.check(klass.method_defined?(m), "#{name}##{m}")
    end
  end

  t.check(Sprite.respond_to?(:load), "Sprite.load (프렐류드)")
  t.check(Tilemap.respond_to?(:load), "Tilemap.load (프렐류드)")
  # 최상위 def 와 같은 자리에 있는 비공개 메서드라 respond_to? 의 둘째 인자로 본다
  t.check(Object.new.respond_to?(:load, true), "Kernel#load")
  t.check(Object.new.respond_to?(:require, true), "Kernel#require")

  t.check_type(Keys, Module, "Keys 모듈")
  t.check_eq(Keys::ESCAPE, 27, "Keys::ESCAPE")
  t.check_eq(Keys::SPACE, 32, "Keys::SPACE")
  t.check_eq(Keys::Z, 90, "Keys::Z")
  t.check_eq(Keys::DIGIT0, 48, "Keys::DIGIT0")
  t.check_eq(Keys::F12, 123, "Keys::F12")
  t.check_eq(System.script, "mruby", "System.script")
end

# ---- 명세 대조 (R2) ----------------------------------------------------------
# 두 방향으로 본다.
#   1. 명세 -> VM: 명세의 Ruby 이름이 전부 VM 에 있다 (respond_to?, method_defined?, 상수)
#   2. VM -> 명세: 명세에 있는 모듈과 클래스의 실제 메서드(singleton_methods,
#      instance_methods(false))와 Keys.constants 가 전부 명세에 있다. 엔진 것은 C 로
#      정의되었거나 프렐류드에서 온 것이다 (스크립트가 덧붙인 메서드는 세지 않는다)
# 덤으로, 프렐류드 표시가 실제 정의 위치와 맞는지, 인자 없는 getter 의 반환 타입이 명세와
# 맞는지 본다. Kernel 은 mruby 내장 메서드와 섞여 있어 2 의 훑기에서 뺀다.
# 새 최상위 모듈의 발견은 Lua 쪽이 맡는다 (바인딩은 두 언어가 짝으로 늘어난다).

API_SPEC_PATH = "./resources/api/initial2d-api.json"

T.run_case("api_surface_spec") do |t|
  api = Json.load(API_SPEC_PATH)
  t.check_type(api, Hash, "명세 JSON 을 읽는다 (#{API_SPEC_PATH})")
  t.check_eq(api["version"], 1, "명세 version")

  # 명세의 타입 식(number, integer|nil, string[])과 Ruby 값을 견준다
  type_ok = nil
  type_ok = lambda do |v, expr|
    expr.split("|").any? do |alt|
      if alt.end_with?("[]")
        base = alt[0, alt.size - 2]
        v.is_a?(Array) && v.all? { |e| type_ok.call(e, base) }
      else
        case alt
        when "any" then true
        when "nil" then v.nil?
        when "number" then v.is_a?(Numeric)
        when "integer" then v.is_a?(Integer)
        when "string" then v.is_a?(String)
        when "boolean" then v == true || v == false
        when "table" then v.is_a?(Hash)
        when "array" then v.is_a?(Array)
        when "symbol" then v.is_a?(Symbol)
        when "function" then v.is_a?(Proc)
        else Object.const_defined?(alt.to_sym) && v.is_a?(Object.const_get(alt.to_sym))
        end
      end
    end
  end

  ruby_params = lambda { |f| f["rubyParams"] || f["params"] }
  ruby_returns = lambda { |f| f["rubyReturns"] || f["returns"] }
  safe_getter = lambda do |f|
    %w[getter predicate].include?(f["rubyKind"]) &&
      ruby_params.call(f).count { |p| !p["optional"] && !p["variadic"] } == 0
  end
  # 정의 위치. nil 이면 C, "<prelude>" 면 엔진의 Ruby 프렐류드, 그 밖은 스크립트 파일
  has_location = Object.const_defined?(:UnboundMethod) && UnboundMethod.method_defined?(:source_location)
  location = lambda { |meth| (loc = meth.source_location) ? loc[0] : nil }
  engine_owned = lambda { |meth| !has_location || [nil, "<prelude>"].include?(location.call(meth)) }
  # 명세에 있고 VM 에도 있는가. 아래의 부르는 검사는 1 에서 이미 잡은 빠진 이름을 건너뛴다
  exists = lambda do |mod, f|
    sym = f["ruby"].to_sym
    f["rubyKind"] == "module_function" ? mod.method_defined?(sym) : mod.respond_to?(sym)
  end

  # 1. 명세 -> VM: 모듈 (Kernel 의 module_function 은 받는 쪽 없이 부르는 메서드)
  api["modules"].each do |m|
    next unless m["ruby"]
    fns = m["functions"].select { |f| f["ruby"] }
    mod = Object.const_defined?(m["ruby"].to_sym) ? Object.const_get(m["ruby"].to_sym) : nil
    missing = fns.reject do |f|
      if f["rubyKind"] == "module_function"
        Object.new.respond_to?(f["ruby"].to_sym, true)
      else
        !mod.nil? && mod.respond_to?(f["ruby"].to_sym)
      end
    end
    t.check(missing.empty?, "명세 -> VM: #{m['ruby']} 의 Ruby 메서드 #{fns.size}개가 있다",
            "VM 에 없음: #{missing.map { |f| f['ruby'] }.join(', ')}")
  end

  # 1. 명세 -> VM: 클래스
  api["classes"].each do |c|
    next unless c["ruby"]
    klass = Object.const_get(c["ruby"].to_sym)
    t.check_type(klass, Class, "명세 -> VM: 클래스 #{c['ruby']}")
    missing = []
    count = 0
    c["constructors"].each do |k|
      next unless k["ruby"]
      count += 1
      missing << k["ruby"] unless klass.respond_to?(k["ruby"].split(".")[1].to_sym)
    end
    c["methods"].each do |f|
      next unless f["ruby"]
      count += 1
      missing << "##{f['ruby']}" unless klass.method_defined?(f["ruby"].to_sym)
    end
    t.check(missing.empty?, "명세 -> VM: 클래스 #{c['ruby']} 의 Ruby 이름 #{count}개가 있다",
            "VM 에 없음: #{missing.join(', ')}")
  end

  # 2. VM -> 명세: 모듈의 singleton_methods
  api["modules"].each do |m|
    next unless m["ruby"]
    next if m["functions"].any? { |f| f["rubyKind"] == "module_function" }
    mod = Object.const_get(m["ruby"].to_sym)
    described = m["functions"].map { |f| f["ruby"] }.compact
    actual = mod.singleton_methods.select { |s| engine_owned.call(mod.method(s)) }.map(&:to_s)
    extra = (actual - described).sort
    t.check(extra.empty?, "VM -> 명세: #{m['ruby']} 의 메서드 #{actual.size}개가 모두 명세에 있다",
            "명세에 없음: #{extra.join(', ')}")
  end

  # 2. VM -> 명세: 클래스의 instance_methods(false) 와 singleton_methods
  api["classes"].each do |c|
    next unless c["ruby"]
    klass = Object.const_get(c["ruby"].to_sym)
    described = c["methods"].map { |f| f["ruby"] }.compact
    described_singleton = c["constructors"].map { |k| k["ruby"] && k["ruby"].split(".")[1] }.compact
    instance = klass.instance_methods(false).select { |s| engine_owned.call(klass.instance_method(s)) }.map(&:to_s)
    singleton = klass.singleton_methods.select { |s| engine_owned.call(klass.method(s)) }.map(&:to_s)
    extra = (instance - described).sort.map { |n| "##{n}" } +
            (singleton - described_singleton).sort.map { |n| ".#{n}" }
    t.check(extra.empty?,
            "VM -> 명세: 클래스 #{c['ruby']} 의 메서드 #{instance.size + singleton.size}개가 모두 명세에 있다",
            "명세에 없음: #{extra.join(', ')}")
  end

  # 1, 2. 상수 (Keys): 이름 목록이 양쪽으로 같고 값도 같다
  api["constants"].each do |c|
    next unless c["ruby"]
    mod = Object.const_get(c["ruby"].to_sym)
    names = c["names"]
    actual = mod.constants.map(&:to_s)
    only_vm = (actual - names).sort
    only_spec = (names - actual).sort
    t.check(only_vm.empty? && only_spec.empty?, "상수 #{c['ruby']} #{names.size}개가 명세와 같다",
            "VM 에만: #{only_vm.join(', ')} / 명세에만: #{only_spec.join(', ')}")
    wrong = names.select do |n|
      mod.const_defined?(n.to_sym) && mod.const_get(n.to_sym) != c["values"][n]
    end
    t.check(wrong.empty?, "상수 #{c['ruby']} 의 값이 명세와 같다", "다름: #{wrong.join(', ')}")
  end

  # 프렐류드 표시: prelude 가 true 인 것만 "<prelude>" 에서 정의되었다
  if has_location
    wrong = []
    checked = 0
    judge = lambda do |label, meth, spec|
      checked += 1
      wrong << label if (location.call(meth) == "<prelude>") != (spec["prelude"] == true)
    end
    api["modules"].each do |m|
      next unless m["ruby"]
      mod = Object.const_get(m["ruby"].to_sym)
      m["functions"].each do |f|
        next unless f["ruby"] && exists.call(mod, f)
        meth = f["rubyKind"] == "module_function" ? mod.instance_method(f["ruby"].to_sym) : mod.method(f["ruby"].to_sym)
        judge.call("#{m['ruby']}.#{f['ruby']}", meth, f)
      end
    end
    api["classes"].each do |c|
      next unless c["ruby"]
      klass = Object.const_get(c["ruby"].to_sym)
      c["constructors"].each do |k|
        next unless k["ruby"] && klass.respond_to?(k["ruby"].split(".")[1].to_sym)
        judge.call(k["ruby"], klass.method(k["ruby"].split(".")[1].to_sym), k)
      end
      c["methods"].each do |f|
        next unless f["ruby"] && klass.method_defined?(f["ruby"].to_sym)
        judge.call("#{c['ruby']}##{f['ruby']}", klass.instance_method(f["ruby"].to_sym), f)
      end
    end
    t.check(wrong.empty?, "prelude 표시 #{checked}건이 실제 정의 위치(C++ 또는 프렐류드)와 맞다",
            "어긋남: #{wrong.join(', ')}")
  end

  # 인자 없는 getter 의 반환 타입 (모듈)
  mismatches = []
  called = 0
  api["modules"].each do |m|
    next unless m["ruby"]
    mod = Object.const_get(m["ruby"].to_sym)
    m["functions"].each do |f|
      next unless f["ruby"] && safe_getter.call(f) && exists.call(mod, f)
      called += 1
      value = mod.send(f["ruby"].to_sym)
      expected = ruby_returns.call(f)
      mismatches << "#{m['ruby']}.#{f['ruby']} 실제 #{value.class}, 명세 #{expected}" unless type_ok.call(value, expected)
    end
  end
  t.check(mismatches.empty?, "인자 없는 getter #{called}개의 반환 타입이 명세와 맞다", mismatches.join("; "))

  # 클래스: 생성자의 반환 타입과 인스턴스 getter 의 반환 타입
  probes = {
    "Sprite" => ["Sprite.new", [0, 0, 16, 16, 1, "api_surface_probe"]],
    "Tilemap" => ["Tilemap.new", ["./fixtures/maps/sample_v1.json"]],
    "FontEx" => ["FontEx.new", ["api_surface_probe", 16, 64, 16]],
  }
  api["classes"].each do |c|
    probe = probes[c["ruby"]]
    next unless probe
    klass = Object.const_get(c["ruby"].to_sym)
    spec = c["constructors"].find { |k| k["ruby"] == probe[0] }
    t.check(!spec.nil?, "명세에 #{probe[0]} 가 있다")
    next if spec.nil? || !klass.respond_to?(probe[0].split(".")[1].to_sym)
    obj = klass.send(probe[0].split(".")[1].to_sym, *probe[1])
    expected = ruby_returns.call(spec)
    t.check(type_ok.call(obj, expected), "#{probe[0]} 가 명세의 타입(#{expected})을 돌려준다", obj.class)
    class_mismatches = []
    n = 0
    c["methods"].each do |f|
      next unless f["ruby"] && safe_getter.call(f) && klass.method_defined?(f["ruby"].to_sym)
      n += 1
      value = obj.send(f["ruby"].to_sym)
      e = ruby_returns.call(f)
      class_mismatches << "##{f['ruby']} 실제 #{value.class}, 명세 #{e}" unless type_ok.call(value, e)
    end
    if n > 0
      t.check(class_mismatches.empty?, "#{c['ruby']} 인스턴스 getter #{n}개의 반환 타입이 명세와 맞다",
              class_mismatches.join("; "))
    end
    obj.dispose if obj.respond_to?(:dispose)
  end
end
