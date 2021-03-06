/**
 * @file MenuState.cpp
 * @date 2018/03/26 11:35
 *
 * @author biud436
 * Contact: biud436@gmail.com
 *
 * @brief 
 *
 *
 * @note
*/

#include "MenuState.h"
#include "App.h"
#include "TextureManager.h"
#include "Sprite.h"
#include "Input.h"
#include "SoundManager.h"
#include "GameObject.h"
#include "ExperimentalFont.h"
#include "GameStateMachine.h"
#include "MapState.h"

const std::string MenuState::m_strMenuId = "MENU";


bool MenuState::onEnter()
{
	//AntiAliasingFont* pFont = new AntiAliasingFont(L"��������", 36);
	//pFont->setText(L"�ȳ��ϼ���?")
	//	.setPosition(100, 100)
	//	.setTextColor(255, 0, 0);

	//m_gameObjects.push_back(pFont);

	App::GetInstance().GetGameStateMachine().changeState(new MapState());

	return true;
}


bool MenuState::onExit()
{
	// ���� ������Ʈ ����
	for (auto i : m_gameObjects)
	{
		delete i;
	}

	m_gameObjects.clear();

	return true;
}


void MenuState::update(float elapsed)
{

	for (auto i : m_gameObjects)
	{
		i->update(elapsed);
	}
}


void MenuState::render()
{
	for (auto i : m_gameObjects)
	{
		i->draw();
	}
}


void MenuState::addChild(GameObject* p)
{
	m_gameObjects.push_back(p);
}