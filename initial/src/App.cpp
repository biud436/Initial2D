/**
 * @file App.cpp
 * @date 2018/03/26 11:18
 *
 * @author biud436
 * Contact: biud436@gmail.com
 *
 * @brief 
 *
 *
 * @note
*/

#include "App.h"
#include "Sprite.h"
#include "TextureManager.h"
#include "Input.h"
#include "GameStateMachine.h"

extern HWND g_hWnd;
extern LRESULT CALLBACK WndProc(HWND, UINT, WPARAM, LPARAM);

App* App::s_pInstance = NULL;

App& App::GetInstance(void)
{
	static App *s_pInstance = new App();
	return *s_pInstance;
}

App::App() :
	m_szWindowName(WINDOW_NAME),
	m_szClassName(CLASS_NAME),
	m_nWindowWidth(WINDOW_WIDTH),
	m_nWindowHeight(WINDOW_HEIGHT),
	m_frameTime(0.0),
	m_pInput(NULL),
	m_pGameStateMachine(NULL),
	m_nFPS(100),
	m_elapsed(0)
{

#ifndef NDEBUG
	if (AllocConsole())
		freopen("CON", "w", stdout);
#endif
	
	if (!QueryPerformanceFrequency(&m_nTimeFreq)) {
		// todo : add it.
	}

	QueryPerformanceCounter(&m_nTimeStart);

	m_pTextureManager = new TextureManager();	// 텍스처 매니저
	m_pInput = new Input();	// 입력 객체

}


App::~App()
{
	Destroy();
}


const char* App::GetWindowName()
{
	return m_szWindowName;
}


const char* App::GetClassName()
{
	return m_szClassName;
}


const int App::GetWindowWidth()
{
	return m_nWindowWidth;
}


const int App::GetWindowHeight()
{
	return m_nWindowHeight;
}


int App::Run(int nCmdShow)
{
	MSG Message;
	WNDCLASSEX wx;
	
	wx.cbClsExtra = 0;
	wx.cbSize = sizeof(WNDCLASSEX);
	wx.cbWndExtra = 0;
	wx.hbrBackground = (HBRUSH)GetStockObject(WHITE_BRUSH);
	wx.hCursor = (HCURSOR)LoadCursor(0, IDC_ARROW);
	wx.hIcon = LoadIcon(0, IDI_APPLICATION);
	wx.hIconSm = 0;
	wx.hInstance = ::GetModuleHandle(0);
	wx.lpfnWndProc = WndProc;
	wx.lpszClassName = this->GetClassName();
	wx.lpszMenuName = NULL;
	wx.style = CS_HREDRAW | CS_VREDRAW;
	
	RegisterClassEx(&wx);

	m_hWnd = CreateWindow(this->GetClassName(),
		this->GetWindowName(),
		WS_OVERLAPPEDWINDOW | WS_VISIBLE,
		CW_USEDEFAULT, // x
		CW_USEDEFAULT, // y
		this->GetWindowWidth(),  // width
		this->GetWindowHeight(), // height
		0,
		(HMENU)0,
		::GetModuleHandle(0),
		0);

	g_hWnd = m_hWnd;

	if (m_hWnd == NULL)
	{
		delete this;
		return GetLastError();
	}

	ShowWindow(g_hWnd, nCmdShow);

	Initialize();

	bool done = false;

	while (!done)
	{
		if (PeekMessage(&Message, NULL, 0, 0, PM_REMOVE))
		{
			if (Message.message == WM_QUIT)
				done = true;

			TranslateMessage(&Message);
			DispatchMessage(&Message);

		}
		else
		{
			Update();
		}
	}

	delete this;

	return static_cast<int>(Message.wParam);
}


LRESULT App::HandleEvent(HWND hWnd, UINT uMsg, WPARAM wParam, LPARAM lParam)
{
	switch (uMsg)
	{
	case WM_MOUSEWHEEL:
		if (m_pInput != nullptr) {
			m_pInput->setMouseZ(HIWORD(wParam) > 0 ? 1 : -1);
		}
		return 0;
	case WM_DESTROY:
		PostQuitMessage(0);
		return 0;
	}
	return DefWindowProc(hWnd, uMsg, wParam, lParam);
}


App::DeviceContext& App::GetContext()
{
	return m_context;
}


TextureManager& App::GetTextureManager()
{
	return *m_pTextureManager;
}


GameStateMachine& App::GetGameStateMachine()
{
	return *m_pGameStateMachine;
}


Input& App::GetInput()
{
	return *m_pInput;
}


void App::Update()
{
	// 현재 시간과 경과 시간을 구합니다.
	QueryPerformanceCounter(&m_nTimeEnd);
	float elapsed = static_cast<float>(m_nTimeEnd.QuadPart - m_nTimeStart.QuadPart);

	// 프레임 시간을 구합니다.
	m_frameTime = elapsed / static_cast<float>(m_nTimeFreq.QuadPart);

	m_elapsed += 60 * m_frameTime;

	m_nTimeStart = m_nTimeEnd;

	char TITLE[64];

	for (; m_elapsed >= 1.0; m_elapsed -= 1.0) {
		UpdateInput();
		ObjectUpdate(UpdateTime());
	}

	// 평균 FPS 구하기
	if (m_frameTime > 0.0)
		m_nFPS = (m_nFPS * 0.99f) + (0.01f / m_frameTime);

	// FPS 출력
	sprintf(TITLE, "Demo Game - FPS : %d\n", static_cast<int>(m_nFPS));
	SetWindowText(m_hWnd, TITLE);

	RenderClear();
	RenderTransform();
	Render();
	RenderPresent();

}


void App::UpdateInput()
{
	m_pInput->update();
}

void App::RenderClear()
{
	m_context.currentContext = CreateCompatibleDC(m_context.mainContext);
	m_context.currentSurface = CreateCompatibleBitmap(m_context.mainContext, GetWindowWidth(), GetWindowHeight());
	m_context.prevSurface = (HBITMAP)SelectObject(m_context.currentContext, m_context.currentSurface);
	m_context.newContext = NULL;
	m_context.rotateContext = NULL;
}


void App::RenderTransform()
{
	RECT rect;
	SetMapMode(m_context.mainContext, MM_ANISOTROPIC);
	GetClientRect(g_hWnd, &rect);
	SetWindowExtEx(m_context.mainContext, WINDOW_WIDTH, WINDOW_HEIGHT, NULL);
	SetViewportExtEx(m_context.mainContext, rect.right, rect.bottom, NULL);
}


void App::RenderPresent()
{
	SetStretchBltMode(m_context.mainContext, COLORONCOLOR);
	BitBlt(m_context.mainContext, 0, 0, GetWindowWidth(), GetWindowHeight(), m_context.currentContext, 0, 0, SRCCOPY);

	DeleteObject(SelectObject(m_context.currentContext, m_context.prevSurface)); // 이전 상태로 복원
	DeleteObject(m_context.currentSurface); // 복사된 DC 삭제
	DeleteDC(m_context.currentContext);

}


double App::UpdateTime()
{
	return m_frameTime;

}


void App::Quit()
{
	::PostQuitMessage(0);
}