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
#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include "platform/Env.h"

#ifdef RS_WINDOWS
extern HWND g_hWnd;
extern LRESULT CALLBACK WndProc(HWND, UINT, WPARAM, LPARAM);
#endif

App* App::s_pInstance = NULL;

namespace
{
	const double DELAY_TIME = 1.0 / 60.0;
	const char* GAME_TITLE = "Demo Game - FPS : ";
}

App& App::GetInstance(void)
{
	static App *s_pInstance = new (std::nothrow) App();
	return *s_pInstance;
}

App::App() :
	m_szWindowName(WINDOW_NAME.c_str()),
	m_szClassName(CLASS_NAME.c_str()),
	m_nWindowWidth(WINDOW_WIDTH),
	m_nWindowHeight(WINDOW_HEIGHT),
	m_nBaseWidth(WINDOW_WIDTH),
	m_nBaseHeight(WINDOW_HEIGHT),
	m_nRenderScale(1),
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

#ifdef RS_WINDOWS
	// 디버그 모드라면 콘솔 창을 띄운다.
#ifndef NDEBUG
	if (AllocConsole())
		freopen("CON", "w", stdout);
#endif

	if (!QueryPerformanceFrequency(&m_nTimeFreq)) {
		// todo : add it.
	}

#ifndef NDEBUG
	const HANDLE hConsole = GetStdHandle(STD_OUTPUT_HANDLE);
	const HWND hWndConsole = GetConsoleWindow();

	// 콘솔 윈도우 이름 설정
	std::string sClassName = WINDOW_NAME;
	sClassName += " - Console";
	SetConsoleTitle(sClassName.c_str());

	// 콘솔 윈도우 위치 설정
	RECT rt = { 0, };
	GetWindowRect(hWndConsole, &rt);
	SetWindowPos(hWndConsole, HWND_NOTOPMOST, rt.left, rt.top, 0, 0, SWP_NOSIZE | SWP_NOMOVE | SWP_SHOWWINDOW);

#endif

	QueryPerformanceCounter(&m_nTimeStart);
#endif // RS_WINDOWS

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

/**
* @brief WindowName을 구합니다.
*/
const char* App::GetWindowName() const
{
	return m_szWindowName;
}

/**
* @brief ClassName을 구합니다.
*/
const char* App::GetClassName() const
{
	return m_szClassName;
}

/**
* @brief 창의 폭을 구합니다.
*/
const int App::GetWindowWidth() const
{
	return m_nWindowWidth;
}

/**
* @brief 창의 높이를 구합니다.
*/
const int App::GetWindowHeight() const
{
	return m_nWindowHeight;
}

/**
* @brief 창(논리 해상도) 크기를 설정합니다. 창 생성 전에 호출해야 합니다.
*/
void App::SetWindowSize(int width, int height)
{
	if (width <= 0 || height <= 0)
	{
		return;
	}
	m_nBaseWidth = width;
	m_nBaseHeight = height;
	SetRenderScale(m_nRenderScale);
}

/**
* @brief 배율을 적용하기 전의 창 크기입니다.
*/
const int App::GetBaseWidth() const
{
	return m_nBaseWidth;
}

const int App::GetBaseHeight() const
{
	return m_nBaseHeight;
}

/**
* @brief 픽셀 확대 배율. 논리 해상도를 창 크기의 1/배율로 줄여, 같은 화면을
*        그만큼 크게 그린다 (16px 타일을 32px로 보이게 하는 식).
*
* 창 크기와 논리 해상도를 분리하는 것이 요점이다. 확대는 렌더러가 하므로
* 타일맵, 스프라이트, 비트맵 폰트가 한꺼번에 같은 비율로 커지고, 마우스 좌표도
* 논리 좌표로 변환되어 들어온다 (platform/sdl2/InputSDL2.cpp).
*
* 나누어떨어지지 않는 배율은 남는 픽셀만큼 여백이 생기므로, 창 크기의 약수를
* 쓰는 것이 좋다 (768x896이면 2, 4).
*/
void App::SetRenderScale(int scale)
{
	if (scale < 1)
	{
		scale = 1;
	}
	// 상한은 안전장치다. 이보다 크면 논리 해상도가 몇 십 픽셀로 줄어 화면이 무의미해진다.
	if (scale > 16)
	{
		scale = 16;
	}

	m_nRenderScale = scale;
	m_nWindowWidth = m_nBaseWidth / scale;
	m_nWindowHeight = m_nBaseHeight / scale;
}

