/**
 * @file InputSDL2.cpp
 * @brief Input의 SDL2 어댑터 구현 (비-Windows).
 * @details GetKeyboardState/GetAsyncKeyState → SDL_GetKeyboardState/SDL_GetMouseState.
 *          엔진과 Lua에 노출되는 키 코드는 Win32 VK_* 값 그대로 유지하며(스크립트 호환),
 *          SDL 스캔코드 → VK 매핑 테이블로 변환한다. 4-상태 키 머신 로직은 원본과 동일하다.
 */
#include "Constants.h"

#ifndef RS_WINDOWS

#include "Input.h"
#include "App.h"

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
	};
}

void Input::updateKeyboard()
{
	memcpy(m_kbOld, m_kbCurrent, sizeof(m_kbOld));
	memset(m_kbCurrent, 0, sizeof(m_kbCurrent));
	memset(m_kbMap, 0, sizeof(m_kbMap));

	int numKeys = 0;
	const Uint8* keys = SDL_GetKeyboardState(&numKeys);

	// 문자 키: VK 'A'~'Z' == 0x41~0x5A
	for (int i = 0; i < 26; ++i) {
		m_kbCurrent[0x41 + i] = keys[SDL_SCANCODE_A + i] ? PRESSED : RELEASED;
	}

	// 숫자 키: VK '0'~'9' == 0x30~0x39 (SDL은 1~9,0 순서)
	for (int i = 0; i < 9; ++i) {
		m_kbCurrent[0x31 + i] = keys[SDL_SCANCODE_1 + i] ? PRESSED : RELEASED;
	}
	m_kbCurrent[0x30] = keys[SDL_SCANCODE_0] ? PRESSED : RELEASED;

	// 기능 키: VK_F1~VK_F12
	for (int i = 0; i < 12; ++i) {
		m_kbCurrent[VK_F1 + i] = keys[SDL_SCANCODE_F1 + i] ? PRESSED : RELEASED;
	}

	// 좌우 구분 없는 조합 키
	m_kbCurrent[VK_SHIFT] = (keys[SDL_SCANCODE_LSHIFT] || keys[SDL_SCANCODE_RSHIFT]) ? PRESSED : RELEASED;
	m_kbCurrent[VK_CONTROL] = (keys[SDL_SCANCODE_LCTRL] || keys[SDL_SCANCODE_RCTRL]) ? PRESSED : RELEASED;
	m_kbCurrent[VK_MENU] = (keys[SDL_SCANCODE_LALT] || keys[SDL_SCANCODE_RALT]) ? PRESSED : RELEASED;

	for (const auto& entry : KEY_TABLE) {
		m_kbCurrent[entry.vk] = keys[entry.scancode] ? PRESSED : RELEASED;
	}

	// 4-상태 키 머신 (원본 Win32 구현과 동일)
	for (int i = 0; i < 256; ++i)
	{
		int old = m_kbOld[i];
		int cur = m_kbCurrent[i];

		if (old == RELEASED && cur == PRESSED)
			m_kbMap[i] = KB_DOWN;
		else if (old == PRESSED && cur == PRESSED)
			m_kbMap[i] = KB_PRESS;
		else if (old == PRESSED && cur == RELEASED)
			m_kbMap[i] = KB_UP;
		else
			m_kbMap[i] = KB_NONE;
	}
}

void Input::updateMouse()
{
	memcpy(m_mbOld, m_mbCurrent, sizeof(m_mbOld));
	memset(m_mbCurrent, 0, sizeof(m_mbCurrent));
	memset(m_mbMap, 0, sizeof(m_mbMap));

	int windowX = 0;
	int windowY = 0;
	const Uint32 buttons = SDL_GetMouseState(&windowX, &windowY);

	m_mbCurrent[0] = (buttons & SDL_BUTTON(SDL_BUTTON_LEFT)) ? PRESSED : RELEASED;
	m_mbCurrent[1] = (buttons & SDL_BUTTON(SDL_BUTTON_RIGHT)) ? PRESSED : RELEASED;
	m_mbCurrent[2] = (buttons & SDL_BUTTON(SDL_BUTTON_MIDDLE)) ? PRESSED : RELEASED;

	for (int i = 0; i < 8; ++i)
	{
		int old = m_mbOld[i];
		int cur = m_mbCurrent[i];

		if (old == RELEASED && cur == PRESSED)
			m_mbMap[i] = KB_DOWN;
		else if (old == PRESSED && cur == PRESSED)
			m_mbMap[i] = KB_PRESS;
		else if (old == PRESSED && cur == RELEASED)
			m_mbMap[i] = KB_UP;

	}

	// 창 좌표 → 논리 좌표 변환 (SDL_RenderSetLogicalSize 대응 — GDI의 ScreenToClient+MM_ANISOTROPIC)
	float logicalX = static_cast<float>(windowX);
	float logicalY = static_cast<float>(windowY);

	SDL_Renderer* renderer = App::GetInstance().GetContext().renderer;
	if (renderer != nullptr) {
		SDL_RenderWindowToLogical(renderer, windowX, windowY, &logicalX, &logicalY);
	}

	m_mouse.setX(logicalX);
	m_mouse.setY(logicalY);

	setMouseZ(0);
}

#endif // !RS_WINDOWS
