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

#include <Shlwapi.h>
#pragma comment(lib, "shlwapi.lib")

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

	LOG_D("�����Ǿ����ϴ�.");

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

	// ���콺 �� Ű���� ��� �ʱ�ȭ
	m_pInput->initialize(m_hWnd);

	// ��� �ʱ�ȭ
	Lua_Init();
	
	// ���� ���� �ӽ� �ʱ�ȭ
	m_pGameStateMachine = new GameStateMachine();
	m_pGameStateMachine->changeState(new MenuState());

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

	// �Է� ��ü ����
	DestroyFont();
	SAFE_DELETE(m_pInput);
	SAFE_DELETE(m_pGameStateMachine);
	SAFE_DELETE(m_pTextureManager);

	ReleaseDC(m_hWnd, m_context.mainContext);

}