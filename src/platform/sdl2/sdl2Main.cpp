/**
 * @file sdl2Main.cpp
 * @brief SDL2 엔트리 포인트 (비-Windows). win32Main.cpp의 WinMain에 대응한다.
 */
#include "Constants.h"

#ifndef RS_WINDOWS

#ifdef __ANDROID__
// SDLActivity가 JNI로 호출할 수 있도록 main을 SDL_main으로 매핑한다.
#include <SDL_main.h>
#endif

#include "App.h"

int main(int argc, char* argv[])
{
	(void)argc;
	(void)argv;

	return App::GetInstance().Run(0);
}

#endif // !RS_WINDOWS
