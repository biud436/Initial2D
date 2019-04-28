#include "lua_sprite.h"
#include "Sprite.h"

extern lua_State* g_pLuaState;

LuaObjectToken luaj_Sprite[LUA_SPRITE_MEMBERS] = {
	{ "Create", LUA_METHOD_P1(CreateSprite) },
	{ "Update", LUA_METHOD_P1(UpdateSprite) },
	{ "Draw", LUA_METHOD_P1(DrawSprite) },
	{ "GetPosition", LUA_METHOD_P1(GetSpritePosition) },
	{ "GetScale", LUA_METHOD_P1(GetSpriteScale) },
	{ "GetWidth", LUA_METHOD_P1(GetSpriteWidth) },
	{ "GetHeight", LUA_METHOD_P1(GetSpriteHeight) },
	{ "GetRadians", LUA_METHOD_P1(GetSpriteRadians) },
	{ "GetAngle", LUA_METHOD_P1(GetSpriteAngle) },
	{ "GetVisible", LUA_METHOD_P1(GetSpriteVisible) },
	{ "GetOpacity", LUA_METHOD_P1(GetSpriteOpacity) },
	{ "GetFrameDelay", LUA_METHOD_P1(GetSpriteFrameDelay) },
	{ "GetStartFrame", LUA_METHOD_P1(GetSpriteStartFrame) },
	{ "GetEndFrame", LUA_METHOD_P1(GetSpriteEndFrame) },
	{ "GetCurrentFrame", LUA_METHOD_P1(GetSpriteCurrentFrame) },
	{ "GetRect", LUA_METHOD_P1(GetSpriteRect) },
	{ "GetAnimComplete", LUA_METHOD_P1(GetSpriteAnimComplete) },
	{ "SetPosition", LUA_METHOD_P1(SetSpritePosition) },
	{ "SetScale", LUA_METHOD_P1(SetSpriteScale) },
	{ "SetAngle", LUA_METHOD_P1(SetSpriteAngle) },
	{ "SetRadians", LUA_METHOD_P1(SetSpriteRadians) },
	{ "SetVisible", LUA_METHOD_P1(SetSpriteVisible) },
	{ "SetOpacity", LUA_METHOD_P1(SetSpriteOpacity) },
	{ "SetFrameDelay", LUA_METHOD_P1(SetSpriteFrameDelay) },
	{ "SetFrames", LUA_METHOD_P1(SetSpriteFrames) },
	{ "SetCurrentFrame", LUA_METHOD_P1(SetSpriteCurrentFrame) },
	{ "SetRect", LUA_METHOD_P1(SetSpriteRect) },
	{ "SetLoop", LUA_METHOD_P1(SetSpriteLoop) },
	{ "SetAnimComplete", LUA_METHOD_P1(SetSpriteAnimComplete) },
};

LUA_METHOD(CreateSpriteImpl)
{
	lua_newtable(pL);

	for (int i = 0; i < LUA_SPRITE_MEMBERS; i++)
	{
		lua_pushstring(pL, luaj_Sprite[i].name);
		lua_pushcfunction(pL, luaj_Sprite[i].func);
		lua_settable(pL, -3);
	}

	lua_setglobal(pL, "Sprite");

	return 0;
}


/**
 * Sprite.Create(x, y, width, height, maxFrames, textureId)
 */
LUA_METHOD(CreateSprite)
{
	int n = lua_gettop(pL);
	if (n < 6)
	{
		lua_pushnumber(pL, 0);
		return 1;
	}

	float x = luaL_checknumber(pL, 1);
	float y = luaL_checknumber(pL, 2);
	int width = luaL_checkinteger(pL, 3);
	int height = luaL_checkinteger(pL, 4);
	int maxFrames = luaL_checkinteger(pL, 5);
	std::string textureId = luaL_checkstring(pL, 6);

	Sprite* pSprite = new Sprite();
	pSprite->initialize(x, y, width, height, maxFrames, textureId);

	DWORD d = (DWORD)pSprite;

	lua_pushnumber(pL, d);

	return 1;

}

/**
 * Sprite.Update(spriteId, elapsed)
 */
