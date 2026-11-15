#include "lua_texture.h"
#include "App.h"
#include "TextureManager.h"

extern lua_State* g_pLuaState;

LuaObjectToken luaj_TextureManager[LUA_TM_MEMBERS] = {
	{ "Load", Lua_LoadTexture },
	{ "Remove", Lua_RemoveTexture },
	{ "IsValid", Lua_IsValidTexture },
	{ "GetSize", Lua_GetTextureSize },
	{ "CreateTarget", Lua_CreateTargetTexture }
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

/**
 * local width, height = TextureManager.GetSize(id)
 * 등록한 텍스처의 크기 (픽셀). 없는 id 면 nil.
 */
LUA_METHOD(GetTextureSize)
{
	std::string id = luaL_checkstring(pL, 1);

	TextureGroup::iterator iter = TheTextureManager.m_textureMap.find(id);
	if (iter == TheTextureManager.m_textureMap.end() || iter->second == nullptr)
	{
		lua_pushnil(pL);
		return 1;
	}

	lua_pushinteger(pL, iter->second->width);
	lua_pushinteger(pL, iter->second->height);
	return 2;
}

/**
 * local ok = TextureManager.CreateTarget(id, width, height)
 * 그려 넣을 수 있는 빈(투명) 텍스처를 만든다. 같은 id 가 있으면 바꾼다. SetRenderTarget(id) 로 그 안에
 * 그리고, 스프라이트가 이 id 로 그 결과를 그린다.
 */
LUA_METHOD(CreateTargetTexture)
{
	std::string id = luaL_checkstring(pL, 1);
	const int width = static_cast<int>(luaL_checkinteger(pL, 2));
	const int height = static_cast<int>(luaL_checkinteger(pL, 3));

#ifndef RS_WINDOWS
	lua_pushboolean(pL, TheTextureManager.CreateTarget(id, width, height));
#else
	(void)width; (void)height;
	lua_pushboolean(pL, false); // GDI 판에는 렌더 타깃이 없다
#endif
	return 1;
}
