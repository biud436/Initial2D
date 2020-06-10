#ifndef _LUA_TEXTURE_H_
#define _LUA_TEXTURE_H_

#include "lua_tbl.h"

LUA_METHOD(CreateTextureManagerObject);

// Lua TextureManager API from C
LUA_METHOD(LoadTexture);
LUA_METHOD(RemoveTexture);
LUA_METHOD(IsValidTexture);

#endif
