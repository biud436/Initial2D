#ifndef _LUA_PROT_H__
#define _LUA_PROT_H__

#include "lua/lua.h"
#include "lua/lualib.h"
#include "lua/lauxlib.h"

int Lua_MessageBox(lua_State *g_pLuaSt);
int Lua_LoadScript(lua_State *pL);
int Lua_PreparaFont(lua_State *pL);
int Lua_DrawPoint(lua_State *pL);
int Lua_DrawSetColor(lua_State *pL);
int Lua_DrawText(lua_State *pL);
int Lua_WindowWidth(lua_State *pL);
int Lua_WindowHeight(lua_State *pL);
int Lua_GetFrameCount(lua_State *pL);
int Lua_GameExit(lua_State *pL);
int Lua_GetCurrentDirectory(lua_State *pL);
static int l_wcsprint(lua_State *pL);

int Lua_Init();
int Lua_Update(double elapsed);
int Lua_Render();
int Lua_Destory();

#endif