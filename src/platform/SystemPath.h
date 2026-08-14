#ifndef __PLATFORM_SYSTEMPATH_H_
#define __PLATFORM_SYSTEMPATH_H_

#include <string>

namespace Initial2D {
namespace Platform {

	/** 실행 파일의 절대 경로 (UTF-8). 실패 시 빈 문자열. */
	std::string GetExecutablePath();

	/** 실행 파일이 있는 디렉터리의 절대 경로 (UTF-8). 실패 시 빈 문자열.
	 *  기존 Utility.h의 GetWorkingDirectory(), main.cpp의 GetExecutablePath()를 대체한다. */
	std::string GetExecutableDirectory();

} // namespace Platform
} // namespace Initial2D

#endif
