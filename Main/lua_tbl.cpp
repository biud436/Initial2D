#include "App.h"
#include "Sprite.h"
#include "TextureManager.h"
#include "Input.h"
#include "GameStateMachine.h"
#include "MenuState.h"
#include "SoundManager.h"

#include "lua/lua.h"
#include "lua/lualib.h"
#include "lua/lauxlib.h"
#include "lua_tbl.h"

lua_State* g_pLuaState;
extern HWND g_hWnd;

/**
* struct LuaObjectToken
*/
struct LuaObjectToken
{
	typedef int(*LuaFunc)(lua_State* pL);

	const char *name;
	LuaFunc func;

	LuaObjectToken(const char *s, LuaFunc f)
	{
		name = s;
		func = f;
	}

};

// Lua Audio API from C
static int Lua_PlayMusic(lua_State *pL);
static int Lua_PlaySound(lua_State *pL);
static int Lua_GetBgmVolume(lua_State *pL);
static int Lua_SetBgmVolume(lua_State *pL);
static int Lua_InsertNextMusic(lua_State *pL);
static int Lua_PauseMusic(lua_State *pL);
static int Lua_StopMusic(lua_State *pL);
static int Lua_ResumeMusic(lua_State *pL);
static int Lua_IsPlayingMusic(lua_State *pL);
static int Lua_FadeOutMusic(lua_State *pL);
static int Lua_SetMusicPosition(lua_State *pL);
static int Lua_ReleaseMusic(lua_State *pL);

// Lua Input API from C
static int Lua_IsKeyDown(lua_State *pL);
static int Lua_IsKeyUp(lua_State *pL);
static int Lua_IsKeyPress(lua_State *pL);
static int Lua_IsAnyKeyDown(lua_State *pL);
static int Lua_GetMouseX(lua_State *pL);
static int Lua_GetMouseY(lua_State *pL);
static int Lua_IsMouseDown(lua_State *pL);
static int Lua_IsMouseUp(lua_State *pL);
static int Lua_IsMousePress(lua_State *pL);
static int Lua_IsAnyMouseDown(lua_State *pL);
static int Lua_GetMouseZ(lua_State *pL);
static int Lua_SetMouseZ(lua_State *pL);

// Lua TextureManager API from C
static int Lua_LoadTexture(lua_State *pL);
static int Lua_RemoveTexture(lua_State *pL);
static int Lua_IsValidTexture(lua_State *pL);

#define LUA_AUDIO_MEMBERS 12
#define LUA_INPUT_MEMBERS 12
#define LUA_TM_MEMBERS 3

LuaObjectToken luaj_Audio[LUA_AUDIO_MEMBERS] = {
	{ "PlayMusic", Lua_PlayMusic },
	{ "PlaySound", Lua_PlaySound },
	{ "SetVolume", Lua_SetBgmVolume },
	{ "GetVolume", Lua_GetBgmVolume },
	{ "InsertNextMusic", Lua_InsertNextMusic },
	{ "PauseMusic",  Lua_PauseMusic },
	{ "StopMusic",  Lua_StopMusic },
	{ "ResumeMusic",  Lua_ResumeMusic },
	{ "IsPlayingMusic",  Lua_IsPlayingMusic },
	{ "FadeOutMusic",  Lua_FadeOutMusic },
	{ "SetMusicPosition",  Lua_SetMusicPosition },
	{ "ReleaseMusic",  Lua_ReleaseMusic },
};

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

LuaObjectToken luaj_TextureManager[LUA_TM_MEMBERS] = {
	{ "Load", Lua_LoadTexture },
	{ "Remove", Lua_RemoveTexture },
	{ "IsValid", Lua_IsValidTexture }
};

/**
* Show MessageBox
*/
static int Lua_MessageBox(lua_State *g_pLuaSt)
{
	int n = lua_gettop(g_pLuaSt);

	std::string text = lua_tostring(g_pLuaSt, 1);
	std::string caption = lua_tostring(g_pLuaSt, 2);

	MessageBox(g_hWnd, text.c_str(), caption.c_str(), MB_OK);

	return 0;
}

/**
* Frame Update
*/
static int Lua_Update()
{
	lua_getglobal(g_pLuaState, "Update");
	lua_call(g_pLuaState, 0, 0);

	return 0;
}

static int Lua_Render()
{
	lua_getglobal(g_pLuaState, "Render");
	lua_call(g_pLuaState, 0, 0);

	return 0;

}

static int Lua_Destory()
{
	lua_getglobal(g_pLuaState, "Destroy");
	lua_call(g_pLuaState, 0, 0);

	lua_close(g_pLuaState);
	return 0;
}

static int Lua_CreateAudioObject(lua_State *pL)
{
	lua_newtable(pL);

	for (int i = 0; i < LUA_AUDIO_MEMBERS; i++)
	{
		lua_pushstring(pL, luaj_Audio[i].name);
		lua_pushcfunction(pL, luaj_Audio[i].func);
		lua_settable(pL, -3);
	}

	lua_setglobal(pL, "Audio");
}

