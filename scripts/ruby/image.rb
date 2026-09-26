# image.rb : Lua 의 scripts/lua/image.lua 에 대응하는 얇은 층 (S2, docs/plans/s2-ruby-aldebaran.md)
#
# Lua 의 Image(path, x, y, w, h, frames, id) 는 텍스처를 읽고 스프라이트를 만든 뒤,
# dispose() 에서 **텍스처까지** 놓는다. Ruby 의 Sprite 는 진짜 객체라 GC 가 스프라이트를
# 거두지만 텍스처는 TextureManager 소유라 남는다. 그래서 같은 인자 순서의 생성자와,
# 텍스처까지 놓는 release 를 여기서 준다.
#
#   img = Image.create("./resources/tiles/tile1.png", 0, 0, 48, 48, 1, "tile")
#   img.set_position(10, 20); img.update(0); img.draw
#   img.release          # Lua 의 img.dispose() 에 해당 (스프라이트와 텍스처를 놓는다)

class Sprite
  # Image.create 가 읽은 텍스처 id. Sprite.new 로 직접 만든 것은 nil.
  attr_accessor :texture_id

  # 스프라이트를 놓고, Image.create 가 읽은 텍스처도 놓는다 (Lua 의 Image.dispose 와 같다).
  # 같은 텍스처를 나눠 쓰는 스프라이트가 여럿이면 하나만 release 하고 나머지는 dispose 한다.
  def release
    dispose unless disposed?
    if texture_id
      TextureManager.remove(texture_id)
      self.texture_id = nil
    end
  end
end

module Image
  # Lua 의 Image(...) 와 같은 인자 순서. 텍스처를 읽지 못하면 RuntimeError.
  def self.create(path, x, y, width, height, max_frames, id)
    sprite = Sprite.load(path, id, x, y, width, height, max_frames)
    sprite.texture_id = id
    sprite
  end

  # 모듈들이 image_factory 기본값으로 쓰는 Proc (Lua 모듈의 `imageFactory or Image` 자리)
  FACTORY = ->(path, x, y, width, height, max_frames, id) {
    Image.create(path, x, y, width, height, max_frames, id)
  }
end
