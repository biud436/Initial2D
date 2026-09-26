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
#include "ExceptionText.h"
#include "platform/Env.h"

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
	// Script_Restart 가 도는 동안 켜진다. 이때의 스크립트 오류는 게임을 끝내지 않는다.
	bool s_restarting = false;

	// 백엔드가 오류를 보고한 뒤 부른다 (메시지는 백엔드가 이미 stderr 에 적었다).
	// 첫 오류에서 게임을 끝내고 종료 코드는 1 이 된다. 재시작(핫 리로드) 중이면 게임은 두고
	// 스크립트만 멈춘다. 다음 재시작이 성공하면 되살아난다.
	void MarkFailed()
	{
		if (s_failed)
		{
			return;
		}
		s_failed = true;
		if (!s_restarting)
		{
			App::GetInstance().Quit();
		}
	}

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
#ifdef __EMSCRIPTEN__
	// 브라우저 빌드 표시. 에디터가 "wasm" 을 보고 내장 실행(E4)을 연다.
	features += " wasm";
#endif
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
			MarkFailed();
		}
		return rc;
#else
		std::fprintf(stderr,
			"mruby: this build has no mruby. Install it (brew install mruby) and run cmake again,\n"
			"       or select Lua with INITIAL2D_SCRIPT=lua.\n");
		MarkFailed();
		return 1;
#endif
	}

	s_initialized = true;
	{
		const int rc = Lua_Init();
		if (Lua_Failed())
		{
			MarkFailed();
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
			MarkFailed();
		}
		return rc;
	}
#endif
	{
		const int rc = Lua_Update(elapsed);
		if (Lua_Failed())
		{
			MarkFailed();
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
			MarkFailed();
		}
		return rc;
	}
#endif
	{
		const int rc = Lua_Render();
		if (Lua_Failed())
		{
			MarkFailed();
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
			MarkFailed();
		}
		return rc;
	}
#endif
	{
		const int rc = Lua_Destory();
		if (Lua_Failed())
		{
			MarkFailed();
		}
		return rc;
	}
}

bool Script_Restart()
{
	struct RestartScope
	{
		RestartScope() { s_restarting = true; }
		~RestartScope() { s_restarting = false; }
	} scope;

	try
	{
		Script_Destroy();
		// 내린 VM 의 실패(이전 오류, destroy 훅의 오류)는 새 VM 의 성패와 상관없다
		s_failed = false;
		Script_Init();
	}
	catch (...)
	{
		// 바인딩 밖의 엔진 코드가 던진 C++ 예외. VM 의 상태를 믿을 수 없으므로 닫지 않고 버린다.
		// 스크립트 오류와 같이 스크립트만 멈추고(Update, Render, Destroy 를 건너뛴다) 다음 재시작을 기다린다.
		std::fprintf(stderr, "script restart failed: %s\n", Initial2D::CurrentExceptionText().c_str());
		std::fflush(stderr);
		s_initialized = false;
		s_failed = true;
	}
	return !s_failed;
}

bool Script_Failed()
{
	return s_failed;
}
