# 알데바란, 스테이지 목록 (docs/plans/aldebaran-7-tomb.md 7절 1항).
#
# 씬이 인자로 받는 스테이지 id와 그 모듈의 목록이다. 스테이지 모듈이 정의해야
# 하는 항목은 stages/forest.rb 위쪽에 있다. 순서(ORDER)는 원안 4.2절의 지도 순서다.
#
# require하는 쪽은 경로를 파일 이름까지 적는다:
#   require "scripts/ruby/games/aldebaran/stages/init"
#
# 스테이지 id는 문자열이다 (환경 변수 INITIAL2D_ALDEBARAN_STAGE에서 받고 테스트 기록에 그대로 출력된다).

module Aldebaran
  module Stages
    ORDER = ["forest", "tomb"]

    # id마다 require할 파일과, require 뒤에 정의되는 모듈의 이름
    MODULES = {
      "forest" => ["scripts/ruby/games/aldebaran/stages/forest", :Forest],
      "tomb" => ["scripts/ruby/games/aldebaran/stages/tomb", :Tomb],
    }

    @cache = {}

    # id의 스테이지 모듈을 돌려준다. 결과는 [모듈, nil]이고, 모르는 id면 [nil, 이유]다.
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

    # 첫 스테이지
    def self.first
      get(ORDER[0])[0]
    end

    # 이 스테이지의 다음 스테이지. 마지막이면 nil (게임의 끝이다)
    def self.after(id)
      ORDER.each_with_index do |key, i|
        if key == id && !ORDER[i + 1].nil?
          return get(ORDER[i + 1])[0]
        end
      end
      nil
    end

    # 몇 번째 스테이지인가 (결과 창의 "1 / 2" 표시용). 1부터 센다.
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