static int Lua_CreateInputObject(lua_State *pL)
{
	lua_newtable(pL);

	for (int i = 0; i < LUA_INPUT_MEMBERS; i++)
	{
		lua_pushstring(pL, luaj_Input[i].name);
		lua_pushcfunction(pL, luaj_Input[i].func);
		lua_settable(pL, -3);
	}

	lua_setglobal(pL, "Input");
}

static int Lua_CreateTextureManagerObject(lua_State *pL)
{
	lua_newtable(pL);

	for (int i = 0; i < LUA_TM_MEMBERS; i++)
	{
		lua_pushstring(pL, luaj_TextureManager[i].name);
		lua_pushcfunction(pL, luaj_TextureManager[i].func);
		lua_settable(pL, -3);
	}

	lua_setglobal(pL, "TextureManager");
}

static int Lua_SetBgmVolume(lua_State *pL)
{
	int n = lua_gettop(pL);
	if (n < 1)
	{
		return 0;
	}

	int vol = luaL_checkinteger(pL, 1);

	Audio->setVolume(vol);

	return 0;
}

static int Lua_GetBgmVolume(lua_State *pL)
{

	int vol = Audio->getVolume();

	lua_pushinteger(pL, vol);

	return 1;
}

static int Lua_PlayMusic(lua_State *pL)
{
	int n = lua_gettop(pL);

	if (n < 3)
	{
		return 0;
	}

	// path
	std::string path = lua_tostring(pL, 1);

	// id
	std::string id = lua_tostring(pL, 2);

	// loop (int)
	int loop = lua_toboolean(pL, 3);

	if (loop == 0)
		loop = -1;

	bool result = Audio->load(path, id, SOUND_MUSIC);

	if (result)
	{
		Audio->playMusic(id, loop);
	}

	return 0;
}

static int Lua_InsertNextMusic(lua_State *pL)
{
	int n = lua_gettop(pL);

	if (n < 3)
	{
		return 0;
	}

	// path
	std::string path = lua_tostring(pL, 1);

	// id
	std::string id = lua_tostring(pL, 2);

	// loop (int)
	int loop = lua_toboolean(pL, 3);

	if (loop == 0)
		loop = -1;

	bool result = Audio->load(path, id, SOUND_MUSIC);

	if (result)
	{
		Audio->insertNextMusic(id, loop);
	}

	return 0;
}

static int Lua_PlaySound(lua_State *pL)
{
	int n = lua_gettop(pL);

	if (n < 3)
	{
		return 0;
	}

	// path
	std::string path = lua_tostring(pL, 1);

	// id
	std::string id = lua_tostring(pL, 2);

	// loop (int)
	int loop = lua_toboolean(pL, 3);

	if (loop == 0)
		loop = -1;

	bool result = Audio->load(path, id, SOUND_SFX);

	if (result)
	{
		Audio->playSound(id, loop);
	}

	return 0;
}

static int Lua_PauseMusic(lua_State *pL)
{

	Audio->pauseMusic();

	return 0;
}

static int Lua_StopMusic(lua_State *pL)
{

	Audio->stopMusic();

	return 0;
}

static int Lua_ResumeMusic(lua_State *pL)
{

	Audio->resumeMusic();

	return 0;
}

static int Lua_IsPlayingMusic(lua_State *pL)
{
	bool isPlaying = Audio->isPlaying();

	if (isPlaying)
	{
		lua_pushboolean(pL, 1);
	}
	else
	{
		lua_pushboolean(pL, 0);
	}

	return 1;
}

static int Lua_FadeOutMusic(lua_State *pL)
{
	int n = lua_gettop(pL);

	if (n < 1)
	{
		return 0;
	}

	int ms = luaL_checkinteger(pL, 1);

	Audio->fadeOutMusic(ms);

	return 0;
}

static int Lua_SetMusicPosition(lua_State *pL)
{
	int n = lua_gettop(pL);

	if (n < 1)
	{
		return 0;
	}

	double position = luaL_checknumber(pL, 1);

	Audio->setMusicPosition(position);

	return 0;
}

static int Lua_ReleaseMusic(lua_State *pL)
{
	int n = lua_gettop(pL);

	if (n < 1)
	{
		return 0;
	}

	std::string id = lua_tostring(pL, 1);

	Audio->releaseMusic(id);

	return 0;
}

static int Lua_Init()
{
	g_pLuaState = luaL_newstate();
	luaL_openlibs(g_pLuaState);

	lua_register(g_pLuaState, "MessageBox", Lua_MessageBox);
	Lua_CreateAudioObject(g_pLuaState);

	int result = luaL_dofile(g_pLuaState, "scripts/main.lua");
	if (result != LUA_OK)
	{
		MessageBox(NULL, "루아 스크립트 로드 실패", "실패", MB_OK);
	}

	lua_getglobal(g_pLuaState, "Initialize");
	lua_call(g_pLuaState, 0, 0);

	// TODO : 테이블 생성 시 아래 주소 참고 할 것.
	// https://forums.tigsource.com/index.php?topic=22524.0
	// 

	return 0;
}