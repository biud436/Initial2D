#ifndef _LUA_INPUT_H_
#define _LUA_INPUT_H_

#include "lua_tbl.h"

LUA_METHOD(CreateInputObject);

// Lua Input API from C
LUA_METHOD(IsKeyDown);
LUA_METHOD(IsKeyUp);
LUA_METHOD(IsKeyPress);
LUA_METHOD(IsAnyKeyDown);
LUA_METHOD(GetMouseX);
LUA_METHOD(GetMouseY);
LUA_METHOD(IsMouseDown);
LUA_METHOD(IsMouseUp);
LUA_METHOD(IsMousePress);
LUA_METHOD(IsAnyMouseDown);
LUA_METHOD(GetMouseZ);
LUA_METHOD(SetMouseZ);

#endif