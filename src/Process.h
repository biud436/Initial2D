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
		~Process();

		/**
		 * @brief Create the child process.
		 */
		bool create(std::wstring filename);

		/**
		 * @brief Catch the error.
		 */
		std::string catchError();

		/** 
		 * @brief This method allows you to convert character sets to WBCS
		 */
		std::wstring getWindowName();

		/**
		 * @brief This method allows you to convert character set to MBCS (CP_ACP)
		 */
		std::string toMBCS(std::wstring toUTF16);

		/**
		 * @brief Finds out an ID of the main thread.
		 */
		static DWORD FindMainThreadID(HANDLE process);

		/**
		 * @brief Get Process ID from the binary file name.
		 */
		static DWORD FindProcessID(std::string binaryName);

	private:
		HWND m_hWnd;
	};

}

#endif