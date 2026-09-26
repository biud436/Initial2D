# run_tests.rb : mruby 단위 테스트 진입점.
# 러너(run_engine_tests.py)가 이 파일을 워크 디렉터리의 scripts/ruby/main.rb 로 복사하고
# INITIAL2D_SCRIPT=mruby 로 엔진 바이너리를 실행한다. 첫 프레임에 전부 실행하고 끝낸다.

load "scripts/ruby/rbtests/test.rb"
load "scripts/ruby/rbtests/manifest.rb"

def init
  puts "[mruby_unit_tests]"
  MRUBY_TEST_MANIFEST.each do |path|
    begin
      load path
    rescue Exception => e
      T.fail += 1
      puts "  FAIL  케이스 로드 실패: #{path}  |  #{e.class}: #{e.message}"
    end
  end
  T.summary
  System.exit
end

def update(elapsed); end
def render; end
def destroy; end
