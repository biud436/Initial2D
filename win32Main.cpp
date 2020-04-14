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

#ifdef TEST_MODE
#undef RS_WINDOWS
#endif

#if defined(RS_WINDOWS)

#include <Windows.h>
#include <tchar.h>
#include "App.h"

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

#include <iostream>
#include "Thread.h"

class MyThread : public Thread {
public:
	MyThread() : Thread::Thread() 
	{
		OutputDebugString("MyThread();\n");
	}
	virtual ~MyThread() 
	{ 
		OutputDebugString("~MyThread();\n");
	}
	virtual void run() 
	{
		Thread::run();
		OutputDebugString("run();\n");
		std::cout << "myThread.run();" << std::endl;
	}
};

int main(int argc, char* argv)
{
	std::cout << "test" << std::endl;
	MyThread* myThread = new MyThread();
	myThread->start();
	myThread->join();
	std::cout << "exit" << std::endl;
	delete myThread;
	return 0;
}

#endif