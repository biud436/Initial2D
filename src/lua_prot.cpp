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
#include <cctype>
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

// 스크립트 오류는 PANIC(abort, 종료 코드 134) 대신 mruby 와 같은 무게로 다룬다:
// 메시지(파일:줄: ...)를 stderr 에 적고 VM 을 멈춘다. 에디터의 콘솔이 그 줄을 링크로 만든다
// (InitialEditor E1). 게임을 끝낼지(종료 코드 1)는 ScriptRuntime 이 Lua_Failed 를 보고 정한다.
static bool s_luaFailed = false;

static bool Lua_ReportIfError(int status, const char* where)
{
	if (status == LUA_OK)
	{
		return false;
	}
	const char* msg = lua_tostring(g_pLuaState, -1);
	std::fprintf(stderr, "Lua error in %s: %s\n", where, msg ? msg : "(no message)");
	std::fflush(stderr);
	lua_pop(g_pLuaState, 1);
	s_luaFailed = true;
	return true;
}

bool Lua_Failed()
{
	return s_luaFailed;
}

/**
* Frame Update
*/
int Lua_Update(double elapsed)
{
	if (s_luaFailed) return 0;
	lua_getglobal(g_pLuaState, "Update");

	lua_pushnumber(g_pLuaState, elapsed);
	Lua_ReportIfError(lua_pcall(g_pLuaState, 1, 0, 0), "update");

	return 0;
}

int Lua_Render()
{
	if (s_luaFailed) return 0;
	lua_getglobal(g_pLuaState, "Render");
	Lua_ReportIfError(lua_pcall(g_pLuaState, 0, 0, 0), "render");

	return 0;

}

int Lua_Destory()
{
	if (!s_luaFailed)
	{
		lua_getglobal(g_pLuaState, "Destroy");
		Lua_ReportIfError(lua_pcall(g_pLuaState, 0, 0, 0), "destroy");
	}

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
	if (luaL_dofile(pL, filename) != LUA_OK)
	{
		return lua_error(pL); // 메시지(파일:줄: ...)가 스택 위에 있다
	}

	return 0;
}

