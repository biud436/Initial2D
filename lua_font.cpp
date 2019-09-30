#include "lua_font.h"
#include "ExperimentalFont.h"
#include <clocale>
#include <codecvt>
#include <string>
#include <exception>

extern lua_State* g_pLuaState;

LuaObjectToken luaj_FontEx[LUA_FONTEX_MEMBERS] = {
	{ "Create", LUA_METHOD_P1(CreateFontEx) },
	{ "Update", LUA_METHOD_P1(UpdateFontEx) },
	{ "Draw", LUA_METHOD_P1(DrawFontEx) },
	{ "Dispose", LUA_METHOD_P1(ReleaseFontEx) },
	{ "SetText", LUA_METHOD_P1(SetFontExText) },
	{ "SetPosition", LUA_METHOD_P1(SetFontExPosition) },
	{ "SetTextColor", LUA_METHOD_P1(SetFontExTextColor) }
};


LUA_METHOD(CreateFontExImpl)
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


// local myFont = FontEx.Create(FontFace, FontSize)
LUA_METHOD(CreateFontEx)
{
	try {
		int n = lua_gettop(pL);
		if (n < 2)
		{
			lua_pushnumber(pL, 0);
			return 1;
		}

		std::string preFontFace = luaL_checkstring(pL, 1);
		int fontSize = luaL_checknumber(pL, 2);

		// ASCII -> WBCS (UTF8)
		std::wstring_convert<std::codecvt_utf8<wchar_t>> converter;
		std::wstring sFontFace = converter.from_bytes(preFontFace);

		printf_s("ASCII -> WBCS (UTF8) \n");

		AntiAliasingFont* pFont = new AntiAliasingFont(sFontFace, fontSize);

		DWORD d = (DWORD)pFont;

		lua_pushnumber(pL, d);

		return 1;

	}  catch (std::exception &e) {
		luaL_error(pL, e.what());
	}
}


// FontEx.Update(fontId)
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


// FontEx.Draw(fontId)
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

// FontEx.TextColor(fontId, red, green, blue)
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