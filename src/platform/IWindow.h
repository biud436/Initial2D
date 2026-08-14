#ifndef __PLATFORM_IWINDOW_H_
#define __PLATFORM_IWINDOW_H_

#include <string>

namespace Initial2D {
namespace Platform {

	/**
	 * @class IWindow
	 * @brief 창 생성·이벤트 펌프의 플랫폼 중립 인터페이스 (Phase 1 초안, Phase 2에서 확정).
	 *
	 * 구현체:
	 *  - Win32 어댑터: 기존 WndProc 기반 창 (platform/win32/, Phase 2)
	 *  - SDL2 어댑터: SDL_Window 기반 (platform/sdl2/, Phase 2 — 기존 src/Window.cpp 재사용)
	 */
	class IWindow
	{
	public:
		virtual ~IWindow() = default;

		virtual bool create(const std::string& title, int width, int height) = 0;

		/** 플랫폼 이벤트 큐를 비우고 엔진 이벤트로 변환한다. 매 프레임 호출된다. */
		virtual void pumpEvents() = 0;

		virtual bool isDone() const = 0;

		virtual void destroy() = 0;

		/** HWND 또는 SDL_Window*. 어댑터 내부 전용 — 게임 로직에서 캐스팅 금지. */
		virtual void* nativeHandle() const = 0;
	};

} // namespace Platform
} // namespace Initial2D

#endif