int Lua_PreparaFont(lua_State *pL)
{
	std::string filename = luaL_checkstring(pL, 1);

	// LoadFont가 파싱과 텍스처 적재를 모두 한다. 예전에는 그 결과를 버리고
	// Font::open()의 반환값을 썼는데, open()은 "이미 폰트가 하나 열려 있으면"
	// 무조건 true라서 잘못된 파일을 줘도 성공으로 보고했다 (2026-08-17).
	bool isValid = App::GetInstance().LoadFont(filename);
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

namespace
{
	BYTE ClampColor(lua_Integer v)
	{
		if (v < 0) return 0;
		if (v > 255) return 255;
		return static_cast<BYTE>(v);
	}

	// 지금 글자 크기 (줄 높이, 픽셀). 정하지 않았으면 폰트 파일의 줄 높이, 폰트가 없으면 0
	int CurrentTextSize()
	{
		TextureManager &tm = App::GetInstance().GetTextureManager();
		if (tm.m_textSize > 0)
		{
			return tm.m_textSize;
		}
		GameFont* pFont = App::GetInstance().GetFont();
		if (pFont != nullptr && pFont->get() != nullptr && pFont->get()->isValid())
		{
			return pFont->get()->getDesc().LineHeight;
		}
		return 0;
	}
}

/**
 * SetTextColor(r, g, b [, a])
 * DrawText 의 글자 색. 기본은 흰색 255, 255, 255, 255. 스크립트가 다시 시작하면 기본으로 돌아간다.
 */
int Lua_SetTextColor(lua_State *pL)
{
	TextureManager &tm = App::GetInstance().GetTextureManager();
	tm.m_textColor = Initial2D::Color(
		ClampColor(luaL_checkinteger(pL, 1)),
		ClampColor(luaL_checkinteger(pL, 2)),
		ClampColor(luaL_checkinteger(pL, 3)),
		ClampColor(luaL_optinteger(pL, 4, 255)));
	return 0;
}

/** local r, g, b, a = GetTextColor() */
int Lua_GetTextColor(lua_State *pL)
{
	const Initial2D::Color& c = App::GetInstance().GetTextureManager().m_textColor;
	lua_pushinteger(pL, c.red);
	lua_pushinteger(pL, c.green);
	lua_pushinteger(pL, c.blue);
	lua_pushinteger(pL, c.alpha);
	return 4;
}

/**
 * SetTextSize(px)
 * DrawText 와 GetTextWidth 의 글자 크기 (줄 높이, 픽셀). 0 이면 폰트 파일의 크기.
 * 글리프를 늘여 그리므로 폰트 파일의 크기에서 멀수록 거칠어진다.
 */
int Lua_SetTextSize(lua_State *pL)
{
	const lua_Integer size = luaL_checkinteger(pL, 1);
#ifndef RS_WINDOWS
	App::GetInstance().GetTextureManager().m_textSize = size > 0 ? static_cast<int>(size) : 0;
#else
	(void)size; // GDI 판은 폰트 파일의 크기로만 그린다
#endif
	return 0;
}

/** local px = GetTextSize()  -- 지금 글자 크기. 폰트가 없으면 0 */
int Lua_GetTextSize(lua_State *pL)
{
	lua_pushinteger(pL, CurrentTextSize());
	return 1;
}

/** DrawRect(x, y, width, height): 테두리 1픽셀. 색은 draw_set_color */
int Lua_DrawRect(lua_State *pL)
{
	const float x = static_cast<float>(luaL_checknumber(pL, 1));
	const float y = static_cast<float>(luaL_checknumber(pL, 2));
	const float w = static_cast<float>(luaL_checknumber(pL, 3));
	const float h = static_cast<float>(luaL_checknumber(pL, 4));
#ifndef RS_WINDOWS
	App::GetInstance().GetTextureManager().DrawRect(x, y, w, h, false);
#else
	(void)x; (void)y; (void)w; (void)h;
#endif
	return 0;
}

/** FillRect(x, y, width, height): 칠한 사각형. 색은 draw_set_color */
int Lua_FillRect(lua_State *pL)
{
	const float x = static_cast<float>(luaL_checknumber(pL, 1));
	const float y = static_cast<float>(luaL_checknumber(pL, 2));
	const float w = static_cast<float>(luaL_checknumber(pL, 3));
	const float h = static_cast<float>(luaL_checknumber(pL, 4));
#ifndef RS_WINDOWS
	App::GetInstance().GetTextureManager().DrawRect(x, y, w, h, true);
#else
	(void)x; (void)y; (void)w; (void)h;
#endif
	return 0;
}

/** DrawLine(x1, y1, x2, y2). 색은 draw_set_color */
int Lua_DrawLine(lua_State *pL)
{
	const float x1 = static_cast<float>(luaL_checknumber(pL, 1));
	const float y1 = static_cast<float>(luaL_checknumber(pL, 2));
	const float x2 = static_cast<float>(luaL_checknumber(pL, 3));
	const float y2 = static_cast<float>(luaL_checknumber(pL, 4));
#ifndef RS_WINDOWS
	App::GetInstance().GetTextureManager().DrawLine(x1, y1, x2, y2);
#else
	(void)x1; (void)y1; (void)x2; (void)y2;
#endif
	return 0;
}

/** DrawCircle(cx, cy, radius): 테두리 1픽셀. 색은 draw_set_color */
int Lua_DrawCircle(lua_State *pL)
{
	const float cx = static_cast<float>(luaL_checknumber(pL, 1));
	const float cy = static_cast<float>(luaL_checknumber(pL, 2));
	const float r = static_cast<float>(luaL_checknumber(pL, 3));
#ifndef RS_WINDOWS
	App::GetInstance().GetTextureManager().DrawCircle(cx, cy, r, false);
#else
	(void)cx; (void)cy; (void)r;
#endif
	return 0;
}

/** FillCircle(cx, cy, radius): 칠한 원. 색은 draw_set_color */
int Lua_FillCircle(lua_State *pL)
{
	const float cx = static_cast<float>(luaL_checknumber(pL, 1));
	const float cy = static_cast<float>(luaL_checknumber(pL, 2));
	const float r = static_cast<float>(luaL_checknumber(pL, 3));
#ifndef RS_WINDOWS
	App::GetInstance().GetTextureManager().DrawCircle(cx, cy, r, true);
#else
	(void)cx; (void)cy; (void)r;
#endif
	return 0;
}

/**
 * local ok = SetRenderTarget(id)   -- TextureManager.CreateTarget 으로 만든 텍스처에 그린다
 * SetRenderTarget(nil)             -- 화면으로 돌아간다
 * 엔진은 매 프레임 Render 가 끝나면 화면으로 되돌린다.
 */
int Lua_SetRenderTarget(lua_State *pL)
{
	const char* id = lua_isnoneornil(pL, 1) ? "" : luaL_checkstring(pL, 1);
#ifndef RS_WINDOWS
	lua_pushboolean(pL, App::GetInstance().GetTextureManager().SetRenderTarget(id));
#else
	lua_pushboolean(pL, id[0] == '\0');
#endif
	return 1;
}

/** local id = GetRenderTarget()   -- 화면이면 nil */
int Lua_GetRenderTarget(lua_State *pL)
{
#ifndef RS_WINDOWS
	const std::string& id = App::GetInstance().GetTextureManager().GetRenderTarget();
	if (!id.empty())
	{
		lua_pushstring(pL, id.c_str());
		return 1;
	}
#endif
	lua_pushnil(pL);
	return 1;
}

/** ClearRenderTarget(r, g, b [, a]): 지금 그리는 곳을 한 색으로 지운다. 화면이면 게임 영역만 */
int Lua_ClearRenderTarget(lua_State *pL)
{
	const BYTE r = ClampColor(luaL_checkinteger(pL, 1));
	const BYTE g = ClampColor(luaL_checkinteger(pL, 2));
	const BYTE b = ClampColor(luaL_checkinteger(pL, 3));
	const BYTE a = ClampColor(luaL_optinteger(pL, 4, 255));
#ifndef RS_WINDOWS
	App::GetInstance().GetTextureManager().ClearTarget(r, g, b, a);
#else
	(void)r; (void)g; (void)b; (void)a;
#endif
	return 0;
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

/**
 * 픽셀 확대 배율을 정한다. 창 크기는 그대로 두고 논리 해상도만 1/배율로 줄여
 * 화면 전체(타일맵, 스프라이트, 폰트)를 그만큼 크게 그린다.
 * 배율을 바꾸면 WindowWidth/Height가 달라지므로 씬은 그 뒤에 배치를 계산해야 한다.
 */
int Lua_SetRenderScale(lua_State *pL)
{
	const int scale = static_cast<int>(luaL_checkinteger(pL, 1));
	App::GetInstance().SetRenderScale(scale);
	lua_pushinteger(pL, App::GetInstance().GetRenderScale());
	return 1;
}

int Lua_GetRenderScale(lua_State *pL)
{
	lua_pushinteger(pL, App::GetInstance().GetRenderScale());
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

/**
 * local name = GetPlatform()
 * "windows" | "macos" | "linux" | "android" | "ios" | 그 외 SDL이 보고하는 이름(소문자)
 * 스크립트가 터치 조작 UI(가상 패드) 표시 여부 등을 결정할 때 쓴다.
 */
int Lua_GetPlatform(lua_State *pL)
{
#ifdef RS_WINDOWS
	lua_pushstring(pL, "windows");
#else
	std::string name = SDL_GetPlatform();
	if (name == "Mac OS X") name = "macos";
	else if (name == "Windows") name = "windows";
	else if (name == "Linux") name = "linux";
	else if (name == "Android") name = "android";
	else if (name == "iOS") name = "ios";
	else std::transform(name.begin(), name.end(), name.begin(), ::tolower);
	lua_pushstring(pL, name.c_str());
#endif
	return 1;
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
	// 새 VM 은 오류 없이 시작한다 (재시작 때 이전 VM 의 실패를 넘겨받지 않는다)
	s_luaFailed = false;

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
		lua_register(g_pLuaState, "SetTextColor", Lua_SetTextColor);
		lua_register(g_pLuaState, "GetTextColor", Lua_GetTextColor);
		lua_register(g_pLuaState, "SetTextSize", Lua_SetTextSize);
		lua_register(g_pLuaState, "GetTextSize", Lua_GetTextSize);
		lua_register(g_pLuaState, "DrawRect", Lua_DrawRect);
		lua_register(g_pLuaState, "FillRect", Lua_FillRect);
		lua_register(g_pLuaState, "DrawLine", Lua_DrawLine);
		lua_register(g_pLuaState, "DrawCircle", Lua_DrawCircle);
		lua_register(g_pLuaState, "FillCircle", Lua_FillCircle);
		lua_register(g_pLuaState, "SetRenderTarget", Lua_SetRenderTarget);
		lua_register(g_pLuaState, "GetRenderTarget", Lua_GetRenderTarget);
		lua_register(g_pLuaState, "ClearRenderTarget", Lua_ClearRenderTarget);
		lua_register(g_pLuaState, "WindowWidth", Lua_WindowWidth);
		lua_register(g_pLuaState, "WindowHeight", Lua_WindowHeight);
		lua_register(g_pLuaState, "SetRenderScale", Lua_SetRenderScale);
		lua_register(g_pLuaState, "GetRenderScale", Lua_GetRenderScale);
		lua_register(g_pLuaState, "GetFrameCount", Lua_GetFrameCount);
		lua_register(g_pLuaState, "GameExit", Lua_GameExit);

		// Draw
		lua_register(g_pLuaState, "draw_text", Lua_DrawText);
		lua_register(g_pLuaState, "draw_point", Lua_DrawPoint);
		lua_register(g_pLuaState, "draw_set_color", Lua_DrawSetColor);

		lua_register(g_pLuaState, "GetCurrentDirectory", Lua_GetCurrentDirectory);
		lua_register(g_pLuaState, "GetPlatform", Lua_GetPlatform);

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

		if (!Lua_ReportIfError(luaL_dostring(g_pLuaState, "LoadScript(\"./scripts/lua/main.lua\")"), "scripts/lua/main.lua"))
		{
			// 스크립트 파일 내에 선언된 초기화 함수를 호출합니다.
			lua_getglobal(g_pLuaState, "Initialize");
			Lua_ReportIfError(lua_pcall(g_pLuaState, 0, 0, 0), "init");
		}

	}
	catch (std::exception &e) {
		luaL_error(g_pLuaState, e.what());
	}
	catch (...) {
		luaL_error(g_pLuaState, "Unknown Error");
	}

	return 0;
}