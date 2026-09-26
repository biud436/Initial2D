# test.rb : mruby 단위 테스트 프레임워크 (S1, docs/plans/s1-mruby-binding.md).
# tests/lua/luatest.lua 에 대응한다. 엔진 바이너리 안의 mruby VM 에서 실행되며,
# 케이스 파일은 tests/ruby/cases/ 에 두고 manifest.rb 목록에 명시한다.
#
# 케이스 파일의 모양:
#
#   T.run_case("이름") do |t|
#     t.check(cond, "라벨")
#     t.check_eq(actual, expected, "라벨")
#   end

module T
  @pass = 0
  @fail = 0

  class << self
    attr_accessor :pass, :fail

    def check(cond, label, detail = nil)
      if cond
        @pass += 1
        puts "  PASS  #{label}"
      else
        @fail += 1
        puts "  FAIL  #{label}#{detail ? "  |  #{detail}" : ''}"
      end
    end

    def check_eq(actual, expected, label)
      check(actual == expected, label, "실제 #{actual.inspect}, 기대 #{expected.inspect}")
    end

    def check_type(value, klass, label)
      check(value.is_a?(klass), label, "#{value.class} 이며, 기대 #{klass}")
    end

    # 예외를 잡아 FAIL 로 집계한다 (Lua 의 pcall 에 해당)
    def run_case(name)
      puts "[#{name}]"
      yield self
    rescue Exception => e
      @fail += 1
      puts "  FAIL  케이스 실행 오류  |  #{e.class}: #{e.message}"
    end

    def summary
      # 러너(파이썬)가 파싱하는 고정 형식. 바꾸면 run_engine_tests.py 도 함께 바꿀 것.
      puts "MRUBY_TESTS_RESULT: #{@pass} PASS / #{@fail} FAIL"
    end
  end
end
