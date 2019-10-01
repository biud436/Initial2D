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
	std::cout << ##MSG << std::endl;
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

	/**
	 * @struct DeviceContext
	 * @brief DeviceContext ����
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
	* ���� ����� �ʱ�ȭ�մϴ�(��� �� �ݵ�� ����)
	*/
	virtual void Initialize();

	/**
	* ���� ����� �ʱ�ȭ�ϰ� ���� ������ �����մϴ�.
	*/
	int Run(int nCmdShow);

	/**
	* �޽����� ó���մϴ�.
	*/
	LRESULT HandleEvent(HWND hWnd, UINT uMsg, WPARAM wParam, LPARAM lParam);

	/**
	* WindowName�� ���մϴ�.
	*/
	const char* GetWindowName();

	/**
	* ClassName�� ���մϴ�.
	*/
	const char* GetClassName();

	/**
	* â�� ���� ���մϴ�.
	*/
	const int GetWindowWidth();

	/**
	* â�� ���̸� ���մϴ�.
	*/
	const int GetWindowHeight();

	/**
	* ���� Context�� �����ɴϴ�.
	*/
	DeviceContext& GetContext();

	/**
	* TextureManager�� �ν��Ͻ��� �����ɴϴ�.
	*/
	TextureManager& GetTextureManager();

	/**
	* ���� �ӽ��� ȹ���մϴ�.
	*/
	GameStateMachine& GetGameStateMachine();

	/**
	* �Է� ����� �ν��Ͻ��� �����ɴϴ�.
	*/
	Input& GetInput();

	/**
	* �������� ������Ʈ�մϴ�. (���ο�)
	*
	* Note: ������Ʈ ������ ������ �����ϴ�. 
	* 1. UpdateInput();
	* 2. ObjectUpdate(UpdateTime());
	* 3. RenderClear();
	* 4. RenderTransform();
	* 5. Render();
	* 6. RenderPresent();
	*/
	void Update();

	/**
	* �Է� ����� ������Ʈ�մϴ�
	*/
	void UpdateInput();

	/**
	* ���� �ӽ��� ������Ʈ �մϴ�(��� �� �ݵ�� ����)
	*
	* @param elapsed ���� �����ӿ��� �󸶸�ŭ ������ ���� ���� �ð�
	*
	*/
	virtual void ObjectUpdate(double elapsed);

	/**
	* frameTime�� ������Ʈ �մϴ�.
	*/
	double UpdateTime();

	/**
	* �������� �ʿ��� DC�� �غ��մϴ�.
	*/
	void RenderClear();

	/**
	* ȭ�� ���� ��带 �����մϴ�.
	*/
	void RenderTransform();

	/**
	* ���� �������� �������մϴ�(��� �� �ݵ�� ����)
	*/
	virtual void Render();

	/**
	* ������ ����� ȭ�鿡 ����ϰ� �޸𸮸� �����մϴ�.
	*/
	void RenderPresent();
	
	/**
	* �޸� ����(��� �� �ݵ�� ����)
	*/
	virtual void Destroy();

	/**
	* �޸� ���� �� ������ �����մϴ�.
	*/
	void Quit();

	/**
	* ��Ŀ���� ���մϴ�.
	*/
	bool GetFocus();

	/**
	 * ��Ʈ�� ���մϴ�.
	 */
	GameFont* GetFont();

	/**
	* ��Ʈ�� �ε��մϴ�.
	*/
	bool LoadFont(std::string fontName);

	/**
	* ��Ʈ �޸� ����
	*/
	bool DestroyFont();

	/**
	* ������ ī��Ʈ
	*/
	int GetFrameCount();

protected:

	const char*       m_szWindowName;			// ������ �̸�
	const char*       m_szClassName;			// Ŭ���� �̸�
	int               m_nWindowWidth;					// â�� ��
	int               m_nWindowHeight;				// â�� ����

	int               m_nFPS;

	double            m_elapsed;

	// �ؽ�ó ������
	TextureManager*   m_pTextureManager;

	HWND              m_hWnd;	// ������ �ڵ�

								// ������ ����
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

private:

	App();
	virtual ~App();
	App(const App& other);
	void operator=(const App&);

};

#endif