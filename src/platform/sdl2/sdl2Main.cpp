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
