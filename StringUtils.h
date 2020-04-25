#ifndef __STRINGUTILS_H_
#define __STRINGUTILS_H_

#define WIN32_LEAN_AND_MEAN
#include <string>
#include <Windows.h>

std::string ConvertWideCharToMultiByte(std::wstring& wstr, UINT codePage);
std::wstring ConvertMultiByteToWideChar(std::string& str, UINT codePage);

#endif