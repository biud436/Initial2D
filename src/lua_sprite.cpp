#include <cstdint>
#include <cstring>
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
	{ "GetColor", LUA_METHOD_P1(GetSpriteColor) },
	{ "SetColor", LUA_METHOD_P1(SetSpriteColor) },
	{ "GetPivot", LUA_METHOD_P1(GetSpritePivot) },
	{ "SetPivot", LUA_METHOD_P1(SetSpritePivot) },
	{ "GetFlip", LUA_METHOD_P1(GetSpriteFlip) },
	{ "SetFlip", LUA_METHOD_P1(SetSpriteFlip) },
	{ "GetBlendMode", LUA_METHOD_P1(GetSpriteBlendMode) },
	{ "SetBlendMode", LUA_METHOD_P1(SetSpriteBlendMode) },
	{ "Dispose", LUA_METHOD_P1(DisposeSprite) },
};

namespace
{
	BYTE ClampByte(lua_Integer v)
	{
		if (v < 0) return 0;
		if (v > 255) return 255;
		return static_cast<BYTE>(v);
	}

	const char* const kBlendNames[] = { "normal", "add", "multiply" };
}

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

/**
 * local r, g, b = Sprite.GetColor(spriteId)
 */
LUA_CLASS(Get, Sprite, Color)
{
	Sprite* p = (Sprite*)(uintptr_t)lua_tonumber(pL, 1);
	if (!p)
	{
		lua_pushinteger(pL, 255);
		lua_pushinteger(pL, 255);
		lua_pushinteger(pL, 255);
		return 3;
	}
	const SpriteData& data = p->getSpriteData();
	lua_pushinteger(pL, data.red);
	lua_pushinteger(pL, data.green);
	lua_pushinteger(pL, data.blue);
	return 3;
}

/**
 * Sprite.SetColor(spriteId, r, g, b)
 * 색 입히기. 텍스처 색에 r/255, g/255, b/255 를 곱한다. 255, 255, 255 가 원래 색.
 */
LUA_CLASS(Set, Sprite, Color)
{
	Sprite* p = (Sprite*)(uintptr_t)lua_tonumber(pL, 1);
	const BYTE r = ClampByte(luaL_checkinteger(pL, 2));
	const BYTE g = ClampByte(luaL_checkinteger(pL, 3));
	const BYTE b = ClampByte(luaL_checkinteger(pL, 4));
	if (p)
	{
		p->setColor(r, g, b);
	}
	return 0;
}

/**
 * local px, py = Sprite.GetPivot(spriteId)
 */
LUA_CLASS(Get, Sprite, Pivot)
{
	Sprite* p = (Sprite*)(uintptr_t)lua_tonumber(pL, 1);
	if (!p)
	{
		lua_pushnumber(pL, 0);
		lua_pushnumber(pL, 0);
		return 2;
	}
	const SpriteData& data = p->getSpriteData();
	lua_pushnumber(pL, data.pivotX);
	lua_pushnumber(pL, data.pivotY);
	return 2;
}

/**
 * Sprite.SetPivot(spriteId, px, py)
 * 기준점 (칸 안의 비율, 0, 0 은 왼쪽 위, 0.5, 0.5 는 가운데). 위치는 이 점이 놓일 자리이고
 * 회전과 확대의 중심이다.
 */
LUA_CLASS(Set, Sprite, Pivot)
{
	Sprite* p = (Sprite*)(uintptr_t)lua_tonumber(pL, 1);
	const float px = static_cast<float>(luaL_checknumber(pL, 2));
	const float py = static_cast<float>(luaL_checknumber(pL, 3));
	if (p)
	{
		p->setPivot(px, py);
	}
	return 0;
}

/**
 * local flipX, flipY = Sprite.GetFlip(spriteId)
 */
LUA_CLASS(Get, Sprite, Flip)
{
	Sprite* p = (Sprite*)(uintptr_t)lua_tonumber(pL, 1);
	if (!p)
	{
		lua_pushboolean(pL, 0);
		lua_pushboolean(pL, 0);
		return 2;
	}
	const SpriteData& data = p->getSpriteData();
	lua_pushboolean(pL, data.flipX);
	lua_pushboolean(pL, data.flipY);
	return 2;
}

/**
 * Sprite.SetFlip(spriteId, flipX, flipY)
 * 칸 안에서 좌우(flipX), 상하(flipY)로 뒤집는다. 기준점의 자리는 그대로다.
 */
LUA_CLASS(Set, Sprite, Flip)
{
	Sprite* p = (Sprite*)(uintptr_t)lua_tonumber(pL, 1);
	const bool flipX = lua_toboolean(pL, 2) != 0;
	const bool flipY = lua_toboolean(pL, 3) != 0;
	if (p)
	{
		p->setFlip(flipX, flipY);
	}
	return 0;
}

/**
 * local mode = Sprite.GetBlendMode(spriteId)   -- "normal" | "add" | "multiply"
 */
LUA_CLASS(Get, Sprite, BlendMode)
{
	Sprite* p = (Sprite*)(uintptr_t)lua_tonumber(pL, 1);
	const int blend = p ? p->getSpriteData().blend : 0;
	lua_pushstring(pL, kBlendNames[(blend >= 0 && blend <= 2) ? blend : 0]);
	return 1;
}

/**
 * Sprite.SetBlendMode(spriteId, mode)
 * "normal"(알파 혼합), "add"(더하기, 빛), "multiply"(곱하기, 그림자와 색 필터). 다른 값은 오류.
 */
LUA_CLASS(Set, Sprite, BlendMode)
{
	Sprite* p = (Sprite*)(uintptr_t)lua_tonumber(pL, 1);
	const char* name = luaL_checkstring(pL, 2);
	int blend = -1;
	for (int i = 0; i < 3; i++)
	{
		if (std::strcmp(name, kBlendNames[i]) == 0)
		{
			blend = i;
		}
	}
	if (blend < 0)
	{
		return luaL_argerror(pL, 2, "blend mode must be \"normal\", \"add\" or \"multiply\"");
	}
	if (p)
	{
		p->setBlendMode(blend);
	}
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