# 알데바란, 스테이지 목록 (docs/plans/aldebaran-7-tomb.md 7절 1항).
# scripts/lua/games/aldebaran/stages/init.lua 의 Ruby 판.
#
# A6까지 스테이지는 하나였고 game.lua가 그 하나를 직접 require 했다. 1-2가
# 생기면서 씬은 "어느 스테이지인가"를 인자로 받아야 한다. 이 파일이 그 인자의
# 값들이다.
#
# 스테이지 모듈이 채워야 하는 칸은 stages/forest.rb 위쪽에 모아 두었다.
# 순서(ORDER)는 원안 4.2절의 지도 순서다 (1-1, 1-2, ...).
#
# 부르는 쪽은 경로를 끝까지 적는다 (Lua 와 짝을 맞춘다):
#   require "scripts/ruby/games/aldebaran/stages/init"
#
# 스테이지 id 는 문자열이다. 환경 변수(INITIAL2D_ALDEBARAN_STAGE)에서 오고 테스트 기록에
# 그대로 찍히기 때문이다.

module Aldebaran
  module Stages
    ORDER = ["forest", "tomb"]

    # id 마다 읽을 파일과, 읽고 나서 생기는 모듈의 이름
    MODULES = {
      "forest" => ["scripts/ruby/games/aldebaran/stages/forest", :Forest],
      "tomb" => ["scripts/ruby/games/aldebaran/stages/tomb", :Tomb],
    }

    @cache = {}

    # 스테이지 하나. 모르는 id 면 nil 과 이유를 돌려준다.
    # Lua 의 두 값 반환을 짝으로 옮겼다: [모듈, nil] 또는 [nil, 이유].
    def self.get(id)
      return [nil, "스테이지 id가 없다"] if id.nil?
      return [@cache[id], nil] unless @cache[id].nil?
      entry = MODULES[id]
      if entry.nil?
        return [nil, "모르는 스테이지 '" + id.to_s + "'"]
      end
      require entry[0]
      stage = Stages.const_get(entry[1])
      @cache[id] = stage
      [stage, nil]
    end

    # 처음 여는 스테이지
    def self.first
      get(ORDER[0])[0]
    end

    # 이 스테이지 다음. 마지막이면 nil (게임의 끝이다)
    def self.after(id)
      ORDER.each_with_index do |key, i|
        if key == id && !ORDER[i + 1].nil?
          return get(ORDER[i + 1])[0]
        end
      end
      nil
    end

    # 몇 번째인가 (결과 창의 "1 / 2" 표시용). Lua 와 같이 1 부터 센다.
    def self.index_of(id)
      ORDER.each_with_index do |key, i|
        return i + 1 if key == id
      end
      nil
    end

    COUNT = ORDER.size

    def self.count
      COUNT
    end
  end
end
