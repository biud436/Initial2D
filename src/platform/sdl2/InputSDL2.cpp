/**
 * @file InputSDL2.cpp
 * @brief Input의 SDL2 어댑터 구현 (비-Windows).
 * @details GetKeyboardState/GetAsyncKeyState → SDL_GetKeyboardState/SDL_GetMouseState.
 *          엔진과 Lua에 노출되는 키 코드는 Win32 VK_* 값 그대로 유지하며(스크립트 호환),
 *          SDL 스캔코드 → VK 매핑(ScancodeMap.cpp)으로 변환한다.
 *          4-상태 키 머신 로직은 원본과 동일하다.
 */
#include "Constants.h"

#ifndef RS_WINDOWS

#include "Input.h"
#include "App.h"
#include "ScancodeMap.h"

#include <SDL.h>
#include <cstring>

void Input::updateKeyboard()
{
	memcpy(m_kbOld, m_kbCurrent, sizeof(m_kbOld));
	memset(m_kbMap, 0, sizeof(m_kbMap));

	int numKeys = 0;
	const Uint8* keys = SDL_GetKeyboardState(&numKeys);

	// 스캔코드 → VK 변환은 순수 함수로 떼어 두었다 (ScancodeMap.cpp).
	// 가짜 키보드 상태로 부를 수 있어야 회귀 테스트를 쓸 수 있기 때문이다.
	// 이벤트 래치도 함께 넘긴다 — 폴링 사이에 눌렸다 떼어진 키를 살린다.
	Initial2D::Platform::ApplyScancodeState(keys, numKeys, m_kbCurrent, m_kbEventLatch);

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

	// 이벤트 래치 반영: 폴링 사이에 눌렸다 떼어진 짧은 클릭·탭도 1틱은 PRESSED로 관측된다
	for (int i = 0; i < 3; ++i) {
		if (m_mbEventLatch[i]) {
			m_mbCurrent[i] = PRESSED;
			m_mbEventLatch[i] = 0;
		}
	}

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

void Input::latchKeyDown(int vKey)
{
	if (vKey > 0 && vKey < 256) {
		m_kbEventLatch[vKey] = 1;
	}
}

void Input::latchMouseDown(int index)
{
	if (index >= 0 && index < 8) {
		m_mbEventLatch[index] = 1;
	}
}

#endif // !RS_WINDOWS
