/**
 * @file GameStateMachine.h
 * @date 2018/03/26 11:25
 *
 * @author biud436
 * Contact: biud436@gmail.com
 *
 * @brief 
 *
 *
 * @note
*/

#ifndef GAMESTATEMACHINE_H
#define GAMESTATEMACHINE_H

#include <vector>

class GameState;

/**
 * @class GameStateMachine
 * @brief 
 */
class GameStateMachine
{
public:
	GameStateMachine();
	virtual ~GameStateMachine();

	/**
	* @fn    	pushState
	* @brief 	
	* @param 	GameState * pNewState
	* @return   void
	*/
	void pushState(GameState* pNewState);


	/**
	* @fn    	changeState
	* @brief 	
	* @param 	GameState * pNewState
	* @return   void
	*/
	void changeState(GameState* pNewState);


	/**
	* @fn    	popState
	* @brief 	
	* @return   void
	*/
	void popState();


	/**
	* @fn    	update
	* @brief 	
	* @param 	float elapsed
	* @return   void
	*/
	void update(float elapsed);


	/**
	* @fn    	render
	* @brief 	
	* @return   void
	*/
	void render();

	/**
	* @fn    	current
	* @brief
	* @return   GameState* 
	*/
	GameState* current();


private:

	std::vector<GameState*> m_gameStates;

};

#endif

