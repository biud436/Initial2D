/**
 * @file GameState.h
 * @date 2018/03/26 11:21
 *
 * @author biud436
 * Contact: biud436@gmail.com
 *
 * @brief 
 *
 *
 * @note
*/

#ifndef GAMESTATE_H
#define GAMESTATE_H

#include <string>
#include <vector>

/**
 * @class GameState
 * @brief 
 */
class GameState
{
public:

	/**
	* @fn    	update
	* @brief 	
	* @param 	float elapsed
	* @return   void
	*/
	virtual void update(float elapsed) = 0;


	/**
	* @fn    	render
	* @brief 	
	* @return   void
	*/
	virtual void render() = 0;


	/**
	* @fn    	onEnter
	* @brief 	
	* @return   bool
	*/
	virtual bool onEnter() = 0;


	/**
	* @fn    	onExit
	* @brief 	
	* @return   bool
	*/
	virtual bool onExit() = 0;


	/**
	* @fn    	getStateId
	* @brief 	
	* @return   std::string
	*/
	virtual std::string getStateId() const = 0;
};

#endif