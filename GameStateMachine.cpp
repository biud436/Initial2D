/**
 * @file GameStateMachine.cpp
 * @date 2018/03/26 11:28
 *
 * @author biud436
 * Contact: biud436@gmail.com
 *
 * @brief 
 *
 *
 * @note
*/

#include "GameStateMachine.h"
#include "GameState.h"


GameStateMachine::GameStateMachine()
{
}


GameStateMachine::~GameStateMachine()
{
}

void GameStateMachine::pushState(GameState* pNewState)
{
	m_gameStates.push_back(pNewState);
	m_gameStates.back()->onEnter();
}


void GameStateMachine::changeState(GameState* pNewState)
{
	if (!m_gameStates.empty())
	{
		// 같은 씬으로는 이동할 수 없다.
		if (m_gameStates.back()->getStateId() == pNewState->getStateId())
		{
			return;
		}

		if (m_gameStates.back()->onExit())
		{
			delete m_gameStates.back();
			m_gameStates.pop_back();
		}
	}

	m_gameStates.push_back(pNewState);
	m_gameStates.back()->onEnter();

}

void GameStateMachine::popState()
{
	if (!m_gameStates.empty())
	{
		if (m_gameStates.back()->onExit())
		{
			delete m_gameStates.back();
			m_gameStates.pop_back();
		}
	}
}

void GameStateMachine::update(float elapsed)
{
	if (!m_gameStates.empty())
	{
		m_gameStates.back()->update(elapsed);
	}
}

void GameStateMachine::render()
{
	if (!m_gameStates.empty())
	{
		m_gameStates.back()->render();
	}
}