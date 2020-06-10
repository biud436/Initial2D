#ifndef _LUA_AUDIO_H_
#define _LUA_AUDIO_H_

#include "lua_tbl.h"

LUA_METHOD(CreateAudioObject);

// Lua Audio API from C
LUA_METHOD(PlayMusic);
LUA_METHOD(PlaySound);
LUA_METHOD(GetBgmVolume);
LUA_METHOD(SetBgmVolume);
LUA_METHOD(InsertNextMusic);
LUA_METHOD(PauseMusic);
LUA_METHOD(StopMusic);
LUA_METHOD(ResumeMusic);
LUA_METHOD(IsPlayingMusic);
LUA_METHOD(FadeOutMusic);
LUA_METHOD(SetMusicPosition);
LUA_METHOD(ReleaseMusic);

#endif