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

#include <Windows.h>
#include <vector>
#include "Constants.h"

#include <iostream>
#include <string>
#include <memory>
#include <tchar.h>
#include <sstream>

#ifdef _UNICODE
#define _tsprintf swprintf;
#else
#define _tsprintf sprintf;
#endif

/** 
 * @def LOG_D(MSG)
 * 디버그 콘솔에 디버그 메시지 #MSG를 출력합니다.
 */
#ifndef NDEBUG
#define LOG_D(MSG) \
	std::cout << ##MSG << std::endl;
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

	/**
	 * @struct DeviceContext
	 * @brief DeviceContext 보관
	 *
	 */
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

	/**
	* 게임 모듈을 초기화합니다(상속 시 반드시 구현)
	*/
	virtual void Initialize();

	/**
	* 게임 모듈을 초기화하고 게임 루프를 실행합니다.
	*/
	int Run(int nCmdShow);

	/**
	* 메시지를 처리합니다.
	*/
	LRESULT HandleEvent(HWND hWnd, UINT uMsg, WPARAM wParam, LPARAM lParam);

	/**
	* WindowName을 구합니다.
	*/
	const char* GetWindowName();

	/**
	* ClassName을 구합니다.
	*/
	const char* GetClassName();

	/**
	* 창의 폭을 구합니다.
	*/
	const int GetWindowWidth();

	/**
	* 창의 높이를 구합니다.
	*/
	const int GetWindowHeight();

	/**
	* 현재 Context를 가져옵니다.
	*/
	DeviceContext& GetContext();

	/**
	* TextureManager의 인스턴스를 가져옵니다.
	*/
	TextureManager& GetTextureManager();

	/**
	* 상태 머신을 획득합니다.
	*/
	GameStateMachine& GetGameStateMachine();

	/**
	* 입력 모듈의 인스턴스를 가져옵니다.
	*/
	Input& GetInput();

	/**
	* 프레임을 업데이트합니다. (내부용)
	*
	* Note: 업데이트 순서는 다음과 같습니다. 
	* 1. UpdateInput();
	* 2. ObjectUpdate(UpdateTime());
	* 3. RenderClear();
	* 4. RenderTransform();
	* 5. Render();
	* 6. RenderPresent();
	*/
	void Update();

	/**
	* 입력 모듈을 업데이트합니다
	*/
	void UpdateInput();

	/**
	* 상태 머신을 업데이트 합니다(상속 시 반드시 구현)
	*
	* @param elapsed 이전 프레임에서 얼마만큼 지났는 지에 대한 시간
	*
	*/
	virtual void ObjectUpdate(double elapsed);

	/**
	* frameTime을 업데이트 합니다.
	*/
	double UpdateTime();

	/**
	* 렌더링에 필요한 DC를 준비합니다.
	*/
	void RenderClear();

	/**
	* 화면 맵핑 모드를 변경합니다.
	*/
	void RenderTransform();

	/**
	* 현재 프레임을 렌더링합니다(상속 시 반드시 구현)
	*/
	virtual void Render();

	/**
	* 렌더링 결과를 화면에 출력하고 메모리를 정리합니다.
	*/
	void RenderPresent();
	
	/**
	* 메모리 해제(상속 시 반드시 구현)
	*/
	virtual void Destroy();

	/**
	* 메모리 정리 후 게임을 종료합니다.
	*/
	void Quit();

	/**
	* 포커스를 구합니다.
	*/
	bool GetFocus();

	/**
	 * 폰트를 구합니다.
	 */
	GameFont* GetFont();

	/**
	* 폰트를 로드합니다.
	*/
	bool LoadFont(std::string fontName);

	/**
	* 폰트 메모리 해제
	*/
	bool DestroyFont();

	/**
	* 프레임 카운트
	*/
	int GetFrameCount();

protected:

	const char*       m_szWindowName;			// 윈도우 이름
	const char*       m_szClassName;			// 클래스 이름
	int               m_nWindowWidth;					// 창의 폭
	int               m_nWindowHeight;				// 창의 높이

	int               m_nFPS;

	double            m_elapsed;

	// 텍스처 관리자
	TextureManager*   m_pTextureManager;

	HWND              m_hWnd;	// 윈도우 핸들

								// 프레임 관리
	LARGE_INTEGER	  m_nTimeFreq;
	LARGE_INTEGER	  m_nTimeStart;
	LARGE_INTEGER	  m_nTimeEnd;
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
	App(const App& other);
	void operator=(const App&);

};

#endif