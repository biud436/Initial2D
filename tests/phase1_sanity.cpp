/**
 * @file phase1_sanity.cpp
 * @brief macOS 포팅 Phase 1 검증.
 *  - std 기반 Thread가 원본 인터페이스(start/join/run 오버라이드)대로 동작하는지
 *  - StringUtils/Utility가 Windows.h 없이 컴파일·동작하는지
 *  - 플랫폼 중립 인터페이스 헤더가 전부 컴파일되는지 (include만으로 검증)
 *  - SystemPath / PosixProcess의 POSIX 구현이 동작하는지
 */
#include "Thread.h"
#include "StringUtils.h"
#include "Utility.h"

#include "platform/IWindow.h"
#include "platform/IInputDevice.h"
#include "platform/IRenderDevice.h"
#include "platform/IGlyphRasterizer.h"
#include "platform/IProcess.h"
#include "platform/SystemPath.h"

#ifndef _WIN32
#include "platform/posix/PosixProcess.h"
#endif

#include <cstdio>
#include <string>

class SanityThread : public Thread
{
public:
	int value = 0;
	void run() override { value = 42; }
};

int main()
{
	// Thread (std::thread 공통화 검증)
	SanityThread thread;
	thread.start();
	thread.join();
	if (thread.value != 42) {
		std::fprintf(stderr, "FAIL: Thread run/join (value=%d)\n", thread.value);
		return 1;
	}

	// StringUtils (Windows.h 제거 후 동작 검증 — 기존 동작 그대로)
	if (GetFileExtension(".\\res\\mycomputer.png") != std::string(".png")) {
		std::fprintf(stderr, "FAIL: GetFileExtension\n");
		return 1;
	}
	const auto tokens = StrSplit("WOW,WOW,WOW", "WOW");
	if (tokens.size() != 3) {
		std::fprintf(stderr, "FAIL: StrSplit size=%zu\n", tokens.size());
		return 1;
	}

	// SystemPath
	const std::string exeDir = Initial2D::Platform::GetExecutableDirectory();
	if (exeDir.empty()) {
		std::fprintf(stderr, "FAIL: GetExecutableDirectory empty\n");
		return 1;
	}

#ifndef _WIN32
	// PosixProcess (posix_spawn)
	Initial2D::Platform::PosixProcess process;
	if (!process.create("true")) {
		std::fprintf(stderr, "FAIL: PosixProcess.create: %s\n", process.catchError().c_str());
		return 1;
	}
#endif

	std::printf("phase1 sanity OK — thread/std, string utils, platform headers, exe dir: %s\n",
		exeDir.c_str());
	return 0;
}
