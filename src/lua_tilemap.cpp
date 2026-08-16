/**
 * @file lua_tilemap.cpp
 * @brief 타일맵 Lua 바인딩 (2단계, docs/plans/02-tilemap.md).
 *
 * Lua API (핸들은 Sprite와 같은 포인터 핸들 방식):
 *  - Tilemap.Load(path) -> handle | nil, 오류 메시지
 *  - Tilemap.Dispose(handle)
 *  - Tilemap.Draw(handle, layerFrom, layerTo [, camX, camY])
 *  - Tilemap.GetSize(handle) -> width, height, tileWidth, tileHeight, layerCount
 *  - Tilemap.GetTileId(handle, x, y, layer) -> gid
 *  - Tilemap.SetTileId(handle, x, y, layer, gid) -> boolean
 *  - Tilemap.IsPassable(handle, x, y) -> boolean
 *
 * 좌표 규약: x, y는 0 기준 타일 좌표 (맵 데이터·에디터와 동일),
 * layer는 1 기준 인덱스 (Lua 배열 관례). camX, camY는 월드 픽셀.
 */
#include <cstdint>
#include "lua_tilemap.h"
#include "Tilemap.h"

extern lua_State* g_pLuaState;

namespace {

	Initial2D::Tilemap* ToTilemap(lua_State* pL, int index)
	{
		uintptr_t d = (uintptr_t)lua_tonumber(pL, index);
		return (Initial2D::Tilemap*)d;
	}
}

LuaObjectToken luaj_Tilemap[LUA_TILEMAP_MEMBERS] = {
	{ "Load", LUA_METHOD_P1(TilemapLoad) },
	{ "Dispose", LUA_METHOD_P1(TilemapDispose) },
	{ "Draw", LUA_METHOD_P1(TilemapDraw) },
	{ "GetSize", LUA_METHOD_P1(TilemapGetSize) },
	{ "GetTileId", LUA_METHOD_P1(TilemapGetTileId) },
	{ "SetTileId", LUA_METHOD_P1(TilemapSetTileId) },
	{ "IsPassable", LUA_METHOD_P1(TilemapIsPassable) },
};

LUA_METHOD(CreateTilemapObject)
{
	lua_newtable(pL);

	for (int i = 0; i < LUA_TILEMAP_MEMBERS; i++)
	{
		lua_pushstring(pL, luaj_Tilemap[i].name);
		lua_pushcfunction(pL, luaj_Tilemap[i].func);
		lua_settable(pL, -3);
	}

	lua_setglobal(pL, "Tilemap");

	return 0;
}

/**
 * local handle, err = Tilemap.Load(path)
 */
LUA_METHOD(TilemapLoad)
{
	std::string path = luaL_checkstring(pL, 1);

	Initial2D::Tilemap* pMap = new Initial2D::Tilemap();
	if (!pMap->load(path))
	{
		std::string error = pMap->lastError();
		delete pMap;
		lua_pushnil(pL);
		lua_pushstring(pL, error.c_str());
		return 2;
	}

	lua_pushnumber(pL, (uintptr_t)pMap);
	return 1;
}

/**
 * Tilemap.Dispose(handle) — 해제 후 같은 핸들 사용은 금지.
 * (타일셋 텍스처는 TextureManager가 소유하므로 함께 해제되지 않는다)
 */
LUA_METHOD(TilemapDispose)
{
	Initial2D::Tilemap* p = ToTilemap(pL, 1);

	if (!p)
	{
		return 0;
	}

	delete p;
	return 0;
}

/**
 * Tilemap.Draw(handle, layerFrom, layerTo [, camX, camY])
 * layerFrom..layerTo는 1 기준, 양 끝 포함.
 */
LUA_METHOD(TilemapDraw)
{
	Initial2D::Tilemap* p = ToTilemap(pL, 1);

	if (!p)
	{
		return 0;
	}

	int layerFrom = (int)luaL_checkinteger(pL, 2);
	int layerTo = (int)luaL_checkinteger(pL, 3);
	int camX = (int)luaL_optinteger(pL, 4, 0);
	int camY = (int)luaL_optinteger(pL, 5, 0);

	p->draw(layerFrom - 1, layerTo - 1, camX, camY);
	return 0;
}

/**
 * local w, h, tileW, tileH, layers = Tilemap.GetSize(handle)
 */
LUA_METHOD(TilemapGetSize)
{
	Initial2D::Tilemap* p = ToTilemap(pL, 1);

	if (!p)
	{
		return 0;
	}

	lua_pushinteger(pL, p->width());
	lua_pushinteger(pL, p->height());
	lua_pushinteger(pL, p->tileWidth());
	lua_pushinteger(pL, p->tileHeight());
	lua_pushinteger(pL, p->layerCount());
	return 5;
}

/**
 * local gid = Tilemap.GetTileId(handle, x, y, layer) — 범위 밖은 0.
 */
LUA_METHOD(TilemapGetTileId)
{
	Initial2D::Tilemap* p = ToTilemap(pL, 1);

	if (!p)
	{
		lua_pushinteger(pL, 0);
		return 1;
	}

	int x = (int)luaL_checkinteger(pL, 2);
	int y = (int)luaL_checkinteger(pL, 3);
	int layer = (int)luaL_checkinteger(pL, 4);

	lua_pushinteger(pL, p->getTileId(x, y, layer - 1));
	return 1;
}

/**
 * local ok = Tilemap.SetTileId(handle, x, y, layer, gid)
 */
LUA_METHOD(TilemapSetTileId)
{
	Initial2D::Tilemap* p = ToTilemap(pL, 1);

	if (!p)
	{
		lua_pushboolean(pL, 0);
		return 1;
	}

	int x = (int)luaL_checkinteger(pL, 2);
	int y = (int)luaL_checkinteger(pL, 3);
	int layer = (int)luaL_checkinteger(pL, 4);
	int gid = (int)luaL_checkinteger(pL, 5);

	lua_pushboolean(pL, p->setTileId(x, y, layer - 1, gid) ? 1 : 0);
	return 1;
}

/**
 * local passable = Tilemap.IsPassable(handle, x, y) — 범위 밖은 false.
 */
LUA_METHOD(TilemapIsPassable)
{
	Initial2D::Tilemap* p = ToTilemap(pL, 1);

	if (!p)
	{
		lua_pushboolean(pL, 0);
		return 1;
	}

	int x = (int)luaL_checkinteger(pL, 2);
	int y = (int)luaL_checkinteger(pL, 3);

	lua_pushboolean(pL, p->isPassable(x, y) ? 1 : 0);
	return 1;
}