LUA_METHOD(UpdateSprite)
{
	int n = lua_gettop(pL);
	DWORD d = (DWORD)lua_tonumber(pL, 1);
	Sprite* p = (Sprite*)d;

	if (!p)
	{
		return 0;
	}

	float elapsed = luaL_checknumber(pL, 2);
	p->update(elapsed);

	return 0;

}

/**
* Sprite.Draw(spriteId)
*/
LUA_METHOD(DrawSprite)
{
	int n = lua_gettop(pL);
	DWORD d = (DWORD)lua_tonumber(pL, 1);
	Sprite* p = (Sprite*)d;

	if (!p)
	{
		return 0;
	}

	p->draw();

	return 0;

}

/**
* local x, y = Sprite.GetPosition(spriteId)
*/
LUA_CLASS(Get, Sprite, Position)
{
	int n = lua_gettop(pL);
	DWORD d = (DWORD)lua_tonumber(pL, 1);
	Sprite* p = (Sprite*)d;

	if (!p)
	{
		lua_pushnumber(pL, 0);
		lua_pushnumber(pL, 0);
		return 2;
	}

	lua_pushnumber(pL, p->getX());
	lua_pushnumber(pL, p->getY());

	return 2;
}

/**
* local scale = Sprite.GetScale(spriteId)
*/
LUA_CLASS(Get, Sprite, Scale)
{
	int n = lua_gettop(pL);
	DWORD d = (DWORD)lua_tonumber(pL, 1);
	Sprite* p = (Sprite*)d;

	if (!p)
	{
		lua_pushnumber(pL, 0);
		return 1;
	}

	lua_pushnumber(pL, p->getScale());

	return 1;
}

/**
* Sprite.GetWidth(spriteId)
*/
LUA_CLASS(Get, Sprite, Width)
{
	int n = lua_gettop(pL);
	DWORD d = (DWORD)lua_tonumber(pL, 1);
	Sprite* p = (Sprite*)d;

	if (!p)
	{
		lua_pushnumber(pL, 0);
		return 1;
	}

	lua_pushnumber(pL, p->getWidth());
	return 1;
}

LUA_CLASS(Get, Sprite, Height)
{
	int n = lua_gettop(pL);
	DWORD d = (DWORD)lua_tonumber(pL, 1);
	Sprite* p = (Sprite*)d;

	if (!p)
	{
		lua_pushnumber(pL, 0);
		return 1;
	}

	lua_pushnumber(pL, p->getHeight());
	return 1;
}

LUA_CLASS(Get, Sprite, Angle)
{
	int n = lua_gettop(pL);
	DWORD d = (DWORD)lua_tonumber(pL, 1);
	Sprite* p = (Sprite*)d;

	if (!p)
	{
		lua_pushnumber(pL, 0);
		return 1;
	}

	lua_pushnumber(pL, p->getAngle());
	return 1;
}

LUA_CLASS(Get, Sprite, Radians)
{
	int n = lua_gettop(pL);
	DWORD d = (DWORD)lua_tonumber(pL, 1);
	Sprite* p = (Sprite*)d;

	if (!p)
	{
		lua_pushnumber(pL, 0);
		return 1;
	}

	lua_pushnumber(pL, p->getRadians());
	return 1;
}

LUA_CLASS(Get, Sprite, Visible)
{
	int n = lua_gettop(pL);
	DWORD d = (DWORD)lua_tonumber(pL, 1);
	Sprite* p = (Sprite*)d;

	if (!p)
	{
		lua_pushboolean(pL, 0);
		return 1;
	}

	lua_pushboolean(pL, p->getVisible());
	return 1;
}

LUA_CLASS(Get, Sprite, Opacity)
{
	int n = lua_gettop(pL);
	DWORD d = (DWORD)lua_tonumber(pL, 1);
	Sprite* p = (Sprite*)d;

	if (!p)
	{
		lua_pushnumber(pL, 255);
		return 1;
	}

	lua_pushnumber(pL, p->getOpacity());
	return 1;
}

LUA_CLASS(Get, Sprite, FrameDelay)
{
	int n = lua_gettop(pL);
	DWORD d = (DWORD)lua_tonumber(pL, 1);
	Sprite* p = (Sprite*)d;

	if (!p)
	{
		lua_pushnumber(pL, 0);
		return 1;
	}

	lua_pushnumber(pL, p->getFrameDelay());
	return 1;
}

