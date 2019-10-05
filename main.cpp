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

#include <stdio.h>
#include <mruby.h>
#include <mruby/compile.h>

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

	mrb_state* mrb = mrb_open();
	if (!mrb) {
		LOG_D("mrb �ʱ�ȭ ����");
		return;
	}

	mrb_load_string(mrb, "p 'hello world!'");
	mrb_close(mrb);

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