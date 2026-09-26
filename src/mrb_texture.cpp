/**
 * @file mrb_texture.cpp
 * @brief TextureManager 모듈 (mruby). lua_texture.cpp 에 대응한다.
 *
 *   TextureManager.load(path, id) -> true/false
 *   TextureManager.remove(id)     -> true/false
 *   TextureManager.valid?(id)     -> true/false
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
}

void MRuby_DefineTextureManager(mrb_state* mrb)
{
	struct RClass* tm = mrb_define_module(mrb, "TextureManager");
	mrb_define_module_function(mrb, tm, "load", tm_load, MRB_ARGS_REQ(2));
	mrb_define_module_function(mrb, tm, "remove", tm_remove, MRB_ARGS_REQ(1));
	mrb_define_module_function(mrb, tm, "valid?", tm_valid, MRB_ARGS_REQ(1));
}

#endif // INITIAL2D_HAS_MRUBY
