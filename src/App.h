/**
 * @file App.h
 * @date 2018/03/26 11:18
 *
 * @author biud436
 * Contact: biud436@gmail.com
 *
 * @brief 
 * �ڵ尡 ����� �����̴�.
 * @note
*/

#ifndef APP_H
#define APP_H

#include <Windows.h>
#include <vector>
#include "Constants.h"

#include <iostream>
#include <string>
#include <memory>
#include <tchar.h>
#include <sstream>
#include "NonCopyable.h"
#include "Window.h"


#ifdef _UNICODE
#define _tsprintf swprintf;
#else
#define _tsprintf sprintf;
#endif

/** 
 * @def LOG_D(MSG)
 * ����� �ֿܼ� ����� �޽��� #MSG�� ����մϴ�.
 */
#ifndef NDEBUG
#define LOG_D(MSG) \
	std::cout << MSG << std::endl;	
#else
#define LOG_D(MSG)
#endif

/**
 * @def InputManager 
 * Input ��ü�� �ν��Ͻ��� �ٷ� ȹ���մϴ�.
 */
#define InputManager App::GetInstance().GetInput()

 /**
 * @def TheTextureManager
 * TextureManager�� �ν��Ͻ��� �ٷ� ȹ���մϴ�.
 */
#define TheTextureManager App::GetInstance().GetTextureManager()

/// @cond
class Sprite;
class Input;
class GameStateMachine;
class TextureManager;
class Font;
/// @endcond

using GameFont = std::unique_ptr<Font>;


/**
 * @class App
 * @author biud436 (biud436@gmail.com)
 * @brief ���� ���
 * @details
 ��� �� Initialize, ObjectUpdate, Render, Destroy�� �ݵ�� �������̵��ؾ� �մϴ�.
 */
class App
{
public:

	struct DeviceContext {

		HDC mainContext;
		HDC currentContext;
		HDC rotateContext;
		HDC newContext;

		HBITMAP currentSurface;
		HBITMAP prevSurface;

	} m_context;
	
	static App* s_pInstance;
	static App& GetInstance();

	virtual void Initialize();
	
	int Run(int nCmdShow);

	LRESULT HandleEvent(HWND hWnd, UINT uMsg, WPARAM wParam, LPARAM lParam);

	const char* GetWindowName() const;
	const char* GetClassName() const;
	const int GetWindowWidth() const;
	const int GetWindowHeight() const;

	DeviceContext& GetContext();
	TextureManager& GetTextureManager();
	GameStateMachine& GetGameStateMachine();
	Input& GetInput();

	void Update();
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

	HWND GetWindowHandle() const { return m_hWnd;  }

protected:

	const char*       m_szWindowName;			
	const char*       m_szClassName;			
	int               m_nWindowWidth;			
	int               m_nWindowHeight;			

	int               m_nFPS;

	double            m_elapsed;
	double            m_accumulateElapsed;

	TextureManager*   m_pTextureManager;

	HWND              m_hWnd;	

	LARGE_INTEGER	  m_nTimeFreq;
	LARGE_INTEGER	  m_nTimeStart;
	LARGE_INTEGER	  m_nTimeEnd;
	double			  m_frameTime;
	int				  m_nFrameCount;

	// �Է�
	Input*            m_pInput;

	// ��� ����
	GameStateMachine* m_pGameStateMachine;

	// â ��Ŀ��
	bool              m_bFocus;

	// ��Ʈ ��Ʋ��
	GameFont          m_pFont;

	Window m_window;

private:

	App();
	virtual ~App();

	App(const App&);
	App& operator=(const App&);

};

#endif