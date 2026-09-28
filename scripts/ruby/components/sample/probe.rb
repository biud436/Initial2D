# components/sample/probe.rb : 받은 params 를 오브젝트에 적어 두는 컴포넌트 (씬 로더 params 픽스처)
#
# 선언(scripts/components/sample/probe.json)에 필드 타입 일곱이 다 있다. new(params) 로 받은 Hash 를
# init 에서 obj.probes 에 모으고, 훅마다 params 의 title 을 obj.probe_log 에 "훅=제목" 으로 적는다.
# 클래스는 논리 이름 전체의 모듈 경로(Components::Sample::Probe)에 있다.

module Components
  module Sample
    class Probe
      def initialize(params)
        @params = params
        @updated = false
        @rendered = false
      end

      def init(obj, scene)
        obj.probes = (obj.probes || []) + [@params]
        log(obj, "init")
      end

      def update(obj, scene, elapsed)
        return if @updated
        @updated = true
        log(obj, "update")
      end

      def render(obj, scene)
        return if @rendered
        @rendered = true
        log(obj, "render")
      end

      def destroy(obj, scene)
        log(obj, "destroy")
      end

      private

      def log(obj, hook)
        obj.probe_log = (obj.probe_log || []) + ["#{hook}=#{@params['title']}"]
      end
    end
  end
end
