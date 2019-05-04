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
#include "Font.h"

#include <thread>

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
	m_elapsed(0),
	m_bFocus(true),
	m_nFrameCount(0),
	m_pFont(nullptr)
{

	// 디버그 모드라면 콘솔 창을 띄운다.
#ifndef NDEBUG
	if (AllocConsole())
		freopen("CON", "w", stdout);
#endif
	
	if (!QueryPerformanceFrequency(&m_nTimeFreq)) {
		// todo : add it.
	}

	QueryPerformanceCounter(&m_nTimeStart);

	// 텍스쳐 관리자 생성
	m_pTextureManager = new TextureManager();

	// 입력 관리자 생성
	m_pInput = new Input();

	// 폰트 생성
	m_pFont = std::make_unique<Font>();

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

	// 이런 소멸자는 사용에 주의를 요구한다.
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
	case WM_SETFOCUS:
		m_bFocus = true;
		return 0;
	case WM_KILLFOCUS:
		m_bFocus = false;
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

const double DELAY_TIME = 1.0 / 60.0;

void App::Update()
{
	// 경과된 시간(Elapsed)을 구한다.
	QueryPerformanceCounter(&m_nTimeEnd);

	m_frameTime = (double)(m_nTimeEnd.QuadPart - m_nTimeStart.QuadPart) / (double)m_nTimeFreq.QuadPart;

	m_elapsed += m_frameTime;

	m_nFrameCount++;

	char TITLE[128];

	// 부동 소수점 오차를 줄이기 위해 정밀도가 높은 double 형을 사용하였다.
	while(m_elapsed >= DELAY_TIME)
	{
		UpdateInput();
		ObjectUpdate(m_frameTime);
		m_elapsed -= DELAY_TIME;
	}

	if (m_frameTime >= 1.0)
	{
		sprintf(TITLE, "Demo Game - FPS : %d\n", m_nFrameCount);
		SetWindowText(m_hWnd, TITLE);
		m_nFPS = m_nFrameCount;
		m_nFrameCount = 0;
		m_elapsed = 0.0;
		m_nTimeStart = m_nTimeEnd;
	}

	// Rendering
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

bool App::GetFocus()
{
	return m_bFocus;
}

GameFont* App::GetFont()
{
	return &m_pFont;
}

bool App::LoadFont()
{
	bool isValid = m_pFont->ParseFont(".\\resources\\hangul.fnt");
	
	m_pFont->load();

	return isValid;
}

bool App::DestroyFont()
{
	bool isValid = m_pFont->remove();

	m_pFont.reset();
	m_pFont.release();

	return isValid;
}

int App::GetFrameCount()
{
	return m_nFPS;
}