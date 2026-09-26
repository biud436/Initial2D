# image.rb : 텍스처 해제까지 맡는 Sprite 생성과 해제 도우미 (docs/plans/s2-ruby-aldebaran.md)
#
# 스프라이트가 GC로 회수되어도 텍스처는 TextureManager 소유라 남으므로, 텍스처 id를
# 기억하는 생성자 Image.create와 스프라이트와 텍스처를 함께 해제하는 release를 제공한다.
#
#   img = Image.create("./resources/tiles/tile1.png", 0, 0, 48, 48, 1, "tile")
#   img.set_position(10, 20); img.update(0); img.draw
#   img.release          # 스프라이트와 텍스처를 함께 해제한다

class Sprite
  # Image.create가 읽은 텍스처 id. Sprite.new로 직접 만든 스프라이트는 nil.
  attr_accessor :texture_id

  # 스프라이트를 해제하고, Image.create가 읽은 텍스처도 해제한다.
  # 같은 텍스처를 공유하는 스프라이트가 여럿이면 하나만 release하고 나머지는 dispose한다.
  def release
    dispose unless disposed?
    if texture_id
      TextureManager.remove(texture_id)
      self.texture_id = nil
    end
  end
end

module Image
  # 경로, 위치, 크기, 프레임 수, 텍스처 id 순서로 받는다. 텍스처를 읽지 못하면 RuntimeError.
  def self.create(path, x, y, width, height, max_frames, id)
    sprite = Sprite.load(path, id, x, y, width, height, max_frames)
    sprite.texture_id = id
    sprite
  end

  # 공용 모듈들이 image_factory 인자의 기본값으로 쓰는 Proc
  FACTORY = ->(path, x, y, width, height, max_frames, id) {
    Image.create(path, x, y, width, height, max_frames, id)
  }
end
