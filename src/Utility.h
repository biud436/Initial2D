#ifndef _UTILITY_H_
#define _UTILITY_H_

#include <string>

#ifdef _WIN32

#define WIN32_LEAN_AND_MEAN
#include <Windows.h>
#include <Shlwapi.h>
#include <tchar.h>

#ifdef _UNICODE
using _TString = std::wstring;
#else
using _TString = std::string;
#endif

inline _TString GetWorkingDirectory()
{
	HMODULE hModule = GetModuleHandle(nullptr);
	if (!hModule)
	{
		return "";
	}

	TCHAR path[256];
	// 프로그램 실행 경로 획득한다.
	GetModuleFileName(hModule, path, sizeof(path));
	// 실행 경로에서 프로그램 명을 제외한다.
	PathRemoveFileSpec(path);
	_tcscat_s(path, "");

	return path;
}

#else

using _TString = std::string;

// 비-Windows에서의 실행 경로 획득은 platform/SystemPath.h의
// Initial2D::Platform::GetExecutableDirectory()를 사용한다.

#endif // _WIN32

class Utility
{
public:
	Utility();
	~Utility();
};

#endif
