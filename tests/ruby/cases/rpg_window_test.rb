# rpg_window_test.rb : 스킨 창(scripts/ruby/rpg/window.rb) 검증. rpg_window_test.lua 의 Ruby 판.
#
# 조각 계산은 순수 함수라 그대로 검사하고, 그리기는 가짜 Image 생성자를 넣어
# "무엇을 어디에 몇 번 찍었는가"를 기록으로 확인한다. 엔진 텍스처가 없어도 돈다.

require "scripts/ruby/rpg/window"
require "scripts/ruby/rpg/specs"

# 그리기 기록만 남기는 가짜 스프라이트 (Image.create 가 주는 Sprite 의 표면을 흉내낸다)
class WindowTestImage
  attr_reader :path, :w, :h, :id
  attr_accessor :scale, :loop, :opacity

  def initialize(log, path, w, h, id)
    @log = log
    @path, @w, @h, @id = path, w, h, id
    @scale = 1
    @rect = [0, 0, 0, 0]
    @pos = [0, 0]
    @opacity = 255
  end

  def set_rect(rx, ry, rw, rh)
    @rect = [rx, ry, rw, rh]
  end

  def set_position(px, py)
    @pos = [px, py]
  end

  def update(_elapsed); end

  def draw
    @log[:draws].push({ w: @w, h: @h, sx: @rect[0], sy: @rect[1],
                        x: @pos[0], y: @pos[1], scale: @scale })
  end

  # dispose 는 스프라이트만, release 는 텍스처까지 놓는다 (scripts/ruby/image.rb 의 Sprite#release)
  def dispose
    @log[:disposed] += 1
  end

  def release
    @log[:released] += 1
  end
end

