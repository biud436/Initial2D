#include "lua_audio.h"
#include "SoundManager.h"

extern lua_State* g_pLuaState;

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

LUA_METHOD(CreateAudioObject)
{
	lua_newtable(pL);

	for (int i = 0; i < LUA_AUDIO_MEMBERS; i++)
	{
		lua_pushstring(pL, luaj_Audio[i].name);
		lua_pushcfunction(pL, luaj_Audio[i].func);
		lua_settable(pL, -3);
	}

	lua_setglobal(pL, "Audio");

	return 0;
}

LUA_METHOD(SetBgmVolume)
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

LUA_METHOD(GetBgmVolume)
{

	int vol = Audio->getVolume();

	lua_pushinteger(pL, vol);

	return 1;
}

LUA_METHOD(PlayMusic)
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

LUA_METHOD(InsertNextMusic)
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

LUA_METHOD(PlaySound)
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

	// loop (boolean)
	int luaLoop = lua_toboolean(pL, 3);
	int loop;

	if (luaLoop)
		loop = -1; // 무한 반복
	else
		loop = 0;  // 한 번만 재생

	bool result = Audio->load(path, id, SOUND_SFX);

	if (result)
	{
		Audio->playSound(id, loop);
	}

	return 0;
}

LUA_METHOD(PauseMusic)
{

	Audio->pauseMusic();

	return 0;
}

LUA_METHOD(StopMusic)
{

	Audio->stopMusic();

	return 0;
}

LUA_METHOD(ResumeMusic)
{

	Audio->resumeMusic();

	return 0;
}

LUA_METHOD(IsPlayingMusic)
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

LUA_METHOD(FadeOutMusic)
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

LUA_METHOD(SetMusicPosition)
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

LUA_METHOD(ReleaseMusic)
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