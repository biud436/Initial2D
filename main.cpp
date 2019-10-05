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
	LOG_D("초기화");
	m_context.mainContext = GetDC(m_hWnd);

	// 마우스 및 키보드 모듈 초기화
	m_pInput->initialize(m_hWnd);

	// 루아 초기화
	Lua_Init();
	
	// 게임 상태 머신 초기화
	m_pGameStateMachine = new GameStateMachine();
	m_pGameStateMachine->changeState(new MenuState());

	mrb_state* mrb = mrb_open();
	if (!mrb) {
		LOG_D("mrb 초기화 실패");
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

	// 입력 객체 삭제
	DestroyFont();
	SAFE_DELETE(m_pInput);
	SAFE_DELETE(m_pGameStateMachine);
	SAFE_DELETE(m_pTextureManager);

	ReleaseDC(m_hWnd, m_context.mainContext);

}