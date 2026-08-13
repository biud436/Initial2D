/**
 * @file App.h
 * @date 2018/03/26 11:18
 *
 * @author biud436
 * Contact: biud436@gmail.com
 *
 * @brief 
 * 코드가 상당히 개판이다.
 * @note
*/

#ifndef APP_H
#define APP_H

#include "Constants.h"

#ifdef RS_WINDOWS
#include <Windows.h>
#include <tchar.h>
#else
#include <SDL.h>
#include "platform/WinTypes.h"
#endif

#include <vector>
#include <iostream>
#include <string>
#include <memory>
#include <sstream>
#include "NonCopyable.h"
#include "Window.h"

#ifdef RS_WINDOWS
#ifdef _UNICODE
#define _tsprintf swprintf;
#else
#define _tsprintf sprintf;
#endif
#endif

/** 
 * @def LOG_D(MSG)
 * 디버그 콘솔에 디버그 메시지 #MSG를 출력합니다.
 */
#ifndef NDEBUG
#define LOG_D(MSG) \
	std::cout << MSG << std::endl;	
#else
#define LOG_D(MSG)
#endif

/**
 * @def InputManager 
 * Input 객체의 인스턴스를 바로 획득합니다.
 */
#define InputManager App::GetInstance().GetInput()

 /**
 * @def TheTextureManager
 * TextureManager의 인스턴스를 바로 획득합니다.
 */
#define TheTextureManager App::GetInstance().GetTextureManager()

/// @cond
class Sprite;
class Input;
class GameStateMachine;
class TextureManager;
class Font;
class DXCore;
/// @endcond

using GameFont = std::unique_ptr<Font>;


/**
 * @class App
 * @author biud436 (biud436@gmail.com)
 * @brief 게임 모듈
 * @details
 상속 시 Initialize, ObjectUpdate, Render, Destroy는 반드시 오버라이드해야 합니다.
 */
class App
{
public:

#ifdef RS_WINDOWS
	struct DeviceContext {

		HDC mainContext;
		HDC currentContext;
		HDC rotateContext;
		HDC newContext;

		HBITMAP currentSurface;
		HBITMAP prevSurface;

	} m_context;
#else
	/** SDL2 어댑터의 디바이스 컨텍스트 — GDI DeviceContext에 대응 */
	struct DeviceContext {

		SDL_Window*   window;
		SDL_Renderer* renderer;

	} m_context;
#endif
	
	static App* s_pInstance;
	static App& GetInstance();

	virtual void Initialize();
	
	int Run(int nCmdShow);

#ifdef RS_WINDOWS
	LRESULT HandleEvent(HWND hWnd, UINT uMsg, WPARAM wParam, LPARAM lParam);
#else
	void HandleEvent(const SDL_Event& event);
#endif

	const char* GetWindowName() const;
	const char* GetClassName() const;
	const int GetWindowWidth() const;
	const int GetWindowHeight() const;

	DeviceContext& GetContext();
	TextureManager& GetTextureManager();
	GameStateMachine& GetGameStateMachine();
	Input& GetInput();

#ifdef RS_WINDOWS
	void Update();
#endif
	void UpdateInput();
	virtual void ObjectUpdate(double elapsed);
	double UpdateTime();

	void RenderClear();
	void RenderTransform();
	virtual void Render();
	void RenderPresent();
	virtual void Destroy();

	void Quit();

	bool GetFocus() const;

	GameFont* GetFont();

	bool LoadFont(std::string fontName);
	bool DestroyFont();

	int GetFrameCount() const;

	void SetAppIcon(std::string filename);

#ifdef RS_WINDOWS
	HWND GetWindowHandle() const { return m_hWnd;  }
#else
	SDL_Window* GetWindowHandle() const { return m_context.window; }
#endif

protected:

	const char*       m_szWindowName;			
	const char*       m_szClassName;			
	int               m_nWindowWidth;			
	int               m_nWindowHeight;			

	int               m_nFPS;

	double            m_elapsed;
	double            m_accumulateElapsed;

	TextureManager*   m_pTextureManager;

#ifdef RS_WINDOWS
	HWND              m_hWnd;

	LARGE_INTEGER	  m_nTimeFreq;
	LARGE_INTEGER	  m_nTimeStart;
	LARGE_INTEGER	  m_nTimeEnd;
#endif
	double			  m_frameTime;
	int				  m_nFrameCount;

	// 입력
	Input*            m_pInput;

	// 장면 관리
	GameStateMachine* m_pGameStateMachine;

	// 창 포커스
	bool              m_bFocus;

	// 폰트 아틀라스
	GameFont          m_pFont;

private:

	App();
	virtual ~App();

	App(const App&);
	App& operator=(const App&);

};

#endif