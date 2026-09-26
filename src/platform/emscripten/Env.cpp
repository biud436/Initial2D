/**
 * @file Env.cpp
 * @brief Platform::GetEnv 의 Emscripten 구현 (R3).
 * @details 로더(tools/web/initial2d-loader.js)가 Module.initial2dEnv 에 넣어 둔 설정을
 *          읽는다. 값은 문자열로 바꿔 캐시하므로 getenv 와 같은 수명 규칙을 지킨다.
 *          initial2dEnv 에 없으면 libc getenv 로 내려간다 (로더가 Module.ENV 에도
 *          같은 값을 넣으므로 보통은 같은 답이 나온다).
 */
#ifdef __EMSCRIPTEN__

#include "../Env.h"

#include <emscripten.h>

#include <cstdlib>
#include <map>
#include <string>

namespace {

	// 이름 -> 값. 한 번 읽은 값은 프로세스가 사는 동안 같은 주소를 돌려준다.
	// (에디터가 reload 때 initial2dEnv 를 바꾸면 여기의 캐시도 함께 갱신한다)
	std::map<std::string, std::string> g_cache;

	// Module.initial2dEnv[name] 이 있으면 malloc 한 UTF-8 문자열, 없으면 0.
	char* ReadFromModule(const char* name)
	{
		return static_cast<char*>(EM_ASM_PTR({
			var name = UTF8ToString($0);
			var env = Module['initial2dEnv'];
			if (!env || typeof env !== 'object') return 0;
			if (!Object.prototype.hasOwnProperty.call(env, name)) return 0;
			var value = env[name];
			if (value === null || value === undefined || value === false) return 0;
			return stringToNewUTF8(String(value));
		}, name));
	}

} // namespace

namespace Initial2D {
namespace Platform {

	const char* GetEnv(const char* name)
	{
		if (name == nullptr) {
			return nullptr;
		}

		char* fromModule = ReadFromModule(name);
		if (fromModule != nullptr) {
			std::string& slot = g_cache[name];
			slot = fromModule;
			std::free(fromModule);
			return slot.c_str();
		}

		return std::getenv(name);
	}

} // namespace Platform
} // namespace Initial2D

#endif // __EMSCRIPTEN__
