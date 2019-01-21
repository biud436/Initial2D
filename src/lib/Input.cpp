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

extern HWND g_hWnd;

Input::Input()
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

	m_mouse.setX(0.0f);
	m_mouse.setY(0.0f);

}


void Input::update()
{
	updateKeyboard();
	updateMouse();
}


void Input::updateKeyboard()
{
	memcpy(m_kbOld, m_kbCurrent, sizeof(m_kbOld));
	memset(m_kbCurrent, 0, sizeof(m_kbCurrent));
	memset(m_kbMap, 0, sizeof(m_kbMap));

	GetKeyboardState(m_kbCurrent);

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

	m_mouse.setX(static_cast<float>(tempPt.x));
	m_mouse.setY(static_cast<float>(tempPt.y));

}

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
	for (int i = 0; i < 256; ++i)
	{
		if (m_kbMap[i] == KB_DOWN)
			return true;
	}
	return false;
}