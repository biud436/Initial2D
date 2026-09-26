/**
 * @file mrb_sprite.cpp
 * @brief Sprite 클래스 (mruby). lua_sprite.cpp 에 대응한다.
 *
 * Lua 는 포인터를 숫자 핸들로 건네고 Dispose 를 손으로 부르지만, Ruby 에서는
 * Sprite 가 진짜 객체다. GC 가 거두면 C++ Sprite 도 지워진다 (dfree). 텍스처는
 * 여전히 TextureManager 소유라 함께 지워지지 않는다.
 *
 *   sprite = Sprite.new(x, y, width, height, max_frames, texture_id)
 *   sprite = Sprite.load(path, id, x, y, width, height, frames = 1)   # 프렐류드
 *   sprite.update(elapsed); sprite.draw
 *   sprite.x, sprite.y, sprite.position -> [x, y], sprite.set_position(x, y)
 *   sprite.width, sprite.height, sprite.scale, sprite.scale = n
 *   sprite.angle, sprite.angle = deg, sprite.radians, sprite.radians = rad
 *   sprite.visible?, sprite.visible = bool, sprite.opacity, sprite.opacity = 0..255
 *   sprite.frame_delay, sprite.frame_delay = ms, sprite.set_frames(first, last)
 *   sprite.start_frame, sprite.end_frame, sprite.current_frame, sprite.current_frame = n
 *   sprite.loop = bool, sprite.anim_complete?, sprite.anim_complete = bool
 *   sprite.set_sheet_grid(cols, rows)
 *   sprite.rect -> { x:, y:, right:, bottom:, width:, height: }
 *   sprite.set_rect(x, y, width, height) 또는 set_rect(x: , y: , width: , height: )
 *   sprite.dispose, sprite.disposed?
 */
#include "Constants.h"

#ifdef INITIAL2D_HAS_MRUBY

#include "mrb_prot.h"
#include "Sprite.h"

#include <string>

namespace
{
	void SpriteFree(mrb_state* mrb, void* ptr)
	{
		delete static_cast<Sprite*>(ptr);
	}

	const mrb_data_type SpriteType = { "Sprite", SpriteFree };

	Sprite* GetSprite(mrb_state* mrb, mrb_value self)
	{
		Sprite* p = static_cast<Sprite*>(mrb_data_get_ptr(mrb, self, &SpriteType));
		if (p == nullptr)
		{
			mrb_raise(mrb, E_RUNTIME_ERROR, "disposed Sprite");
		}
		return p;
	}

	mrb_value sprite_initialize(mrb_state* mrb, mrb_value self)
	{
		mrb_float x = 0, y = 0;
		mrb_int width = 0, height = 0, maxFrames = 1;
		const char* textureId = nullptr;
		mrb_get_args(mrb, "ffiiiz", &x, &y, &width, &height, &maxFrames, &textureId);

		if (DATA_PTR(self) != nullptr)
		{
			SpriteFree(mrb, DATA_PTR(self));
			DATA_PTR(self) = nullptr;
		}

		Sprite* p = new Sprite();
		p->initialize(static_cast<float>(x), static_cast<float>(y),
			static_cast<int>(width), static_cast<int>(height), static_cast<int>(maxFrames),
			std::string(textureId));

		DATA_TYPE(self) = &SpriteType;
		DATA_PTR(self) = p;
		return self;
	}

	mrb_value sprite_update(mrb_state* mrb, mrb_value self)
	{
		mrb_float elapsed = 0;
		mrb_get_args(mrb, "f", &elapsed);
		GetSprite(mrb, self)->update(static_cast<float>(elapsed));
		return self;
	}

	mrb_value sprite_draw(mrb_state* mrb, mrb_value self)
	{
		GetSprite(mrb, self)->draw();
		return self;
	}

	mrb_value sprite_x(mrb_state* mrb, mrb_value self)
	{
		return mrb_float_value(mrb, GetSprite(mrb, self)->getX());
	}

	mrb_value sprite_y(mrb_state* mrb, mrb_value self)
	{
		return mrb_float_value(mrb, GetSprite(mrb, self)->getY());
	}

	mrb_value sprite_position(mrb_state* mrb, mrb_value self)
	{
		Sprite* p = GetSprite(mrb, self);
		mrb_value pair = mrb_ary_new_capa(mrb, 2);
		mrb_ary_push(mrb, pair, mrb_float_value(mrb, p->getX()));
		mrb_ary_push(mrb, pair, mrb_float_value(mrb, p->getY()));
		return pair;
	}

