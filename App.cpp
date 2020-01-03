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

namespace 
{
const double DELAY_TIME = 1.0 / 60.0;
const char* GAME_TITLE = TEXT("Demo Game - FPS : ");
}


App& App::GetInstance(void)
{
	static App *s_pInstance = new (std::nothrow) App();
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
	m_accumulateElapsed(0),
	m_bFocus(true),
	m_nFrameCount(0),
	m_pFont(nullptr)
{

	// ����� ����� �ܼ� â�� ����.
#ifndef NDEBUG
	if (AllocConsole())
		freopen("CON", "w", stdout);
#endif
	
	if (!QueryPerformanceFrequency(&m_nTimeFreq)) {
		// todo : add it.
	}

	QueryPerformanceCounter(&m_nTimeStart);

	// �ؽ��� ������ ����
	m_pTextureManager = new TextureManager();

	// �Է� ������ ����
	m_pInput = new Input();

	// ��Ʈ ����
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

	std::unique_ptr<RECT> pRect = std::make_unique<RECT>();
	GetClientRect(g_hWnd, pRect.get());
	int cw = pRect.get()->right - pRect.get()->left;
	int ch = pRect.get()->bottom - pRect.get()->top;

	SetWindowPos(g_hWnd, NULL,
		GetSystemMetrics(SM_CXSCREEN) / 2 - cw / 2,
		GetSystemMetrics(SM_CYSCREEN) / 2 - ch / 2,
		GetWindowWidth(),
		GetWindowHeight(),
		SWP_SHOWWINDOW);

	pRect.reset(0);

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

	// �̷� �Ҹ��ڴ� ��뿡 ���Ǹ� �䱸�Ѵ�.
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


void App::Update()
{
	// ������ ������ �ð� ����
	QueryPerformanceCounter(&m_nTimeEnd);

	// ������ �ð�
	m_frameTime = (double)(m_nTimeEnd.QuadPart - m_nTimeStart.QuadPart) / ((double)(m_nTimeFreq.QuadPart));

	m_elapsed += m_frameTime;
	m_accumulateElapsed += m_frameTime;

	m_nFrameCount++;

	// ������ �ӵ��� �����̶�� ������Ʈ�� �����Ѵ�.
	if (m_frameTime >= DELAY_TIME) {
		UpdateInput();
		ObjectUpdate(m_frameTime);
		m_elapsed -= DELAY_TIME;
	}
	else {
		Sleep(1);
	}

	// 60 �������� ������ ���� üũ�Ѵ�.
	if (m_accumulateElapsed >= 1.0) {

		// ��� ������ ���� ���� �ð� / 1 ������ �ð�
		m_nFPS = static_cast<int>(m_accumulateElapsed / DELAY_TIME);

		m_nFrameCount = 0;
		m_elapsed = 0.0;

		{
			std::ostringstream oss;
			oss << GAME_TITLE << m_nFPS << std::endl;
			SetWindowText(m_hWnd, &oss.str()[0]);
			
			m_accumulateElapsed = 0.0;

		}
	}

	m_nTimeStart = m_nTimeEnd;

	//while(m_elapsed >= DELAY_TIME)
	//{
	//	UpdateInput();
	//	ObjectUpdate(m_frameTime);
	//	m_elapsed -= DELAY_TIME;
	//	Sleep(1);
	//}

	//if (m_frameTime >= 1.0) {
	//	std::ostringstream oss; 
	//	oss << GAME_TITLE << m_nFrameCount << std::endl;
	//	SetWindowText(m_hWnd, &oss.str()[0]);
	//	m_nFPS = m_nFrameCount;
	//	m_nFrameCount = 0;
	//	m_elapsed = 0.0;
	//	m_nTimeStart = m_nTimeEnd;
	//}

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

	DeleteObject(SelectObject(m_context.currentContext, m_context.prevSurface)); // ���� ���·� ����
	DeleteObject(m_context.currentSurface); // ����� DC ����
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

bool App::LoadFont(std::string fontName)
{
	bool isValid = m_pFont->ParseFont(fontName);
	
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