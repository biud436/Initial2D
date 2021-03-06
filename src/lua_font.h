#ifndef _LUA_FONT_H_
#define _LUA_FONT_H_

#include "lua_tbl.h"

#define LUA_FONTEX_MEMBERS 10

int Lua_CreateFontExImpl(lua_State* pL);

static int Lua_CreateFontEx(lua_State *pL);
LUA_METHOD(UpdateFontEx);
LUA_METHOD(DrawFontEx);
LUA_METHOD(ReleaseFontEx);

LUA_CLASS(Set, FontEx, Text);
LUA_CLASS(Set, FontEx, Position);
LUA_CLASS(Set, FontEx, TextColor);
LUA_CLASS(Set, FontEx, Opacity);
LUA_CLASS(Get, FontEx, TextWidth);
LUA_CLASS(Set, FontEx, Angle);

#endif