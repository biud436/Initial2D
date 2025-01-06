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
	TCHAR szCurrentPath[MAX_PATH];

	GetModuleFileName(NULL, szCurrentPath, MAX_PATH);

	// 파일 이름을 제거하고 디렉토리 경로만 남깁니다
	PathRemoveFileSpec(szCurrentPath);

	// 백슬래시를 추가합니다
	PathAddBackslash(szCurrentPath);

#ifdef UNICODE
	std::wstring ws(szCurrentPath);
	return std::string(ws.begin(), ws.end());
#else
	return std::string(szCurrentPath);
#endif
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

	std::cout << "path:" << sCurrentPath << std::endl;

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

	// 게임 상태 머신 초기화
	m_pGameStateMachine = new GameStateMachine();
	m_pGameStateMachine->changeState(new MenuState());

	// Lua Interpreter Initialization
	Lua_Init();
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