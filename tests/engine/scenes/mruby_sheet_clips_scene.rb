# 스프라이트 시트 클립 검증 씬 (엔진 2) 의 Ruby 판. sheet_clips_scene.lua 와 같은 줄을 찍고 같은 그림을 그리며
# 러너가 같은 검사와 같은 골든(sheet_clips)으로 확인한다.

require "scripts/ruby/scene_loader"

TICK = 20

def sheet_state(obj)
  a = obj.animator
  "#{obj.id}=#{a.clip.nil? ? 'nil' : a.clip}:#{a.frame}#{a.done? ? ',done' : ''}"
end

def report(label)
  parts = ["walker", "waver", "hitter"].map { |id| sheet_state(@scene.find(id)) }
  puts "sheet:#{label}:#{parts.join(' ')}"
end

def rect_of(id)
  r = @scene.find(id).sprite.rect
  "#{id}=#{r[:x]},#{r[:y]}"
end

def init
  @scene = SceneLoader.open("fixtures/scenes/sheet_v1.json")
  sheet = @scene.find("walker").sheet
  puts "sheet:grid:#{sheet.columns}x#{sheet.rows} frames=#{sheet.frame_count} frame=#{sheet.frame_width}x#{sheet.frame_height}"
  report("open")
  (1..26).each do |tick|
    @scene = @scene.tick(TICK)
    report("t#{tick}") if [5, 8, 10, 13, 20, 21, 26].include?(tick)
    if tick == 20
      @scene.find("walker").props["clip"] = "hit"   # 다음 틱에 처음부터 (그 틱에는 시간을 보내지 않는다)
      @scene.find("waver").animate = false          # 멈춘다
    elsif tick == 23
      @scene.find("hitter").animator.restart        # 끝난 once 를 다시
    end
  end
  puts "sheet:rect:#{rect_of('walker')} #{rect_of('waver')} #{rect_of('hitter')}"
end

def update(elapsed)
end

def render
  @scene.draw
end

def destroy
  @scene.close
end
