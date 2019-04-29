#ifndef _LUA_TBL_H__
#define _LUA_TBL_H__

#include "lua/lua.h"
#include "lua/lualib.h"
#include "lua/lauxlib.h"

int Lua_MessageBox(lua_State *g_pLuaSt);
int Lua_LoadScript(lua_State *pL);
int Lua_PreparaFont(lua_State *pL);
int Lua_DrawText(lua_State *pL);
int Lua_WindowWidth(lua_State *pL);
int Lua_WindowHeight(lua_State *pL);
int Lua_GetFrameCount(lua_State *pL);
int Lua_Init();
int Lua_Update(double elapsed);
int Lua_Render();
int Lua_Destory();

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