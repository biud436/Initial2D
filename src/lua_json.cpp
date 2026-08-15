/**
 * @file lua_json.cpp
 * @brief JSON 파일을 Lua 테이블로 읽는 바인딩 (1단계, docs/plans/01-engine-core.md).
 *
 * Lua: Json.Load(path) -> table | nil, 오류 메시지
 *
 * 변환 규칙:
 *  - 객체 -> 문자열 키 테이블, 배열 -> 1부터 시작하는 배열 테이블
 *  - 정수는 integer로, 실수는 number로, null은 nil로
 *    (배열 안의 null은 테이블 구멍이 되므로 #연산 대신 순회를 권장)
 */
#include "lua_json.h"
#include "platform/Utf8.h"

#include "json/json.h"

#include <fstream>

extern lua_State* g_pLuaState;

static void PushJsonValue(lua_State* pL, const Json::Value& value)
{
	// 깊게 중첩된 파일에서 Lua 스택이 넘치지 않게 한다
	luaL_checkstack(pL, 4, "Json.Load: too deeply nested");

	switch (value.type())
	{
	case Json::nullValue:
		lua_pushnil(pL);
		break;
	case Json::intValue:
		lua_pushinteger(pL, value.asInt());
		break;
	case Json::uintValue:
		lua_pushinteger(pL, static_cast<lua_Integer>(value.asUInt()));
		break;
	case Json::realValue:
		lua_pushnumber(pL, value.asDouble());
		break;
	case Json::stringValue:
		lua_pushstring(pL, value.asCString());
		break;
	case Json::booleanValue:
		lua_pushboolean(pL, value.asBool());
		break;
	case Json::arrayValue:
	{
		lua_createtable(pL, static_cast<int>(value.size()), 0);
		for (Json::ArrayIndex i = 0; i < value.size(); ++i)
		{
			PushJsonValue(pL, value[i]);
			lua_rawseti(pL, -2, static_cast<lua_Integer>(i) + 1);
		}
		break;
	}
	case Json::objectValue:
	{
		lua_createtable(pL, 0, static_cast<int>(value.size()));
		for (const std::string& key : value.getMemberNames())
		{
			lua_pushlstring(pL, key.c_str(), key.size());
			PushJsonValue(pL, value[key]);
			lua_settable(pL, -3);
		}
		break;
	}
	}
}

LUA_METHOD(JsonLoad)
{
	std::string path = luaL_checkstring(pL, 1);
	path = Initial2D::Platform::NormalizePath(path);

	std::ifstream file(path, std::ifstream::binary);
	if (!file.good())
	{
		lua_pushnil(pL);
		lua_pushstring(pL, ("Json.Load: cannot open " + path).c_str());
		return 2;
	}

	Json::Value root;
	try
	{
		file >> root;
	}
	catch (const std::exception& e)
	{
		lua_pushnil(pL);
		lua_pushstring(pL, ("Json.Load: parse error in " + path + ": " + e.what()).c_str());
		return 2;
	}

	PushJsonValue(pL, root);
	return 1;
}

LuaObjectToken luaj_Json[LUA_JSON_MEMBERS] = {
	{ "Load", Lua_JsonLoad },
};

LUA_METHOD(CreateJsonObject)
{
	lua_newtable(pL);

	for (int i = 0; i < LUA_JSON_MEMBERS; i++)
	{
		lua_pushstring(pL, luaj_Json[i].name);
		lua_pushcfunction(pL, luaj_Json[i].func);
		lua_settable(pL, -3);
	}

	lua_setglobal(pL, "Json");

	return 0;
}
