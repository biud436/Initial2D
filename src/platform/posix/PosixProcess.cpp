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
	}

	std::string PosixProcess::catchError()
	{
		return m_lastError;
	}

} // namespace Platform
} // namespace Initial2D
