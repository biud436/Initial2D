#include <cstdint>
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
	{ "SetSheetGrid", LUA_METHOD_P1(SetSpriteSheetGrid) },
	{ "Dispose", LUA_METHOD_P1(DisposeSprite) },
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

	uintptr_t d = (uintptr_t)pSprite;

	lua_pushnumber(pL, d);

	return 1;

}

/**
 * Sprite.Update(spriteId, elapsed)
 */
LUA_METHOD(UpdateSprite)
{
	int n = lua_gettop(pL);
	uintptr_t d = (uintptr_t)lua_tonumber(pL, 1);
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
	uintptr_t d = (uintptr_t)lua_tonumber(pL, 1);
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
	uintptr_t d = (uintptr_t)lua_tonumber(pL, 1);
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
	uintptr_t d = (uintptr_t)lua_tonumber(pL, 1);
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
	uintptr_t d = (uintptr_t)lua_tonumber(pL, 1);
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
	uintptr_t d = (uintptr_t)lua_tonumber(pL, 1);
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
	uintptr_t d = (uintptr_t)lua_tonumber(pL, 1);
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
	uintptr_t d = (uintptr_t)lua_tonumber(pL, 1);
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
	uintptr_t d = (uintptr_t)lua_tonumber(pL, 1);
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
	uintptr_t d = (uintptr_t)lua_tonumber(pL, 1);
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
	uintptr_t d = (uintptr_t)lua_tonumber(pL, 1);
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
	uintptr_t d = (uintptr_t)lua_tonumber(pL, 1);
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
	uintptr_t d = (uintptr_t)lua_tonumber(pL, 1);
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
	uintptr_t d = (uintptr_t)lua_tonumber(pL, 1);
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
	uintptr_t d = (uintptr_t)lua_tonumber(pL, 1);
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
	// 테이블은 키와 값 아래(-3)에 있다. 기존 -2는 키 문자열을 인덱싱해
	// 호출 즉시 런타임 오류를 내던 버그.
	lua_settable(pL, -3);

	return 1;
}

LUA_CLASS(Get, Sprite, AnimComplete)
{
	int n = lua_gettop(pL);
	uintptr_t d = (uintptr_t)lua_tonumber(pL, 1);
	Sprite* p = (Sprite*)d;

	if (!p)
	{
		lua_pushboolean(pL, 0);
		return 1;
	}

	lua_pushboolean(pL, p->getAnimComplete());
	return 1;
}

/**
 * Sprite.SetSheetGrid(spriteId, cols, rows)
 * 시트 분할을 설정한다 (기본 4x4, R2K3 CharSet은 3x4).
 */
LUA_CLASS(Set, Sprite, SheetGrid)
{
	uintptr_t d = (uintptr_t)lua_tonumber(pL, 1);
	Sprite* p = (Sprite*)d;

	if (!p)
	{
		return 0;
	}

	int cols = luaL_checkinteger(pL, 2);
	int rows = luaL_checkinteger(pL, 3);
	p->setSheetGrid(cols, rows);

	return 0;
}

/**
 * Sprite.Dispose(spriteId)
 * 스프라이트를 해제한다. 해제 후 같은 핸들 사용은 금지.
 * (텍스처는 TextureManager가 소유하므로 함께 해제되지 않는다)
 */
LUA_METHOD(DisposeSprite)
{
	uintptr_t d = (uintptr_t)lua_tonumber(pL, 1);
	Sprite* p = (Sprite*)d;

	if (!p)
	{
		return 0;
	}

	delete p;
	return 0;
}

LUA_CLASS(Set, Sprite, Position)
{
	int n = lua_gettop(pL);
	uintptr_t d = (uintptr_t)lua_tonumber(pL, 1);
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
	uintptr_t d = (uintptr_t)lua_tonumber(pL, 1);
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
	uintptr_t d = (uintptr_t)lua_tonumber(pL, 1);
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
	uintptr_t d = (uintptr_t)lua_tonumber(pL, 1);
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
	uintptr_t d = (uintptr_t)lua_tonumber(pL, 1);
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
	uintptr_t d = (uintptr_t)lua_tonumber(pL, 1);
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
	uintptr_t d = (uintptr_t)lua_tonumber(pL, 1);
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
	uintptr_t d = (uintptr_t)lua_tonumber(pL, 1);
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
	uintptr_t d = (uintptr_t)lua_tonumber(pL, 1);
	Sprite* p = (Sprite*)d;

	int currentFrame = luaL_checkinteger(pL, 2);

	if (!p)
	{
		return 0;
	}

	p->setCurrentFrame(currentFrame);

	return 0;
}

/**
 * Sprite.SetRect(spriteId, x, y, width, height)
 * Sprite.SetRect(spriteId, { x =, y =, width =, height = })
 *
 * 텍스처에서 잘라 그릴 소스 사각형을 직접 지정한다. 시트 격자(SetSheetGrid +
 * SetCurrentFrame)로 표현할 수 없는 위치 — 대화창 스킨의 나인 슬라이스 조각처럼
 * 폭의 배수가 아닌 좌표 — 를 그릴 때 쓴다.
 *
 * 예전 구현은 테이블 형태만 받으면서(그래서 scripts/image.lua의 네 인자 호출은
 * 조용히 무시됐다) width와 height를 y 변수에 덮어써 읽고 있었다. 두 형태를 모두
 * 받고, 오른쪽·아래 좌표는 무인자 setRect()와 같은 규칙(left + width)으로 채운다.
 */
LUA_CLASS(Set, Sprite, Rect)
{
	uintptr_t d = (uintptr_t)lua_tonumber(pL, 1);
	Sprite* p = (Sprite*)d;

	if (!p)
	{
		return 0;
	}

	int x = 0, y = 0, width = 0, height = 0;

	if (lua_istable(pL, 2))
	{
		const char* keys[4] = { "x", "y", "width", "height" };
		int* fields[4] = { &x, &y, &width, &height };
		for (int i = 0; i < 4; i++)
		{
			lua_pushstring(pL, keys[i]);
			lua_gettable(pL, 2);
			*fields[i] = static_cast<int>(luaL_optinteger(pL, -1, 0));
			lua_pop(pL, 1);
		}
	}
	else
	{
		x = static_cast<int>(luaL_optinteger(pL, 2, 0));
		y = static_cast<int>(luaL_optinteger(pL, 3, 0));
		width = static_cast<int>(luaL_optinteger(pL, 4, 0));
		height = static_cast<int>(luaL_optinteger(pL, 5, 0));
	}

	p->setRect(x, y, x + width, y + height);

	return 0;
}

LUA_CLASS(Set, Sprite, Loop)
{
	int n = lua_gettop(pL);
	uintptr_t d = (uintptr_t)lua_tonumber(pL, 1);
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
	uintptr_t d = (uintptr_t)lua_tonumber(pL, 1);
	Sprite* p = (Sprite*)d;

	int b = lua_toboolean(pL, 2);

	if (!p)
	{
		return 0;
	}

	p->setAnimComplete(b == 1);

	return 0;
}