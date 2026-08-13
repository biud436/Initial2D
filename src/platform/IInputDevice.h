#ifndef __PLATFORM_IINPUTDEVICE_H_
#define __PLATFORM_IINPUTDEVICE_H_

namespace Initial2D {
namespace Platform {

	/**
	 * @class IInputDevice
	 * @brief 키 입력 폴링의 플랫폼 중립 인터페이스 (Phase 1 초안, Phase 4에서 확정).
	 *
	 * 키 코드는 기존 Win32 VK_* 값을 중립 표준으로 사용한다.
	 * Lua 스크립트(lua_input.cpp)에 노출된 키 코드 값과의 호환성이 최우선이므로
	 * SDL2 어댑터가 SDL_Scancode → VK 값으로 변환할 책임을 진다.
	 */
	class IInputDevice
	{
	public:
		virtual ~IInputDevice() = default;

		/** 매 프레임 키 상태 스냅샷을 갱신한다. */
		virtual void update() = 0;

		/** @param virtualKey 기존 VK_* 계열 키 코드 */
		virtual bool isKeyDown(int virtualKey) const = 0;
	};

} // namespace Platform
} // namespace Initial2D

#endif
