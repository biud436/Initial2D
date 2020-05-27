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

void App::Initialize()
{
	m_context.mainContext = GetDC(m_hWnd);

	HWND hWnd = m_hWnd;

	LOG_D("생성되었습니다.");

	std::string sCurrentPath = GetExecutablePath();

	sCurrentPath.append("config.setting");

	std::cout << sCurrentPath << std::endl;

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

	std::vector<std::string> dirs;
	Initial2D::ReadDirectory(dirs, std::string(".\\resources\\*.*"));
	for (std::vector<std::string>::iterator iter = dirs.begin(); iter != dirs.end(); iter++) {
		std::cout << *iter << std::endl;
	}

	// Lua Interpreter Initialization
	Lua_Init();
	
	// 게임 상태 머신 초기화
	m_pGameStateMachine = new GameStateMachine();
	m_pGameStateMachine->changeState(new MenuState());

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


void App::ObjectUpdate(double elapsed)
{
	Lua_Update(elapsed);
	m_pGameStateMachine->update(elapsed);
}


void App::Render()
{
	Lua_Render();
	m_pGameStateMachine->render();
}


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