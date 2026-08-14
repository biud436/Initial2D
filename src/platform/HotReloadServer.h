/**
 * @file HotReloadServer.h
 * @brief Lua 스크립트 핫 리로드용 TCP 수신 서버 (개발 전용, 비-Windows).
 * @details 백그라운드 스레드가 루프백(127.0.0.1)으로 Lua 번들을 수신해 큐에 적재한다.
 *          파일 기록과 VM 재시작은 메인 루프가 TakeBundle()로 가져가 수행한다.
 *          프로토콜·사용법: docs/porting/android-hmr-plan.md (이슈 #16)
 */
#pragma once

#include <string>
#include <vector>

namespace Initial2D {
namespace Platform {

	struct HotReloadFile {
		std::string path;        // '/' 구분 상대 경로 (검증 완료 상태)
		std::vector<char> data;
	};

	namespace HotReloadServer {

		// 수신 스레드를 시작한다. 이미 실행 중이거나 성공하면 true.
		bool Start(int port);

		// 대기 중인 번들이 있으면 out으로 옮기고 true를 반환한다. (메인 스레드 전용)
		bool TakeBundle(std::vector<HotReloadFile>& out);

		void Stop();

	} // namespace HotReloadServer

} // namespace Platform
} // namespace Initial2D
