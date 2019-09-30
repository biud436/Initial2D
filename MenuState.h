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
	* 업데이트를 수행합니다.
	*/
	virtual void update(float elapsed) override;
	
	/**
	* 렌더링을 수행합니다.
	*/
	virtual void render() override;
	
	/**
	* 진입 시에 수행됩니다.
	*/
	virtual bool onEnter() override;
	
	/**
	* 제거 시에 수행됩니다.
	*/
	virtual bool onExit() override;

	/**
	* ID를 반환합니다.
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