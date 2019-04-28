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

extern HWND g_hWnd;

void App::Initialize()
{
	LOG_D("�ʱ�ȭ");
	m_context.mainContext = GetDC(m_hWnd);

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
	m_pGameStateMachine->update(elapsed);

	Lua_Update(elapsed);

}


void App::Render()
{
	m_pGameStateMachine->render();

	Lua_Render();

}


void App::Destroy()
{
	Lua_Destory();

	// �Է� ��ü ����
	SAFE_DELETE(m_pInput);
	SAFE_DELETE(m_pGameStateMachine);
	SAFE_DELETE(m_pTextureManager);

	ReleaseDC(m_hWnd, m_context.mainContext);

}