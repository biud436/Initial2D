/**
 * @file mrb_input.cpp
 * @brief Input 모듈 (mruby). lua_input.cpp 에 대응한다.
 *
 *   Input.key_down?(key)   이번 틱에 눌렸다        (alias trigger?)
 *   Input.key_press?(key)  눌린 채로 있다          (alias press?)
 *   Input.key_up?(key)     이번 틱에 떼었다        (alias release?)
 *   Input.any_key_down?
 *   Input.mouse_x, Input.mouse_y
 *   Input.mouse_down?(button), mouse_press?(button), mouse_up?(button), any_mouse_down?
 *   Input.mouse_z, Input.mouse_z = wheel
 *   Input.touch_count, Input.touch(i)   i 는 0 부터. [id, x, y, phase] 또는 nil
 *
 * key 는 가상 키 정수이거나 Keys 의 상수 이름 Symbol 이다 (:z, :space, :escape, :"0").
 * button 은 0(왼쪽), 1(오른쪽), 2(가운데) 또는 :left, :right, :middle.
 */
#include "Constants.h"

#ifdef INITIAL2D_HAS_MRUBY

#include "mrb_prot.h"
#include "App.h"
#include "Input.h"

#include <algorithm>
#include <cctype>
#include <string>

namespace
{
	int ToVirtualKey(mrb_state* mrb, mrb_value value)
	{
		if (mrb_integer_p(value) || mrb_float_p(value))
		{
			return static_cast<int>(MRuby_ToInt(mrb, value));
		}
		if (mrb_symbol_p(value) || mrb_string_p(value))
		{
			std::string name = MRuby_ToStdString(mrb, value);
			std::transform(name.begin(), name.end(), name.begin(), ::toupper);
			if (name.size() == 1 && std::isdigit(static_cast<unsigned char>(name[0])))
			{
				name = "DIGIT" + name;
			}
			struct RClass* keys = mrb_module_get(mrb, "Keys");
			const mrb_sym sym = mrb_intern_cstr(mrb, name.c_str());
			if (!mrb_const_defined_at(mrb, mrb_obj_value(keys), sym))
			{
				mrb_raisef(mrb, E_ARGUMENT_ERROR, "unknown key: %s (see Keys)", name.c_str());
			}
			return static_cast<int>(mrb_integer(mrb_const_get(mrb, mrb_obj_value(keys), sym)));
		}
		mrb_raise(mrb, E_TYPE_ERROR, "key must be an Integer or a Symbol");
		return 0;
	}

	int ToMouseButton(mrb_state* mrb, mrb_value value)
	{
		if (mrb_integer_p(value) || mrb_float_p(value))
		{
			return static_cast<int>(MRuby_ToInt(mrb, value));
		}
		if (mrb_symbol_p(value) || mrb_string_p(value))
		{
			const std::string name = MRuby_ToStdString(mrb, value);
			if (name == "left") return 0;
			if (name == "right") return 1;
			if (name == "middle") return 2;
			mrb_raisef(mrb, E_ARGUMENT_ERROR, "unknown mouse button: %s (:left, :right, :middle)", name.c_str());
		}
		mrb_raise(mrb, E_TYPE_ERROR, "mouse button must be an Integer or a Symbol");
		return 0;
	}

	Input& TheInput()
	{
		return App::GetInstance().GetInput();
	}

	mrb_value input_key_down(mrb_state* mrb, mrb_value)
	{
		mrb_value key;
		mrb_get_args(mrb, "o", &key);
		return mrb_bool_value(TheInput().isKeyDown(ToVirtualKey(mrb, key)));
	}

	mrb_value input_key_up(mrb_state* mrb, mrb_value)
	{
		mrb_value key;
		mrb_get_args(mrb, "o", &key);
		return mrb_bool_value(TheInput().isKeyUp(ToVirtualKey(mrb, key)));
	}

	mrb_value input_key_press(mrb_state* mrb, mrb_value)
	{
		mrb_value key;
		mrb_get_args(mrb, "o", &key);
		return mrb_bool_value(TheInput().isKeyPress(ToVirtualKey(mrb, key)));
	}

	mrb_value input_any_key_down(mrb_state* mrb, mrb_value)
	{
		return mrb_bool_value(TheInput().isAnyKeyDown());
	}

	mrb_value input_mouse_x(mrb_state* mrb, mrb_value)
	{
		return mrb_float_value(mrb, TheInput().getMouseX());
	}

	mrb_value input_mouse_y(mrb_state* mrb, mrb_value)
	{
		return mrb_float_value(mrb, TheInput().getMouseY());
	}

	mrb_value input_mouse_down(mrb_state* mrb, mrb_value)
	{
		mrb_value button;
		mrb_get_args(mrb, "o", &button);
		return mrb_bool_value(TheInput().isMouseDown(ToMouseButton(mrb, button)));
	}

