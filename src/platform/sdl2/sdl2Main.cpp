/**
 * @file sdl2Main.cpp
 * @brief SDL2 엔트리 포인트 (비-Windows). win32Main.cpp의 WinMain에 대응한다.
 */
#include "Constants.h"

#ifndef RS_WINDOWS

#include "App.h"

int main(int argc, char* argv[])
{
	(void)argc;
	(void)argv;

	return App::GetInstance().Run(0);
}

#endif // !RS_WINDOWS
