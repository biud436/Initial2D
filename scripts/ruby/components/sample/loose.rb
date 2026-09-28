# components/sample/loose.rb : 선언 파일이 없는 컴포넌트. 받은 params 를 obj.loose 에 둔다
# (선언이 없으면 씬 파일의 params 항목이 검사 없이 그대로 온다). initialize 의 인자는 선택이다.

class Loose
  def initialize(params = {})
    @params = params
  end

  def init(obj, scene)
    obj.loose = @params
  end
end
