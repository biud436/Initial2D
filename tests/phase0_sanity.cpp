/**
 * @file phase0_sanity.cpp
 * @brief macOS 포팅 Phase 0 검증 — vendored lua/sqlite3/jsoncpp가
 *        macOS에서 빌드·링크·실행되는지 확인하는 최소 프로그램.
 */
// vendored Lua는 C++로 컴파일되므로 엔진과 동일하게 extern "C" 없이 직접 include한다
// (lua.hpp의 extern "C" 선언은 심볼 맹글링 불일치를 일으킴)
#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"
#include "sqlite3.h"
#include "json/json.h"
#include <cstdio>

int main()
{
	// Lua
	lua_State* L = luaL_newstate();
	luaL_openlibs(L);
	if (luaL_dostring(L, "x = 1 + 2") != LUA_OK) {
		std::fprintf(stderr, "FAIL: lua_dostring\n");
		return 1;
	}
	lua_getglobal(L, "x");
	const int x = static_cast<int>(lua_tointeger(L, -1));
	lua_close(L);
	if (x != 3) {
		std::fprintf(stderr, "FAIL: lua result %d != 3\n", x);
		return 1;
	}

	// SQLite (in-memory)
	sqlite3* db = nullptr;
	if (sqlite3_open(":memory:", &db) != SQLITE_OK) {
		std::fprintf(stderr, "FAIL: sqlite3_open\n");
		return 1;
	}
	char* errMsg = nullptr;
	if (sqlite3_exec(db, "CREATE TABLE t(a INTEGER); INSERT INTO t VALUES (42);", nullptr, nullptr, &errMsg) != SQLITE_OK) {
		std::fprintf(stderr, "FAIL: sqlite3_exec: %s\n", errMsg ? errMsg : "?");
		sqlite3_close(db);
		return 1;
	}
	sqlite3_close(db);

	// jsoncpp
	Json::Value root;
	Json::Reader reader;
	if (!reader.parse("{\"engine\":\"Initial2D\"}", root) || root["engine"].asString() != "Initial2D") {
		std::fprintf(stderr, "FAIL: jsoncpp parse\n");
		return 1;
	}

	std::printf("phase0 sanity OK — %s / sqlite %s / jsoncpp\n", LUA_RELEASE, sqlite3_libversion());
	return 0;
}
