#include "lua_input.h"
#include "App.h"
#include "Input.h"

extern lua_State* g_pLuaState;

LuaObjectToken luaj_Input[LUA_INPUT_MEMBERS] = {
	{ "IsKeyDown", Lua_IsKeyDown },
	{ "IsKeyUp", Lua_IsKeyUp },
	{ "IsKeyPress", Lua_IsKeyPress },
	{ "IsAnyKeyDown", Lua_IsAnyKeyDown },
	{ "GetMouseX", Lua_GetMouseX },
	{ "GetMouseY",  Lua_GetMouseY },
	{ "IsMouseDown",  Lua_IsMouseDown },
	{ "IsMouseUp",  Lua_IsMouseUp },
	{ "IsMousePress",  Lua_IsMousePress },
	{ "IsAnyMouseDown",  Lua_IsAnyMouseDown },
	{ "GetMouseZ",  Lua_GetMouseZ },
	{ "SetMouseZ",  Lua_SetMouseZ },
};

LUA_METHOD(CreateInputObject)
{
	lua_newtable(pL);

	for (int i = 0; i < LUA_INPUT_MEMBERS; i++)
	{
		lua_pushstring(pL, luaj_Input[i].name);
		lua_pushcfunction(pL, luaj_Input[i].func);
		lua_settable(pL, -3);
	}

	lua_setglobal(pL, "Input");

	return 0;
}

/**
 * Input.IsKeyDown(vKey);
 */
LUA_METHOD(IsKeyDown)
{
	int n = lua_gettop(pL);
	
	if (n < 1)
	{
		lua_pushboolean(pL, 0);
		return 1;
	}

	int vKey = luaL_checkinteger(pL, 1);

	bool isValid = App::GetInstance().GetInput().isKeyDown(vKey);

	lua_pushboolean(pL, isValid);

	return 1;
}

/**
* Input.IsKeyUp(vKey);
*/
LUA_METHOD(IsKeyUp)
{
	int n = lua_gettop(pL);

	if (n < 1)
	{
		lua_pushboolean(pL, 0);
		return 1;
	}

	int vKey = luaL_checkinteger(pL, 1);

	bool isValid = App::GetInstance().GetInput().isKeyUp(vKey);

	lua_pushboolean(pL, isValid);

	return 1;
}

/**
* Input.IsAnyKeyDown();
*/
LUA_METHOD(IsAnyKeyDown)
{
	int n = lua_gettop(pL);

	if (n < 1)
	{
		lua_pushboolean(pL, 0);
		return 1;
	}

	bool isValid = App::GetInstance().GetInput().isAnyKeyDown();

	lua_pushboolean(pL, isValid);

	return 1;
}

/**
* Input.IsKeyPress(vKey);
*/
LUA_METHOD(IsKeyPress)
{
	int n = lua_gettop(pL);

	if (n < 1)
	{
		lua_pushboolean(pL, 0);
		return 1;
	}

	int vKey = luaL_checkinteger(pL, 1);

	bool isValid = App::GetInstance().GetInput().isKeyPress(vKey);

	lua_pushboolean(pL, isValid);

	return 1;
}

/**
* Input.GetMouseX();
*/
LUA_METHOD(GetMouseX)
{
	int n = lua_gettop(pL);

	if (n < 1)
	{
		lua_pushnumber(pL, 0);
		return 1;
	}

	float value = App::GetInstance().GetInput().getMouseX();

	lua_pushnumber(pL, value);

	return 1;
}

/**
* Input.GetMouseY();
*/
LUA_METHOD(GetMouseY)
{
	int n = lua_gettop(pL);

	if (n < 1)
	{
		lua_pushnumber(pL, 0);
		return 1;
	}

	float value = App::GetInstance().GetInput().getMouseY();

	lua_pushnumber(pL, value);

	return 1;
}

/**
* Input.IsMouseDown(vKey);
*/
LUA_METHOD(IsMouseDown)
{
	int n = lua_gettop(pL);

	if (n < 1)
	{
		lua_pushboolean(pL, false);
		return 1;
	}

	int vKey = luaL_checkinteger(pL, 1);
	bool isValid = App::GetInstance().GetInput().isMouseDown(vKey);

	lua_pushboolean(pL, isValid);

	return 1;
}

/**
* Input.IsMouseUp(vKey);
*/
LUA_METHOD(IsMouseUp)
{
	int n = lua_gettop(pL);

	if (n < 1)
	{
		lua_pushboolean(pL, false);
		return 1;
	}

	int vKey = luaL_checkinteger(pL, 1);
	bool isValid = App::GetInstance().GetInput().isMouseUp(vKey);

	lua_pushboolean(pL, isValid);

	return 1;
}

/**
* Input.IsMousePress(vKey);
*/
LUA_METHOD(IsMousePress)
{
	int n = lua_gettop(pL);

	if (n < 1)
	{
		lua_pushboolean(pL, false);
		return 1;
	}

	int vKey = luaL_checkinteger(pL, 1);
	bool isValid = App::GetInstance().GetInput().isMousePress(vKey);

	lua_pushboolean(pL, isValid);

	return 1;
}

/**
* Input.IsAnyMouseDown();
*/
LUA_METHOD(IsAnyMouseDown)
{
	int n = lua_gettop(pL);

	if (n < 1)
	{
		lua_pushboolean(pL, false);
		return 1;
	}

	bool isValid = App::GetInstance().GetInput().isAnyMouseDown();

	lua_pushboolean(pL, isValid);

	return 1;
}


/**
* Input.GetMouseZ();
*/
LUA_METHOD(GetMouseZ)
{
	int n = lua_gettop(pL);

	if (n < 1) 
	{
		lua_pushinteger(pL, 0);
		return 1;
	}

	int value = App::GetInstance().GetInput().getMouseZ();
	lua_pushinteger(pL, value);

	return 1;
}

/**
* Input.SetMouseZ(wheelValue);
*/
LUA_METHOD(SetMouseZ)
{
	int n = lua_gettop(pL);

	if (n < 1)
	{
		return 0;
	}

	int value = luaL_checkinteger(pL, 1);

	App::GetInstance().GetInput().setMouseZ(value);

	return 0;
}