const int App::GetRenderScale() const
{
	return m_nRenderScale;
}

#ifdef RS_WINDOWS

/**
 * @brief 게임 모듈을 초기화하고 게임 루프를 실행합니다.
 */
namespace
{
	/** list 가 쉼표로 이은 정수 가운데 value 가 있으면 true. */
	bool ListHas(const char* list, long value)
	{
		const char* p = list;
		while (*p != '\0')
		{
			if (std::atol(p) == value)
			{
				return true;
			}
			while (*p != '\0' && *p != ',') { ++p; }
			if (*p == ',') { ++p; }
		}
		return false;
	}

	/** 메모리 DC 의 그림(논리 해상도)을 32비트 BMP 파일로 쓴다. */
	void SaveDcAsBmp(HDC source, int width, int height, const char* path)
	{
		BITMAPINFO info;
		ZeroMemory(&info, sizeof(info));
		info.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
		info.bmiHeader.biWidth = width;
		info.bmiHeader.biHeight = -height; // 위에서 아래로
		info.bmiHeader.biPlanes = 1;
		info.bmiHeader.biBitCount = 32;
		info.bmiHeader.biCompression = BI_RGB;
		void* bits = NULL;
		HDC copyDc = CreateCompatibleDC(source);
		HBITMAP copy = CreateDIBSection(copyDc, &info, DIB_RGB_COLORS, &bits, NULL, 0);
		if (copy == NULL || bits == NULL)
		{
			DeleteDC(copyDc);
			return;
		}
		HGDIOBJ old = SelectObject(copyDc, copy);
		BitBlt(copyDc, 0, 0, width, height, source, 0, 0, SRCCOPY);
		GdiFlush();

		const DWORD imageSize = static_cast<DWORD>(width) * static_cast<DWORD>(height) * 4;
		BITMAPFILEHEADER file;
		ZeroMemory(&file, sizeof(file));
		file.bfType = 0x4D42; // "BM"
		file.bfOffBits = sizeof(BITMAPFILEHEADER) + sizeof(BITMAPINFOHEADER);
		file.bfSize = file.bfOffBits + imageSize;
		FILE* out = std::fopen(path, "wb");
		if (out != NULL)
		{
			std::fwrite(&file, sizeof(file), 1, out);
			std::fwrite(&info.bmiHeader, sizeof(BITMAPINFOHEADER), 1, out);
			std::fwrite(bits, 1, imageSize, out);
			std::fclose(out);
		}
		SelectObject(copyDc, old);
		DeleteObject(copy);
		DeleteDC(copyDc);
	}
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

	// 그리는 영역(클라이언트)이 배율 1의 창 크기가 되도록 테두리와 제목 표시줄을 더한 바깥 크기
	RECT outer = { 0, 0, this->GetBaseWidth(), this->GetBaseHeight() };
	AdjustWindowRect(&outer, WS_OVERLAPPEDWINDOW, FALSE);
	const int outerWidth = outer.right - outer.left;
	const int outerHeight = outer.bottom - outer.top;

