# components/sample/drift.rb : params["target"] 이 가리키는 오브젝트를 매 틱 (dx, dy) 만큼 옮기는 컴포넌트
#
# 선언은 scripts/components/sample/drift.json (target 은 object, dx 기본 1, dy 기본 0).

module Components
  module Sample
    class Drift
      def initialize(params)
        @params = params
      end

      def update(obj, scene, elapsed)
        id = @params["target"]
        target = id.nil? ? nil : scene.find(id)
        return if target.nil?
        target.x = target.x + @params["dx"]
        target.y = target.y + @params["dy"]
      end
    end
  end
end