	mrb_value input_mouse_up(mrb_state* mrb, mrb_value)
	{
		mrb_value button;
		mrb_get_args(mrb, "o", &button);
		return mrb_bool_value(TheInput().isMouseUp(ToMouseButton(mrb, button)));
	}

	mrb_value input_mouse_press(mrb_state* mrb, mrb_value)
	{
		mrb_value button;
		mrb_get_args(mrb, "o", &button);
		return mrb_bool_value(TheInput().isMousePress(ToMouseButton(mrb, button)));
	}

	mrb_value input_any_mouse_down(mrb_state* mrb, mrb_value)
	{
		return mrb_bool_value(TheInput().isAnyMouseDown());
	}

	mrb_value input_mouse_z(mrb_state* mrb, mrb_value)
	{
		return mrb_int_value(mrb, TheInput().getMouseZ());
	}

	mrb_value input_set_mouse_z(mrb_state* mrb, mrb_value)
	{
		mrb_int wheel = 0;
		mrb_get_args(mrb, "i", &wheel);
		TheInput().setMouseZ(static_cast<int>(wheel));
		return mrb_int_value(mrb, wheel);
	}

	/** 이번 틱에 보이는 손가락 수 (UP 으로 보고되는 마지막 틱 포함). GDI 경로는 0. */
	mrb_value input_touch_count(mrb_state* mrb, mrb_value)
	{
#ifndef RS_WINDOWS
		return mrb_int_value(mrb, TheInput().getTouchCount());
#else
		return mrb_int_value(mrb, 0);
#endif
	}

	/** Input.touch(i) -> [id, x, y, :down | :press | :up] 또는 범위 밖이면 nil (i 는 0 부터) */
	mrb_value input_touch(mrb_state* mrb, mrb_value)
	{
		mrb_int index = 0;
		mrb_get_args(mrb, "i", &index);
#ifndef RS_WINDOWS
		const Input::Touch* t = TheInput().getTouch(static_cast<int>(index));
		if (t == nullptr)
		{
			return mrb_nil_value();
		}
		mrb_value tuple = mrb_ary_new(mrb);
		mrb_ary_push(mrb, tuple, mrb_int_value(mrb, static_cast<mrb_int>(t->id)));
		mrb_ary_push(mrb, tuple, mrb_float_value(mrb, t->x));
		mrb_ary_push(mrb, tuple, mrb_float_value(mrb, t->y));
		const char* phase = "press";
		if (t->map == Input::KB_DOWN) phase = "down";
		else if (t->map == Input::KB_UP) phase = "up";
		mrb_ary_push(mrb, tuple, mrb_symbol_value(mrb_intern_cstr(mrb, phase)));
		return tuple;
#else
		return mrb_nil_value();
#endif
	}
}

void MRuby_DefineInput(mrb_state* mrb)
{
	struct RClass* input = mrb_define_module(mrb, "Input");
	mrb_define_module_function(mrb, input, "key_down?", input_key_down, MRB_ARGS_REQ(1));
	mrb_define_module_function(mrb, input, "key_up?", input_key_up, MRB_ARGS_REQ(1));
	mrb_define_module_function(mrb, input, "key_press?", input_key_press, MRB_ARGS_REQ(1));
	mrb_define_module_function(mrb, input, "any_key_down?", input_any_key_down, MRB_ARGS_NONE());
	// RGSS 식 별명. 눌린 순간 / 눌린 채 / 뗀 순간
	mrb_define_module_function(mrb, input, "trigger?", input_key_down, MRB_ARGS_REQ(1));
	mrb_define_module_function(mrb, input, "press?", input_key_press, MRB_ARGS_REQ(1));
	mrb_define_module_function(mrb, input, "release?", input_key_up, MRB_ARGS_REQ(1));

	mrb_define_module_function(mrb, input, "mouse_x", input_mouse_x, MRB_ARGS_NONE());
	mrb_define_module_function(mrb, input, "mouse_y", input_mouse_y, MRB_ARGS_NONE());
	mrb_define_module_function(mrb, input, "mouse_down?", input_mouse_down, MRB_ARGS_REQ(1));
	mrb_define_module_function(mrb, input, "mouse_up?", input_mouse_up, MRB_ARGS_REQ(1));
	mrb_define_module_function(mrb, input, "mouse_press?", input_mouse_press, MRB_ARGS_REQ(1));
	mrb_define_module_function(mrb, input, "any_mouse_down?", input_any_mouse_down, MRB_ARGS_NONE());
	mrb_define_module_function(mrb, input, "mouse_z", input_mouse_z, MRB_ARGS_NONE());
	mrb_define_module_function(mrb, input, "mouse_z=", input_set_mouse_z, MRB_ARGS_REQ(1));

	mrb_define_module_function(mrb, input, "touch_count", input_touch_count, MRB_ARGS_NONE());
	mrb_define_module_function(mrb, input, "touch", input_touch, MRB_ARGS_REQ(1));
}

#endif // INITIAL2D_HAS_MRUBY
