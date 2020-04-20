#pragma once
#ifndef __PROCESS_H_
#define __PROCESS_H_

#define WIN32_LEAN_AND_MEAN
#include <Windows.h>
#include <tchar.h>
#include <string>
#include <exception>


namespace Initial2D {

	enum PROCESS_ERROR
	{
		FAILED = 0,
		OK = 1
	};

	class Process
	{
	public:
		Process(std::wstring filename);
		Process(const Process &e) : m_hWnd(e.m_hWnd) {}
		bool create(std::wstring filename);
		std::string catchError();
		std::wstring getWindowName();
		std::string toMBCS(std::wstring toUTF16);
		virtual ~Process();
	private:
		HWND m_hWnd;
	};

}

#endif