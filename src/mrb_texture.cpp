/**
 * @file mrb_texture.cpp
 * @brief TextureManager 모듈 (mruby). lua_texture.cpp 에 대응한다.
 *
 *   TextureManager.load(path, id) -> true/false
 *   TextureManager.remove(id)     -> true/false
 *   TextureManager.valid?(id)     -> true/false
 *   TextureManager.size(id)       -> [width, height] 또는 nil
 *   TextureManager.create_target(id, width, height) -> true/false
 */
#include "Constants.h"

#ifdef INITIAL2D_HAS_MRUBY

#include "mrb_prot.h"
#include "App.h"
#include "TextureManager.h"

namespace
{
	mrb_value tm_load(mrb_state* mrb, mrb_value)
	{
		const char* path = nullptr;
		const char* id = nullptr;
		mrb_get_args(mrb, "zz", &path, &id);
		return mrb_bool_value(TheTextureManager.Load(path, id, 0));
	}

	mrb_value tm_remove(mrb_state* mrb, mrb_value)
	{
		const char* id = nullptr;
		mrb_get_args(mrb, "z", &id);
		return mrb_bool_value(TheTextureManager.Remove(id));
	}

	mrb_value tm_valid(mrb_state* mrb, mrb_value)
	{
		const char* id = nullptr;
		mrb_get_args(mrb, "z", &id);
		return mrb_bool_value(TheTextureManager.valid(id));
	}

	/** TextureManager.size(id) -> [width, height]. 없는 id 면 nil */
	mrb_value tm_size(mrb_state* mrb, mrb_value)
	{
		const char* id = nullptr;
		mrb_get_args(mrb, "z", &id);
		TextureGroup::iterator iter = TheTextureManager.m_textureMap.find(id);
		if (iter == TheTextureManager.m_textureMap.end() || iter->second == nullptr)
		{
			return mrb_nil_value();
		}
		mrb_value values[2] = { mrb_int_value(mrb, iter->second->width), mrb_int_value(mrb, iter->second->height) };
		return mrb_ary_new_from_values(mrb, 2, values);
	}

	/** TextureManager.create_target(id, width, height) -> true/false. 그려 넣을 수 있는 빈 텍스처 */
	mrb_value tm_create_target(mrb_state* mrb, mrb_value)
	{
		const char* id = nullptr;
		mrb_int width = 0, height = 0;
		mrb_get_args(mrb, "zii", &id, &width, &height);
#ifndef RS_WINDOWS
		return mrb_bool_value(TheTextureManager.CreateTarget(id, static_cast<int>(width), static_cast<int>(height)));
#else
		return mrb_false_value(); // GDI 판에는 렌더 타깃이 없다
#endif
	}
}

void MRuby_DefineTextureManager(mrb_state* mrb)
{
	struct RClass* tm = mrb_define_module(mrb, "TextureManager");
	mrb_define_module_function(mrb, tm, "load", MRUBY_GUARD(tm_load), MRB_ARGS_REQ(2));
	mrb_define_module_function(mrb, tm, "remove", MRUBY_GUARD(tm_remove), MRB_ARGS_REQ(1));
	mrb_define_module_function(mrb, tm, "valid?", MRUBY_GUARD(tm_valid), MRB_ARGS_REQ(1));
	mrb_define_module_function(mrb, tm, "size", MRUBY_GUARD(tm_size), MRB_ARGS_REQ(1));
	mrb_define_module_function(mrb, tm, "create_target", MRUBY_GUARD(tm_create_target), MRB_ARGS_REQ(3));
}

#endif // INITIAL2D_HAS_MRUBY
