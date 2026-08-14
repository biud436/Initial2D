#ifndef __PLATFORM_UTF8_H_
#define __PLATFORM_UTF8_H_

#include <string>

namespace Initial2D {
namespace Platform {

	/** UTF-8 → wstring (Windows: UTF-16, 그 외: UTF-32). 잘못된 시퀀스는 U+FFFD로 대체. */
	std::wstring Utf8ToWide(const std::string& utf8);

	/** wstring → UTF-8. */
	std::string WideToUtf8(const std::wstring& wide);

	/** 경로 구분자 '\\'를 '/'로 정규화한다 (비-Windows용). */
	std::string NormalizePath(std::string path);

} // namespace Platform
} // namespace Initial2D

#endif
