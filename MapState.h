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
 * 타일맵 로더
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
	* 프레임을 업데이트합니다.
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
	* 상태 ID 값을 반환합니다.
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