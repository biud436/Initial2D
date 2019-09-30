/**
 * @file MapState.h
 * @date 2018/03/26 11:30
 *
 * @author biud436
 * Contact: biud436@gmail.com
 *
 * @brief 
 * 
 *
 * @todo
 * Ÿ�ϸ� �δ�
*/

#ifndef MAPSTATE_H
#define MAPSTATE_H

#include "GameState.h"

class GameObject;

using GameObjects = std::vector<GameObject*>;

/**
*	@file MapState.h
*	@author biud436
*	@brief
*/
class MapState :
	public GameState
{
public:

	/**
	* �������� ������Ʈ�մϴ�.
	*/
	virtual void update(float elapsed) override;


	/**
	* �������� �����մϴ�.
	*/
	virtual void render() override;


	/**
	* ���� �ÿ� ����˴ϴ�.
	*/
	virtual bool onEnter() override;


	/**
	* ���� �ÿ� ����˴ϴ�.
	*/
	virtual bool onExit() override;


	/**
	* ���� ID ���� ��ȯ�մϴ�.
	* @return   std::string
	*/
	virtual std::string getStateId() const override
	{
		return m_strMapId;
	}

private:
	static const std::string m_strMapId;
	GameObjects m_gameObjects;
};

#endif