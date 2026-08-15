#include "lua_tbl.h"
#include "lua_audio.h"
#include "lua_input.h"
#include "lua_json.h"
#include "lua_sprite.h"
#include "lua_texture.h"
#include "lua_tilemap.h"
#include "lua_font.h"

#include "App.h"
#include "Sprite.h"
#include "TextureManager.h"
#include "Input.h"
#include "GameStateMachine.h"
#include "MenuState.h"
#include "SoundManager.h"
#include "MenuState.h"
#include "Encrypt.h"

#ifdef RS_WINDOWS
#define WIN32_LEAN_AND_MEAN

#include <Windows.h>
#include <tchar.h>
#include <atlconv.h>
#else
#include <SDL.h>
#include <filesystem>
#include <algorithm>
#include "platform/Utf8.h"
#include "platform/WinTypes.h"
#endif

#include <cstdio>
#include <vector>

#include "Font.h"

#include <memory>
#include <exception>
#include <cstdlib>

#include <string> 
#include <locale> 
#include <codecvt> 
#include <cassert>

#ifdef RS_WINDOWS

int ShowMessageBox(HWND hWnd, LPCWCHAR text, LPCWCHAR caption, UINT type);

namespace Initial2D {
	/**
	 * 윈도우즈 플랫폼에서 스크립트 파일을 읽습니다.
	 */
	std::vector<TCHAR*> ReadScriptFiles()
	{
		// 와일드카드(*) 를 사용합니다.
		TCHAR target[] = _T(".\\scripts\\*.lua");
		WIN32_FIND_DATA FindFileData;
		HANDLE hFind = INVALID_HANDLE_VALUE;

		hFind = FindFirstFile(target, &FindFileData);

		std::vector<TCHAR*> item;

		if (hFind == INVALID_HANDLE_VALUE)
		{
			return item;
		}
		else
		{
			while (FindNextFile(hFind, &FindFileData) != 0)
			{
				item.push_back(FindFileData.cFileName);
			}
			FindClose(hFind);
		}

		return item;
	}
}

#endif // RS_WINDOWS

// Lua Global State
lua_State* g_pLuaState;

#ifdef RS_WINDOWS

// HWND
extern HWND g_hWnd;

wchar_t* AllocWideChar(const char* law)
{
	int length = MultiByteToWideChar(CP_UTF8, 0, law, -1, NULL, 0);
	
	if (length == 0)
	{
		return L"";
	}

	// NULL 문자를 포함하여 메모리를 초기화 않으면 오류가 난다.
	LPWSTR lpszWideChar = new WCHAR[length + 1];

	if (lpszWideChar == NULL)
	{
		return L"";
	}

	memset(lpszWideChar, 0, sizeof(WCHAR) * (length + 1));
	int ret = MultiByteToWideChar(CP_UTF8, 0, law, -1, lpszWideChar, length);

	if (ret == 0)
	{
		return L"";
	}

	return lpszWideChar;
}

std::string AllocMBCS(std::wstring str)
{
	int nStringArraySize = WideCharToMultiByte(CP_ACP, 0, &str[0], str.size(), NULL, 0, NULL, NULL);
	if (nStringArraySize == 0) {
		return "";
	}

	std::string raw(nStringArraySize, '\0');
	WideCharToMultiByte(CP_ACP, 0, &str[0], str.size(), &raw[0], raw.size(), NULL, NULL);

	return raw;
}

/**
* Show MessageBox
*/

int ShowMessageBox(HWND hWnd, LPCWCHAR text, LPCWCHAR caption, UINT type)
{
	MessageBoxW(hWnd, text, caption, type);
	return 0;
}

#else // 비-Windows: UTF-8 유틸리티 기반 구현 (인터페이스 동일)

wchar_t* AllocWideChar(const char* law)
{
	const std::wstring wide = Initial2D::Platform::Utf8ToWide(law != nullptr ? law : "");
	wchar_t* buffer = new wchar_t[wide.size() + 1];
	std::copy(wide.begin(), wide.end(), buffer);
	buffer[wide.size()] = L'\0';
	return buffer;
}

std::string AllocMBCS(std::wstring str)
{
	return Initial2D::Platform::WideToUtf8(str);
}

#endif // RS_WINDOWS

void RemoveWideChar(const wchar_t* law)
{
	delete[] law;
}

// lua_prot.h의 비-static 선언과 일치시킨다 (MSVC는 불일치를 허용했으나 clang은 오류)
int Lua_MessageBox(lua_State *g_pLuaSt)
{
	int n = lua_gettop(g_pLuaSt);

	const char *text = lua_tostring(g_pLuaSt, 1);
	const char *caption = lua_tostring(g_pLuaSt, 2);

#ifdef RS_WINDOWS
	WCHAR *wt = AllocWideChar(text);
	WCHAR *wc = AllocWideChar(caption);

	ShowMessageBox(g_hWnd, wt, wc, MB_OK);

	RemoveWideChar(wt);
	RemoveWideChar(wc);
#else
	SDL_ShowSimpleMessageBox(SDL_MESSAGEBOX_INFORMATION,
		caption != nullptr ? caption : "",
		text != nullptr ? text : "",
		App::GetInstance().GetWindowHandle());
#endif

	return 0;
}

