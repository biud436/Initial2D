/**
 * @file Input.cpp
 * @date 2018/03/26 11:14
 *
 * @author biud436
 * Contact: biud436@gmail.com
 *
 * @brief 
 *
 *
 * @note
*/

#include "Input.h"
#include "App.h"
#include "platform/Env.h"

#include <cstdio>
#include <cstring>
#include <sstream>
#include <string>
#include <vector>

#ifdef RS_WINDOWS
extern HWND g_hWnd;
#endif

Input::Input() : m_nWheel(0)
{
}


Input::~Input()
{

}


void Input::initialize(HWND hWnd)
{
	m_hWnd = hWnd;

	memset(m_kbCurrent, 0, sizeof(m_kbCurrent));
	memset(m_kbOld, 0, sizeof(m_kbOld));
	memset(m_kbMap, 0, sizeof(m_kbMap));

	memset(m_mbCurrent, 0, sizeof(m_mbCurrent));
	memset(m_mbOld, 0, sizeof(m_mbOld));
	memset(m_mbMap, 0, sizeof(m_mbMap));

#ifndef RS_WINDOWS
	memset(m_mbEventLatch, 0, sizeof(m_mbEventLatch));
	memset(m_kbEventLatch, 0, sizeof(m_kbEventLatch));
	memset(m_touches, 0, sizeof(m_touches));
	m_nTouchCount = 0;
	m_nWheelLatch = 0;
#endif

	m_mouse.setX(0.0f);
	m_mouse.setY(0.0f);

}


void Input::update()
{
	updateKeyboard();
	updateMouse();
#ifndef RS_WINDOWS
	updateTouches();
#endif
}


int Input::getMouseZ() const
{
	return m_nWheel;
}

void Input::setMouseZ(int value)
{
	m_nWheel = value;
}

#ifdef RS_WINDOWS
// Win32 키보드/마우스 폴링. SDL2 어댑터는 platform/sdl2/InputSDL2.cpp 참조.

namespace
{
	struct TestKeyEvent
	{
		long tick;
		int vk;
		bool down;
	};

	/**
	 * @brief INITIAL2D_TEST_EVENTS 의 키 항목 (처음 부를 때 한 번 읽는다).
	 *
	 * "틱:keydown:가상키" 와 "틱:keyup:가상키" 를 쉼표로 잇는다 (예: "120:keydown:39,420:keyup:39" 는
	 * 120번째 갱신에서 오른쪽 화살표를 누르고 420번째에서 뗀다). 틱은 1부터 센 갱신 횟수다.
	 * 다른 종류(SDL2 판의 wheel, mousedown)는 건너뛴다.
	 */
	const std::vector<TestKeyEvent>& TestKeyEvents()
	{
		static std::vector<TestKeyEvent> events;
		static bool parsed = false;
		if (parsed)
		{
			return events;
		}
		parsed = true;
		const char* spec = Initial2D::Platform::GetEnv("INITIAL2D_TEST_EVENTS");
		if (spec == nullptr)
		{
			return events;
		}
		std::stringstream items(spec);
		std::string item;
		while (std::getline(items, item, ','))
		{
			long tick = 0;
			char kind[16] = { 0 };
			int vk = 0;
			if (std::sscanf(item.c_str(), "%ld:%15[a-z]:%d", &tick, kind, &vk) != 3 || vk <= 0 || vk > 255)
			{
				continue;
			}
			if (std::strcmp(kind, "keydown") == 0 || std::strcmp(kind, "keyup") == 0)
			{
				events.push_back({ tick, vk, std::strcmp(kind, "keydown") == 0 });
			}
		}
		return events;
	}

	long g_testTick = 0;
	bool g_testKeys[256] = { false };
}

void Input::updateKeyboard()
{
	memcpy(m_kbOld, m_kbCurrent, sizeof(m_kbOld));
	memset(m_kbCurrent, 0, sizeof(m_kbCurrent));
	memset(m_kbMap, 0, sizeof(m_kbMap));

	GetKeyboardState(m_kbCurrent);

	// 검증용 키 입력을 실제 키 상태 위에 덧씌운다 (엔진 안에서만, 다른 창에는 가지 않는다)
	++g_testTick;
	for (const TestKeyEvent& e : TestKeyEvents())
	{
		if (e.tick == g_testTick)
		{
			g_testKeys[e.vk] = e.down;
		}
	}
	for (int i = 0; i < 256; ++i)
	{
		if (g_testKeys[i])
		{
			m_kbCurrent[i] |= 0x80;
		}
	}

	for (int i = 0; i < 256; ++i)
	{
		m_kbCurrent[i] = ((m_kbCurrent[i] & 0x80)) ? PRESSED : RELEASED;

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

	m_mbCurrent[0] = (GetAsyncKeyState(VK_LBUTTON) & 0x8000) ? PRESSED : RELEASED;
	m_mbCurrent[1] = (GetAsyncKeyState(VK_RBUTTON) & 0x8000) ? PRESSED : RELEASED;
	m_mbCurrent[2] = (GetAsyncKeyState(VK_MBUTTON) & 0x8000) ? PRESSED : RELEASED;

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

	POINT tempPt;
	GetCursorPos(&tempPt);
	ScreenToClient(m_hWnd, &tempPt);

	// 화면은 논리 해상도를 창 전체로 늘려 그리므로 마우스도 논리 좌표로 바꾼다 (SDL2 판과 같다)
	RECT client;
	GetClientRect(m_hWnd, &client);
	if (client.right > 0 && client.bottom > 0)
	{
		const App& app = App::GetInstance();
		tempPt.x = tempPt.x * app.GetWindowWidth() / client.right;
		tempPt.y = tempPt.y * app.GetWindowHeight() / client.bottom;
	}

	m_mouse.setX(static_cast<float>(tempPt.x));
	m_mouse.setY(static_cast<float>(tempPt.y));

	setMouseZ(0);

}

#endif // RS_WINDOWS (updateKeyboard/updateMouse)

bool Input::isKeyDown(int vKey) const
{
	return m_kbMap[vKey] == KB_DOWN;
}


bool Input::isKeyUp(int vKey) const
{
	return m_kbMap[vKey] == KB_UP;
}


bool Input::isKeyPress(int vKey) const
{
	return m_kbMap[vKey] == KB_PRESS;
}


bool Input::isAnyKeyDown() const
{
	for (int i = 0; i < 256; ++i)
	{
		if (m_kbMap[i] == KB_DOWN)
			return true;
	}
	return false;
}

float Input::getMouseX()
{
	return m_mouse.getX();
}

float Input::getMouseY()
{
	return m_mouse.getY();
}

bool Input::isMouseDown(int vKey) const
{
	return m_mbMap[vKey] == KB_DOWN;
}


bool Input::isMouseUp(int vKey) const
{
	return m_mbMap[vKey] == KB_UP;
}


bool Input::isMousePress(int vKey) const
{
	return m_mbMap[vKey] == KB_PRESS;
}


bool Input::isAnyMouseDown() const
{
	for (int i = 0; i < 8; ++i)
	{
		if (m_mbMap[i] == KB_DOWN)
			return true;
	}
	return false;
}