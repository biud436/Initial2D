#include "lua_tbl.h"
#include "lua_audio.h"
#include "lua_input.h"
#include "lua_sprite.h"
#include "lua_texture.h"

#include "App.h"
#include "Sprite.h"
#include "TextureManager.h"
#include "Input.h"
#include "GameStateMachine.h"
#include "MenuState.h"
#include "SoundManager.h"
#include "MenuState.h"

#define WIN32_LEAN_AND_MEAN

#include <Windows.h>
#include <tchar.h>
#include <cstdio>
#include <vector>

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

// Lua Global State
lua_State* g_pLuaState;

// HWND
extern HWND g_hWnd;

wchar_t* AllocWideChar(const char* law)
{
	int len = strlen(law);

	WCHAR *wide_text = new WCHAR[len];
	memset(wide_text, 0, sizeof(WCHAR) * len);

	MultiByteToWideChar(CP_ACP, 0, (LPCSTR)law, -1, wide_text, len);

	return wide_text;
}

void DestroyWideChar(const wchar_t* law)
{
	delete[] law;
}

/**
* Show MessageBox
*/
static int Lua_MessageBox(lua_State *g_pLuaSt)
{
	int n = lua_gettop(g_pLuaSt);

	const char *text = lua_tostring(g_pLuaSt, 1);
	const char *caption = lua_tostring(g_pLuaSt, 2);

	WCHAR *wt = AllocWideChar(text);
	WCHAR *wc = AllocWideChar(caption);

	MessageBoxW(g_hWnd, wt, wc, MB_OK);

	DestroyWideChar(wt);
	DestroyWideChar(wc);

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

int Lua_Init()
{
	g_pLuaState = luaL_newstate();
	luaL_openlibs(g_pLuaState);

	lua_register(g_pLuaState, "MessageBox", Lua_MessageBox);
	lua_register(g_pLuaState, "LoadScript", Lua_LoadScript);

	// Audio
	Lua_CreateAudioObject(g_pLuaState);

	// Input
	Lua_CreateInputObject(g_pLuaState);

	// Sprite
	Lua_CreateSpriteImpl(g_pLuaState);

	// Texture
	Lua_CreateTextureManagerObject(g_pLuaState);

	// 스크립트 파일을 읽습니다 (Windows Only)
	luaL_dostring(g_pLuaState, 
		"for dir in io.popen([[dir \"./scripts/\" /r /b]]) :lines() do LoadScript(\"./scripts/\"..dir) end");

	// 스크립트 파일 내에 선언된 초기화 함수를 호출합니다.
	lua_getglobal(g_pLuaState, "Initialize");
	lua_call(g_pLuaState, 0, 0);

	return 0;
}