T.run_case("rpg_window") do |t|
  window = Rpg::Window
  spec = Rpg::Specs::WINDOW

  # 기록 { draws: [...], disposed: n, released: n } 을 채우는 가짜 Image 생성 Proc
  new_log = -> { { draws: [], disposed: 0, released: 0 } }
  fake_image_factory = lambda do |log|
    ->(path, _x, _y, w, h, _frames, id) { WindowTestImage.new(log, path, w, h, id) }
  end

  # 조각들이 목표 영역을 빈틈없이, 밖으로 넘치지 않게 덮는지 센다
  coverage = lambda do |pieces, w, h|
    grid = {}
    outside = 0
    pieces.each do |p|
      (p[:dy]..p[:dy] + p[:sh] - 1).each do |y|
        (p[:dx]..p[:dx] + p[:sw] - 1).each do |x|
          if x < 0 || y < 0 || x >= w || y >= h
            outside += 1
          else
            grid[y * w + x] = (grid[y * w + x] || 0) + 1
          end
        end
      end
    end
    covered = 0
    overlap = 0
    grid.each_value do |n|
      covered += 1
      overlap += 1 if n > 1
    end
    [covered, outside, overlap]
  end

  # ---- [1] 반복 채우기: 자투리까지 정확히 --------------------------------
  pieces = window.tile_fill([], 0, 0, 70, 20, 0, 0, 32, 32)
  covered, outside, overlap = coverage.call(pieces, 70, 20)
  t.check_eq(covered, 70 * 20, "반복 채우기가 영역을 빈틈없이 덮는다")
  t.check_eq(outside, 0, "영역 밖으로 넘치지 않는다 (자투리는 소스를 자른다)")
  t.check_eq(overlap, 0, "겹쳐 그리지 않는다")
  t.check_eq(pieces.size, 3, "70x20은 32+32+6 세 조각")
  t.check(pieces[2][:sw] == 6 && pieces[2][:sh] == 20, "마지막 조각은 잘린 크기",
          "#{pieces[2][:sw]}x#{pieces[2][:sh]}")

  t.check_eq(window.tile_fill([], 0, 0, 0, 10, 0, 0, 8, 8).size, 0, "빈 영역은 조각 없음")

  # ---- [2] 나인 슬라이스 --------------------------------------------------
  frame = window.nine_patch([], spec[:frame], spec[:frame_corner], 100, 40, false)
  covered, outside, overlap = coverage.call(frame, 100, 40)
  t.check_eq(outside, 0, "테두리가 창 밖으로 나가지 않는다")
  t.check_eq(overlap, 0, "테두리 조각끼리 겹치지 않는다")
  # 테두리만 그리므로 가운데(8..92, 8..32)는 비어 있어야 한다
  t.check_eq(covered, 100 * 40 - (100 - 16) * (40 - 16), "가운데는 비운다 (테두리만)")

  corner = frame[0]
  t.check(corner[:dx] == 0 && corner[:dy] == 0 && corner[:sw] == 8 && corner[:sh] == 8,
          "첫 조각은 좌상단 모서리 8x8")
  t.check(corner[:sx] == spec[:frame][:x] && corner[:sy] == spec[:frame][:y],
          "모서리는 테두리 블록의 좌상단에서 잘라 온다")

  filled = window.nine_patch([], spec[:cursor], spec[:cursor_corner], 64, 24, true)
  covered, = coverage.call(filled, 64, 24)
  t.check_eq(covered, 64 * 24, "가운데까지 채우면 사각형 전체를 덮는다 (커서)")

  t.check_eq(window.nine_patch([], spec[:frame], 8, 12, 40, false).size, 0,
             "모서리가 겹칠 만큼 좁으면 그리지 않는다")

  # ---- [3] 창 전체: 바탕 + 테두리 -----------------------------------------
  all = window.slices(64, 48, spec)
  covered, outside = coverage.call(all, 64, 48)
  t.check_eq(covered, 64 * 48, "바탕이 창 전체를 덮는다")
  t.check_eq(outside, 0, "창 밖으로 넘치지 않는다")

  # 바탕 띠: 원본의 위쪽부터 순서대로 쓴다 (그라데이션 방향 유지)
  bands = {}
  window.background_fill([], 64, 48, spec).each { |p| bands[p[:sy]] = true }
  t.check_eq(bands.size, Rpg::Window::BG_BANDS, "바탕은 원본을 세로 4등분해 쓴다")

  # ---- [4] 커서 조각: 깜빡임은 다른 그림에서 잘라 온다 --------------------
  c1 = window.cursor_slices(32, 16, spec, false)
  c2 = window.cursor_slices(32, 16, spec, true)
  t.check_eq(c1[0][:sx], spec[:cursor][:x], "기본 커서")
  t.check_eq(c2[0][:sx], spec[:cursor2][:x], "깜빡임용 두 번째 커서")

  # ---- [5] 창 객체: 열기와 닫기 애니메이션 --------------------------------
  log = new_log.call
  skin = Rpg::Skin.new(path: "fake.png", scale: 1, image_factory: fake_image_factory.call(log))
  win = window.new(skin: skin, x: 10, y: 20, width: 64, height: 48, open_frames: 4)

  t.check(win.closed?, "창은 닫힌 채로 시작한다")
  win.draw
  t.check_eq(log[:draws].size, 0, "닫힌 창은 아무것도 그리지 않는다")

  win.open
  win.update
  x, y, w, h = win.rect
  t.check(h == 12 && y == 20 + 18, "열리는 중에는 가운데에서 자란다", format("y=%d h=%d", y, h))
  t.check(x == 10 && w == 64, "가로는 처음부터 제 크기")
  t.check(!win.open?, "열리는 중에는 내용을 그리지 않는다")

  4.times { win.update }
  t.check(win.open?, "4프레임이면 다 열린다")
  _, oy, _, oh = win.rect
  t.check(oy == 20 && oh == 48, "다 열리면 원래 크기")

  win.draw
  t.check(log[:draws].size > 0, "열린 창은 조각을 그린다")
  first = log[:draws][0]
  t.check(first[:x] >= 10 && first[:y] >= 20, "창 위치에서부터 그린다")

  win.close
  4.times { win.update }
  t.check(win.closed?, "닫기도 4프레임")

  no_skin = false
  begin
    window.new(skin: nil)
  rescue ArgumentError
    no_skin = true
  end
  t.check(no_skin, "skin 없이는 창을 만들 수 없다 (ArgumentError)")

  # ---- [6] 안쪽 여백과 배율 ------------------------------------------------
  cx, cy, cw, ch = win.content_rect
  t.check(cx == 10 + 8 && cy == 20 + 8, "내용 영역은 모서리(8)만큼 안쪽")
  t.check(cw == 64 - 16 && ch == 48 - 16, "내용 크기도 그만큼 줄어든다")

  log2 = new_log.call
  skin2 = Rpg::Skin.new(path: "fake.png", scale: 2, image_factory: fake_image_factory.call(log2))
  win2 = window.new(skin: skin2, x: 0, y: 0, width: 65, height: 48, open_frames: 0)
  t.check_eq(win2.width, 64, "배율 2에서는 창 폭을 배율의 배수로 내린다")
  t.check_eq(win2.padding, 16, "여백도 배율만큼 커진다")
  win2.open
  win2.update
  win2.draw
  t.check(log2[:draws].size > 0, "배율 2 창도 그려진다")
  scaled = log2[:draws][0]
  t.check_eq(scaled[:scale], 2, "조각은 배율만큼 확대해 찍는다")

  # 조각 좌표에도 배율이 곱해진다 (32 스킨픽셀 = 64 화면픽셀)
  far = nil
  log2[:draws].each do |entry|
    far = entry if far.nil? || entry[:x] > far[:x]
  end
  t.check(far[:x] % 2 == 0, "화면 좌표는 배율의 배수", far[:x].to_s)

  # ---- [7] 텍스처 해제는 한 번만 ------------------------------------------
  skin.image(8, 8)
  skin.image(16, 8)
  cached = skin.cache.size
  skin.dispose
  t.check_eq(log[:released], 1, "크기별 스프라이트가 여럿이어도 텍스처 해제는 한 번")
  t.check_eq(log[:released] + log[:disposed], cached, "나머지 스프라이트는 dispose 로 놓는다")
  t.check_eq(skin.cache.size, 0, "해제 뒤에는 캐시를 비운다")
end
