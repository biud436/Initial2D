/**
 * @file mrb_font.cpp
 * @brief FontEx 클래스 (mruby). lua_font.cpp 에 대응한다.
 *
 * 동적 폰트(GetGlyphOutline)는 Windows 전용이라 macOS 와 Android 에서는
 * 무동작 스텁이다 (platform/sdl2/ExperimentalFontStub.cpp). API 형태만 같다.
 *
 *   font = FontEx.new(face, size, width, height)
 *   font.text = "..."; font.set_position(x, y); font.set_text_color(r, g, b)
 *   font.opacity = 0..255; font.angle = deg; font.text_width(text)
 *   font.update(elapsed); font.draw; font.dispose; font.disposed?
 */
#include "Constants.h"

#ifdef INITIAL2D_HAS_MRUBY

#include "mrb_prot.h"
#include "ExperimentalFont.h"

#ifdef RS_WINDOWS
#include <codecvt>
#include <locale>
#else
#include "platform/Utf8.h"
#endif

#include <string>

namespace
{
	std::wstring ToWide(const std::string& utf8)
	{
#ifdef RS_WINDOWS
		std::wstring_convert<std::codecvt_utf8<wchar_t>> converter;
		return converter.from_bytes(utf8);
#else
		return Initial2D::Platform::Utf8ToWide(utf8);
#endif
	}

	void FontFree(mrb_state* mrb, void* ptr)
	{
		delete static_cast<AntiAliasingFont*>(ptr);
	}

	const mrb_data_type FontType = { "FontEx", FontFree };

	AntiAliasingFont* GetFont(mrb_state* mrb, mrb_value self)
	{
		AntiAliasingFont* p = static_cast<AntiAliasingFont*>(mrb_data_get_ptr(mrb, self, &FontType));
		if (p == nullptr)
		{
			mrb_raise(mrb, E_RUNTIME_ERROR, "disposed FontEx");
		}
		return p;
	}

	mrb_value font_initialize(mrb_state* mrb, mrb_value self)
	{
		const char* face = nullptr;
		mrb_int size = 0, width = 0, height = 0;
		mrb_get_args(mrb, "ziii", &face, &size, &width, &height);

		if (DATA_PTR(self) != nullptr)
		{
			FontFree(mrb, DATA_PTR(self));
			DATA_PTR(self) = nullptr;
		}

		AntiAliasingFont* p = new AntiAliasingFont(ToWide(face), static_cast<int>(size),
			static_cast<int>(width), static_cast<int>(height));
		DATA_TYPE(self) = &FontType;
		DATA_PTR(self) = p;
		return self;
	}

	mrb_value font_update(mrb_state* mrb, mrb_value self)
	{
		mrb_float elapsed = 0;
		mrb_get_args(mrb, "f", &elapsed);
		GetFont(mrb, self)->update(static_cast<float>(elapsed));
		return self;
	}

	mrb_value font_draw(mrb_state* mrb, mrb_value self)
	{
		GetFont(mrb, self)->draw();
		return self;
	}

	mrb_value font_set_text(mrb_state* mrb, mrb_value self)
	{
		mrb_value text;
		mrb_get_args(mrb, "S", &text);
		GetFont(mrb, self)->setText(ToWide(MRuby_ToStdString(mrb, text)));
		return text;
	}

	mrb_value font_set_position(mrb_state* mrb, mrb_value self)
	{
		mrb_int x = 0, y = 0;
		mrb_get_args(mrb, "ii", &x, &y);
		GetFont(mrb, self)->setPosition(static_cast<int>(x), static_cast<int>(y));
		return self;
	}

	mrb_value font_set_text_color(mrb_state* mrb, mrb_value self)
	{
		mrb_int r = 0, g = 0, b = 0;
		mrb_get_args(mrb, "iii", &r, &g, &b);
		GetFont(mrb, self)->setTextColor(static_cast<int>(r), static_cast<int>(g), static_cast<int>(b));
		return self;
	}

	mrb_value font_set_opacity(mrb_state* mrb, mrb_value self)
	{
		mrb_int opacity = 255;
		mrb_get_args(mrb, "i", &opacity);
		GetFont(mrb, self)->setOpacity(static_cast<int>(opacity));
		return mrb_int_value(mrb, opacity);
	}

	mrb_value font_set_angle(mrb_state* mrb, mrb_value self)
	{
		mrb_float angle = 0;
		mrb_get_args(mrb, "f", &angle);
		GetFont(mrb, self)->setAngle(static_cast<float>(angle));
		return mrb_float_value(mrb, angle);
	}

	mrb_value font_text_width(mrb_state* mrb, mrb_value self)
	{
		mrb_value text;
		mrb_get_args(mrb, "S", &text);
		std::wstring wide = ToWide(MRuby_ToStdString(mrb, text));
		return mrb_int_value(mrb, GetFont(mrb, self)->getTextWidth(&wide[0]));
	}

	mrb_value font_dispose(mrb_state* mrb, mrb_value self)
	{
		mrb_data_check_type(mrb, self, &FontType);
		if (DATA_PTR(self) != nullptr)
		{
			FontFree(mrb, DATA_PTR(self));
			DATA_PTR(self) = nullptr;
		}
		return mrb_nil_value();
	}

	mrb_value font_disposed(mrb_state* mrb, mrb_value self)
	{
		mrb_data_check_type(mrb, self, &FontType);
		return mrb_bool_value(DATA_PTR(self) == nullptr);
	}
}

void MRuby_DefineFontEx(mrb_state* mrb)
{
	struct RClass* cls = mrb_define_class(mrb, "FontEx", mrb->object_class);
	MRB_SET_INSTANCE_TT(cls, MRB_TT_DATA);

	mrb_define_method(mrb, cls, "initialize", font_initialize, MRB_ARGS_REQ(4));
	mrb_define_method(mrb, cls, "update", font_update, MRB_ARGS_REQ(1));
	mrb_define_method(mrb, cls, "draw", font_draw, MRB_ARGS_NONE());
	mrb_define_method(mrb, cls, "text=", font_set_text, MRB_ARGS_REQ(1));
	mrb_define_method(mrb, cls, "set_position", font_set_position, MRB_ARGS_REQ(2));
	mrb_define_method(mrb, cls, "set_text_color", font_set_text_color, MRB_ARGS_REQ(3));
	mrb_define_method(mrb, cls, "opacity=", font_set_opacity, MRB_ARGS_REQ(1));
	mrb_define_method(mrb, cls, "angle=", font_set_angle, MRB_ARGS_REQ(1));
	mrb_define_method(mrb, cls, "text_width", font_text_width, MRB_ARGS_REQ(1));
	mrb_define_method(mrb, cls, "dispose", font_dispose, MRB_ARGS_NONE());
	mrb_define_method(mrb, cls, "disposed?", font_disposed, MRB_ARGS_NONE());
}

#endif // INITIAL2D_HAS_MRUBY
