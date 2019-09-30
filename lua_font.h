#ifndef _LUA_FONT_H_
#define _LUA_FONT_H_

#include "lua_tbl.h"

#define LUA_FONTEX_MEMBERS 8

LUA_METHOD(CreateFontExImpl);

// Lua Sprite API from C
LUA_METHOD(CreateFontEx);
LUA_METHOD(UpdateFontEx);
LUA_METHOD(DrawFontEx);
LUA_METHOD(ReleaseFontEx);

LUA_CLASS(Set, FontEx, Text);
LUA_CLASS(Set, FontEx, Position);
LUA_CLASS(Set, FontEx, TextColor);
LUA_CLASS(Set, FontEx, Opacity);

#endif