# rpg_specs_test.rb : R2K3 리소스 규격 데이터(scripts/ruby/rpg/specs.rb) 검증.
# rpg_specs_test.lua 의 Ruby 판.
# 엔진 없이 도는 순수 로직이다. 규격 값이 서로 어긋나거나(시트 크기와 분할이
# 맞지 않는 등) 프레임 좌표 계산이 틀어지면 여기서 잡힌다.

require "scripts/ruby/rpg/specs"

T.run_case("rpg_specs") do |t|
  s = Rpg::Specs

  # 오류가 나면 true (Lua 의 pcall(...) == false 에 해당)
  raises = lambda do |f|
    begin
      f.call
      false
    rescue ArgumentError
      true
    end
  end

  # [1] 시트 크기와 분할의 정합성 (하나만 바꿔도 여기서 깨진다)
  c = s::CHARSET
  t.check_eq(c[:sheet_cols] * c[:block_w], c[:sheet_w], "CharSet: 블록 4열이 시트 폭과 같다")
  t.check_eq(c[:sheet_rows] * c[:block_h], c[:sheet_h], "CharSet: 블록 2행이 시트 높이와 같다")
  t.check_eq(c[:sheet_cols] * c[:sheet_rows], c[:per_sheet], "CharSet: 시트당 캐릭터 8명")
  t.check_eq(c[:patterns] * c[:frame_w], c[:block_w], "CharSet: 3프레임이 블록 폭과 같다")
  t.check_eq(c[:dirs] * c[:frame_h], c[:block_h], "CharSet: 4방향이 블록 높이와 같다")
  t.check_eq(c[:sheet_w].to_f / c[:frame_w], c[:grid_cols], "CharSet: 24x32 격자는 12열")
  t.check_eq(c[:sheet_h].to_f / c[:frame_h], c[:grid_rows], "CharSet: 24x32 격자는 8행")

  f = s::FACESET
  t.check_eq(f[:cols] * f[:size], f[:sheet_w], "FaceSet: 4열이 시트 폭과 같다")
  t.check_eq(f[:rows] * f[:size], f[:sheet_h], "FaceSet: 4행이 시트 높이와 같다")
  t.check_eq(f[:cols] * f[:rows], f[:per_sheet], "FaceSet: 시트당 얼굴 16개")

  cs = s::CHIPSET
  t.check_eq(cs[:columns] * cs[:tile], cs[:sheet_w], "ChipSet: 30열이 시트 폭과 같다")
  t.check_eq(cs[:rows] * cs[:tile], cs[:sheet_h], "ChipSet: 16행이 시트 높이와 같다")

  # [2] 방향 행: 이름 4개가 0..3에 하나씩 배정된다
  seen = {}
  count = 0
  c[:dir_rows].each do |name, row|
    t.check(row >= 0 && row < c[:dirs], "방향 행 범위: #{name}", row.to_s)
    t.check(seen[row].nil?, "방향 행 중복 없음: #{name}", row.to_s)
    seen[row] = name
    count += 1
  end
  t.check_eq(count, c[:dirs], "방향은 4개")
  t.check_eq(seen[0], :up, "0행은 위 (뒤통수)")
  t.check_eq(seen[2], :down, "2행은 아래 (정면)")

  # [3] 프레임 좌표: 손으로 계산한 값과 대조
  x, y, w, h = s.charset_frame_rect(0, :down, 1)
  t.check_eq(x, 24, "0번 캐릭터 아래 방향 가운데 프레임 x")
  t.check_eq(y, 64, "0번 캐릭터 아래 방향 가운데 프레임 y")
  t.check_eq(w, 24, "프레임 폭")
  t.check_eq(h, 32, "프레임 높이")

  # 5번 캐릭터 = 2행 2열 블록 → (72*1, 128*1) 기준
  x, y = s.charset_frame_rect(5, :left, 2)
  t.check_eq(x, 72 + 48, "5번 캐릭터 왼쪽 방향 세 번째 프레임 x")
  t.check_eq(y, 128 + 96, "5번 캐릭터 왼쪽 방향 세 번째 프레임 y")

  # 시트 안의 모든 프레임이 시트 밖으로 나가지 않는다
  dirs = [:up, :right, :down, :left]
  (0..c[:per_sheet] - 1).each do |i|
    dirs.each do |dir|
      (0..c[:patterns] - 1).each do |p|
        fx, fy = s.charset_frame_rect(i, dir, p)
        t.check(fx >= 0 && fx + c[:frame_w] <= c[:sheet_w] &&
                fy >= 0 && fy + c[:frame_h] <= c[:sheet_h],
                format("프레임이 시트 안에 있다 (%d,%s,%d)", i, dir, p),
                "#{fx},#{fy}")
      end
    end
  end

  # [4] 격자 프레임 번호: 좌표와 같은 칸을 가리킨다
  t.check_eq(s.charset_frame_index(0, :down, 1), 25, "0번 아래 가운데 = 2행 1열 = 25")
  t.check_eq(s.charset_frame_index(0, :up, 0), 0, "0번 위 첫 프레임 = 0")
  # 7번 캐릭터는 블록 (3열, 1행) → 픽셀 (216,128), 왼쪽(3행) 세 번째 프레임 → (264,224)
  # 격자로는 (224/32)행 (264/24)열 = 7행 11열 = 95
  t.check_eq(s.charset_frame_index(7, :left, 2), 95, "7번 왼쪽 마지막 프레임 = 95")
  (0..c[:per_sheet] - 1).each do |i|
    dirs.each do |dir|
      (0..c[:patterns] - 1).each do |p|
        idx = s.charset_frame_index(i, dir, p)
        t.check(idx.is_a?(Integer) && idx >= 0 && idx < c[:grid_cols] * c[:grid_rows],
                format("격자 번호가 정수 범위 (%d,%s,%d)", i, dir, p), idx.inspect)
      end
    end
  end

  # [5] 걷기 열 순서: 0,1,2,1 이 반복되고 가운데(서기)로 돌아온다
  t.check_eq(s.walk_pattern_at(0), 0, "걸음 0")
  t.check_eq(s.walk_pattern_at(1), 1, "걸음 1 (서기)")
  t.check_eq(s.walk_pattern_at(2), 2, "걸음 2")
  t.check_eq(s.walk_pattern_at(3), 1, "걸음 3 (서기로 복귀)")
  t.check_eq(s.walk_pattern_at(4), 0, "걸음 4는 다시 처음")
  t.check_eq(s.walk_pattern_at(103), s.walk_pattern_at(3), "큰 값도 주기가 같다")
  # 서기 열은 규격 표의 칸이다 (event-commands.json 의 sheets.charset.standPattern 과 같은 값)
  t.check_eq(c[:stand_pattern], 1, "서 있는 자세는 가운데 열")
  t.check_eq(s.walk_pattern_at(1), c[:stand_pattern], "걷기 순서의 둘째 걸음이 서기 열")
  t.check_eq(s.walk_pattern_at(3), c[:stand_pattern], "걷기 순서의 넷째 걸음이 서기 열")

  # [6] FaceSet과 ChipSet 좌표
  fx, fy, fw = s.faceset_rect(0)
  t.check(fx == 0 && fy == 0 && fw == 48, "0번 얼굴은 좌상단 48x48")
  fx, fy = s.faceset_rect(15)
  t.check(fx == 144 && fy == 144, "15번 얼굴은 우하단")
  tx, ty = s.chipset_tile_rect(30)
  t.check(tx == 0 && ty == 16, "30번 타일은 두 번째 줄 처음")

  # [7] 글자색 견본 20개가 팔레트 영역 안에 있다
  win = s::WINDOW
  (0..win[:text_colors][:count] - 1).each do |i|
    cx, cy, cw, ch = s.text_color_rect(i)
    t.check(cx >= 0 && cx + cw <= win[:skin_w] && cy >= 0 && cy + ch <= win[:skin_h],
            "글자색 견본이 스킨 안에 있다: #{i}", "#{cx},#{cy}")
  end

  # [8] 잘못된 입력은 조용히 틀린 값을 주는 대신 오류를 낸다
  t.check(raises.call(-> { s.charset_frame_rect(8, :down, 0) }), "캐릭터 번호 범위 밖은 오류")
  t.check(raises.call(-> { s.charset_frame_rect(0, :diagonal, 0) }), "모르는 방향은 오류")
  t.check(raises.call(-> { s.charset_frame_rect(0, :down, 3) }), "프레임 번호 범위 밖은 오류")
  t.check(raises.call(-> { s.faceset_rect(16) }), "얼굴 번호 범위 밖은 오류")
  # Ruby 판에서 더한 검사: 방향은 Symbol 이고, 나머지 범위 검사도 오류를 낸다
  t.check(raises.call(-> { s.charset_frame_rect(0, "down", 0) }), "문자열 방향은 오류 (Symbol 만 받는다)")
  t.check(raises.call(-> { s.chipset_tile_rect(480) }), "타일 번호 범위 밖은 오류")
  t.check(raises.call(-> { s.text_color_rect(20) }), "글자색 번호 범위 밖은 오류")
  t.check_eq(s.charset_frame_rect(0, :down, 1), [24, 64, 24, 32], "좌표는 [x, y, w, h] 배열")
  t.check_eq(s::LOGICAL_SIZE, { width: 320, height: 240 }, "논리 해상도 320x240")
end
