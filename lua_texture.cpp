#include "lua_texture.h"
#include "App.h"
#include "TextureManager.h"

extern lua_State* g_pLuaState;

LuaObjectToken luaj_TextureManager[LUA_TM_MEMBERS] = {
	{ "Load", Lua_LoadTexture },
	{ "Remove", Lua_RemoveTexture },
	{ "IsValid", Lua_IsValidTexture }
};

LUA_METHOD(CreateTextureManagerObject)
{
	lua_newtable(pL);

	for (int i = 0; i < LUA_TM_MEMBERS; i++)
	{
		lua_pushstring(pL, luaj_TextureManager[i].name);
		lua_pushcfunction(pL, luaj_TextureManager[i].func);
		lua_settable(pL, -3);
	}

	lua_setglobal(pL, "TextureManager");

	return 0;
}

/**
 * TextureManager.Load(filename, id);
 */
LUA_METHOD(LoadTexture)
{
	int n = lua_gettop(pL);
	
	if (n < 2)
	{
		lua_pushboolean(pL, false);
		return 1;
	}

	std::string filename = luaL_checkstring(pL, 1);
	std::string id = luaL_checkstring(pL, 2);

	bool isValid = TheTextureManager.Load(filename, id, 0);
	lua_pushboolean(pL, isValid);

	return 1;
}

/**
* TextureManager.Remove(id);
*/
LUA_METHOD(RemoveTexture)
{
	int n = lua_gettop(pL);

	if (n < 1)
	{
		lua_pushboolean(pL, false);
		return 1;
	}

	std::string id = luaL_checkstring(pL, 1);

	bool isValid = TheTextureManager.Remove(id);
	lua_pushboolean(pL, isValid);

	return 1;
}

/**
* TextureManager.IsValid(id);
*/
LUA_METHOD(IsValidTexture)
{
	int n = lua_gettop(pL);

	if (n < 1)
	{
		lua_pushboolean(pL, false);
		return 1;
	}

	std::string id = luaL_checkstring(pL, 1);

	bool isValid = TheTextureManager.valid(id);
	lua_pushboolean(pL, isValid);

	return 1;
}
