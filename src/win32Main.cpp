/**
 * @file win32Main.cpp
 * @date 2018/03/26 11:59
 *
 * @author biud436
 * Contact: biud436@gmail.com
 *
 * @brief 
 *
 *
 * @note
*/

#include "Constants.h"

#if defined(RS_WINDOWS)

#include <Windows.h>
#include <tchar.h>
#include "App.h"

/** @cond DO_NOT_INCLUDE */

LRESULT CALLBACK WndProc(HWND, UINT, WPARAM, LPARAM);

HWND g_hWnd;

int WINAPI WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpszParam, int nCmdShow)
{
	return App::GetInstance().Run(nCmdShow);
}

LRESULT CALLBACK WndProc(HWND hWnd, UINT uMsg, WPARAM wParam, LPARAM lParam)
{
	return App::GetInstance().HandleEvent(hWnd, uMsg, wParam, lParam);
}

#else

int RSGameMain(int argc, char* argv)
{
	return 0;
}

#endif

/** @endcond */