#ifndef __PLATFORM_SDL2_SCANCODEMAP_H_
#define __PLATFORM_SDL2_SCANCODEMAP_H_

namespace Initial2D {
namespace Platform {

	/** SDL 키보드 상태(SDL_GetKeyboardState)를 Win32 VK 상태 배열로 옮긴다.
	 *
	 *  엔진과 Lua에 노출되는 키 코드는 전 플랫폼에서 VK_* 값이므로(스크립트 호환)
	 *  스캔코드를 VK로 옮기는 표가 필요하다. 그 표에는 **한 VK에 스캔코드가 둘
	 *  이상 붙는 경우**가 있다 — ESC와 안드로이드 뒤로가기는 스크립트에서 같은
	 *  키다. 그래서 대입이 아니라 "하나라도 눌렸으면 눌린 것"으로 합친다.
	 *
	 *  Input에서 떼어 낸 이유는 검증 때문이다. 실제 키보드 상태는 테스트에서
	 *  만들어 낼 수 없지만, 이 함수는 배열을 받으므로 가짜 상태로 부를 수 있다
	 *  (tests/unit/scancode_map_test.cpp).
	 *
	 *  @param keys     SDL_GetKeyboardState가 준 배열 (스캔코드로 색인)
	 *  @param numKeys  그 배열의 길이
	 *  @param vkState  채울 256칸 배열. 이 함수가 먼저 전부 RELEASED로 지운다.
	 *  @param latch    이벤트로 래치된 키 (256칸, 없으면 nullptr). 폴링 사이에
	 *                  눌렸다 떼어진 키를 1틱 PRESSED로 살려 주고 지운다.
	 */
	void ApplyScancodeState(const unsigned char* keys, int numKeys, unsigned char* vkState,
		unsigned char* latch = nullptr);

	/** SDL 스캔코드 하나에 대응하는 Win32 VK 값. 표에 없으면 0.
	 *  키 이벤트를 래치할 때 쓴다 (App::HandleEvent). */
	int ScancodeToVirtualKey(int scancode);

} // namespace Platform
} // namespace Initial2D

#endif
