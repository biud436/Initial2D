#ifndef __PLATFORM_POSIX_PROCESS_H_
#define __PLATFORM_POSIX_PROCESS_H_

#include "../IProcess.h"
#include <sys/types.h>

namespace Initial2D {
namespace Platform {

	/**
	 * @class PosixProcess
	 * @brief posix_spawn 기반 IProcess 구현 (macOS/Linux).
	 *
	 * 기존 Win32 Process(src/Process.h)와 동일하게 자식 프로세스를 기다리지 않는다.
	 */
	class PosixProcess : public IProcess
	{
	public:
		PosixProcess() = default;
		~PosixProcess() override;

		bool create(const std::string& command) override;
		std::string catchError() override;

	private:
		pid_t m_pid = -1;
		std::string m_lastError;
	};

} // namespace Platform
} // namespace Initial2D

#endif
