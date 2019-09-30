/**
 * @file MenuState.h
 * @date 2018/03/26 11:34
 *
 * @author biud436
 * Contact: biud436@gmail.com
 *
 * @brief 
 *
 *
 * @note
*/

#ifndef MENUSTATE_H
#define MENUSTATE_H

#include "GameState.h"

///@cond
class GameObject;
// @endcond

using GameObjects = std::vector<GameObject*>;

/**
* @class MenuState
*/
class MenuState : public GameState
{
public:
	
	/**
	* ������Ʈ�� �����մϴ�.
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
	* ID�� ��ȯ�մϴ�.
	*/
	virtual std::string getStateId() const override
	{
		return m_strMenuId;
	}

	/**
	* @fn    	addChild
	* @brief
	* @return   std::string
	*/
	virtual void addChild(GameObject* p) override;

private:
	static const std::string m_strMenuId;
	GameObjects m_gameObjects;

};

#endif