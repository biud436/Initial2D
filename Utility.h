#ifndef _UTILITY_H_
#define _UTILITY_H_

#define WIN32_LEAN_AND_MEAN
#include <Windows.h>
#include <Shlwapi.h>
#include <string>
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

class Utility
{
public:
	Utility();
	~Utility();
};

#endif
