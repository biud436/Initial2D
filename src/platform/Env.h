/**
 * @file Env.h
 * @brief INITIAL2D_* 설정을 읽는 얇은 wrapper (R3, docs/plans/r3-emscripten.md).
 * @details 엔진은 개발과 검수용 설정을 환경 변수로 받는다 (INITIAL2D_WINDOW,
 *          INITIAL2D_SCRIPT, INITIAL2D_EXIT_AFTER 등). 브라우저에는 프로세스 환경이
 *          없으므로 에디터와 웹 페이지는 같은 이름을 `Module.initial2dEnv` 객체로 넘긴다.
 *          C++ 쪽 getenv 호출은 전부 이 함수를 거치고, 네이티브에서는 std::getenv 와
 *          같은 것이라 동작이 바뀌지 않는다 (헤더 인라인이라 Windows 프로젝트 파일에
 *          더할 소스도 없다).
 *
 *          Emscripten 에서는 Module.initial2dEnv[name] 을 먼저 보고, 없으면 getenv 로
 *          내려간다 (로더가 Module.ENV 에도 같은 값을 넣어 두므로 Lua 의 os.getenv 도
 *          같은 값을 본다). 구현은 platform/emscripten/Env.cpp.
 */
#pragma once

#include <cstdlib>

namespace Initial2D {
namespace Platform {

#ifdef __EMSCRIPTEN__
	/** 반환 포인터는 getenv 처럼 프로세스가 사는 동안 유효하다 (값은 처음 읽은 것을 캐시한다). */
	const char* GetEnv(const char* name);
#else
	inline const char* GetEnv(const char* name)
	{
		return std::getenv(name);
	}
#endif

} // namespace Platform
} // namespace Initial2D
