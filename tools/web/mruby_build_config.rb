# mruby 4.0.0 의 Emscripten 빌드 설정 (R3, docs/plans/r3-emscripten.md 9절)
#
# tools/build_web.sh 가 mruby 소스 폴더에서 다음처럼 부른다.
#   MRUBY_CONFIG=<이 파일> MRUBY_BUILD_DIR=<저장소>/build-web/mruby rake
# 산출물은 build-web/mruby/emscripten/ 의 lib/libmruby.a, include/, lib/libmruby.flags.mak 이고,
# CMakeLists.txt 의 EMSCRIPTEN 분기가 이것을 링크한다.
#
# 예외 방식: mruby 는 C 로 컴파일되고 raise 를 setjmp/longjmp 로 한다. emscripten 툴체인이
# -fwasm-exceptions 를 주므로 setjmp/longjmp 는 wasm 예외(SUPPORT_LONGJMP=wasm)가 되고,
# 엔진의 나머지(C++ 로 컴파일된 Lua 포함)와 같은 wasm 예외 방식을 쓴다.

# 버전은 tools/build_web.sh 가 태그(4.0.0)로 고정한다. mruby 가 이 파일 옆에 쓰는 잠금 파일(.lock)은 만들지 않는다.
MRuby::Lockfile.disable

# 호스트: mrbc 만 만든다. 크로스 빌드의 gem 에 든 Ruby 소스를 이것으로 바이트코드로 굽는다.
MRuby::Build.new do |conf|
  conf.toolchain :clang
  conf.build_mrbc_exec
  conf.disable_libmruby
end

MRuby::CrossBuild.new("emscripten") do |conf|
  conf.toolchain :emscripten

  # 네이티브(Homebrew, gembox 'full-core')와 같은 gem 에서 브라우저에 맞지 않는 것만 뺀다.
  #   mruby-bin-* (config 제외)  실행 파일 (라이브러리에는 필요 없다)
  #   mruby-socket              브라우저에는 BSD 소켓이 없다
  #   mruby-task                시그널과 타이머로 도는 선점형 스케줄러
  #   mruby-test*, mruby-sleep  테스트용 (sleep 은 full-core 에도 없다)
  # mruby-io 와 mruby-dir 은 넣는다 (MEMFS 위에서 File.open, File.exist?, Dir 이 돈다).
  # mruby-bin-config 는 남긴다. 호스트 쪽 host-bin/mruby-config 와 lib/libmruby.flags.mak 을 만들고,
  # CMake 가 flags.mak 의 -D 항목으로 엔진을 libmruby 와 같은 정의로 컴파일한다.
  excluded = /\Amruby-(?:bin-(?!config\z).*|socket|task|test.*|sleep)\z/
  Dir.glob("#{MRUBY_ROOT}/mrbgems/mruby-*/mrbgem.rake").sort.each do |rake|
    name = File.basename(File.dirname(rake))
    conf.gem core: name unless name =~ excluded
  end
  conf.gem core: "hal-posix-io"
  conf.gem core: "hal-posix-dir"

  # 정수 폭을 네이티브(64비트)와 맞춘다. wasm32 의 기본값은 32비트라 2^31 을 넘는 정수가
  # 네이티브에서는 Integer, 브라우저에서는 Bigint 가 된다. 32비트 포인터에서 64비트 정수를 쓰려면
  # boxing 을 꺼야 한다 (mrbconf.h). 실수는 둘 다 손실 없는 double 이다.
  conf.compilers.each do |c|
    c.defines << "MRB_INT64" << "MRB_NO_BOXING"
  end

  # 호출 깊이 한도. 네이티브(Homebrew)의 기본값과 같은 512 로 고정한다. C 를 거치는 재귀
  # (문자열 보간 안의 to_s, Array#inspect 등)는 단계마다 wasm 스택을 최대 약 5.4 KB 쓰므로,
  # 엔진 링크의 STACK_SIZE(8 MB, CMakeLists.txt)가 이 한도보다 먼저 바닥나지 않는다.
  # 한도를 올리면 STACK_SIZE 도 같이 본다 (docs/plans/r3-emscripten.md 10절).
  conf.compilers.each do |c|
    c.defines << "MRB_CALL_LEVEL_MAX=512"
  end
end
