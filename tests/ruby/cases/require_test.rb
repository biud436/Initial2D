# require_test.rb : Kernel#load / Kernel#require (mruby 에는 파일 읽기가 없어 엔진이 준다).

T.run_case("require") do |t|
  File.open("./mrb_require_probe.rb", "w") do |f|
    f.write("$mrb_probe_count = ($mrb_probe_count || 0) + 1\n")
  end

  $mrb_probe_count = 0
  t.check_eq(require("./mrb_require_probe"), true, "require 가 새 파일이면 true (.rb 자동)")
  t.check_eq($mrb_probe_count, 1, "한 번 실행됐다")
  t.check_eq(require("./mrb_require_probe.rb"), false, "같은 파일은 두 번째에 false")
  t.check_eq($mrb_probe_count, 1, "다시 실행되지 않았다")
  t.check_eq(load("./mrb_require_probe.rb"), true, "load 는 true")
  t.check_eq($mrb_probe_count, 2, "load 는 매번 실행한다")

  missing = false
  begin
    require("./no_such_script")
  rescue RuntimeError
    missing = true
  end
  t.check(missing, "없는 파일 require 는 RuntimeError")

  File.open("./mrb_syntax_probe.rb", "w") { |f| f.write("def broken(\n") }
  syntax = false
  begin
    load("./mrb_syntax_probe.rb")
  rescue SyntaxError, RuntimeError
    syntax = true
  end
  t.check(syntax, "문법 오류는 예외로 올라온다")

  File.delete("./mrb_require_probe.rb")
  File.delete("./mrb_syntax_probe.rb")
end
