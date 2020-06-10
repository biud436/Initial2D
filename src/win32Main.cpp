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
#include <string>
#include "Thread.h"
#include "sqlite3.h"
#include "File.h"

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

void test_run_sqlite() 
{
	std::cout << "test" << std::endl;
	MyThread* myThread = new MyThread();
	myThread->start();
	myThread->join();
	std::cout << "exit" << std::endl;
	delete myThread;

	sqlite3 *sqlite = nullptr;
	char* errorMSG = nullptr;
	int result = 0;

	remove("db.sqlite");

	// init with sqlite
	result = sqlite3_open("db.sqlite", &sqlite);
	if (result != SQLITE_OK) {
		std::cout << "sqlite init fail" << std::endl;
		exit(-1);
	}

	// query
	std::string query = "create table if not exists TB_TSET(";
	query += "NO integer primary key autoincrement";
	query += ")";

	result = sqlite3_exec(sqlite, query.c_str(), NULL, NULL, &errorMSG);
	if (result == SQLITE_OK) {
		std::cout << "create table ok" << std::endl;
	}

	// insert
	query.clear();
	query += "insert into TB_TSET(NO) values (1), (2), (3)";

	result = sqlite3_exec(sqlite, query.c_str(), NULL, NULL, &errorMSG);
	if (result == SQLITE_OK) {
		std::cout << "insert query ok()" << std::endl;
	}

	// select

	query.clear();
	query += "select * from TB_TSET";
	sqlite3_stmt *stmt = nullptr;

	// http://www.hanbit.co.kr/media/openbook/cocos2d-x/06-2.html#
	// https://aroundck.tistory.com/5187
	result = sqlite3_prepare_v2(sqlite, query.c_str(), query.length(), &stmt, NULL);
	if (result == SQLITE_OK) {
		std::cout << "select query ok()" << std::endl;
		while (sqlite3_step(stmt) == SQLITE_ROW) {
			int no = sqlite3_column_int(stmt, 0);
			std::cout << no << std::endl;
		}
	}
	else {
		std::cout << "select query fail()" << std::endl;
		sqlite3_close(sqlite);
		exit(-1);
	}

	sqlite3_finalize(stmt);

	// close sqlite
	sqlite3_close(sqlite);
}

void test_run_file_system()
{
	Initial2D::File file;
	file.Open("my_test_file.txt", Initial2D::TextWrite);
	file.Write(std::string("¹¹Áö ÀÌ°Ç"));
	file.Close();
}

int main(int argc, char* argv)
{
	// test_run_sqlite();
	test_run_file_system();

	return 0;
}

#endif