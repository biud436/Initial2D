/**
 * @file Input.h
 * @date 2018/03/26 11:14
 *
 * @author biud436
 * Contact: biud436@gmail.com
 *
 * @brief 
 * 2018.06.21 - ���� �Լ� ����
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
 * @brief �Է� ���
 */
class Input : private noncopyable
{
public:

	/**
	 * Note: Ű ������ Ű�� ������ ����, Ű ����, Ű ��, Ű�� ��� ���� �� 4���� ���·� �����մϴ�.
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
	* �Է� ����� �ʱ�ȭ�մϴ�.
	*/
	void initialize(HWND hWnd);

	/**
	* �Է� ����� ������Ʈ�մϴ�.
	*/
	void update();

	/**
	* Ư�� Ű�� ���ȴ� �� Ȯ���մϴ�.
	*/
	bool isKeyDown(int vKey) const;

	/**
	* Ư�� Ű�� �����ٰ� �ô� �� Ȯ���մϴ�.
	*/
	bool isKeyUp(int vKey) const;

	/**
	* Ư�� Ű�� ���� ���� ���� Ȯ���մϴ�.
	*/
	bool isKeyPress(int vKey) const;

	/**
	* �ƹ� ��ư�̳� ������ �� Ȯ���մϴ�.
	*/
	bool isAnyKeyDown() const;

	/**
	* ���콺 X ��ǥ ��ȯ�մϴ�.
	*/
	float getMouseX();

	/**
	* ���콺 Y ��ǥ ��ȯ�մϴ�.
	*/
	float getMouseY();

	/**
	* Ư�� ���콺 ��ư�� ������ �� Ȯ���մϴ�.
	*/
	bool isMouseDown(int vKey) const;

	/**
	* Ư�� ���콺 ��ư�� �����ٰ� �ô� �� Ȯ���մϴ�.
	*/
	bool isMouseUp(int vKey) const;

	/**
	* Ư�� ���콺 ��ư�� ���� �������� Ȯ���մϴ�.
	*/
	bool isMousePress(int vKey) const;

	/**
	* �ƹ� ���콺 ��ư�̳� ������ �� Ȯ���մϴ�.
	*/
	bool isAnyMouseDown() const;

	/**
	* ���콺 �� ���� Ȯ���մϴ�.
	*/
	int getMouseZ() const;

	/**
	* ���콺 �� ���� �����մϴ�.
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

	// ���� �� ���� ���� ���ʿ� (�Ұ����ϰ� ����)
	Input(const Input&);
	void operator=(const Input&);

};

#endif