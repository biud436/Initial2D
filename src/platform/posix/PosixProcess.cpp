#include "PosixProcess.h"

#include <spawn.h>
#include <sys/wait.h>
#include <cstring>
#include <cerrno>

extern char** environ;

namespace Initial2D {
namespace Platform {

	PosixProcess::~PosixProcess()
	{
		// 자식을 기다리지 않는 원본 Win32 Process와 동일한 정책.
		// 좀비 프로세스는 회수만 시도하고 블로킹하지 않는다.
		if (m_pid > 0) {
			int status = 0;
			waitpid(m_pid, &status, WNOHANG);
		}
	}

	bool PosixProcess::create(const std::string& command)
	{
#ifdef __ANDROID__
		// Android에서는 외부 프로세스 실행을 지원하지 않는다 (no-op 스텁).
		// posix_spawn은 bionic API 28+ 전용이며, 앱 샌드박스에서 셸 실행은 의미가 없다.
		// 상세: docs/porting/android-plan.md Phase A4
		(void)command;
		m_lastError = "process execution is not supported on Android";
		return false;
#else
		const char* argv[] = { "/bin/sh", "-c", command.c_str(), nullptr };

		pid_t pid = -1;
		const int result = posix_spawn(&pid, "/bin/sh", nullptr, nullptr,
			const_cast<char* const*>(argv), environ);

		if (result != 0) {
			m_lastError = std::strerror(result);
			return false;
		}

		m_pid = pid;
		return true;
#endif
	}

	std::string PosixProcess::catchError()
	{
		return m_lastError;
	}

} // namespace Platform
} // namespace Initial2D
