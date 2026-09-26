# layout_test.rb : 터치 컨트롤 배치(scripts/ruby/ui/layout.rb)의 순수 로직 검증 (T1).
# layout_test.lua 의 Ruby 판.
#
# Android는 논리 높이가 고정(448)이고 가로만 기기 비율대로 늘어난다.
# 데스크톱 미리보기(384)부터 좁은 화면 방어(300), 태블릿(597), 16:9(796),
# Galaxy S24(971), 초광폭(1200)까지 전부에서 배치 불변식이 지켜져야 한다.

require "scripts/ruby/ui/layout"

T.run_case("layout") do |t|
  hit_slop = 1.25 # buttons.rb의 판정 반경 배수
  grab = 0.48     # vpad.rb의 잡기 반경 비율

  defs = {
    main: [{ id: :jump, label: "점프" }, { id: :attack, label: "공격" }],
    sub: [{ id: :skill, label: "폭주" }, { id: :bolt, label: "검기" }],
    sys: [{ id: :pause, label: "II" }],
  }

  layout = Ui::Layout
  t.check(layout.respond_to?(:metrics), "Layout.metrics 존재")
  t.check(layout.respond_to?(:controls), "Layout.controls 존재")

  [300, 384, 597, 796, 971, 1200].each do |w|
    h = 448
    c = layout.controls(w, h, defs)
    tag = "#{w}x#{h}: "

    # 패드가 화면 안에 있다
    pad = c[:pad]
    t.check(pad[:x] >= 0 && pad[:y] >= 0 &&
            pad[:x] + pad[:size] <= w && pad[:y] + pad[:size] <= h,
            tag + "패드가 화면 안", "#{pad[:x]},#{pad[:y]} #{pad[:size]}")

    # 버튼이 다섯이고 전부 화면 안에 있다
    t.check_eq(c[:buttons].size, 5, tag + "버튼 다섯")
    c[:buttons].each do |b|
      t.check(b[:x] >= 0 && b[:y] >= 0 && b[:x] + b[:size] <= w && b[:y] + b[:size] <= h,
              tag + "#{b[:id]} 화면 안", "#{b[:x]},#{b[:y]} #{b[:size]}")
    end

    # 패드의 잡기 원과 버튼의 판정 원(슬롭 포함)이 겹치지 않는다.
    # 겹치면 패드를 잡으려다 버튼이 눌린다.
    pcx = pad[:x] + pad[:size].to_f / 2
    pcy = pad[:y] + pad[:size].to_f / 2
    c[:buttons].each do |b|
      dx = (b[:x] + b[:size].to_f / 2) - pcx
      dy = (b[:y] + b[:size].to_f / 2) - pcy
      min_dist = pad[:size] * grab + b[:size].to_f / 2 * hit_slop
      t.check(dx * dx + dy * dy > min_dist * min_dist,
              tag + "패드와 #{b[:id]} 분리",
              "#{Math.sqrt(dx * dx + dy * dy).floor} < #{min_dist.floor}")
    end

    # 버튼끼리 표시 원이 겹치지 않는다 (판정 슬롭은 겹쳐도 가까운 쪽이 이긴다)
    n = c[:buttons].size
    (0...n).each do |i|
      ((i + 1)...n).each do |j|
        a = c[:buttons][i]
        b = c[:buttons][j]
        dx = (a[:x] + a[:size].to_f / 2) - (b[:x] + b[:size].to_f / 2)
        dy = (a[:y] + a[:size].to_f / 2) - (b[:y] + b[:size].to_f / 2)
        min_dist = a[:size].to_f / 2 + b[:size].to_f / 2
        t.check(dx * dx + dy * dy >= min_dist * min_dist,
                tag + "#{a[:id]}와 #{b[:id]} 분리")
      end
    end
  end

  # 크기 위계: 주 버튼 > 보조 > 시스템, 패드가 가장 크다
  m = layout.metrics(971, 448)
  t.check(m[:pad] > m[:btn_main] && m[:btn_main] > m[:btn_sub] && m[:btn_sub] >= m[:btn_sys],
          "크기 위계", "#{m[:pad]} #{m[:btn_main]} #{m[:btn_sub]} #{m[:btn_sys]}")

  # 비례: 높이가 두 배면 크기도 두 배 (반올림 1 이내)
  # (라벨은 Lua 와 같게 Lua 키 이름을 쓴다: btn_main 은 btnMain)
  m2 = layout.metrics(971, 896)
  {
    pad: "pad", btn_main: "btnMain", btn_sub: "btnSub", btn_sys: "btnSys",
    margin: "margin", gap: "gap",
  }.each do |k, lua_name|
    t.check((m2[k] - 2 * m[k]).abs <= 1, "비례: " + lua_name, "#{m[k]} → #{m2[k]}")
  end

  # Ruby 판 추가: 치수는 전부 정수 (Lua 의 math.floor(v + 0.5) 가 정수를 낸다)
  t.check(m.values.all? { |v| v.is_a?(Integer) }, "치수는 정수", m.inspect)

  # 앵커: 점프(첫 main)가 우하단 모서리, 정지(sys)가 우상단 모서리
  c = layout.controls(971, 448, defs)
  by_id = {}
  c[:buttons].each { |b| by_id[b[:id]] = b }
  t.check(by_id[:jump][:x] + by_id[:jump][:size] == 971 - c[:metrics][:margin],
          "점프가 오른쪽 모서리", by_id[:jump][:x])
  t.check(by_id[:jump][:y] + by_id[:jump][:size] == 448 - c[:metrics][:margin],
          "점프가 아래 모서리", by_id[:jump][:y])
  t.check(by_id[:pause][:y] == c[:metrics][:margin], "정지가 위 모서리", by_id[:pause][:y])
  t.check(by_id[:attack][:x] < by_id[:jump][:x], "공격은 점프 안쪽")
  t.check(by_id[:skill][:y] < by_id[:jump][:y], "폭주는 점프 윗줄")
  t.check(by_id[:jump][:label] == "점프" && by_id[:pause][:label] == "II", "라벨 유지")

  # 좁은 화면 방어: 300에서도 전체가 줄어 한 줄에 들어간다 (위 불변식이 이미
  # 확인했다). 축소가 실제로 일어났는지만 본다.
  narrow = layout.controls(300, 448, defs)
  t.check(narrow[:pad][:size] < c[:pad][:size], "좁은 화면에서 패드 축소",
          "#{narrow[:pad][:size]} < #{c[:pad][:size]}")

  # ---- Ruby 판 추가: Lua 판과 같은 수치 ----------------------------------------
  # 아래 기대값은 scripts/lua/ui/layout.lua 를 lua5.4 로 돌려 얻은 것이다.
  # 정수와 실수 나눗셈이 섞이는 자리(축소 비율, 보조 버튼 중심)가 어긋나면 여기서 드러난다.
  dump = lambda do |cc|
    s = "pad #{cc[:pad][:x]},#{cc[:pad][:y]},#{cc[:pad][:size]}"
    cc[:buttons].each { |b| s += " #{b[:id]}=#{b[:x]},#{b[:y]},#{b[:size]}" }
    s
  end
  t.check_eq([m[:margin], m[:gap], m[:pad], m[:btn_main], m[:btn_sub], m[:btn_sys]],
             [13, 9, 134, 67, 49, 45], "971x448 치수가 Lua 판과 같다")
  {
    300 => "pad 12,311,125 jump=226,374,62 attack=156,374,62 skill=235,321,45 bolt=165,321,45 pause=246,12,42",
    384 => "pad 13,301,134 jump=304,368,67 attack=228,368,67 skill=313,310,49 bolt=237,310,49 pause=326,13,45",
    597 => "pad 13,301,134 jump=517,368,67 attack=441,368,67 skill=526,310,49 bolt=450,310,49 pause=539,13,45",
    796 => "pad 13,301,134 jump=716,368,67 attack=640,368,67 skill=725,310,49 bolt=649,310,49 pause=738,13,45",
    971 => "pad 13,301,134 jump=891,368,67 attack=815,368,67 skill=900,310,49 bolt=824,310,49 pause=913,13,45",
    1200 => "pad 13,301,134 jump=1120,368,67 attack=1044,368,67 skill=1129,310,49 bolt=1053,310,49 pause=1142,13,45",
  }.each do |w, expected|
    t.check_eq(dump.call(layout.controls(w, 448, defs)), expected, "#{w}x448 배치가 Lua 판과 같다")
  end
  # 보조 버튼이 주 버튼보다 많을 때 (이어서 왼쪽으로), 주 버튼이 없을 때, 축소와 시스템 버튼 둘
  t.check_eq(dump.call(layout.controls(597, 448, {
    main: [{ id: :a }], sub: [{ id: :s1 }, { id: :s2 }, { id: :s3 }],
  })), "pad 13,301,134 a=517,368,67 s1=526,310,49 s2=450,310,49 s3=374,310,49",
             "보조가 넘치면 이어서 왼쪽으로 (Lua 판과 같다)")
  t.check_eq(dump.call(layout.controls(597, 448, { sub: [{ id: :s1 }, { id: :s2 }] })),
             "pad 13,301,134 s1=450,310,49 s2=374,310,49", "주 버튼 없는 보조 줄 (Lua 판과 같다)")
  t.check_eq(dump.call(layout.controls(250, 333, {
    main: [{ id: :a }, { id: :b }, { id: :c }], sub: [{ id: :s1 }], sys: [{ id: :p }, { id: :q }],
  })), "pad 8,242,83 a=201,284,41 b=155,284,41 c=109,284,41 s1=206,248,31 p=215,8,27 q=183,8,27",
             "축소와 시스템 버튼 둘 (Lua 판과 같다)")
  t.check(c[:buttons].all? { |b| b[:x].is_a?(Integer) && b[:y].is_a?(Integer) }, "버튼 좌표는 정수")
  t.check_eq(layout.controls(400, 300)[:buttons], [], "defs 생략은 버튼 없음")
end