	mrb_value sprite_set_position(mrb_state* mrb, mrb_value self)
	{
		mrb_float x = 0, y = 0;
		mrb_get_args(mrb, "ff", &x, &y);
		Sprite* p = GetSprite(mrb, self);
		p->setX(static_cast<float>(x));
		p->setY(static_cast<float>(y));
		return self;
	}

	mrb_value sprite_scale(mrb_state* mrb, mrb_value self)
	{
		return mrb_float_value(mrb, GetSprite(mrb, self)->getScale());
	}

	mrb_value sprite_set_scale(mrb_state* mrb, mrb_value self)
	{
		mrb_float scale = 1;
		mrb_get_args(mrb, "f", &scale);
		GetSprite(mrb, self)->setScale(static_cast<float>(scale));
		return mrb_float_value(mrb, scale);
	}

	mrb_value sprite_width(mrb_state* mrb, mrb_value self)
	{
		return mrb_int_value(mrb, GetSprite(mrb, self)->getWidth());
	}

	mrb_value sprite_height(mrb_state* mrb, mrb_value self)
	{
		return mrb_int_value(mrb, GetSprite(mrb, self)->getHeight());
	}

	mrb_value sprite_angle(mrb_state* mrb, mrb_value self)
	{
		return mrb_float_value(mrb, GetSprite(mrb, self)->getAngle());
	}

	mrb_value sprite_set_angle(mrb_state* mrb, mrb_value self)
	{
		mrb_float angle = 0;
		mrb_get_args(mrb, "f", &angle);
		GetSprite(mrb, self)->setAngle(static_cast<float>(angle));
		return mrb_float_value(mrb, angle);
	}

	mrb_value sprite_radians(mrb_state* mrb, mrb_value self)
	{
		return mrb_float_value(mrb, GetSprite(mrb, self)->getRadians());
	}

	mrb_value sprite_set_radians(mrb_state* mrb, mrb_value self)
	{
		mrb_float radians = 0;
		mrb_get_args(mrb, "f", &radians);
		GetSprite(mrb, self)->setRadians(static_cast<float>(radians));
		return mrb_float_value(mrb, radians);
	}

	mrb_value sprite_visible(mrb_state* mrb, mrb_value self)
	{
		return mrb_bool_value(GetSprite(mrb, self)->getVisible());
	}

	mrb_value sprite_set_visible(mrb_state* mrb, mrb_value self)
	{
		mrb_bool visible = 1;
		mrb_get_args(mrb, "b", &visible);
		GetSprite(mrb, self)->setVisible(visible != 0);
		return mrb_bool_value(visible);
	}

	mrb_value sprite_opacity(mrb_state* mrb, mrb_value self)
	{
		return mrb_int_value(mrb, GetSprite(mrb, self)->getOpacity());
	}

	mrb_value sprite_set_opacity(mrb_state* mrb, mrb_value self)
	{
		mrb_int opacity = 255;
		mrb_get_args(mrb, "i", &opacity);
		GetSprite(mrb, self)->setOpacity(static_cast<int>(opacity));
		return mrb_int_value(mrb, opacity);
	}

	mrb_value sprite_frame_delay(mrb_state* mrb, mrb_value self)
	{
		return mrb_float_value(mrb, GetSprite(mrb, self)->getFrameDelay());
	}

	mrb_value sprite_set_frame_delay(mrb_state* mrb, mrb_value self)
	{
		mrb_float delay = 0;
		mrb_get_args(mrb, "f", &delay);
		GetSprite(mrb, self)->setFrameDelay(delay);
		return mrb_float_value(mrb, delay);
	}

	mrb_value sprite_set_frames(mrb_state* mrb, mrb_value self)
	{
		mrb_int first = 0, last = 0;
		mrb_get_args(mrb, "ii", &first, &last);
		GetSprite(mrb, self)->setFrames(static_cast<int>(first), static_cast<int>(last));
		return self;
	}

	mrb_value sprite_start_frame(mrb_state* mrb, mrb_value self)
	{
		return mrb_int_value(mrb, GetSprite(mrb, self)->getStartFrame());
	}

	mrb_value sprite_end_frame(mrb_state* mrb, mrb_value self)
	{
		return mrb_int_value(mrb, GetSprite(mrb, self)->getEndFrame());
	}

	mrb_value sprite_current_frame(mrb_state* mrb, mrb_value self)
	{
		return mrb_int_value(mrb, GetSprite(mrb, self)->getCurrentFrame());
	}

	mrb_value sprite_set_current_frame(mrb_state* mrb, mrb_value self)
	{
		mrb_int frame = 0;
		mrb_get_args(mrb, "i", &frame);
		GetSprite(mrb, self)->setCurrentFrame(static_cast<int>(frame));
		return mrb_int_value(mrb, frame);
	}

