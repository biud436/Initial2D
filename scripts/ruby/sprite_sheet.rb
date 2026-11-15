# sprite_sheet.rb : 스프라이트 시트 파일(시트 포맷 v1)을 읽고 이름 있는 클립을 재생한다
# (엔진 2, docs/plans/engine2-sprite-sheets.md). Lua 판 scripts/lua/sprite_sheet.lua 와 같은 파일을 같은 규칙으로
# 읽고 오류 문장도 같다. 씬 로더는 sprite 의 props.sheet 를 이 모듈로 연다.
#
#   require "scripts/ruby/sprite_sheet"
#   sheet = SpriteSheet.load("resources/bird.sprite.json")
#   anim = sheet.animator
#   anim.play("fly")
#   anim.update(elapsed)     # ms
#   anim.apply(sprite)       # 지금 프레임의 칸과 기준점을 Sprite 에 옮긴다
#
# 프레임 번호는 0 부터 왼쪽에서 오른쪽, 위에서 아래로 센다. 열과 행의 수는 이미지 크기에서 나온다.

module SpriteSheet
  VERSION = 1
  DEFAULT_DURATION = 100   # ms. 씬 로더의 frameDelay 기본값과 같다
  LOOP_MODES = ["loop", "once", "pingpong"]

  # 시트의 모든 오류. 메시지는 "sheet: ..." 으로 시작한다 (Lua 판과 같은 문장)
  class Error < StandardError
  end

  @cache = {}   # 경로 -> 읽은 시트. 시트는 읽은 뒤 바뀌지 않으므로 오브젝트끼리 나눠 쓴다

  class << self
    # -----------------------------------------------------------------------
    # 도우미
    # -----------------------------------------------------------------------

    def where(path)
      path.nil? ? "" : " (#{path})"
    end

    def raise_at(path, message)
      raise Error, "sheet: #{message}#{where(path)}"
    end

    # 프로젝트 루트 기준 상대 경로에 "./" 를 붙인다 (절대 경로와 이미 "./" 인 것은 그대로)
    def resolve_path(p)
      return p if p.start_with?("/") || p.start_with?("./") || (p.size >= 2 && p[1] == ":")
      "./" + p
    end

    # PNG 헤더(IHDR)에서 이미지 크기를 읽는다
    def png_size(path)
      head = nil
      begin
        f = File.open(path, "rb")
        head = f.read(24)
        f.close
      rescue StandardError
        return nil
      end
      return nil if head.nil? || head.bytesize < 24
      return nil unless head.getbyte(0) == 0x89 && head[1, 3] == "PNG"
      w = (head.getbyte(16) << 24) | (head.getbyte(17) << 16) | (head.getbyte(18) << 8) | head.getbyte(19)
      h = (head.getbyte(20) << 24) | (head.getbyte(21) << 16) | (head.getbyte(22) << 8) | head.getbyte(23)
      [w, h]
    end

    def integer_like?(v)
      v.is_a?(Integer) || (v.is_a?(Float) && v == v.floor)
    end

    # JSON 객체인가: Hash, 또는 빈 Array (Lua 의 Json.Load 는 [] 과 {} 를 같은 빈 표로 읽으므로 같게 본다)
    def json_object?(v)
      v.is_a?(Hash) || (v.is_a?(Array) && v.empty?)
    end

    # JSON 배열인가: Array, 또는 빈 Hash
    def json_array?(v)
      v.is_a?(Array) || (v.is_a?(Hash) && v.empty?)
    end

    def as_hash(v)
      v.is_a?(Hash) ? v : {}
    end

    def as_array(v)
      v.is_a?(Array) ? v : []
    end

    def pivot?(v)
      v.is_a?(Array) && v.size == 2 && v.all? { |x| x.is_a?(Numeric) }
    end

    # 메시지 속의 값: 정수 값이면 정수로, 다른 숫자는 유효 숫자 14자리, nil 은 "nil"
    def value_text(v)
      return "nil" if v.nil?
      return v.to_s unless v.is_a?(Numeric)
      return v.to_i.to_s if v == v.floor && v.abs < 1e15
      format("%.14g", v)
    end

    # -----------------------------------------------------------------------
    # 검사 (파일을 열지 않는 모양 검사. 이미지 크기가 드는 검사는 from_hash 가 한다)
    # -----------------------------------------------------------------------

    def check_clip(name, c)
      label = "clip '#{name}'"
      return "#{label} must be an object" unless json_object?(c)
      c = as_hash(c)
      frames = c["frames"]
      return "#{label} needs frames (a non-empty array)" unless json_array?(frames) && !frames.empty?
      frames.each_with_index do |f, i|
        return "#{label} frames[#{i + 1}] must be an integer >= 0" unless integer_like?(f) && f >= 0
      end
      d = c["duration"]
      unless d.nil?
        if d.is_a?(Numeric)
          return "#{label} duration must be a number > 0 or an array of them" if d <= 0
        elsif json_array?(d) && !d.empty?
          return "#{label} duration needs #{frames.size} values (one per frame), got #{d.size}" if d.size != frames.size
          d.each_with_index do |x, i|
            return "#{label} duration[#{i + 1}] must be a number > 0" unless x.is_a?(Numeric) && x > 0
          end
        else
          return "#{label} duration must be a number > 0 or an array of them"
        end
      end
      if !c["loop"].nil? && !LOOP_MODES.include?(c["loop"])
        return "#{label} loop must be \"loop\", \"once\" or \"pingpong\""
      end
      return "#{label} pivot must be [x, y]" if !c["pivot"].nil? && !pivot?(c["pivot"])
      nil
    end

    # 시트 Hash 를 검사한다. 문제가 있으면 Error, 없으면 true.
    def validate(hash)
      raise Error, "sheet: not an object" unless json_object?(hash)
      hash = as_hash(hash)
      version = hash["version"]
      unless version == VERSION
        raise Error, "sheet: unsupported version #{value_text(version)} (expected #{VERSION})"
      end
      image = hash["image"]
      raise Error, "sheet: image must be a non-empty string" unless image.is_a?(String) && !image.empty?
      ["frameWidth", "frameHeight"].each do |k|
        v = hash[k]
        raise Error, "sheet: #{k} must be an integer >= 1" unless integer_like?(v) && v >= 1
      end
      ["margin", "spacing"].each do |k|
        v = hash[k]
        raise Error, "sheet: #{k} must be an integer >= 0" if !v.nil? && !(integer_like?(v) && v >= 0)
      end
      raise Error, "sheet: pivot must be [x, y]" if !hash["pivot"].nil? && !pivot?(hash["pivot"])
      clips = hash["clips"]
      raise Error, "sheet: clips must be an object" if !clips.nil? && !json_object?(clips)
      clips = as_hash(clips)
      clips.keys.sort.each do |name|
        raise Error, "sheet: clip names must not be empty" if name == ""
        e = check_clip(name, clips[name])
        raise Error, "sheet: #{e}" unless e.nil?
      end
      dc = hash["defaultClip"]
      unless dc.nil?
        raise Error, "sheet: defaultClip must be a string" unless dc.is_a?(String)
        raise Error, "sheet: defaultClip '#{dc}' is not a clip" if dc != "" && !clips.key?(dc)
      end
      true
    end

    # -----------------------------------------------------------------------
    # 읽기
    # -----------------------------------------------------------------------

    # 이미 읽은 Hash 에서 시트를 만든다. path 는 오류 메시지와 sheet.path 에만 쓴다 (없어도 된다).
    # 이미지 크기는 image 의 PNG 헤더에서 읽는다.
    def from_hash(hash, path = nil)
      begin
        validate(hash)
      rescue Error => e
        raise Error, "#{e.message}#{where(path)}"
      end
      Sheet.new(as_hash(hash), path)
    end

    # 시트 파일을 읽는다. 같은 경로는 한 번만 읽는다 (SpriteSheet.clear_cache 로 비운다).
    def load(path)
      raise Error, "sheet: load needs a path" unless path.is_a?(String) && !path.empty?
      sheet = @cache[path]
      return sheet unless sheet.nil?
      data = nil
      begin
        data = Json.load(resolve_path(path))
      rescue RuntimeError => e
        raise Error, "sheet: cannot open #{path} (#{e.message})"
      end
      sheet = from_hash(data, path)
      @cache[path] = sheet
      sheet
    end

    def clear_cache
      @cache = {}
    end
  end

  # 클립 하나 (읽은 뒤 바뀌지 않는다). order 는 재생 순서(frames 의 자리, 0 부터), cycle 은 한 바퀴의 ms
  class Clip
    attr_reader :name, :frames, :durations, :loop, :order, :cycle, :pivot

    def initialize(name, frames, durations, loop_mode, pivot)
      @name = name
      @frames = frames
      @durations = durations
      @loop = loop_mode
      @pivot = pivot
      # pingpong 은 끝에서 돌아오되 양 끝을 두 번 보이지 않는다: 0 1 2 1 0 1 2 1 ...
      @order = (0...frames.size).to_a
      (frames.size - 2).downto(1) { |i| @order.push(i) } if loop_mode == "pingpong"
      @cycle = 0
      @order.each { |i| @cycle += durations[i] }
    end
  end

  class Sheet
    attr_reader :path, :image, :image_width, :image_height, :frame_width, :frame_height, :margin, :spacing,
                :columns, :rows, :frame_count, :pivot, :default_clip, :source

    def initialize(hash, path)
      @source = hash
      @path = path
      @image = hash["image"]
      size = SpriteSheet.png_size(SpriteSheet.resolve_path(@image))
      SpriteSheet.raise_at(path, "cannot read the size of #{@image}") if size.nil?
      @image_width, @image_height = size
      @frame_width = hash["frameWidth"].floor
      @frame_height = hash["frameHeight"].floor
      @margin = (hash["margin"] || 0).floor
      @spacing = (hash["spacing"] || 0).floor
      @columns = (@image_width - 2 * @margin + @spacing) / (@frame_width + @spacing)
      @rows = (@image_height - 2 * @margin + @spacing) / (@frame_height + @spacing)
      if @columns < 1 || @rows < 1
        SpriteSheet.raise_at(path, "#{@image} is #{@image_width}x#{@image_height}, " +
                                   "too small for one #{@frame_width}x#{@frame_height} frame")
      end
      @frame_count = @columns * @rows
      pv = hash["pivot"]
      @pivot = pv.nil? ? [0, 0] : [pv[0], pv[1]]
      dc = hash["defaultClip"]
      @default_clip = (dc.nil? || dc == "") ? nil : dc

      @clips = {}
      clips = SpriteSheet.as_hash(hash["clips"])
      clips.keys.sort.each do |name|
        c = SpriteSheet.as_hash(clips[name])
        frames = []
        durations = []
        SpriteSheet.as_array(c["frames"]).each_with_index do |f, i|
          if f >= @frame_count
            SpriteSheet.raise_at(path, "clip '#{name}' frames[#{i + 1}] is #{SpriteSheet.value_text(f)}, " +
                                       "but the sheet has #{@frame_count} frames")
          end
          frames.push(f.floor)
          d = c["duration"]
          durations.push(d.is_a?(Array) ? d[i] : (d || DEFAULT_DURATION))
        end
        cp = c["pivot"]
        @clips[name] = Clip.new(name, frames, durations, c["loop"] || "loop", cp.nil? ? nil : [cp[0], cp[1]])
      end
    end

    # 프레임 n 의 칸: [x, y, w, h] (이미지 픽셀)
    def frame_rect(n)
      unless SpriteSheet.integer_like?(n) && n >= 0 && n < @frame_count
        SpriteSheet.raise_at(@path, "frame #{SpriteSheet.value_text(n)} is outside the sheet (#{@frame_count} frames)")
      end
      n = n.floor
      col = n % @columns
      row = n / @columns
      [@margin + col * (@frame_width + @spacing), @margin + row * (@frame_height + @spacing), @frame_width, @frame_height]
    end

    # 클립 (Clip). 없으면 nil
    def clip(name)
      @clips[name]
    end

    # 클립 이름 목록 (정렬)
    def clip_names
      @clips.keys.sort
    end

    # 이 시트의 클립을 트는 재생기. 오브젝트마다 하나씩 만든다 (시트는 나눠 쓰고 재생 상태만 따로 둔다).
    def animator
      Animator.new(self)
    end
  end

  class Animator
    attr_reader :sheet

    def initialize(sheet)
      @sheet = sheet
      @clip = nil
      @step = 0
      @time = 0
      @done = false
    end

    # 클립을 처음부터 튼다. 같은 클립이어도 처음으로 돌아간다. nil 이면 클립을 내리고 0 번 프레임을 보인다.
    def play(name)
      if name.nil?
        @clip = nil
      else
        c = @sheet.clip(name)
        SpriteSheet.raise_at(@sheet.path, "no clip '#{name}'") if c.nil?
        @clip = c
      end
      restart
    end

    # 지금 클립을 처음부터 다시 튼다
    def restart
      @step = 0
      @time = 0
      @done = false
      self
    end

    # 시간을 ms 만큼 보낸다. 프레임 시간이 다 차면 다음 프레임으로 가고, 한 번에 여러 프레임을 넘을 수 있다.
    # once 는 마지막 프레임의 시간이 다 차면 끝나고(done?) 그 프레임에 머문다.
    def update(ms)
      c = @clip
      return self if c.nil? || @done || !ms.is_a?(Numeric) || ms <= 0
      @time += ms
      @time = @time % c.cycle if c.loop != "once" && @time >= c.cycle   # 한 바퀴는 같은 자리로 돌아온다
      n = c.order.size
      loop do
        d = c.durations[c.order[@step]]
        break if @time < d
        if @step < n - 1
          @time -= d
          @step += 1
        elsif c.loop == "once"
          @time = d
          @done = true
          break
        else
          @time -= d
          @step = 0
        end
      end
      self
    end

    # 지금 클립 이름 (없으면 nil)
    def clip
      @clip.nil? ? nil : @clip.name
    end

    # 지금 보이는 시트의 프레임 번호 (클립이 없으면 0)
    def frame
      @clip.nil? ? 0 : @clip.frames[@clip.order[@step]]
    end

    # once 클립이 끝났는가 (loop, pingpong 은 늘 false)
    def done?
      @done
    end

    # 기준점 [x, y]: 클립의 pivot, 없으면 시트의 pivot, 그것도 없으면 [0, 0]
    def pivot
      (!@clip.nil? && !@clip.pivot.nil?) ? @clip.pivot : @sheet.pivot
    end

    # 지금 프레임의 칸 [x, y, w, h]
    def rect
      @sheet.frame_rect(frame)
    end

    # 지금 프레임의 칸과 기준점을 스프라이트에 옮긴다. 스프라이트는 프레임 크기로 만든 것이어야 한다.
    def apply(sprite)
      x, y, w, h = rect
      sprite.set_rect(x, y, w, h)
      px, py = pivot
      sprite.set_pivot(px.to_f, py.to_f)
      self
    end
  end
end
