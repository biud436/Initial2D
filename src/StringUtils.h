#ifndef __STRINGUTILS_H_
#define __STRINGUTILS_H_

#define WIN32_LEAN_AND_MEAN
#include <string>
#include <Windows.h>
#include <vector>

std::string ConvertWideCharToMultiByte(std::wstring& wstr, UINT codePage);
std::wstring ConvertMultiByteToWideChar(std::string& str, UINT codePage);

/**
 * 문자열을 자른 후 std::vector<std::string> 형태로 반환합니다.
 * 
 * @example
 * std::vector<std::string>::iterator iter;
 * auto str = StrSplit("WOW,WOW,WOW,WOW", "WOW");
 * for(iter = str.begin(); iter != str.end(); iter++) {
 * 	std::cout << *iter << std::endl;
 * }	
 *
 * output :
 * => WOW
 * => WOW
 * => WOW
 * => WOW
 */
std::vector<std::string> StrSplit(std::string data, std::string find_at);

std::string GetParentDirectory(const char* path);
std::string GetFileName(const char* path);
std::string GetFileExtension(const char* path);

#endif