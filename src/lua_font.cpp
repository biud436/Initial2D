#include "lua_font.h"
#include "ExperimentalFont.h"
#include <clocale>
#include <codecvt>
#include <string>
#include <exception>

extern lua_State* g_pLuaState;

LuaObjectToken luaj_FontEx[LUA_FONTEX_MEMBERS] = {
	{ "Create", Lua_CreateFontEx },
	{ "Update", LUA_METHOD_P1(UpdateFontEx) },
	{ "Draw", LUA_METHOD_P1(DrawFontEx) },
	{ "Dispose", LUA_METHOD_P1(ReleaseFontEx) },
	{ "SetText", LUA_METHOD_P1(SetFontExText) },
	{ "SetPosition", LUA_METHOD_P1(SetFontExPosition) },
	{ "SetTextColor", LUA_METHOD_P1(SetFontExTextColor) },
	{ "SetOpacity", LUA_METHOD_P1(SetFontExOpacity) },
	{ "GetTextWidth", LUA_METHOD_P1(GetFontExTextWidth) },
	{ "SetAngle", LUA_METHOD_P1(SetFontExAngle) },
};

int Lua_CreateFontExImpl(lua_State* pL)
{
	try {

		lua_newtable(pL);

		for (int i = 0; i < LUA_FONTEX_MEMBERS; i++)
		{
			lua_pushstring(pL, luaj_FontEx[i].name);
			lua_pushcfunction(pL, luaj_FontEx[i].func);
			lua_settable(pL, -3);
		}

		lua_setglobal(pL, "FontEx");

	} catch (std::exception &e) {
		luaL_error(pL, e.what());
	}
	
	return 0;
}


/*!
 *
 * @param pL
 * 
 * @code{.lua}
 * local myFont = FontEx.Create(FontFace, FontSize)
 * @endcode
 */
static int Lua_CreateFontEx(lua_State *pL)
{
	try {
		int n = lua_gettop(pL);
		if (n < 4)
		{
			lua_pushnumber(pL, 0);
			return 1;
		}

		std::string preFontFace = luaL_checkstring(pL, 1);
		int fontSize = luaL_checknumber(pL, 2);

		std::wstring_convert<std::codecvt_utf8<wchar_t>> converter;
		std::wstring sFontFace = converter.from_bytes(preFontFace);

		int width = luaL_checknumber(pL, 3);
		int height = luaL_checknumber(pL, 4);

		AntiAliasingFont* pFont = new AntiAliasingFont(sFontFace, fontSize, width, height);

		DWORD d = (DWORD)pFont;

		lua_pushnumber(pL, d);

		return 1;

	}  catch (std::exception &e) {
		luaL_error(pL, e.what());
	}
}

/*!
*
* @param pL
*
* @code{.lua}
* FontEx.Update(fontId)
* @endcode
*/
LUA_METHOD(UpdateFontEx)
{
	int n = lua_gettop(pL);
	DWORD d = (DWORD)lua_tonumber(pL, 1);

	AntiAliasingFont* p = (AntiAliasingFont*)d;

	if (!p)
	{
		return 0;
	}

	float elapsed = luaL_checknumber(pL, 2);
	p->update(elapsed);

	return 0;
}


/*!
*
* @param pL
*
* @code{.lua}
* FontEx.Draw(fontId)
* @endcode
*/
LUA_METHOD(DrawFontEx)
{
	int n = lua_gettop(pL);
	DWORD d = (DWORD)lua_tonumber(pL, 1);

	AntiAliasingFont* p = (AntiAliasingFont*)d;

	if (!p)
	{
		return 0;
	}

	p->draw();

	return 0;
}


// FontEx.Dispose(fontId)
LUA_METHOD(ReleaseFontEx)
{
	int n = lua_gettop(pL);
	DWORD d = (DWORD)lua_tonumber(pL, 1);

	AntiAliasingFont* p = (AntiAliasingFont*)d;

	if (!p)
	{
		return 0;
	}

	delete p;
	p = nullptr;

	return 0;
}

// FontEx.SetText(fontId, text)
LUA_CLASS(Set, FontEx, Text)
{
	int n = lua_gettop(pL);
	DWORD d = (DWORD)lua_tonumber(pL, 1);

	AntiAliasingFont* p = (AntiAliasingFont*)d;

	if (!p)
	{
		return 0;
	}

	std::string asciiText = luaL_checkstring(pL, 2);
	std::wstring_convert<std::codecvt_utf8<wchar_t>> converter;
	std::wstring sText = converter.from_bytes(asciiText);

	p->setText(sText);

	return 0;
}

// FontEx.SetText(fontId, text)
LUA_CLASS(Set, FontEx, Position)
{
	int n = lua_gettop(pL);
	DWORD d = (DWORD)lua_tonumber(pL, 1);

	AntiAliasingFont* p = (AntiAliasingFont*)d;

	if (!p)
	{
		return 0;
	}

	const int x = lua_tonumber(pL, 2);
	const int y = lua_tonumber(pL, 3);

	p->setPosition(x, y);

	return 0;
}

// FontEx.SetTextColor(fontId, red, green, blue)
LUA_CLASS(Set, FontEx, TextColor)
{
	int n = lua_gettop(pL);
	DWORD d = (DWORD)lua_tonumber(pL, 1);

	AntiAliasingFont* p = (AntiAliasingFont*)d;

	if (!p)
	{
		return 0;
	}

	const int r = lua_tonumber(pL, 2);
	const int g = lua_tonumber(pL, 3);
	const int b = lua_tonumber(pL, 4);

	p->setTextColor(r, g, b);

	return 0;
}

// FontEx.SetOpacity(fontId, value)
LUA_CLASS(Set, FontEx, Opacity)
{
	int n = lua_gettop(pL);
	DWORD d = (DWORD)lua_tonumber(pL, 1);

	AntiAliasingFont* p = (AntiAliasingFont*)d;

	if (!p)
	{
		return 0;
	}

	const int opacity = lua_tonumber(pL, 2);

	p->setOpacity(opacity);

	return 0;
}

LUA_CLASS(Get, FontEx, TextWidth)
{
	int n = lua_gettop(pL);
	DWORD d = (DWORD)lua_tonumber(pL, 1);
	int w = 0;

	AntiAliasingFont* p = (AntiAliasingFont*)d;

	if (!p)
	{
		lua_pushnumber(pL, w);
		return 1;
	}

	std::string asciiText = luaL_checkstring(pL, 2);
	std::wstring_convert<std::codecvt_utf8<wchar_t>> converter;
	std::wstring sText = converter.from_bytes(asciiText);

	w = p->getTextWidth(&sText[0]);
	lua_pushnumber(pL, w);

	return 1;
}

LUA_CLASS(Set, FontEx, Angle)
{
	int n = lua_gettop(pL);
	DWORD d = (DWORD)lua_tonumber(pL, 1);
	AntiAliasingFont* p = (AntiAliasingFont*)d;

	float angle = luaL_checknumber(pL, 2);

	if (!p)
	{
		return 0;
	}

	p->setAngle(angle);

	return 0;
}