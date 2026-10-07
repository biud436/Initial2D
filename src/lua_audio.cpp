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

/**
 * @brief loop 인자를 SDL_mixer 루프 값으로 해석한다.
 *
 * 생략하거나 nil 이면 loopByDefault 가 참일 때 무한 반복(-1), 거짓일 때 한 번(onceValue).
 * 불리언이면 true = 무한 반복(-1), false = 한 번. 숫자면 SDL_mixer 값을 그대로 쓴다
 * (음악: 재생 횟수, 효과음: 추가 반복 횟수. 효과음에 1을 주면 두 번 재생된다).
 */
static int ResolveLoopArg(lua_State* pL, int index, int onceValue, bool loopByDefault)
{
	if (lua_isnoneornil(pL, index))
	{
		return loopByDefault ? -1 : onceValue;
	}
	if (lua_type(pL, index) == LUA_TBOOLEAN)
	{
		return lua_toboolean(pL, index) ? -1 : onceValue;
	}
	return static_cast<int>(luaL_checkinteger(pL, index));
}

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
	std::string path = luaL_checkstring(pL, 1);
	std::string id = luaL_checkstring(pL, 2);

	// loop: 생략하면 무한 반복, false 면 한 번 (Mix_FadeInMusic은 1이 한 번)
	int loop = ResolveLoopArg(pL, 3, 1, true);

	bool result = Audio->load(path, id, SOUND_MUSIC);

	if (result)
	{
		Audio->playMusic(id, loop);
	}

	lua_pushboolean(pL, result);
	return 1;
}

LUA_METHOD(InsertNextMusic)
{
	std::string path = luaL_checkstring(pL, 1);
	std::string id = luaL_checkstring(pL, 2);

	// loop: 생략하면 무한 반복, false 면 한 번
	int loop = ResolveLoopArg(pL, 3, 1, true);

	bool result = Audio->load(path, id, SOUND_MUSIC);

	if (result)
	{
		Audio->insertNextMusic(id, loop);
	}

	lua_pushboolean(pL, result);
	return 1;
}

LUA_METHOD(PlaySound)
{
	std::string path = luaL_checkstring(pL, 1);
	std::string id = luaL_checkstring(pL, 2);

	// loop: 생략하거나 false 면 한 번 (Mix_PlayChannel은 0이 한 번)
	int loop = ResolveLoopArg(pL, 3, 0, false);

	bool result = Audio->load(path, id, SOUND_SFX);

	if (result)
	{
		Audio->playSound(id, loop);
	}

	lua_pushboolean(pL, result);
	return 1;
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