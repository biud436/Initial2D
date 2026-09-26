# layout.rb : 터치 컨트롤의 화면 크기 비례 배치 (범용 UI 모듈, T1, 순수 함수).
# scripts/lua/ui/layout.lua 의 Ruby 판.
#
# 기준은 화면 높이 H다. Android에서는 논리 높이가 고정(기준 높이/배율)이고
# 가로만 기기 비율대로 늘어나므로, H 비례 크기는 곧 "화면에 비례하는 물리
# 크기"다. DPI 조회 없이도 폰과 태블릿에서 손가락 크기가 화면과 함께 커진다.
#
# 배치 규칙 (횡스크롤 기본형):
#   좌하단: 가상 패드 (높이의 30%)
#   우하단: 주 버튼 줄(높이의 15%, 모서리부터 안쪽으로)과 그 위 보조 버튼
#           줄(높이의 11%, 주 버튼과 세로 중심 정렬)
#   우상단: 시스템 버튼 (높이의 10%)
# 화면이 좁아 패드와 버튼 무리가 겹칠 상황이면 전체를 같은 비율로 줄인다.
#
# 사용:
#   require "scripts/ruby/ui/layout"
#   c = Ui::Layout.controls(w, h, {
#     main: [{ id: :jump, label: "점프" }, { id: :attack, label: "공격" }],
#     sub:  [{ id: :skill, label: "폭주" }],
#     sys:  [{ id: :pause, label: "II" }],
#   })
#   pad = Ui::VirtualPad.new(c[:pad])          # { x:, y:, size: }
#   buttons = Ui::Buttons.new(items: c[:buttons])

module Ui
  module Layout
    # Lua 의 local round (math.floor(v + 0.5)). 내부용이다.
    def self.round(v)
      (v + 0.5).floor
    end

    # 화면 크기에서 컨트롤 치수를 계산한다 (전부 논리 픽셀).
    def self.metrics(w, h)
      u = h
      {
        margin: round(0.030 * u),    # 화면 가장자리 여백
        gap: round(0.020 * u),       # 컨트롤 사이 간격
        pad: round(0.300 * u),       # 가상 패드 한 변
        btn_main: round(0.150 * u),  # 주 버튼 (점프, 공격)
        btn_sub: round(0.110 * u),   # 보조 버튼 (스킬류)
        btn_sys: round(0.100 * u),   # 시스템 버튼 (일시 정지)
      }
    end

    # 컨트롤 배치. defs 의 :main, :sub, :sys 는 { id:, label: } 목록이다 (머리 주석 참조).
    # 반환: { pad: { x:, y:, size: }, buttons: [{ id:, label:, x:, y:, size: }, ...], metrics: }
    def self.controls(w, h, defs = nil)
      defs ||= {}
      main = defs[:main] || []
      sub = defs[:sub] || []
      sys = defs[:sys] || []
      m = metrics(w, h)

      # 좁은 화면 방어: 패드와 주 버튼 줄이 한 줄에 다 안 들어가면 전체 축소
      main_w = main.size * m[:btn_main] + [0, main.size - 1].max * m[:gap]
      need = 2 * m[:margin] + m[:pad] + 2 * m[:gap] + main_w
      if need > w
        f = w.to_f / need
        m.keys.each do |k|
          m[k] = [1, (m[k] * f).floor].max
        end
      end

      out = {
        pad: { x: m[:margin], y: h - m[:margin] - m[:pad], size: m[:pad] },
        buttons: [],
        metrics: m,
      }

      # 주 버튼 줄: 오른쪽 모서리부터 안쪽으로
      main_y = h - m[:margin] - m[:btn_main]
      x = w - m[:margin]
      main_centers = []
      main.each do |item|
        x -= m[:btn_main]
        out[:buttons].push({
          id: item[:id], label: item[:label], x: x, y: main_y, size: m[:btn_main],
        })
        main_centers.push(x + m[:btn_main].to_f / 2)
        x -= m[:gap]
      end

      # 보조 버튼 줄: main[i]와 세로 중심 정렬, 남으면 이어서 왼쪽으로
      # (i 는 Lua 와 같이 1 부터 센다)
      sub_y = main_y - m[:gap] - m[:btn_sub]
      sub.each_with_index do |item, idx|
        i = idx + 1
        cx = main_centers[i - 1]
        if cx.nil?
          cx = (main_centers.last || (w - m[:margin] - m[:btn_main].to_f / 2)) -
               (i - main_centers.size) * (m[:btn_main] + m[:gap])
        end
        out[:buttons].push({
          id: item[:id], label: item[:label],
          x: round(cx - m[:btn_sub].to_f / 2), y: sub_y, size: m[:btn_sub],
        })
      end

      # 시스템 버튼: 우상단 모서리부터 안쪽으로
      x = w - m[:margin]
      sys.each do |item|
        x -= m[:btn_sys]
        out[:buttons].push({
          id: item[:id], label: item[:label], x: x, y: m[:margin], size: m[:btn_sys],
        })
        x -= m[:gap]
      end

      out
    end
  end
end
