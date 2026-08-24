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
	{ "GetTouchCount",  Lua_GetTouchCount },
	{ "GetTouch",  Lua_GetTouch },
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

/**
* Input.GetTouchCount();
* 이번 틱에 보이는 손가락 수 (UP으로 보고되는 마지막 틱 포함).
* Windows GDI 경로에는 터치가 없으므로 항상 0이다.
*/
LUA_METHOD(GetTouchCount)
{
#ifndef RS_WINDOWS
	lua_pushinteger(pL, App::GetInstance().GetInput().getTouchCount());
#else
	lua_pushinteger(pL, 0);
#endif
	return 1;
}

/**
* Input.GetTouch(i);  -- 1부터 GetTouchCount()까지
* id, x, y, phase 네 값을 돌려준다. phase는 "down", "press", "up".
* 범위 밖이면 nil 하나.
*/
LUA_METHOD(GetTouch)
{
#ifndef RS_WINDOWS
	int n = lua_gettop(pL);
	if (n < 1)
	{
		lua_pushnil(pL);
		return 1;
	}

	int index = static_cast<int>(luaL_checkinteger(pL, 1));
	const Input::Touch* t = App::GetInstance().GetInput().getTouch(index - 1);
	if (t == nullptr)
	{
		lua_pushnil(pL);
		return 1;
	}

	lua_pushinteger(pL, static_cast<lua_Integer>(t->id));
	lua_pushnumber(pL, t->x);
	lua_pushnumber(pL, t->y);
	switch (t->map)
	{
	case Input::KB_DOWN: lua_pushstring(pL, "down"); break;
	case Input::KB_UP: lua_pushstring(pL, "up"); break;
	default: lua_pushstring(pL, "press"); break;
	}
	return 4;
#else
	lua_pushnil(pL);
	return 1;
#endif
}
