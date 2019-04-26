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

const std::string MenuState::m_strMenuId = "MENU";


bool MenuState::onEnter()
{
	LOG_D("MenuState.onEnter()");

	TextureManager &tm = App::GetInstance().GetTextureManager();
	tm.Load(".\\resources\\Ruins4.png", "Ruins4", NULL);
	tm.Load(".\\resources\\011-Lancer03.png", "character1", NULL);

	//Audio->load("resources/test.ogg", "bgm", SOUND_MUSIC);
	//Audio->playMusic("bgm", -1);

	// 배경 생성
	Sprite* pBackground = new Sprite();
	pBackground->initialize(0, 0, 640, 480, 1, "Ruins4");
	pBackground->setX(0.0f);
	pBackground->setY(0.0f);
	pBackground->setLoop(false);
	pBackground->setFrameDelay(0.0f);
	pBackground->setAngle(0.0f);

	// 캐릭터 생성
	Sprite* pCharacter = new Sprite();
	pCharacter->initialize(0, 0, 32, 48, 4, "character1");
	pCharacter->setX(WINDOW_WIDTH / 2 - 16);
	pCharacter->setY(WINDOW_HEIGHT / 2 - 24);
	pCharacter->setLoop(true);
	pCharacter->setFrameDelay(0.25f);
	pCharacter->setAngle(10.0f);
	pCharacter->setScale(3.0f);

	m_gameObjects.push_back(pBackground);
	m_gameObjects.push_back(pCharacter);

	return true;
}


bool MenuState::onExit()
{
	LOG_D("MenuState.onExit()");

	Audio->fadeOutMusic(1000);
	Audio->releaseMusic("bgm");

	// 텍스처 제거
	TextureManager &tm = App::GetInstance().GetTextureManager();
	tm.Remove("Ruins4");
	tm.Remove("character1");

	// 게임 오브젝트 제거
	for (auto i : m_gameObjects)
	{
		delete i;
	}

	m_gameObjects.clear();

	return true;
}


void MenuState::update(float elapsed)
{

	if (InputManager.isKeyDown('P')) {
		Audio->pauseMusic();	
	}
	if (InputManager.isKeyDown('R')) {
		Audio->resumeMusic();
	}

	for (auto i : m_gameObjects)
	{
		if (i->getSpriteData().id == "character1")
		{

			if (InputManager.isKeyPress(VK_RIGHT))
				i->setAngle(i->getAngle() - 3.0f);
			else if (InputManager.isKeyPress(VK_LEFT))
				i->setAngle(i->getAngle() + 3.0f);
		}

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
