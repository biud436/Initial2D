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
	// ���α׷� ���� ��� ȹ���Ѵ�.
	GetModuleFileName(hModule, path, sizeof(path));
	// ���� ��ο��� ���α׷� ���� �����Ѵ�.
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
