# 알데바란, 맵 파일의 오브젝트에서 스테이지 배치를 만든다 (docs/plans/m1-map-objects.md).
#
# 맵 포맷 v2의 objects(픽셀 좌표, 타입, props)를 읽어 스테이지 모듈이 쓰는 표로 바꾼다.
# 타입과 칸은 resources/schema/map-objects.json이 정하고, 에디터는 같은 스키마로
# 오브젝트를 맵 위에 그리고 고친다.
#
#   start       점, 하나  → start { x:, y: }
#   checkpoint  점        → checkpoints [{ x:, y: }] (x 오름차순)
#   spawn       점        → spawns [{ species:, x:, y:, min_x:, max_x:, boss: }] (파일 순서)
#   landmark    띠         → landmarks [{ id:, x0:, x1:, title:, text:, hallucination:, skill: }]
#   section     띠         → sections [{ name:, x1: }] (x 오름차순). x1은 띠의 오른끝
#   light       점        → 빛기둥 x. 기후 표가 방 이름으로 골라 쓴다 (lights_in)
#
# 띠의 오른끝은 x + width이고 양 끝을 포함한다. 띠 모양 오브젝트의 y는 쓰지 않는다.
# 종, 흔적 id, 힘, 구간 이름은 종별 표와 기후 표의 키와 같은 Symbol로 바꾼다.
#
#   require "scripts/ruby/games/aldebaran/stages/placement"
#   placed = Aldebaran::Stages::Placement.build("./resources/maps/aldebaran_forest.json")

