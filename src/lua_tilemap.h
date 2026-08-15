#ifndef _LUA_TILEMAP_H__
#define _LUA_TILEMAP_H__

#include "lua_tbl.h"

LUA_METHOD(CreateTilemapObject);

LUA_METHOD(TilemapLoad);
LUA_METHOD(TilemapDispose);
LUA_METHOD(TilemapDraw);
LUA_METHOD(TilemapGetSize);
LUA_METHOD(TilemapGetTileId);
LUA_METHOD(TilemapSetTileId);
LUA_METHOD(TilemapIsPassable);

#endif
