# specs.rb : RPG Maker 2003 리소스 규격 (docs/plans/04-resources.md)
#
# CharSet, FaceSet, ChipSet, System 시트의 배치 규격 표와, 그 표에서 프레임 위치를
# 계산하는 순수 함수를 둔다. 다른 리소스 팩은 같은 형태의 표를 하나 더 만들면 된다.
# 엔진 없이 단위 테스트한다 (tests/ruby/cases/rpg_specs_test.rb).
#
# 값은 resources/RTP.zip(2023년 재배포판)을 열어 실측했다 (2026-08-16). CharSet의 방향
# 행은 0행 뒷모습(위), 1행 오른쪽 옆모습, 2행 정면(아래), 3행 왼쪽 옆모습이다.
#
# 방향은 Symbol(:up, :right, :down, :left)이고, 사각형은 배열 [x, y, w, h]로 돌려준다.
# 잘못된 인자는 ArgumentError를 낸다.

module Rpg
  module Specs
    # 원본 게임의 화면 크기. 데모는 이 논리 해상도를 정수배로 확대해 표시한다.
    LOGICAL_SIZE = { width: 320, height: 240 }

    # CharSet: 288x256 한 장에 8명 (4열 2행), 한 명은 72x128 (3프레임 x 4방향)
    CHARSET = {
      sheet_w: 288, sheet_h: 256,
      per_sheet: 8, sheet_cols: 4, sheet_rows: 2,
      block_w: 72, block_h: 128,
      frame_w: 24, frame_h: 32,
      patterns: 3,   # 한 방향의 가로 프레임 수 (왼발, 서기, 오른발)
      stand_pattern: 1,   # 서 있는 자세의 열 (에디터가 이벤트 외형을 그릴 때 쓴다)
      dirs: 4,
      # 방향 이름 → 블록 안의 행 번호 (0부터)
      dir_rows: { up: 0, right: 1, down: 2, left: 3 },
      # 걷기 애니메이션의 열 순서. 가운데(1)가 서 있는 자세라 1로 돌아온다.
      walk_pattern: [0, 1, 2, 1],
      # 시트 전체를 24x32 격자로 보면 12열 8행. Sprite#set_sheet_grid에 그대로 넣는다
      grid_cols: 12, grid_rows: 8,
    }

    # FaceSet: 192x192 한 장에 48x48 얼굴 16개 (4x4)
    FACESET = {
      sheet_w: 192, sheet_h: 192,
      size: 48, cols: 4, rows: 4, per_sheet: 16,
    }

    # ChipSet: 480x256, 16x16 타일 30열 16행. 왼쪽 영역은 오토타일이라 그대로 쓸 수 없다.
    CHIPSET = {
      sheet_w: 480, sheet_h: 256,
      tile: 16, columns: 30, rows: 16,
    }

    # System(대화창 스킨): 160x80. 배치는 resources/rtp/System/System.png의 알파 채널을
    # 픽셀 단위로 확인했다 (2026-08-18).
    #
    #   (0,0)   32x32  창 바탕 (불투명, 세로 그라데이션)
    #   (32,0)  32x32  창 테두리. 8픽셀 나인 슬라이스로 잘라 쓴다. 가운데 16x16은
    #                  테두리가 아니라 스크롤 화살표 두 개가 들어 있는 자리다.
    #   (64,0)  32x32  선택 커서 1 / (96,0) 커서 2 (깜빡임)
    #   (128,0) 32x32  전투 UI용 그림들 (대화창은 쓰지 않는다)
    #   (32,32) 8x16씩 타이머 숫자 "0123456789:"
    #   (0,48)  16x16씩 글자색 견본 20개 (10열 2행)
    WINDOW = {
      skin_w: 160, skin_h: 80,
      background: { x: 0, y: 0, w: 32, h: 32 },    # 창 바탕 (타일처럼 반복해 채운다)
      frame: { x: 32, y: 0, w: 32, h: 32 },        # 테두리 (나인 슬라이스, 모서리 8px)
      frame_corner: 8,
      # 테두리 그림 가운데의 스크롤 화살표 (16x8 두 개). 대화가 다음 쪽으로
      # 이어질 때 아래쪽 화살표를 깜빡여 보여 준다.
      arrow_up: { x: 40, y: 8, w: 16, h: 8 },
      arrow_down: { x: 40, y: 16, w: 16, h: 8 },
      cursor: { x: 64, y: 0, w: 32, h: 32 },       # 선택 커서
      cursor2: { x: 96, y: 0, w: 32, h: 32 },      # 깜빡임용 두 번째 커서
      cursor_corner: 8,
      # 타이머용 숫자: "0123456789:" 11글자, 8x16씩 가로로
      digits: { x: 32, y: 32, w: 8, h: 16, glyphs: "0123456789:" },
      # 글자색 팔레트: 16x16 견본 20개 (10열 2행)
      text_colors: { x: 0, y: 48, w: 16, h: 16, cols: 10, rows: 2, count: 20 },
    }

    # 화면을 꽉 채우는 배경 그림들 (원본 해상도와 같다)
    FULLSCREEN = {
      backdrop: { w: 320, h: 240 },
      title: { w: 320, h: 240 },
      gameover: { w: 320, h: 240 },
    }

    # CharSet 한 프레임의 시트 안 위치(픽셀).
    # char_index 시트 안 캐릭터 번호 (0..7)
    # dir        :up / :right / :down / :left
    # pattern    걷기 열 번호 (0..2)
    # 돌려주는 값 [x, y, w, h] (시트 좌상단 기준 픽셀)
    def self.charset_frame_rect(char_index, dir, pattern)
      c = CHARSET
      raise ArgumentError, "charIndex는 0..7" unless char_index >= 0 && char_index < c[:per_sheet]
      row = c[:dir_rows][dir]
      raise ArgumentError, "알 수 없는 방향: #{dir.inspect}" if row.nil?
      raise ArgumentError, "pattern은 0..2" unless pattern >= 0 && pattern < c[:patterns]

      block_x = (char_index % c[:sheet_cols]) * c[:block_w]
      block_y = (char_index.to_f / c[:sheet_cols]).floor * c[:block_h]
      [block_x + pattern * c[:frame_w], block_y + row * c[:frame_h], c[:frame_w], c[:frame_h]]
    end

    # 같은 프레임을 Sprite의 시트 격자(12x8) 프레임 번호로.
    # sprite.set_sheet_grid(12, 8) + sprite.current_frame = (이 값)으로 그릴 수 있다.
    def self.charset_frame_index(char_index, dir, pattern)
      c = CHARSET
      x, y = charset_frame_rect(char_index, dir, pattern)
      # 내림해 정수로 만든다. current_frame=에 그대로 넘긴다.
      (y.to_f / c[:frame_h]).floor * c[:grid_cols] + (x.to_f / c[:frame_w]).floor
    end

    # 걷기 애니메이션의 n번째 걸음이 쓰는 열 번호 (step은 0부터, 무한히 증가해도 된다).
    def self.walk_pattern_at(step)
      seq = CHARSET[:walk_pattern]
      seq[(step % seq.size).floor]
    end

    # FaceSet 얼굴 하나의 위치.
    # index 0..15
    def self.faceset_rect(index)
      f = FACESET
      raise ArgumentError, "얼굴 번호는 0..15" unless index >= 0 && index < f[:per_sheet]
      [(index % f[:cols]) * f[:size], (index.to_f / f[:cols]).floor * f[:size], f[:size], f[:size]]
    end

    # ChipSet의 로컬 타일 번호(0부터) → 시트 안 픽셀 위치.
    def self.chipset_tile_rect(tile_index)
      c = CHIPSET
      count = c[:columns] * c[:rows]
      raise ArgumentError, "타일 번호는 0..#{count - 1}" unless tile_index >= 0 && tile_index < count
      [(tile_index % c[:columns]) * c[:tile], (tile_index.to_f / c[:columns]).floor * c[:tile],
       c[:tile], c[:tile]]
    end

    # System 글자색 견본 하나의 위치 (0..19).
    def self.text_color_rect(index)
      t = WINDOW[:text_colors]
      raise ArgumentError, "글자색 번호는 0..19" unless index >= 0 && index < t[:count]
      [t[:x] + (index % t[:cols]) * t[:w], t[:y] + (index.to_f / t[:cols]).floor * t[:h], t[:w], t[:h]]
    end
  end
end
