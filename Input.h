/**
 * @file Input.h
 * @date 2018/03/26 11:14
 *
 * @author biud436
 * Contact: biud436@gmail.com
 *
 * @brief 
 * 2018.06.21 - 가상 함수 제거
 * @note
*/

#ifndef INPUT_H
#define INPUT_H

#define WIN32_LEAN_AND_MEAN
#include <Windows.h>
#include "Vector2D.h"
#include "Constants.h"
#include "NonCopyable.h"

#define RELEASED 0
#define PRESSED 1

/**
 * @class Input
 * @brief 입력 모듈
 */
class Input : private noncopyable
{
public:

	/**
	 * Note: 키 눌림은 키가 눌리지 않음, 키 눌림, 키 뗌, 키가 계속 눌림 등 4가지 상태로 구분합니다.
	 */
	enum KEY_STATE
	{
		KB_NONE = 0,
		KB_DOWN = 1,
		KB_UP = 2,
		KB_PRESS = 3
	};

public:
	Input();
	virtual ~Input();

	/**
	* 입력 모듈을 초기화합니다.
	*/
	void initialize(HWND hWnd);

	/**
	* 입력 모듈을 업데이트합니다.
	*/
	void update();

	/**
	* 특정 키가 눌렸는 지 확인합니다.
	*/
	bool isKeyDown(int vKey) const;

	/**
	* 특정 키를 눌렀다가 뗐는 지 확인합니다.
	*/
	bool isKeyUp(int vKey) const;

	/**
	* 특정 키가 눌린 상태 인지 확인합니다.
	*/
	bool isKeyPress(int vKey) const;

	/**
	* 아무 버튼이나 눌렀는 지 확인합니다.
	*/
	bool isAnyKeyDown() const;

	/**
	* 마우스 X 좌표 반환합니다.
	*/
	float getMouseX();

	/**
	* 마우스 Y 좌표 반환합니다.
	*/
	float getMouseY();

	/**
	* 특정 마우스 버튼을 눌렀는 지 확인합니다.
	*/
	bool isMouseDown(int vKey) const;

	/**
	* 특정 마우스 버튼을 눌렀다가 뗐는 지 확인합니다.
	*/
	bool isMouseUp(int vKey) const;

	/**
	* 특정 마우스 버튼을 눌린 상태인지 확인합니다.
	*/
	bool isMousePress(int vKey) const;

	/**
	* 아무 마우스 버튼이나 눌렀는 지 확인합니다.
	*/
	bool isAnyMouseDown() const;

	/**
	* 마우스 휠 값을 확인합니다.
	*/
	int getMouseZ() const;

	/**
	* 마우스 휠 값을 설정합니다.
	*/
	void setMouseZ(int value);


protected:
	void updateKeyboard();
	void updateMouse();

protected:

	HWND m_hWnd;
	Vector2D m_mouse;
	
	BYTE m_kbCurrent[256];
	BYTE m_kbOld[256];
	BYTE m_kbMap[256];

	BYTE m_mbCurrent[8];
	BYTE m_mbOld[8];
	BYTE m_mbMap[8];

	int m_nWheel;

private:

	// 복사 및 대입 연산 불필요 (불가능하게 설정)
	Input(const Input&);
	void operator=(const Input&);

};

#endif