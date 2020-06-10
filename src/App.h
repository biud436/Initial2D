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
class App : private UnCopyable
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
	 * @brief ���� ����� �ʱ�ȭ�մϴ�(��� �� �ݵ�� ����)
	 */
	virtual void Initialize();

	/**
	 * @brief ���� ����� �ʱ�ȭ�ϰ� ���� ������ �����մϴ�.
	 */
	int Run(int nCmdShow);

	/**
	 * @brief �޽����� ó���մϴ�.
	 */
	LRESULT HandleEvent(HWND hWnd, UINT uMsg, WPARAM wParam, LPARAM lParam);

	/**
	 * @brief WindowName�� ���մϴ�.
	 */
	const char* GetWindowName();

	/**
	 * @brief ClassName�� ���մϴ�.
	 */
	const char* GetClassName();

	/**
	 * @brief â�� ���� ���մϴ�.
	 */
	const int GetWindowWidth();

	/**
	 * @brief â�� ���̸� ���մϴ�.
	 */
	const int GetWindowHeight();

	/**
	 * @brief ���� Context�� �����ɴϴ�.
	 */
	DeviceContext& GetContext();

	/**
	 * @brief TextureManager�� �ν��Ͻ��� �����ɴϴ�.
	 */
	TextureManager& GetTextureManager();

	/**
	 * @brief ���� �ӽ��� ȹ���մϴ�.
	 */
	GameStateMachine& GetGameStateMachine();

	/**
	 * @brief �Է� ����� �ν��Ͻ��� �����ɴϴ�.
	 */
	Input& GetInput();

	/**
	 * @brief �������� ������Ʈ�մϴ�. (���ο�)
	 * @details
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
	 * @brief �Է� ����� ������Ʈ�մϴ�
	 */
	void UpdateInput();

	/**
	 * @brief ���� �ӽ��� ������Ʈ �մϴ�(��� �� �ݵ�� ����)
	 *
	 * @param elapsed ���� �����ӿ��� �󸶸�ŭ ������ ���� ���� �ð�
	 *
	 */
	virtual void ObjectUpdate(double elapsed);

	/**
	 * @brief frameTime�� ������Ʈ �մϴ�.
	 * 
	 * @return double 
	 */
	double UpdateTime();

	/**
	 * @brief �������� �ʿ��� DC�� �غ��մϴ�.
	 */
	void RenderClear();

	/**
	 * @brief ȭ�� ���� ��带 �����մϴ�.
	 */
	void RenderTransform();

	/**
	 * @brief ���� �������� �������մϴ�(��� �� �ݵ�� ����)
	 */
	virtual void Render();

	/**
	 * @brief ������ ����� ȭ�鿡 ����ϰ� �޸𸮸� �����մϴ�.
	 */
	void RenderPresent();
	
	/**
	 * @brief �޸� ����(��� �� �ݵ�� ����)
	 */
	virtual void Destroy();

	/**
	 * @brief �޸� ���� �� ������ �����մϴ�.
	 */
	void Quit();

	/**
	 * @brief ��Ŀ���� ���մϴ�.
	 */
	bool GetFocus();

	/**
	 * @brief ��Ʈ�� ���մϴ�.
	 */
	GameFont* GetFont();

	/**
	 * @brief ��Ʈ�� �ε��մϴ�.
	 */
	bool LoadFont(std::string fontName);

	/**
	 * @brief ��Ʈ �޸� ����
	 */

	/**
	 * @brief 
	 * 
	 * @return true 
	 * @return false 
	 */
	bool DestroyFont();

	/**
	 * @brief Get the frame count
	 * 
	 * @return int 
	 */
	int GetFrameCount();


	/**
	 * @brief Set the App Icon from a certain image.
	 */
	void SetAppIcon(std::string filename);

protected:

	const char*       m_szWindowName;			// ������ �̸�
	const char*       m_szClassName;			// Ŭ���� �̸�
	int               m_nWindowWidth;					// â�� ��
	int               m_nWindowHeight;				// â�� ����

	int               m_nFPS;

	double            m_elapsed;
	double            m_accumulateElapsed;

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