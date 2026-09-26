/**
 * @file ScriptRuntime.cpp
 * @brief 스크립트 백엔드 선택과 Lua/mruby 진입점 분기 (S1).
 */
#include "ScriptRuntime.h"
#include "lua_prot.h"

#ifdef INITIAL2D_HAS_MRUBY
#include "mrb_prot.h"
#endif

#include "App.h"

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <fstream>
#include <string>

#include "json/json.h"

namespace
{
	bool s_decided = false;
	ScriptBackend s_backend = ScriptBackend::Lua;
	bool s_initialized = false;
	bool s_failed = false;

	bool FileExists(const char* path)
	{
		std::ifstream file(path);
		return file.good();
	}

	// "lua" / "mruby" 문자열을 백엔드로. 모르는 값이면 false.
	bool ParseBackend(const std::string& raw, ScriptBackend& out)
	{
		std::string name;
		for (char c : raw)
		{
			name += static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
		}
		if (name == "lua")
		{
			out = ScriptBackend::Lua;
			return true;
		}
		if (name == "mruby" || name == "ruby" || name == "rb")
		{
			out = ScriptBackend::MRuby;
			return true;
		}
		return false;
	}

	ScriptBackend Decide()
	{
		ScriptBackend backend = ScriptBackend::Lua;

		// 1. 환경 변수
		const char* env = std::getenv("INITIAL2D_SCRIPT");
		if (env != nullptr && *env != '\0')
		{
			if (ParseBackend(env, backend))
			{
				return backend;
			}
			std::fprintf(stderr, "INITIAL2D_SCRIPT=%s: unknown backend (lua | mruby), using lua\n", env);
			return ScriptBackend::Lua;
		}

		// 2. game.json 의 "script"
		std::ifstream file("./game.json", std::ifstream::binary);
		if (file.good())
		{
			try
			{
				Json::Value root;
				file >> root;
				const std::string script = root.get("script", "").asString();
				if (!script.empty())
				{
					if (ParseBackend(script, backend))
					{
						return backend;
					}
					std::fprintf(stderr, "game.json script=%s: unknown backend (lua | mruby), using lua\n",
						script.c_str());
					return ScriptBackend::Lua;
				}
			}
			catch (const std::exception& e)
			{
				std::fprintf(stderr, "game.json parse error: %s\n", e.what());
			}
		}

		// 3. 진입 파일로 추정. main.lua 가 있으면 언제나 Lua 다 (기존 프로젝트를 깨지 않는다).
		if (!FileExists("./scripts/lua/main.lua") && FileExists("./scripts/ruby/main.rb"))
		{
			return ScriptBackend::MRuby;
		}
		return ScriptBackend::Lua;
	}
}

ScriptBackend Script_Backend()
{
	if (!s_decided)
	{
		s_backend = Decide();
		s_decided = true;
	}
	return s_backend;
}

const char* Script_BackendName()
{
	return Script_Backend() == ScriptBackend::MRuby ? "mruby" : "lua";
}

bool Script_HasMRuby()
{
#ifdef INITIAL2D_HAS_MRUBY
	return true;
#else
	return false;
#endif
}

std::string Script_Features()
{
	std::string features = "lua";
	if (Script_HasMRuby())
	{
		features += " mruby";
	}
	return features;
}

int Script_Init()
{
	if (Script_Backend() == ScriptBackend::MRuby)
	{
#ifdef INITIAL2D_HAS_MRUBY
		s_initialized = true;
		const int rc = MRuby_Init();
		if (MRuby_Failed())
		{
			s_failed = true;
		}
		return rc;
#else
		std::fprintf(stderr,
			"mruby: this build has no mruby. Install it (brew install mruby) and run cmake again,\n"
			"       or select Lua with INITIAL2D_SCRIPT=lua.\n");
		s_failed = true;
		App::GetInstance().Quit();
		return 1;
#endif
	}

	s_initialized = true;
	{
		const int rc = Lua_Init();
		if (Lua_Failed())
		{
			s_failed = true;
		}
		return rc;
	}
}

int Script_Update(double elapsed)
{
	if (!s_initialized)
	{
		return 0;
	}
#ifdef INITIAL2D_HAS_MRUBY
	if (Script_Backend() == ScriptBackend::MRuby)
	{
		const int rc = MRuby_Update(elapsed);
		if (MRuby_Failed())
		{
			s_failed = true;
		}
		return rc;
	}
#endif
	{
		const int rc = Lua_Update(elapsed);
		if (Lua_Failed())
		{
			s_failed = true;
		}
		return rc;
	}
}

int Script_Render()
{
	if (!s_initialized)
	{
		return 0;
	}
#ifdef INITIAL2D_HAS_MRUBY
	if (Script_Backend() == ScriptBackend::MRuby)
	{
		const int rc = MRuby_Render();
		if (MRuby_Failed())
		{
			s_failed = true;
		}
		return rc;
	}
#endif
	{
		const int rc = Lua_Render();
		if (Lua_Failed())
		{
			s_failed = true;
		}
		return rc;
	}
}

int Script_Destroy()
{
	if (!s_initialized)
	{
		return 0;
	}
	s_initialized = false;
#ifdef INITIAL2D_HAS_MRUBY
	if (Script_Backend() == ScriptBackend::MRuby)
	{
		const int rc = MRuby_Destroy();
		if (MRuby_Failed())
		{
			s_failed = true;
		}
		return rc;
	}
#endif
	{
		const int rc = Lua_Destory();
		if (Lua_Failed())
		{
			s_failed = true;
		}
		return rc;
	}
}

bool Script_Failed()
{
	return s_failed;
}
