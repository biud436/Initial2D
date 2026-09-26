# components/sample/mover.rb : 다른 오브젝트를 매 틱 옮기는 작은 컴포넌트 (씬 로더 픽스처의 예제)
#
# scripts/lua/components/sample/mover.lua 에 대응한다. node 에 붙어 props["target"] 이 가리키는
# 오브젝트를 틱마다 (dx, dy) 만큼 옮기고, x 가 props["limit"] 에 닿으면 거기서 멈춘다.
# "컴포넌트는 obj.x 를 바꾸는 것으로 움직인다"의 최소 예다.

class Mover
  def init(obj, scene)
    obj.target = scene.find(obj.props["target"])
    if obj.target.nil?
      raise SceneLoader::Error, "mover '#{obj.id}': no target '#{obj.props['target']}'"
    end
  end

  def update(obj, scene, elapsed)
    t = obj.target
    limit = obj.props["limit"]
    t.x = t.x + (obj.props["dx"] || 0)
    t.y = t.y + (obj.props["dy"] || 0)
    t.x = limit if !limit.nil? && t.x >= limit
  end
end
