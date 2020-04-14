#ifndef _LUA_TBL_H__
#define _LUA_TBL_H__

#include "lua_prot.h"

#define LUA_AUDIO_MEMBERS 12
#define LUA_INPUT_MEMBERS 12
#define LUA_TM_MEMBERS 3
#define LUA_SPRITE_MEMBERS 29

struct LuaObjectToken
{
	typedef int(*LuaFunc)(lua_State* pL);

	const char *name;
	LuaFunc func;

	LuaObjectToken(const char *s, LuaFunc f)
	{
		name = s;
		func = f;
	}

};

#define LUA_CLASS(ACCESS, Klass, METHOD_NAME) \
	int Lua_##ACCESS##Klass##METHOD_NAME(lua_State *pL)

#define LUA_METHOD(METHOD_NAME) \
	int Lua_##METHOD_NAME(lua_State *pL)

#define LUA_METHOD_P1(A) \
	Lua_##A

#define LUA_METHOD_P2(A, B, C) \
	#A #C

#endif