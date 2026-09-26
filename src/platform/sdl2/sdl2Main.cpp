/**
 * @file sdl2Main.cpp
 * @brief SDL2 엔트리 포인트 (비-Windows). win32Main.cpp의 WinMain에 대응한다.
 */
#include "Constants.h"

#ifndef RS_WINDOWS

#ifdef __ANDROID__
// SDLActivity가 JNI로 호출할 수 있도록 main을 SDL_main으로 매핑한다.
#include <SDL_main.h>
#include "../android/AndroidBootstrap.h"
#endif

#include "App.h"
#include "ScriptRuntime.h"

#include <cstdio>
#include <cstring>

// CMake 가 빌드마다 만드는 판 헤더 (cmake/initial2d_version.cmake). 그 헤더가 없는 빌드는 "unknown" 이다.
#if defined(__has_include)
#if __has_include("initial2d_version.h")
#include "initial2d_version.h"
#endif
#endif
#ifndef INITIAL2D_VERSION_DESCRIBE
#define INITIAL2D_VERSION_DESCRIBE "unknown"
#define INITIAL2D_VERSION_COMMIT "unknown"
#endif

static void PrintUsage()
{
	std::fprintf(stderr,
		"usage: Initial2D [--features | --version]\n"
		"  (no option)  run the game in the current directory\n"
		"  --features   print the script languages this build runs\n"
		"  --version    print \"Initial2D <describe> <commit>\"\n");
}

int main(int argc, char* argv[])
{
	// 에디터가 stdout 을 파이프로 받을 때 print 줄이 4KB 마다 뭉쳐 오지 않게 줄 단위로 내보낸다
	// (터미널에서는 원래 줄 단위다). SDL_Log 는 stderr 라 영향이 없다.
	std::setvbuf(stdout, nullptr, _IOLBF, 0);

	// `Initial2D --features` — 이 빌드가 실행할 수 있는 스크립트 언어를 찍고 끝난다
	// ("lua" 또는 "lua mruby"). 검수 러너가 mruby 테스트를 돌릴지 정할 때 쓴다.
	if (argc > 1 && std::strcmp(argv[1], "--features") == 0) {
		std::printf("%s\n", Script_Features().c_str());
		return 0;
	}

	// `Initial2D --version`: 판(git describe)과 커밋 40자를 한 줄로 찍고 끝난다
	if (argc > 1 && std::strcmp(argv[1], "--version") == 0) {
		std::printf("Initial2D %s %s\n", INITIAL2D_VERSION_DESCRIBE, INITIAL2D_VERSION_COMMIT);
		return 0;
	}

	// 모르는 "--" 인자는 게임을 띄우지 않고 종료 코드 2 로 끝난다 (-psn_ 같은 한 줄표 인자는 무시한다)
	for (int i = 1; i < argc; ++i) {
		if (std::strncmp(argv[i], "--", 2) == 0) {
			std::fprintf(stderr, "Initial2D: unknown option %s\n", argv[i]);
			PrintUsage();
			return 2;
		}
	}

#ifdef __ANDROID__
	// App 생성(설정 파일 읽기) 전에 assets 추출 + chdir이 끝나야 한다.
	if (!Initial2D::Platform::AndroidBootstrap()) {
		return 1;
	}
#endif

	const int rc = App::GetInstance().Run(0);
	// 스크립트 예외로 끝났으면 종료 코드로 알린다 (Lua 의 panic 과 같은 무게)
	return Script_Failed() ? 1 : rc;
}

#endif // !RS_WINDOWS
