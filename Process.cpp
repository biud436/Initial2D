#include "Process.h"
#include "App.h"
#include "tlhelp32.h"

namespace Initial2D {


	Process::Process(std::wstring filename) :
		m_hWnd(NULL)
	{
		create(filename);
	}


	Process::~Process()
	{
	}

	bool Process::create(std::wstring filename)
	{
		STARTUPINFOW si;
		PROCESS_INFORMATION pi;
		ZeroMemory(&si, sizeof(STARTUPINFOW));
		ZeroMemory(&pi, sizeof(PROCESS_INFORMATION));

		si.cb = sizeof(STARTUPINFOW);
		si.hStdOutput = GetStdHandle(STD_OUTPUT_HANDLE);
		si.hStdError = GetStdHandle(STD_ERROR_HANDLE);
		si.dwFlags = STARTF_USESIZE | STARTF_USEPOSITION | STARTF_USESTDHANDLES;

		BOOL bRet = CreateProcessW(NULL, &filename[0], NULL, NULL, TRUE, NULL, NULL, NULL, &si, &pi);

		if (bRet == PROCESS_ERROR::FAILED)
		{
			CloseHandle(pi.hProcess);
			CloseHandle(pi.hThread);
			throw std::exception(catchError().c_str());
		}

		WaitForSingleObject(pi.hProcess, INFINITE);

		CloseHandle(pi.hProcess);
		CloseHandle(pi.hThread);

		return true;
	}


	std::string Process::catchError()
	{
		DWORD errorCode = GetLastError();

		if (errorCode == 0)
			return "";

		std::wstring buf;
		buf.resize(1024);

		const WORD LCID_ENGLISH = MAKELANGID(LANG_ENGLISH, SUBLANG_ENGLISH_US);
		const WORD LCID_DEFAULT = MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT);
		const WORD LCID_KOREAN = MAKELANGID(LANG_KOREAN, SUBLANG_KOREAN);

		DWORD dwRet = FormatMessageW(FORMAT_MESSAGE_FROM_SYSTEM, NULL, errorCode, LCID_DEFAULT, &buf[0], buf.size(), NULL);

		if (dwRet == PROCESS_ERROR::FAILED)
		{
			dwRet = FormatMessageW(FORMAT_MESSAGE_FROM_SYSTEM, NULL, errorCode, LCID_ENGLISH, &buf[0], buf.size(), NULL);
		}

		std::wstring swWindowName = getWindowName();

		MessageBoxW(m_hWnd, &buf[0], &swWindowName[0], MB_OK | MB_ICONERROR);

		return toMBCS(buf);

	}

	std::wstring Process::getWindowName()
	{
		std::string sWindowName = App::GetInstance().GetWindowName();
		m_hWnd = FindWindowA(NULL, &sWindowName[0]);

		// MBCS -> WBCS·Î º¯È¯
		int size = MultiByteToWideChar(CP_UTF8, 0, &sWindowName[0], sWindowName.size(), NULL, NULL);

		std::wstring swWindowName;
		swWindowName.resize(size);

		MultiByteToWideChar(CP_UTF8, 0, &sWindowName[0], sWindowName.size(), &swWindowName[0], size);

		return swWindowName;
	}

	std::string Process::toMBCS(std::wstring toUTF16)
	{
		int size = WideCharToMultiByte(CP_ACP, 0, &toUTF16[0], toUTF16.size(), NULL, 0, NULL, NULL);

		std::string sFromMBCS;
		sFromMBCS.resize(size);

		WideCharToMultiByte(CP_ACP, 0, &toUTF16[0], toUTF16.size(), &sFromMBCS[0], sFromMBCS.size(), NULL, NULL);

		return sFromMBCS;
	}

	DWORD Process::FindMainThreadID(HANDLE process)
	{
		THREADENTRY32 entry;
		ZeroMemory(&entry, sizeof(THREADENTRY32));
		entry.dwSize = sizeof(THREADENTRY32);

		HANDLE snapshot = CreateToolhelp32Snapshot(TH32CS_SNAPTHREAD, 0);

		if (Thread32First(snapshot, &entry)) 
		{
			DWORD processID = GetProcessId(process);

			while (Thread32Next(snapshot, &entry)) 
			{
				if (entry.th32OwnerProcessID == processID)
				{
					CloseHandle(snapshot);
					return entry.th32ThreadID;
				}
			}
		}

		CloseHandle(snapshot);
		
		return NULL;

	}

	DWORD Process::FindProcessID(std::string binaryName)
	{
		bool isFound = false;
		DWORD retProcessId = NULL;

		PROCESSENTRY32 entry;
		entry.dwSize = sizeof(PROCESSENTRY32);
		HANDLE snapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, NULL);

		if (Process32First(snapshot, &entry) == TRUE) {
			while (Process32Next(snapshot, &entry) == TRUE) {
				std::string binPath = entry.szExeFile;
				if (binPath.find("cheatengine-x86_64.exe") != std::string::npos) {
					isFound = true;
					break;
				}
				if (binPath.find("cheatengine-i386.exe") != std::string::npos) {
					isFound = true;
					break;
				}
			}
		}

		if (isFound) {
			retProcessId = entry.th32ProcessID;
		}
		else {
			retProcessId = static_cast<DWORD>(0);
		}

		CloseHandle(snapshot);

		return retProcessId;

	}

}