/**
* Frame Update
*/
int Lua_Update(double elapsed)
{
	lua_getglobal(g_pLuaState, "Update");

	lua_pushnumber(g_pLuaState, elapsed);
	lua_call(g_pLuaState, 1, 0);

	return 0;
}

int Lua_Render()
{
	lua_getglobal(g_pLuaState, "Render");
	lua_call(g_pLuaState, 0, 0);

	return 0;

}

int Lua_Destory()
{
	lua_getglobal(g_pLuaState, "Destroy");
	lua_call(g_pLuaState, 0, 0);

	lua_close(g_pLuaState);
	return 0;
}

int Lua_LoadScript(lua_State *pL)
{
	int n = lua_gettop(pL);

	if (n < 1)
	{
		return 0;
	}

	const char *filename = luaL_checkstring(pL, 1);
	luaL_dofile(pL, filename);

	return 0;
}

int Lua_PreparaFont(lua_State *pL)
{
	std::string filename = luaL_checkstring(pL, 1);
	bool isValid = App::GetInstance().LoadFont(filename);
	GameFont *pFont = App::GetInstance().GetFont();
	
	isValid = pFont->get()->open(filename);
	lua_pushboolean(pL, isValid);
	return 1;
}

int Lua_DrawPoint(lua_State *pL) 
{
	int n = lua_gettop(pL);
	if (n < 2)
	{
		lua_pushnumber(pL, 0);
		return 1;
	}

	int x = luaL_checkinteger(pL, 1);
	int y = luaL_checkinteger(pL, 2);

	TextureManager &tm = App::GetInstance().GetTextureManager();
	tm.DrawPoint(x, y);

	lua_pushnumber(pL, 0);
	return 1;
}

int Lua_DrawSetColor(lua_State *pL)
{
	int n = lua_gettop(pL);
	if (n < 4)
	{
		lua_pushnumber(pL, 0);
		return 1;
	}

	int r = luaL_checkinteger(pL, 1);
	int g = luaL_checkinteger(pL, 2);
	int b = luaL_checkinteger(pL, 3);
	int a = luaL_checkinteger(pL, 4);

	TextureManager &tm = App::GetInstance().GetTextureManager();
	tm.SetBitmapColor(r, g, b, a);

	lua_pushnumber(pL, 0);
	return 1;
}

int Lua_DrawText(lua_State *pL)
{
	GameFont* pFont = App::GetInstance().GetFont();

	if (pFont->get()->isValid())
	{
		int x, y, width;
		x = luaL_checknumber(pL, 1);
		y = luaL_checknumber(pL, 2);
		width = 0;

		const char *text = luaL_checkstring(pL, 3);
		const wchar_t *c = AllocWideChar(text);
		width = pFont->get()->drawText(x, y, c);
		
		lua_pushnumber(pL, width);

		RemoveWideChar(c);
	}
	else {
		lua_pushnumber(pL, 0);
	}

	return 1;
}

/**
 * @brief 그리지 않고 텍스트의 픽셀 폭만 잰다 (자동 줄바꿈과 가운데 정렬용).
 * Lua: GetTextWidth(text) -> number
 */
int Lua_GetTextWidth(lua_State *pL)
{
	GameFont* pFont = App::GetInstance().GetFont();

	int width = 0;
	if (pFont->get()->isValid())
	{
		const char *text = luaL_checkstring(pL, 1);
		const wchar_t *c = AllocWideChar(text);
		width = pFont->get()->getTextWidth(0, 0, c);
		RemoveWideChar(c);
	}
	lua_pushnumber(pL, width);
	return 1;
}

int Lua_WindowWidth(lua_State *pL)
{
	lua_pushinteger(pL, App::GetInstance().GetWindowWidth());
	return 1;
}

int Lua_WindowHeight(lua_State *pL)
{
	lua_pushinteger(pL, App::GetInstance().GetWindowHeight());
	return 1;
}

int Lua_GetFrameCount(lua_State *pL)
{
	lua_pushinteger(pL, App::GetInstance().GetFrameCount());
	return 1;
}

int Lua_GameExit(lua_State *pL)
{
	// Windows에서는 PostQuitMessage(0), SDL2에서는 SDL_QUIT 이벤트 푸시와 동일하다.
	App::GetInstance().Quit();
	return 0;
}

