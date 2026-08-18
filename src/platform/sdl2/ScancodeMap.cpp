/**
 * @file ScancodeMap.cpp
 * @brief SDL 스캔코드 → Win32 VK 상태 변환 (InputSDL2에서 떼어 낸 순수 함수).
 */
#include "Constants.h"

#ifndef RS_WINDOWS

#include "ScancodeMap.h"

#include "platform/WinTypes.h"
#include "Input.h"      // RELEASED / PRESSED

#include <SDL.h>
#include <cstring>

namespace {

	struct ScancodeToVK
	{
		SDL_Scancode scancode;
		int vk;
	};

	// 엔진/Lua가 사용할 수 있는 주요 키만 매핑한다. 필요 시 추가.
	const ScancodeToVK KEY_TABLE[] = {
		{ SDL_SCANCODE_BACKSPACE, VK_BACK },
		{ SDL_SCANCODE_TAB,       VK_TAB },
		{ SDL_SCANCODE_RETURN,    VK_RETURN },
		{ SDL_SCANCODE_ESCAPE,    VK_ESCAPE },
		{ SDL_SCANCODE_SPACE,     VK_SPACE },
		{ SDL_SCANCODE_PAGEUP,    VK_PRIOR },
		{ SDL_SCANCODE_PAGEDOWN,  VK_NEXT },
		{ SDL_SCANCODE_END,       VK_END },
		{ SDL_SCANCODE_HOME,      VK_HOME },
		{ SDL_SCANCODE_LEFT,      VK_LEFT },
		{ SDL_SCANCODE_UP,        VK_UP },
		{ SDL_SCANCODE_RIGHT,     VK_RIGHT },
		{ SDL_SCANCODE_DOWN,      VK_DOWN },
		{ SDL_SCANCODE_INSERT,    VK_INSERT },
		{ SDL_SCANCODE_DELETE,    VK_DELETE },
		{ SDL_SCANCODE_KP_0,      VK_NUMPAD0 },
		{ SDL_SCANCODE_KP_1,      VK_NUMPAD1 },
		{ SDL_SCANCODE_KP_2,      VK_NUMPAD2 },
		{ SDL_SCANCODE_KP_3,      VK_NUMPAD3 },
		{ SDL_SCANCODE_KP_4,      VK_NUMPAD4 },
		{ SDL_SCANCODE_KP_5,      VK_NUMPAD5 },
		{ SDL_SCANCODE_KP_6,      VK_NUMPAD6 },
		{ SDL_SCANCODE_KP_7,      VK_NUMPAD7 },
		{ SDL_SCANCODE_KP_8,      VK_NUMPAD8 },
		{ SDL_SCANCODE_KP_9,      VK_NUMPAD9 },
		// 안드로이드 뒤로가기 버튼 — 스크립트가 ESC와 같은 의미로 다루게 한다.
		// VK_ESCAPE가 표에 두 번 나오는 유일한 자리다 (아래 합치기 규칙의 이유).
		{ SDL_SCANCODE_AC_BACK,   VK_ESCAPE },
	};
}

namespace Initial2D {
namespace Platform {

void ApplyScancodeState(const unsigned char* keys, int numKeys, unsigned char* vkState)
{
	std::memset(vkState, RELEASED, 256);
	if (keys == nullptr || numKeys <= 0) {
		return;
	}

	// 눌린 키만 표시한다. 대입이 아니라 표시라서, 같은 VK를 가리키는 스캔코드가
	// 여럿이어도 앞의 눌림이 지워지지 않는다 (ESC를 안드로이드 뒤로가기가 덮어
	// 데스크톱에서 ESC가 아예 먹지 않던 버그, 2026-08-18).
	auto down = [keys, numKeys](int scancode) {
		return scancode >= 0 && scancode < numKeys && keys[scancode] != 0;
	};
	auto press = [vkState](int vk) {
		if (vk >= 0 && vk < 256) {
			vkState[vk] = PRESSED;
		}
	};

	// 문자 키: VK 'A'~'Z' == 0x41~0x5A
	for (int i = 0; i < 26; ++i) {
		if (down(SDL_SCANCODE_A + i)) press(0x41 + i);
	}

	// 숫자 키: VK '0'~'9' == 0x30~0x39 (SDL은 1~9,0 순서)
	for (int i = 0; i < 9; ++i) {
		if (down(SDL_SCANCODE_1 + i)) press(0x31 + i);
	}
	if (down(SDL_SCANCODE_0)) press(0x30);

	// 기능 키: VK_F1~VK_F12
	for (int i = 0; i < 12; ++i) {
		if (down(SDL_SCANCODE_F1 + i)) press(VK_F1 + i);
	}

	// 좌우 구분 없는 조합 키
	if (down(SDL_SCANCODE_LSHIFT) || down(SDL_SCANCODE_RSHIFT)) press(VK_SHIFT);
	if (down(SDL_SCANCODE_LCTRL) || down(SDL_SCANCODE_RCTRL)) press(VK_CONTROL);
	if (down(SDL_SCANCODE_LALT) || down(SDL_SCANCODE_RALT)) press(VK_MENU);

	for (const auto& entry : KEY_TABLE) {
		if (down(entry.scancode)) press(entry.vk);
	}
}

} // namespace Platform
} // namespace Initial2D

#endif // !RS_WINDOWS
