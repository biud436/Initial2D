#ifndef __STRINGUTILS_H_
#define __STRINGUTILS_H_

#include <string>
#include <vector>

#ifdef _WIN32
// Win32 전용 문자셋 변환 함수 (macOS 포팅 Phase 1에서 격리).
// 현재 엔진 내 호출처는 없으나 Windows 하위 호환을 위해 유지한다.
// UINT는 unsigned int의 별칭이므로 시그니처 호환이 유지된다.
std::string ConvertWideCharToMultiByte(std::wstring& wstr, unsigned int codePage);
std::wstring ConvertMultiByteToWideChar(std::string& str, unsigned int codePage);
#endif

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