module Aldebaran
  module Stages
    module Placement
      @maps = {}

      # 맵 파일을 읽는다 (경로마다 한 번). 못 읽으면 RuntimeError
      def self.load(path)
        return @maps[path] if @maps.key?(path)
        begin
          @maps[path] = Json.load(path)
        rescue RuntimeError => e
          raise "알데바란: 맵 파일을 읽지 못했다: #{e.message}"
        end
      end

      def self.sym(value)
        value.nil? ? nil : value.to_sym
      end

      # [x, 파일 순서, 값] 목록을 x 오름차순으로 줄 세워 값만 돌려준다. x가 같으면 파일 순서
      def self.by_x(rows)
        rows.sort { |a, b| a[0] == b[0] ? a[1] <=> b[1] : a[0] <=> b[0] }.map { |r| r[2] }
      end

      # 맵의 objects에서 스테이지 표를 만든다. 시작 지점이나 구간이 없으면 RuntimeError
      def self.build(path)
        objects = load(path)["objects"] || []
        start = nil
        checkpoints = []
        spawns = []
        landmarks = []
        sections = []
        lights = []

        objects.each_with_index do |o, i|
          props = o["props"] || {}
          case o["type"]
          when "start"
            start = { x: o["x"], y: o["y"] }
          when "checkpoint"
            checkpoints.push([o["x"], i, { x: o["x"], y: o["y"] }])
          when "spawn"
            spawn = { species: sym(props["species"]), x: o["x"], y: o["y"],
                      min_x: props["minX"], max_x: props["maxX"] }
            spawn[:boss] = true if props["boss"] == true
            spawns.push(spawn)
          when "landmark"
            mark = { id: sym(o["id"]), x0: o["x"], x1: o["x"] + o["width"],
                     title: props["title"], text: props["text"] }
            # JSON의 3은 Integer로 읽히므로 Float로 바꾼다
            mark[:hallucination] = props["hallucination"].to_f unless props["hallucination"].nil?
            mark[:skill] = sym(props["skill"]) unless props["skill"].nil?
            landmarks.push(mark)
          when "section"
            sections.push([o["x"], i, { name: sym(props["name"]), x1: o["x"] + o["width"] }])
          when "light"
            lights.push(o["x"])
          end
        end

        raise "알데바란: #{path}에 시작 지점(start)이 없다" if start.nil?
        raise "알데바란: #{path}에 구간(section)이 없다" if sections.empty?
        # 한 프레임에 체크포인트 둘을 지나면 먼 쪽이 부활 지점이 되도록 x 순서로 둔다.
        # section_at은 오른끝이 오름차순이라고 보고 앞에서부터 찾는다.
        { start: start, checkpoints: by_x(checkpoints), spawns: spawns, landmarks: landmarks,
          sections: by_x(sections), lights: lights }
      end

      # 이름이 name인 구간 안의 빛기둥 x 목록 (파일 순서)
      def self.lights_in(placed, name)
        left = nil
        placed[:sections].each do |s|
          if s[:name] == name
            return placed[:lights].select { |x| (left.nil? || x > left) && x <= s[:x1] }
          end
          left = s[:x1]
        end
        []
      end

      # x가 속한 구간과 다음 구간, 그리고 다음 구간으로 넘어간 정도 (0..1).
      # [지금 구간, 다음 구간, 섞는 비율]을 돌려준다. 마지막 구간 너머는 마지막 구간이다.
      def self.section_at(sections, fade, x)
        sections.each_with_index do |s, i|
          if x <= s[:x1]
            blend = 0
            if i < sections.size - 1
              d = s[:x1] - x
              if d < fade
                blend = (fade - d).to_f / (fade * 2)
              end
            end
            if i > 0
              prev = sections[i - 1]
              d = x - prev[:x1]
              if d < fade
                return [prev[:name], sections[i][:name], 0.5 + d.to_f / (fade * 2)]
              end
            end
            next_name = i < sections.size - 1 ? sections[i + 1][:name] : s[:name]
            return [s[:name], next_name, blend]
          end
        end
        last = sections[-1][:name]
        [last, last, 0]
      end

      # x에서 발이 y인 자리가 지면 속이면 한 칸(step)씩 올려 지면 위의 y를 돌려준다.
      # solid.call(px, py)는 그 픽셀이 막혔는가. 위가 끝까지 막혔으면 y를 그대로 돌려준다.
      def self.stand_y(x, y, solid, step)
        sy = y
        sy -= step while sy > 0 && solid.call(x, sy - 1)
        sy <= 0 ? y : sy
      end

      REACH = 16 # 시작 칸에 설 땅이 없을 때 좌우로 찾는 칸 수

      # 발이 y일 때 머리 위 room 높이가 비었는가
      def self.room_above?(x, y, solid, step, room)
        py = y - 1
        while py > y - room
          return false if solid.call(x, py)
          py -= step
        end
        !solid.call(x, y - room)
      end

      # x 칸에서 발이 y 근처일 때 설 수 있는 y. 설 땅이 없으면 nil.
      # stand_y로 올린 뒤 떨어져 닿는 땅 위에 몸이 들어가면 그 y를 쓴다. 아래가 바닥까지
      # 비었거나 닿는 땅 위가 좁으면 위쪽에서 가장 가까운 설 자리(구덩이 위의 발판)를 찾는다.
      def self.column_y(x, y, solid, step, bottom, room)
        sy = stand_y(x, y, solid, step)
        return nil if solid.call(x, sy - 1) # 위가 끝까지 막혔다
        py = sy
        py += step while py < bottom && !solid.call(x, py)
        return sy if py < bottom && room_above?(x, (py / step).floor * step, solid, step, room)
        gy = (sy / step).floor * step - step
        while gy - room >= 0
          return gy if solid.call(x, gy) && room_above?(x, gy, solid, step, room)
          gy -= step
        end
        nil
      end

      # 옮긴 시작 x에서 캐릭터가 설 자리 [x, y]. 발은 y 근처에서 찾는다.
      # 그 칸에 설 땅이 없으면(구덩이 위) 좌우 REACH칸 안에서 가장 가까운 칸의 가운데로
      # 옮기고, 거리가 같으면 왼쪽을 고른다. 어디에도 없으면 [x, y]를 그대로 돌려준다.
      # solid.call(px, py)는 그 픽셀이 막혔는가, bottom은 월드의 아래끝, room은 몸 높이.
      def self.start_spot(x, y, solid, tile_w, tile_h, bottom, room)
        sy = column_y(x, y, solid, tile_h, bottom, room)
        return [x, sy] unless sy.nil?
        col = (x / tile_w).floor
        (1..REACH).each do |d|
          [col - d, col + d].each do |c|
            cx = c * tile_w + tile_w / 2
            cy = column_y(cx, y, solid, tile_h, bottom, room)
            return [cx, cy] unless cy.nil?
          end
        end
        [x, y]
      end

      # ---- 스테이지 이름 -----------------------------------------------------

      # 경로의 구분자를 /로 맞추고 앞의 ./를 뗀다
      def self.normalize(path)
        p = path.tr("\\", "/")
        p = p[2..-1] while p.start_with?("./")
        p
      end

      # 끝의 .json을 뗀다
      def self.strip_json(name)
        name.end_with?(".json") ? name[0...-5] : name
      end

      # name이 path의 맵을 가리키는가. 맵 이름(파일 이름이나 맵의 name), 파일 이름,
      # 프로젝트 기준 경로, 그 경로로 끝나는 절대 경로를 받는다.
      def self.refers_to?(path, name)
        return false unless name.is_a?(String) && !name.empty?
        want = normalize(name)
        target = normalize(path)
        if want.include?("/")
          return want == target || want.end_with?("/" + target)
        end
        base = strip_json(want)
        base == strip_json(target.split("/")[-1]) || base == load(path)["name"]
      end
    end
  end
end