	mrb_value sprite_set_loop(mrb_state* mrb, mrb_value self)
	{
		mrb_bool loop = 0;
		mrb_get_args(mrb, "b", &loop);
		GetSprite(mrb, self)->setLoop(loop != 0);
		return mrb_bool_value(loop);
	}

	mrb_value sprite_anim_complete(mrb_state* mrb, mrb_value self)
	{
		return mrb_bool_value(GetSprite(mrb, self)->getAnimComplete());
	}

	mrb_value sprite_set_anim_complete(mrb_state* mrb, mrb_value self)
	{
		mrb_bool complete = 0;
		mrb_get_args(mrb, "b", &complete);
		GetSprite(mrb, self)->setAnimComplete(complete != 0);
		return mrb_bool_value(complete);
	}

	/** 시트 분할 (기본 4x4, R2K3 CharSet 은 3x4). 0 이하는 무시된다. */
	mrb_value sprite_set_sheet_grid(mrb_state* mrb, mrb_value self)
	{
		mrb_int cols = 0, rows = 0;
		mrb_get_args(mrb, "ii", &cols, &rows);
		GetSprite(mrb, self)->setSheetGrid(static_cast<int>(cols), static_cast<int>(rows));
		return self;
	}

	/**
	 * 텍스처에서 잘라 그리는 소스 사각형. Lua 의 GetRect 는 width/height 칸에
	 * 오른쪽/아래 좌표를 넣는 규칙이었는데, Ruby 에서는 이름대로 돌려준다.
	 * (right, bottom 도 함께 두어 잃는 정보가 없다)
	 */
	mrb_value sprite_rect(mrb_state* mrb, mrb_value self)
	{
		const RECT rect = GetSprite(mrb, self)->getRect();
		mrb_value hash = mrb_hash_new_capa(mrb, 6);
		mrb_hash_set(mrb, hash, mrb_symbol_value(mrb_intern_lit(mrb, "x")), mrb_int_value(mrb, rect.left));
		mrb_hash_set(mrb, hash, mrb_symbol_value(mrb_intern_lit(mrb, "y")), mrb_int_value(mrb, rect.top));
		mrb_hash_set(mrb, hash, mrb_symbol_value(mrb_intern_lit(mrb, "right")), mrb_int_value(mrb, rect.right));
		mrb_hash_set(mrb, hash, mrb_symbol_value(mrb_intern_lit(mrb, "bottom")), mrb_int_value(mrb, rect.bottom));
		mrb_hash_set(mrb, hash, mrb_symbol_value(mrb_intern_lit(mrb, "width")), mrb_int_value(mrb, rect.right - rect.left));
		mrb_hash_set(mrb, hash, mrb_symbol_value(mrb_intern_lit(mrb, "height")), mrb_int_value(mrb, rect.bottom - rect.top));
		return hash;
	}

	mrb_int HashInt(mrb_state* mrb, mrb_value hash, const char* key)
	{
		mrb_value v = mrb_hash_get(mrb, hash, mrb_symbol_value(mrb_intern_cstr(mrb, key)));
		if (mrb_nil_p(v))
		{
			v = mrb_hash_get(mrb, hash, mrb_str_new_cstr(mrb, key));
		}
		return mrb_nil_p(v) ? 0 : MRuby_ToInt(mrb, v);
	}

	/** set_rect(x, y, width, height) 또는 set_rect({ x:, y:, width:, height: }) */
	mrb_value sprite_set_rect(mrb_state* mrb, mrb_value self)
	{
		mrb_value* argv = nullptr;
		mrb_int argc = 0;
		mrb_get_args(mrb, "*", &argv, &argc);

		mrb_int x = 0, y = 0, width = 0, height = 0;
		if (argc == 1 && mrb_hash_p(argv[0]))
		{
			x = HashInt(mrb, argv[0], "x");
			y = HashInt(mrb, argv[0], "y");
			width = HashInt(mrb, argv[0], "width");
			height = HashInt(mrb, argv[0], "height");
		}
		else if (argc == 4)
		{
			x = MRuby_ToInt(mrb, argv[0]);
			y = MRuby_ToInt(mrb, argv[1]);
			width = MRuby_ToInt(mrb, argv[2]);
			height = MRuby_ToInt(mrb, argv[3]);
		}
		else
		{
			mrb_raise(mrb, E_ARGUMENT_ERROR, "set_rect(x, y, width, height) or set_rect(hash)");
		}

		GetSprite(mrb, self)->setRect(static_cast<int>(x), static_cast<int>(y),
			static_cast<int>(x + width), static_cast<int>(y + height));
		return self;
	}

