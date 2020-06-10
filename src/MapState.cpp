/**
 * @file MapState.cpp
 * @date 2018/03/26 11:33
 *
 * @author biud436
 * Contact: biud436@gmail.com
 *
 * @brief 
 *
 *
 * @note
*/

#include "MapState.h"
#include "App.h"
#include "Sprite.h"
#include "GameObject.h"

const std::string MapState::m_strMapId = "MAP";


void MapState::update(float elapsed)
{
	for (auto i : m_gameObjects)
	{
		i->update(elapsed);
	}
}


void MapState::render()
{
	for (auto i : m_gameObjects)
	{
		i->draw();
	}
}


bool MapState::onEnter()
{
	return true;
}


bool MapState::onExit()
{
	for (auto i : m_gameObjects)
	{
		delete i;
	}

	m_gameObjects.clear();

	return true;
}