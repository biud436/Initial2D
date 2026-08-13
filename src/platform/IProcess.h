#ifndef __PLATFORM_IPROCESS_H_
#define __PLATFORM_IPROCESS_H_

#include <string>

namespace Initial2D {
namespace Platform {

	/**
	 * @class IProcess
	 * @brief 자식 프로세스 실행의 플랫폼 중립 인터페이스.
	 *
	 * 기존 Initial2D::Process(src/Process.h)의 공개 API 중 HWND/DWORD 등
	 * Win32 타입이 노출된 부분을 제외하고 실제 사용되는 기능만 중립화했다.
	 * (현재 엔진 내 실사용 호출처는 main.cpp의 주석 처리된 코드뿐)
	 *
	 * 구현체:
	 *  - Win32 어댑터: 기존 Process(CreateProcess) 유지 (src/Process.h — 무수정 보존)
	 *  - POSIX 어댑터: posix_spawn (platform/posix/PosixProcess.cpp)
	 */
	class IProcess
	{
	public:
		virtual ~IProcess() = default;

		/** @param command UTF-8 커맨드 라인 (셸을 통해 해석된다) */
		virtual bool create(const std::string& command) = 0;

		/** 마지막 오류 메시지를 반환한다. 기존 Process::catchError()에 대응. */
		virtual std::string catchError() = 0;
	};

} // namespace Platform
} // namespace Initial2D

#endif