int Lua_GetCurrentDirectory(lua_State *pL)
{
#ifdef RS_WINDOWS
	std::string s;
	s.resize(MAX_CHAR);

	GetCurrentDirectory(MAX_CHAR, &s[0]);
#else
	std::string s = std::filesystem::current_path().string();
#endif

	int n = lua_gettop(pL);
	int man = 0;
	if (n > 0) {
		std::string from = "\\";
		std::string to = "/";

		size_t start_pos = 0;
		while ((start_pos = s.find(from, start_pos)) != std::string::npos) {
			s.replace(start_pos, from.length(), to);
			start_pos += to.length();
		}
	}
	
	lua_pushstring(pL, s.c_str());

	return 1;
}

int Lua_SetAppIcon(lua_State *pL)
{
	int n = lua_gettop(pL);
	if (n < 1) {
		return 0;
	}

	std::string filename = luaL_checkstring(pL, 1);
	App::GetInstance().SetAppIcon(filename);

	return 0;
}

int Lua_GetResourcesFiles(lua_State *pL)
{
	std::vector<std::string> dirs;
	Initial2D::ReadDirectory(dirs, std::string(".\\resources\\*.*"));

	lua_newtable(pL);

	int i = 1;
	for (std::vector<std::string>::iterator iter = dirs.begin(); iter != dirs.end(); iter++, i++) {
		lua_pushinteger(pL, i);
		lua_pushstring(pL, (*iter).c_str());
		lua_settable(pL, -3);
	}

	return 1;
}

int l_wcsprint(lua_State *pL)
{
	int n = lua_gettop(pL);
	luaL_argcheck(pL, n >= 1, n, "out of range");

	for (int i = 1; i <= n; ++i) {
		wchar_t *from = AllocWideChar(lua_tostring(pL, i));
		std::string to = AllocMBCS(from);
		std::cout << to;
		RemoveWideChar(from);
	}
	std::cout << std::endl;

	return 0;
}

static const struct luaL_Reg printlib[] = {
	{ "print", l_wcsprint },
	{ NULL, NULL }
};

int Lua_Init()
{

	g_pLuaState = luaL_newstate();
	luaL_openlibs(g_pLuaState);

	try {

		lua_getglobal(g_pLuaState, "_G");
		luaL_setfuncs(g_pLuaState, printlib, 0);
		lua_pop(g_pLuaState, 1);

		lua_register(g_pLuaState, "MessageBox", Lua_MessageBox);
		lua_register(g_pLuaState, "LoadScript", Lua_LoadScript);
		lua_register(g_pLuaState, "PreparaFont", Lua_PreparaFont);
		lua_register(g_pLuaState, "DrawText", Lua_DrawText);
		lua_register(g_pLuaState, "GetTextWidth", Lua_GetTextWidth);
		lua_register(g_pLuaState, "WindowWidth", Lua_WindowWidth);
		lua_register(g_pLuaState, "WindowHeight", Lua_WindowHeight);
		lua_register(g_pLuaState, "GetFrameCount", Lua_GetFrameCount);
		lua_register(g_pLuaState, "GameExit", Lua_GameExit);

		// Draw
		lua_register(g_pLuaState, "draw_text", Lua_DrawText);
		lua_register(g_pLuaState, "draw_point", Lua_DrawPoint);
		lua_register(g_pLuaState, "draw_set_color", Lua_DrawSetColor);

		lua_register(g_pLuaState, "GetCurrentDirectory", Lua_GetCurrentDirectory);

		lua_register(g_pLuaState, "SetAppIcon", Lua_SetAppIcon);

		lua_register(g_pLuaState, "GetResourcesFiles", Lua_GetResourcesFiles);

		// Audio
		Lua_CreateAudioObject(g_pLuaState);

		// Input
		Lua_CreateInputObject(g_pLuaState);

		// Json
		Lua_CreateJsonObject(g_pLuaState);

		// Sprite
		Lua_CreateSpriteImpl(g_pLuaState);

		// Tilemap
		Lua_CreateTilemapObject(g_pLuaState);

		// Texture
		Lua_CreateTextureManagerObject(g_pLuaState);

		// FontEx
		Lua_CreateFontExImpl(g_pLuaState);

		// 스크립트 파일을 읽습니다 (Windows Only)
		//luaL_dostring(g_pLuaState,
		//	"for dir in io.popen([[dir \"./scripts/\" /r /b]]) :lines() do LoadScript(\"./scripts/\"..dir) end");

		luaL_dostring(g_pLuaState, "LoadScript(\"./scripts/main.lua\")");

		// 스크립트 파일 내에 선언된 초기화 함수를 호출합니다.
		lua_getglobal(g_pLuaState, "Initialize");
		lua_call(g_pLuaState, 0, 0);

	}
	catch (std::exception &e) {
		luaL_error(g_pLuaState, e.what());
	}
	catch (...) {
		luaL_error(g_pLuaState, "Unknown Error");
	}

	return 0;
}