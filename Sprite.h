/**
 * @file Sprite.h
 * @date 2018/03/26 11:42
 *
 * @author biud436
 * Contact: biud436@gmail.com
 *
 * @brief 
 *
 *
 * @note
*/

#ifndef SPRITE_H
#define SPRITE_H

#define WIN32_LEAN_AND_MEAN

#include <Windows.h>
#include <string>
#include "Vector2D.h"
#include <vector>
#include "Constants.h"

/**
 * @addtogroup Sprites
 * 2D ������ ���� ��������Ʈ Ŭ����
 * @{
 */

/**
 * @struct SpriteData
 * @brief ��������Ʈ ������
 */
struct SpriteData
{

	Vector2D position;		/** ��������Ʈ ���� */
	float	offsetX;		/** ������X */
	float	offsetY;		/** ������X */
	int	width;				/** �̹����� �� */
	int	height;				/** �̹����� ���� */
	float	scale;			/** ������ */
	float	rotation;		/** ȸ�� (����) */
	RECT	rect;			/** RECT */
	std::string	id;			/** �ؽ�ó ID */
	double	frameDelay;		/** ������ ���� */
	int	startFrame;			/** ���� ������ */
	int	endFrame;			/** ������ ������ */
	BYTE	opacity;		/** ����(������) */

	SpriteData();

};

/// @typedef TransformData
typedef XFORM TransformData;

/** 
 * @class Sprite
 * @brief Sprite Ŭ����
 * @details 
 */
class Sprite
{
public:

	Sprite();
	virtual ~Sprite();

	/**
	 * ��������Ʈ�� �ʱ�ȭ �մϴ�.
	 */
	virtual bool	initialize(float x, float y, int width, int height, int maxFrames, std::string textureId);

	/**
	 * ��������Ʈ�� ������Ʈ �մϴ�.
	 *
	 * @param elapsed ���� ���������κ��� ����� �ð�
	 */
	virtual void	update(float elapsed);

	/**
	 * ��������Ʈ�� ��ȭ�մϴ�.
	 */
	virtual void	draw(void);

	/** 
	 * ��������Ʈ �����͸� ȹ���մϴ�.
	 */
	const SpriteData&	getSpriteData(); 
		
	/**
	 * ��������Ʈ�� X ��ǥ�� ���մϴ�.
	 */
	float	getX();

	/**
	 * ��������Ʈ�� Y ��ǥ�� ���մϴ�.
	 */
	float	getY();
	
	/** 
	 * ��������Ʈ�� ������ ���� ���մϴ�.
	 */
	float	getScale();

	/**
	 * ��������Ʈ�� ���� ���մϴ�.
	 */
	int	getWidth();

	/**
	 * ��������Ʈ�� ���̸� ���մϴ�.
	 */
	int	getHeight();

	/**
	 * ��������Ʈ�� ������ ���մϴ�.
	 */
	float	getAngle();

	/**
	 * ��������Ʈ�� ������ �������� ����ϴ�.
	 */
	float	getRadians();

	/**
	 * ��������Ʈ ǥ�� ���θ� ���մϴ�.
	 */
	bool	getVisible();	

	/**
	 * ��������Ʈ�� ���� ���� ���մϴ�.
	 */
	BYTE	getOpacity();

	/**
	 * ��������Ʈ�� ������ �� ������ ������ ���� ���մϴ�.
	 */
	float	getFrameDelay();
	
	/**
	 * ���� ������ ���� ����ϴ�.
	 */
	int	getStartFrame();

	/**
	 * ������ ������ ���� �����ɴϴ�.
	 */
	int	getEndFrame();

	/**
	 * ���� ������ ���� �����ɴϴ�.
	 */
	int	getCurrentFrame();

	/**
	 * ��������Ʈ�� �ؽ�ó ����(Rect)�� �����ɴϴ�.
	 */
	RECT	getRect();

	/**
	 * �ִϸ��̼��� �Ϸ�Ǿ����� ���θ� �˾Ƴ��ϴ�.
	 */
	bool	getAnimComplete();
			
	/**
	 * X ��ǥ�� �����մϴ�.
	 */
	void	setX(float x); 

	/**
	 * Y ��ǥ�� �����մϴ�.
	 */
	void	setY(float y);	

	/**
	 * ��������Ʈ�� ������ ���� �����մϴ�.
	 */
	void	setScale(float scale);

	/**
	 * ȸ�� ������ �����մϴ�.
	 */
	void	setAngle(float degree);

	/**
	 * ȸ�� ������ ���� ������ �����մϴ�.
	 */
	void	setRadians(float rad);

	/**
	 * ��������Ʈ ǥ�� ���θ� �����մϴ�.
	 */
	void	setVisible(bool visible);
			
	/**
	 * ���� ���� ������ �� �ֽ��ϴ�.
	 * 
	 * @param opacity 0~255 ������ ��
	 *
	 */
	void	setOpacity(BYTE opacity);
			
	/**
	 * ������ ���� ������ �ð��� �����մϴ�.
	 */
	void	setFrameDelay(double delay);

	/**
	 * ���� �� ������ ������ ���� �����մϴ�.
	 */
	void	setFrames(int startNum, int endNum);

	/**
	 * ���� ������ ���� �����մϴ�.
	 */
	void	setCurrentFrame(int currentFrame);
	
	/**
	 * ��������Ʈ ������ �����մϴ�.
	 */
	void	setRect();

	/**
	* ��������Ʈ ������ �����մϴ�.
	*/
	void	setRect(RECT rect);

	/**
	* ��������Ʈ ������ �����մϴ�.
	*/
	void	setRect(int x, int y, int width, int height);

	/**
	 * �ִϸ��̼� �ݺ� ��� ���θ� �����մϴ�.
	 */
	void	setLoop(bool isLooping);

	/**
	 * �ִϸ��̼� �Ϸ� ���θ� �����մϴ�.
	 */
	void	setAnimComplete(bool isComplete);

	/**
	 * ȸ��, Ȯ��, ���, �̵� ����� �ٷ�� ����� �� ������ ������Ʈ�մϴ�.
	 */
	virtual void	updateTransform();

	/** 
	 * Ʈ������ �����͸� ����ϴ�.
	 */
	virtual	TransformData&	getTransform();

	/**
	 * ���ο� �ڽ� ��������Ʈ�� �߰��մϴ�.
	 */
	void addChild(Sprite* sprite);

	/**
	 * �ڽ� ��������Ʈ�� �����մϴ�.
	 */
	void removeChild(Sprite* sprite);

protected:

	SpriteData	m_spriteData;
	bool	m_bVisible;	
	bool	m_bAnimComplete;
	bool	m_bLoop;
	int	m_nCurrentFrame;
	int	m_nMaxFrames;
	double	m_fAnimationTime;
	bool	m_bInitialized;

	TransformData	m_transform;

	std::vector<Sprite*> _children;

};

/**
 * @}
 */

#endif