	m_hWnd = CreateWindow(this->GetClassName(),
		this->GetWindowName(),
		WS_OVERLAPPEDWINDOW | WS_VISIBLE,
		CW_USEDEFAULT, // x
		CW_USEDEFAULT, // y
		outerWidth,  // width
		outerHeight, // height
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

	SetWindowPos(g_hWnd, NULL,
		GetSystemMetrics(SM_CXSCREEN) / 2 - outerWidth / 2,
		GetSystemMetrics(SM_CYSCREEN) / 2 - outerHeight / 2,
		outerWidth,
		outerHeight,
		SWP_SHOWWINDOW);

	Initialize();

	bool done = false;

	int lag = 0;
	std::chrono::time_point<std::chrono::steady_clock> endTime = std::chrono::steady_clock::now();

	long longestTime = 0;
	m_nFPS = 0;
	long tickCount = 0;
	long fpsElapsedTime = 0;

	// 검증용 (SDL2 판과 같은 이름). GDI 판은 화면을 그리는 횟수가 주사율에 묶이지 않으므로 갱신 틱을 센다.
	//   INITIAL2D_SCREENSHOT=<경로.bmp>  INITIAL2D_SCREENSHOT_FRAME 의 틱(쉼표 목록, 없으면 120)에 화면을 저장한다.
	//                                    경로에 %ld 가 있으면 틱 번호로 바꾼다
	//   INITIAL2D_EXIT_AFTER=<n>         n 틱 뒤에 끝낸다
	const char* shotPath = Initial2D::Platform::GetEnv("INITIAL2D_SCREENSHOT");
	const char* shotTicks = Initial2D::Platform::GetEnv("INITIAL2D_SCREENSHOT_FRAME");
	const char* exitAfter = Initial2D::Platform::GetEnv("INITIAL2D_EXIT_AFTER");
	const long exitTick = exitAfter != nullptr ? std::atol(exitAfter) : 0;
	long totalTicks = 0;
	long shotDoneTick = 0;

	/**
	 * Game Loop (C++ 11)
	 * https://www.gamedev.net/forums/topic/690860-60-fps-game-loop-using-stdchrono/
	 */
	while (!done)
	{
		std::chrono::time_point<std::chrono::steady_clock> startTime = std::chrono::steady_clock::now();
		std::chrono::milliseconds elapsedTime(std::chrono::duration_cast<std::chrono::milliseconds>(startTime - endTime));
		endTime = startTime;

		// 창을 끌거나 멈췄다 돌아온 뒤 한꺼번에 따라잡지 않도록 프레임 시간을 자른다 (SDL2 판과 같다)
		const long long maxFrameMs = static_cast<long long>(MAX_FRAME_TIME * 1000.0);
		if (elapsedTime.count() > maxFrameMs)
		{
			elapsedTime = std::chrono::milliseconds(maxFrameMs);
		}

		lag += static_cast<int>(elapsedTime.count());

		if (elapsedTime.count() == 0) 
		{
			Sleep(5);
		}
		const int fps = 60;
		const int lengthOfFrame = 1000 / fps;

		while (PeekMessage(&Message, NULL, 0, 0, PM_REMOVE))
		{
			if (Message.message == WM_QUIT)
				done = true;

			TranslateMessage(&Message);
			DispatchMessage(&Message);

		}

		std::chrono::time_point<std::chrono::steady_clock> oldTime = std::chrono::steady_clock::now();
		while (lag >= lengthOfFrame) 
		{
			UpdateInput();
			// 고정 스텝에는 고정 delta 를 넘긴다 (SDL2 판과 같다). 프레임 시간을 넘기면
			// 화면을 자주 그릴수록 한 스텝의 시간이 줄어 게임이 느려진다
			ObjectUpdate(lengthOfFrame);
			lag -= lengthOfFrame;
			++totalTicks;
			
			tickCount++;
			m_elapsed = 1.0 / elapsedTime.count();
		}

		RenderClear();
		RenderTransform();
		Render();

		if (shotPath != nullptr)
		{
			for (long tick = shotDoneTick + 1; tick <= totalTicks; ++tick)
			{
				const bool hit = shotTicks != nullptr ? ListHas(shotTicks, tick) : tick == 120;
				if (hit)
				{
					char path[1024];
					if (std::strchr(shotPath, '%') != nullptr)
					{
						std::snprintf(path, sizeof(path), shotPath, tick);
					}
					else
					{
						std::snprintf(path, sizeof(path), "%s", shotPath);
					}
					SaveDcAsBmp(m_context.currentContext, GetWindowWidth(), GetWindowHeight(), path);
				}
			}
			shotDoneTick = totalTicks;
		}

		RenderPresent();
		m_nFPS++;

		if (exitTick > 0 && totalTicks >= exitTick)
		{
			done = true;
		}

		fpsElapsedTime += static_cast<long>(elapsedTime.count());

		if (fpsElapsedTime >= 1000) 
		{
			std::stringstream sstr;
			sstr << m_nFPS;

			SetWindowText(m_hWnd, &sstr.str()[0]);

			fpsElapsedTime = 0;
			m_nFPS = 0;
			m_elapsed = 0;
			tickCount = 0;
		}
	}

	// 자기 자신을 소멸시킬 수 있나 싶은데 일단은 동작한다.
	delete this;

	return static_cast<int>(Message.wParam);
}

/**
* @brief 메시지를 처리합니다.
*/
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

#endif // RS_WINDOWS (Run/HandleEvent — SDL2 버전은 platform/sdl2/AppSDL2.cpp)

/**
* @brief 현재 Context를 가져옵니다.
*/
App::DeviceContext& App::GetContext()
{
	return m_context;
}

/**
* @brief TextureManager의 인스턴스를 가져옵니다.
*/
TextureManager& App::GetTextureManager()
{
	return *m_pTextureManager;
}

/**
* @brief 상태 머신을 획득합니다.
*/
GameStateMachine& App::GetGameStateMachine()
{
	return *m_pGameStateMachine;
}

/**
* @brief 입력 모듈의 인스턴스를 가져옵니다.
*/
Input& App::GetInput()
{
	return *m_pInput;
}

#ifdef RS_WINDOWS

/**
* @brief 프레임을 업데이트합니다. (내부용)
* @details
* Note: 업데이트 순서는 다음과 같습니다.
* 1. UpdateInput();
* 2. ObjectUpdate(UpdateTime());
* 3. RenderClear();
* 4. RenderTransform();
* 5. Render();
* 6. RenderPresent();
*/
void App::Update()
{
	// 마지막 프레임 시간 측정
	QueryPerformanceCounter(&m_nTimeEnd);

	// 프레임 시간
	m_frameTime = (double)(m_nTimeEnd.QuadPart - m_nTimeStart.QuadPart) / ((double)(m_nTimeFreq.QuadPart));

	m_elapsed += m_frameTime;
	m_accumulateElapsed += m_frameTime;
	
	// 프레임 속도가 정상이라면 업데이트를 진행한다.
	while (m_elapsed >= DELAY_TIME) {
		UpdateInput();
		ObjectUpdate(m_frameTime);
		m_elapsed -= DELAY_TIME;
	}

	m_nFrameCount++;

	// 60 프레임이 지났는 지를 체크한다.
	if (m_accumulateElapsed >= 1.0) {

		// 모든 프레임 값의 누적 시간 / 1 프레임 시간
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

#if 0
	while(m_elapsed >= DELAY_TIME)
	{
		UpdateInput();
		ObjectUpdate(m_frameTime);
		m_elapsed -= DELAY_TIME;
		Sleep(1);
	}

	if (m_frameTime >= 1.0) {
		std::ostringstream oss; 
		oss << GAME_TITLE << m_nFrameCount << std::endl;
		SetWindowText(m_hWnd, &oss.str()[0]);
		m_nFPS = m_nFrameCount;
		m_nFrameCount = 0;
		m_elapsed = 0.0;
		m_nTimeStart = m_nTimeEnd;
	}
#endif

	// Rendering
	RenderClear();
	RenderTransform();
	Render();
	RenderPresent();

}

#endif // RS_WINDOWS (Update)

/**
* @brief 입력 모듈을 업데이트합니다
*/
void App::UpdateInput()
{
	m_pInput->update();
}

#ifdef RS_WINDOWS

/**
* @brief 렌더링에 필요한 DC를 준비합니다.
*/
void App::RenderClear()
{
	m_context.currentContext = CreateCompatibleDC(m_context.mainContext);
	m_context.currentSurface = CreateCompatibleBitmap(m_context.mainContext, GetWindowWidth(), GetWindowHeight());
	m_context.prevSurface = (HBITMAP)SelectObject(m_context.currentContext, m_context.currentSurface);
	m_context.newContext = NULL;
	m_context.rotateContext = NULL;
}

/**
* @brief 화면 맵핑 모드를 변경합니다.
*/
void App::RenderTransform()
{
	RECT rect;
	SetMapMode(m_context.mainContext, MM_ANISOTROPIC);
	GetClientRect(g_hWnd, &rect);
	// 논리 해상도(배율을 나눈 크기)를 창 전체에 맞춘다. RenderPresent 가 이 매핑으로 늘려 그린다
	SetWindowExtEx(m_context.mainContext, GetWindowWidth(), GetWindowHeight(), NULL);
	SetViewportExtEx(m_context.mainContext, rect.right, rect.bottom, NULL);
}

/**
* @brief 렌더링 결과를 화면에 출력하고 메모리를 정리합니다.
*/
void App::RenderPresent()
{
	SetStretchBltMode(m_context.mainContext, COLORONCOLOR);
	StretchBlt(m_context.mainContext, 0, 0, GetWindowWidth(), GetWindowHeight(),
		m_context.currentContext, 0, 0, GetWindowWidth(), GetWindowHeight(), SRCCOPY);

	DeleteObject(SelectObject(m_context.currentContext, m_context.prevSurface)); // 이전 상태로 복원
	DeleteObject(m_context.currentSurface); // 복사된 DC 삭제
	DeleteDC(m_context.currentContext);
}

#endif // RS_WINDOWS (RenderClear/RenderTransform/RenderPresent — SDL2 버전은 platform/sdl2/AppSDL2.cpp)

/**
* @brief frameTime을 업데이트 합니다.
*
* @return double
*/
double App::UpdateTime()
{
	return m_frameTime;

}

#ifdef RS_WINDOWS
/**
* @brief 메모리 정리 후 게임을 종료합니다.
*/
void App::Quit()
{
	::PostQuitMessage(0);
}
#endif // RS_WINDOWS (Quit — SDL2 버전은 platform/sdl2/AppSDL2.cpp)

/**
* @brief 포커스를 구합니다.
*/
bool App::GetFocus() const
{
	return m_bFocus;
}

/**
* @brief 폰트를 구합니다.
*/
GameFont* App::GetFont()
{
	return &m_pFont;
}

/**
* @brief 폰트를 로드합니다.
*/
bool App::LoadFont(std::string fontName)
{
	// 읽지 못한 파일이면 지금 폰트를 그대로 둔다
	if (!m_pFont->ParseFont(fontName))
	{
		return false;
	}

	return m_pFont->load();
}

/**
* @brief 폰트 메모리 해제
*
* @return true
* @return false
*/
bool App::DestroyFont()
{
	bool isValid = m_pFont->remove();

	m_pFont.reset();
	m_pFont.release();

	return isValid;
}

/**
* @brief Get the frame count
*
* @return int
*/
int App::GetFrameCount() const
{
	return m_nFPS;
}

#ifdef RS_WINDOWS
/**
* @brief Set the App Icon from a certain image.
*/
void App::SetAppIcon(std::string filename)
{
	std::string id = ":global:icon";
	HDC hDC = GetContext().mainContext;

	if (!std::ifstream(filename))
	{
		throw new std::exception("the file is not existed");
	}

	// Load the texture from certain file.
	bool bRet = m_pTextureManager->Load(filename, id, &hDC);

	if (!bRet) 
	{
		throw new std::exception("Cannot convert an image file to HBITMAP");
	}

	TextureData *texture = m_pTextureManager->m_textureMap[id];
	HBITMAP hBitmap = texture->texture;

	HBITMAP hBmMask = CreateCompatibleBitmap(hDC, texture->width, texture->height);

	if (hBmMask == NULL) 
	{
		throw new std::exception("Cannot make the hBitmap");
	}

	// Create an icon info
	ICONINFO iconInfo;
	ZeroMemory(&iconInfo, sizeof(ICONINFO));

	iconInfo.fIcon = TRUE;
	iconInfo.hbmColor = hBitmap;
	iconInfo.hbmMask = hBmMask;

	HICON hIcon = CreateIconIndirect(&iconInfo);
	if (hIcon == NULL) 
	{
		throw new std::exception("failed to create the hIcon.", GetLastError());
	}

	SendMessage(m_hWnd, WM_SETICON, ICON_BIG, (LPARAM)hIcon);
	SendMessage(m_hWnd, WM_SETICON, ICON_SMALL, (LPARAM)hIcon);
	SendMessage(m_hWnd, WM_SETICON, ICON_SMALL2, (LPARAM)hIcon);

	DeleteObject(hBmMask);

	if (!m_pTextureManager->Remove(id)) {
		throw new std::exception("failed to remove the texture");
	}

}
#endif // RS_WINDOWS (SetAppIcon — SDL2 버전은 platform/sdl2/AppSDL2.cpp)