LUA_CLASS(Get, Sprite, StartFrame)
{
	int n = lua_gettop(pL);
	DWORD d = (DWORD)lua_tonumber(pL, 1);
	Sprite* p = (Sprite*)d;

	if (!p)
	{
		lua_pushnumber(pL, 0);
		return 1;
	}

	lua_pushnumber(pL, p->getStartFrame());
	return 1;
}

LUA_CLASS(Get, Sprite, EndFrame)
{
	int n = lua_gettop(pL);
	DWORD d = (DWORD)lua_tonumber(pL, 1);
	Sprite* p = (Sprite*)d;

	if (!p)
	{
		lua_pushnumber(pL, 0);
		return 1;
	}

	lua_pushnumber(pL, p->getEndFrame());
	return 1;
}

LUA_CLASS(Get, Sprite, CurrentFrame)
{
	int n = lua_gettop(pL);
	DWORD d = (DWORD)lua_tonumber(pL, 1);
	Sprite* p = (Sprite*)d;

	if (!p)
	{
		lua_pushnumber(pL, 0);
		return 1;
	}

	lua_pushnumber(pL, p->getCurrentFrame());
	return 1;
}

LUA_CLASS(Get, Sprite, Rect)
{
	int n = lua_gettop(pL);

	// Sprite Pointer (1) (-1)
	DWORD d = (DWORD)lua_tonumber(pL, 1);
	Sprite* p = (Sprite*)d;

	if (!p)
	{
		lua_pushnumber(pL, 0);
		return 1;
	}

	RECT rect = p->getRect();

	// My Table (2) (-1)
	// Sprite Pointer (1) (-2)
	lua_createtable(pL, 1, 0);

	// rect.left (-1)
	// x (-2)
	// My Table (2) (-3)
	// Sprite Pointer (1) (-4)

	lua_pushstring(pL, "x");
	lua_pushnumber(pL, rect.left);
	lua_settable(pL, -3);

	lua_pushstring(pL, "y");
	lua_pushnumber(pL, rect.top);
	lua_settable(pL, -3);

	lua_pushstring(pL, "width");
	lua_pushnumber(pL, rect.right);
	lua_settable(pL, -3);

	lua_pushstring(pL, "height");
	lua_pushnumber(pL, rect.bottom);
	lua_settable(pL, -2);

	return 1;
}

LUA_CLASS(Get, Sprite, AnimComplete)
{
	int n = lua_gettop(pL);
	DWORD d = (DWORD)lua_tonumber(pL, 1);
	Sprite* p = (Sprite*)d;

	if (!p)
	{
		lua_pushboolean(pL, 0);
		return 1;
	}

	lua_pushboolean(pL, p->getAnimComplete());
	return 1;
}

LUA_CLASS(Set, Sprite, Position)
{
	int n = lua_gettop(pL);
	DWORD d = (DWORD)lua_tonumber(pL, 1);
	Sprite* p = (Sprite*)d;

	float x = luaL_checknumber(pL, 2);
	float y = luaL_checknumber(pL, 3);

	if (!p)
	{
		return 0;
	}

	p->setX(x);
	p->setY(y);

	return 0;

}

LUA_CLASS(Set, Sprite, Scale)
{
	int n = lua_gettop(pL);
	DWORD d = (DWORD)lua_tonumber(pL, 1);
	Sprite* p = (Sprite*)d;

	float scale = luaL_checknumber(pL, 2);

	if (!p)
	{
		return 0;
	}

	p->setScale(scale);

	return 0;
}

LUA_CLASS(Set, Sprite, Angle)
{
	int n = lua_gettop(pL);
	DWORD d = (DWORD)lua_tonumber(pL, 1);
	Sprite* p = (Sprite*)d;

	float angle = luaL_checknumber(pL, 2);

	if (!p)
	{
		return 0;
	}

	p->setAngle(angle);

	return 0;
}

LUA_CLASS(Set, Sprite, Radians)
{
	int n = lua_gettop(pL);
	DWORD d = (DWORD)lua_tonumber(pL, 1);
	Sprite* p = (Sprite*)d;

	float radians = luaL_checknumber(pL, 2);

	if (!p)
	{
		return 0;
	}

	p->setRadians(radians);

	return 0;
}