	mrb_value sprite_dispose(mrb_state* mrb, mrb_value self)
	{
		mrb_data_check_type(mrb, self, &SpriteType);
		if (DATA_PTR(self) != nullptr)
		{
			SpriteFree(mrb, DATA_PTR(self));
			DATA_PTR(self) = nullptr;
		}
		return mrb_nil_value();
	}

	mrb_value sprite_disposed(mrb_state* mrb, mrb_value self)
	{
		mrb_data_check_type(mrb, self, &SpriteType);
		return mrb_bool_value(DATA_PTR(self) == nullptr);
	}
}

void MRuby_DefineSprite(mrb_state* mrb)
{
	struct RClass* cls = mrb_define_class(mrb, "Sprite", mrb->object_class);
	MRB_SET_INSTANCE_TT(cls, MRB_TT_DATA);

	mrb_define_method(mrb, cls, "initialize", sprite_initialize, MRB_ARGS_REQ(6));
	mrb_define_method(mrb, cls, "update", sprite_update, MRB_ARGS_REQ(1));
	mrb_define_method(mrb, cls, "draw", sprite_draw, MRB_ARGS_NONE());
	mrb_define_method(mrb, cls, "x", sprite_x, MRB_ARGS_NONE());
	mrb_define_method(mrb, cls, "y", sprite_y, MRB_ARGS_NONE());
	mrb_define_method(mrb, cls, "position", sprite_position, MRB_ARGS_NONE());
	mrb_define_method(mrb, cls, "set_position", sprite_set_position, MRB_ARGS_REQ(2));
	mrb_define_method(mrb, cls, "scale", sprite_scale, MRB_ARGS_NONE());
	mrb_define_method(mrb, cls, "scale=", sprite_set_scale, MRB_ARGS_REQ(1));
	mrb_define_method(mrb, cls, "width", sprite_width, MRB_ARGS_NONE());
	mrb_define_method(mrb, cls, "height", sprite_height, MRB_ARGS_NONE());
	mrb_define_method(mrb, cls, "angle", sprite_angle, MRB_ARGS_NONE());
	mrb_define_method(mrb, cls, "angle=", sprite_set_angle, MRB_ARGS_REQ(1));
	mrb_define_method(mrb, cls, "radians", sprite_radians, MRB_ARGS_NONE());
	mrb_define_method(mrb, cls, "radians=", sprite_set_radians, MRB_ARGS_REQ(1));
	mrb_define_method(mrb, cls, "visible?", sprite_visible, MRB_ARGS_NONE());
	mrb_define_method(mrb, cls, "visible=", sprite_set_visible, MRB_ARGS_REQ(1));
	mrb_define_method(mrb, cls, "opacity", sprite_opacity, MRB_ARGS_NONE());
	mrb_define_method(mrb, cls, "opacity=", sprite_set_opacity, MRB_ARGS_REQ(1));
	mrb_define_method(mrb, cls, "frame_delay", sprite_frame_delay, MRB_ARGS_NONE());
	mrb_define_method(mrb, cls, "frame_delay=", sprite_set_frame_delay, MRB_ARGS_REQ(1));
	mrb_define_method(mrb, cls, "set_frames", sprite_set_frames, MRB_ARGS_REQ(2));
	mrb_define_method(mrb, cls, "start_frame", sprite_start_frame, MRB_ARGS_NONE());
	mrb_define_method(mrb, cls, "end_frame", sprite_end_frame, MRB_ARGS_NONE());
	mrb_define_method(mrb, cls, "current_frame", sprite_current_frame, MRB_ARGS_NONE());
	mrb_define_method(mrb, cls, "current_frame=", sprite_set_current_frame, MRB_ARGS_REQ(1));
	mrb_define_method(mrb, cls, "loop=", sprite_set_loop, MRB_ARGS_REQ(1));
	mrb_define_method(mrb, cls, "anim_complete?", sprite_anim_complete, MRB_ARGS_NONE());
	mrb_define_method(mrb, cls, "anim_complete=", sprite_set_anim_complete, MRB_ARGS_REQ(1));
	mrb_define_method(mrb, cls, "set_sheet_grid", sprite_set_sheet_grid, MRB_ARGS_REQ(2));
	mrb_define_method(mrb, cls, "rect", sprite_rect, MRB_ARGS_NONE());
	mrb_define_method(mrb, cls, "set_rect", sprite_set_rect, MRB_ARGS_ANY());
	mrb_define_method(mrb, cls, "dispose", sprite_dispose, MRB_ARGS_NONE());
	mrb_define_method(mrb, cls, "disposed?", sprite_disposed, MRB_ARGS_NONE());
}

#endif // INITIAL2D_HAS_MRUBY
