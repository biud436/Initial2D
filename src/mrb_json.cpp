/**
 * @file mrb_json.cpp
 * @brief Json 모듈 (mruby). lua_json.cpp 에 대응한다.
 *
 *   Json.load(path)  -> Hash | Array | 값. 파일이 없거나 깨졌으면 RuntimeError
 *   Json.parse(text) -> 문자열에서 바로
 *
 * 변환 규칙: 객체 -> 문자열 키 Hash, 배열 -> Array, 정수 -> Integer,
 * 실수 -> Float, null -> nil. (Lua 는 실패를 nil + 메시지로 알리지만
 * Ruby 는 예외가 관례라 raise 한다. rescue 로 잡으면 된다.)
 */
#include "Constants.h"

#ifdef INITIAL2D_HAS_MRUBY

#include "mrb_prot.h"
#include "platform/Utf8.h"

#include "json/json.h"

#include <fstream>
#include <sstream>
#include <string>

namespace
{
	mrb_value ToRuby(mrb_state* mrb, const Json::Value& value)
	{
		switch (value.type())
		{
		case Json::nullValue:
			return mrb_nil_value();
		case Json::intValue:
			return mrb_int_value(mrb, static_cast<mrb_int>(value.asInt64()));
		case Json::uintValue:
			return mrb_int_value(mrb, static_cast<mrb_int>(value.asUInt64()));
		case Json::realValue:
			return mrb_float_value(mrb, value.asDouble());
		case Json::stringValue:
			return mrb_str_new_cstr(mrb, value.asCString());
		case Json::booleanValue:
			return mrb_bool_value(value.asBool());
		case Json::arrayValue:
		{
			mrb_value array = mrb_ary_new_capa(mrb, static_cast<mrb_int>(value.size()));
			for (Json::ArrayIndex i = 0; i < value.size(); ++i)
			{
				const int arena = mrb_gc_arena_save(mrb);
				mrb_ary_push(mrb, array, ToRuby(mrb, value[i]));
				mrb_gc_arena_restore(mrb, arena);
			}
			return array;
		}
		case Json::objectValue:
		{
			mrb_value hash = mrb_hash_new_capa(mrb, static_cast<mrb_int>(value.size()));
			for (const std::string& key : value.getMemberNames())
			{
				const int arena = mrb_gc_arena_save(mrb);
				mrb_hash_set(mrb, hash, mrb_str_new(mrb, key.c_str(), static_cast<mrb_int>(key.size())),
					ToRuby(mrb, value[key]));
				mrb_gc_arena_restore(mrb, arena);
			}
			return hash;
		}
		}
		return mrb_nil_value();
	}

	mrb_value json_load(mrb_state* mrb, mrb_value)
	{
		const char* raw = nullptr;
		mrb_get_args(mrb, "z", &raw);
		const std::string path = Initial2D::Platform::NormalizePath(raw);

		std::ifstream file(path, std::ifstream::binary);
		if (!file.good())
		{
			mrb_raisef(mrb, E_RUNTIME_ERROR, "Json.load: cannot open %s", path.c_str());
		}

		Json::Value root;
		try
		{
			file >> root;
		}
		catch (const std::exception& e)
		{
			const std::string message = "Json.load: parse error in " + path + ": " + e.what();
			mrb_raise(mrb, E_RUNTIME_ERROR, message.c_str());
		}
		return ToRuby(mrb, root);
	}

	mrb_value json_parse(mrb_state* mrb, mrb_value)
	{
		mrb_value text;
		mrb_get_args(mrb, "S", &text);

		std::istringstream stream(MRuby_ToStdString(mrb, text));
		Json::Value root;
		try
		{
			stream >> root;
		}
		catch (const std::exception& e)
		{
			const std::string message = std::string("Json.parse: parse error: ") + e.what();
			mrb_raise(mrb, E_RUNTIME_ERROR, message.c_str());
		}
		return ToRuby(mrb, root);
	}
}

void MRuby_DefineJson(mrb_state* mrb)
{
	struct RClass* json = mrb_define_module(mrb, "Json");
	mrb_define_module_function(mrb, json, "load", json_load, MRB_ARGS_REQ(1));
	mrb_define_module_function(mrb, json, "parse", json_parse, MRB_ARGS_REQ(1));
}

#endif // INITIAL2D_HAS_MRUBY
