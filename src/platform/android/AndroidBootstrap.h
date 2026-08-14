/**
 * @file AndroidBootstrap.h
 * @brief APK assets를 내부 저장소로 추출하고 작업 디렉터리를 옮긴다. (Phase A1)
 * @details 엔진은 상대 경로 fopen으로 파일을 읽지만 APK의 assets는 파일 시스템이
 *          아니다. 최초 실행(또는 에셋 변경) 시 assets 전체를 내부 저장소로 추출한 뒤
 *          chdir 하여, 게임 로직·Lua 스크립트 무수정으로 기존 경로가 동작하게 한다.
 *          상세: docs/porting/android-plan.md
 */
#pragma once

namespace Initial2D {
namespace Platform {

	// 성공 시 cwd가 내부 저장소로 바뀐 상태로 true를 반환한다.
	// App 생성(설정 파일 읽기) 이전에 호출해야 한다.
	bool AndroidBootstrap();

} // namespace Platform
} // namespace Initial2D
