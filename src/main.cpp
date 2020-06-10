/**
 * @file main.cpp
 * @date 2018/03/26 11:30
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
#include "MenuState.h"

#include "lua_tbl.h"

#include "SoundManager.h"

#include <ostream>
#include <fstream>

#include "Process.h"

#include <Shlwapi.h>
#pragma comment(lib, "shlwapi.lib")

#include "Encrypt.h"

extern HWND g_hWnd;

inline std::string GetExecutablePath() {
	HWND hWnd = GetForegroundWindow();
	HINSTANCE hInstance = (HINSTANCE)GetWindowLong(hWnd, GWL_HINSTANCE);
	TCHAR szCurrentPath[MAX_PATH];
	
	GetModuleFileName(NULL, szCurrentPath, sizeof(MAX_PATH));
	PathRemoveFileSpec(szCurrentPath);
	PathAddBackslash(szCurrentPath);

	std::string sCurrentPath = szCurrentPath;

	return sCurrentPath;
}

/**
* @brief 게임 모듈을 초기화합니다(상속 시 반드시 구현)
*/
void App::Initialize()
{
	m_context.mainContext = GetDC(m_hWnd);

	HWND hWnd = m_hWnd;

	LOG_D("생성되었습니다.");

	std::string sCurrentPath = GetExecutablePath();

	sCurrentPath.append("config.setting");

	std::cout << sCurrentPath << std::endl;

	// 설정 파일 작성
	std::ofstream configFile("config.setting");
	if (configFile.fail()) {
		throw new std::exception("");
	}

	bool isDebugMode = false;
	configFile << isDebugMode << "\n";
	configFile << sCurrentPath << "\n";

	std::string cd;
	cd.resize(MAX_PATH);
	GetCurrentDirectory(MAX_PATH, &cd[0]);
	cd.resize(MAX_PATH - 1);

	configFile << &cd[0] << "\n";

	// 마우스 및 키보드 모듈 초기화
	m_pInput->initialize(m_hWnd);

	// Set the App Icon from a certain image.
	SetAppIcon(".\\resources\\icons\\icon.png");

	// Lua Interpreter Initialization
	Lua_Init();
	
	// 게임 상태 머신 초기화
	m_pGameStateMachine = new GameStateMachine();
	m_pGameStateMachine->changeState(new MenuState());

	// 타 윈도우 생성
	m_window.start();

	// 프로세스 정보 출력
	try {
		Initial2D::Process process(L"powershell Get-Process");
		Initial2D::Process process2(L"cmd /c \"echo wow...\"");
	} catch(std::exception ex) {
#ifdef _DEBUG
		printf_s(ex.what());
#endif // !_DEBUG
	}
}

/**
* @brief 상태 머신을 업데이트 합니다(상속 시 반드시 구현)
*
* @param elapsed 이전 프레임에서 얼마만큼 지났는 지에 대한 시간
*
*/
void App::ObjectUpdate(double elapsed)
{
	Lua_Update(elapsed);
	m_pGameStateMachine->update(elapsed);
}

/**
* @brief 현재 프레임을 렌더링합니다(상속 시 반드시 구현)
*/
void App::Render()
{
	Lua_Render();
	m_pGameStateMachine->render();
	m_window.update();
}

/**
* @brief 메모리 해제(상속 시 반드시 구현)
*/
void App::Destroy()
{
	Lua_Destory();

	// 입력 객체 삭제
	DestroyFont();
	SAFE_DELETE(m_pInput);
	SAFE_DELETE(m_pGameStateMachine);
	SAFE_DELETE(m_pTextureManager);

	ReleaseDC(m_hWnd, m_context.mainContext);

}