LUA_CLASS(Set, Sprite, Visible)
{
	int n = lua_gettop(pL);
	DWORD d = (DWORD)lua_tonumber(pL, 1);
	Sprite* p = (Sprite*)d;

	int b = lua_toboolean(pL, 2);

	if (!p)
	{
		return 0;
	}

	p->setVisible(b == 1);

	return 0;
}

LUA_CLASS(Set, Sprite, Opacity)
{
	int n = lua_gettop(pL);
	DWORD d = (DWORD)lua_tonumber(pL, 1);
	Sprite* p = (Sprite*)d;

	int opacity = luaL_checkinteger(pL, 2);

	if (!p)
	{
		return 0;
	}

	p->setOpacity(opacity);

	return 0;
}

LUA_CLASS(Set, Sprite, FrameDelay)
{
	int n = lua_gettop(pL);
	DWORD d = (DWORD)lua_tonumber(pL, 1);
	Sprite* p = (Sprite*)d;

	double value = luaL_checknumber(pL, 2);

	if (!p)
	{
		return 0;
	}

	p->setFrameDelay(value);

	return 0;
}

LUA_CLASS(Set, Sprite, Frames)
{
	int n = lua_gettop(pL);
	DWORD d = (DWORD)lua_tonumber(pL, 1);
	Sprite* p = (Sprite*)d;

	int startFrame = luaL_checkinteger(pL, 2);
	int endFrame = luaL_checkinteger(pL, 3);

	if (!p)
	{
		return 0;
	}

	p->setFrames(startFrame, endFrame);

	return 0;
}

LUA_CLASS(Set, Sprite, CurrentFrame)
{
	int n = lua_gettop(pL);
	DWORD d = (DWORD)lua_tonumber(pL, 1);
	Sprite* p = (Sprite*)d;

	int currentFrame = luaL_checkinteger(pL, 2);

	if (!p)
	{
		return 0;
	}

	p->setCurrentFrame(currentFrame);

	return 0;
}

LUA_CLASS(Set, Sprite, Rect)
{
	int x = 0, y = 0, width = 1, height = 1;
	int n = lua_gettop(pL);
	DWORD d = (DWORD)lua_tonumber(pL, 1);
	Sprite* p = (Sprite*)d;

	// STACK TOP
	// 2 (-1) Rect Table
	// 1 (-2) Sprite Pointer
	// STACK BOTTOM

	if (!p || !lua_istable(pL, -1))
	{
		return 0;
	}

	// 3 (-1) x
	// 2 (-2) Rect Table
	// 1 (-3) Sprite Pointer

	lua_pushstring(pL, "x");
	lua_gettable(pL, 2);
	x = luaL_checkinteger(pL, -1);
	lua_pop(pL, 1);

	// 3 (-1) y
	// 2 (-2) Rect Table
	// 1 (-3) Sprite Pointer

	lua_pushstring(pL, "y");
	lua_gettable(pL, 2);
	y = luaL_checkinteger(pL, -1);
	lua_pop(pL, 1);

	// 3 (-1) width
	// 2 (-2) Rect Table
	// 1 (-3) Sprite Pointer

	lua_pushstring(pL, "width");
	lua_gettable(pL, 2);
	y = luaL_checkinteger(pL, -1);
	lua_pop(pL, 1);

	// 3 (-1) height
	// 2 (-2) Rect Table
	// 1 (-3) Sprite Pointer

	lua_pushstring(pL, "height");
	lua_gettable(pL, 2);
	y = luaL_checkinteger(pL, -1);
	lua_pop(pL, 1);

	p->setRect(x, y, width, height);

	lua_pop(pL, 1);
	lua_pop(pL, 1);

	return 0;
}

LUA_CLASS(Set, Sprite, Loop)
{
	int n = lua_gettop(pL);
	DWORD d = (DWORD)lua_tonumber(pL, 1);
	Sprite* p = (Sprite*)d;

	int b = lua_toboolean(pL, 2);

	if (!p)
	{
		return 0;
	}

	p->setLoop(b == 1);

	return 0;
}

LUA_CLASS(Set, Sprite, AnimComplete)
{
	int n = lua_gettop(pL);
	DWORD d = (DWORD)lua_tonumber(pL, 1);
	Sprite* p = (Sprite*)d;

	int b = lua_toboolean(pL, 2);

	if (!p)
	{
		return 0;
	}

	p->setAnimComplete(b == 1);

	return 0;
}