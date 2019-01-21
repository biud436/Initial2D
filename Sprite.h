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
 * 2D 게임을 위한 스프라이트 클래스
 * @{
 */

/**
 * @struct SpriteData
 * @brief 스프라이트 데이터
 */
struct SpriteData
{

	Vector2D position;		/** 스프라이트 벡터 */
	float	offsetX;		/** 오프셋X */
	float	offsetY;		/** 오프셋X */
	int	width;				/** 이미지의 폭 */
	int	height;				/** 이미지의 높이 */
	float	scale;			/** 스케일 */
	float	rotation;		/** 회전 (라디안) */
	RECT	rect;			/** RECT */
	std::string	id;			/** 텍스처 ID */
	double	frameDelay;		/** 프레임 지연 */
	int	startFrame;			/** 시작 프레임 */
	int	endFrame;			/** 마지막 프레임 */
	BYTE	opacity;		/** 투명도(미지원) */

	SpriteData();

};

/// @typedef TransformData
typedef XFORM TransformData;

/** 
 * @class Sprite
 * @brief Sprite 클래스
 * @details 
 */
class Sprite
{
public:

	Sprite();
	virtual ~Sprite();

	/**
	 * 스프라이트를 초기화 합니다.
	 */
	virtual bool	initialize(float x, float y, int width, int height, int maxFrames, std::string textureId);

	/**
	 * 스프라이트를 업데이트 합니다.
	 *
	 * @param elapsed 지난 프레임으로부터 경과한 시간
	 */
	virtual void	update(float elapsed);

	/**
	 * 스프라이트를 묘화합니다.
	 */
	virtual void	draw(void);

	/** 
	 * 스프라이트 데이터를 획득합니다.
	 */
	const SpriteData&	getSpriteData(); 
		
	/**
	 * 스프라이트의 X 좌표를 구합니다.
	 */
	float	getX();

	/**
	 * 스프라이트의 Y 좌표를 구합니다.
	 */
	float	getY();
	
	/** 
	 * 스프라이트의 스케일 값을 구합니다.
	 */
	float	getScale();

	/**
	 * 스프라이트의 폭을 구합니다.
	 */
	int	getWidth();

	/**
	 * 스프라이트의 높이를 구합니다.
	 */
	int	getHeight();

	/**
	 * 스프라이트의 각도를 구합니다.
	 */
	float	getAngle();

	/**
	 * 스프라이트의 각도를 라디안으로 얻습니다.
	 */
	float	getRadians();

	/**
	 * 스프라이트 표시 여부를 구합니다.
	 */
	bool	getVisible();	

	/**
	 * 스프라이트의 투명도 값을 구합니다.
	 */
	BYTE	getOpacity();

	/**
	 * 스프라이트의 프레임 간 프레임 딜레이 값을 구합니다.
	 */
	float	getFrameDelay();
	
	/**
	 * 시작 프레임 값을 얻습니다.
	 */
	int	getStartFrame();

	/**
	 * 마지막 프레임 값을 가져옵니다.
	 */
	int	getEndFrame();

	/**
	 * 현재 프레임 값을 가져옵니다.
	 */
	int	getCurrentFrame();

	/**
	 * 스프라이트의 텍스처 영역(Rect)을 가져옵니다.
	 */
	RECT	getRect();

	/**
	 * 애니메이션이 완료되었는지 여부를 알아냅니다.
	 */
	bool	getAnimComplete();
			
	/**
	 * X 좌표를 설정합니다.
	 */
	void	setX(float x); 

	/**
	 * Y 좌표를 설정합니다.
	 */
	void	setY(float y);	

	/**
	 * 스프라이트의 스케일 값을 설정합니다.
	 */
	void	setScale(float scale);

	/**
	 * 회전 각도를 설정합니다.
	 */
	void	setAngle(float degree);

	/**
	 * 회전 각도를 라디안 단위로 설정합니다.
	 */
	void	setRadians(float rad);

	/**
	 * 스프라이트 표시 여부를 설정합니다.
	 */
	void	setVisible(bool visible);
			
	/**
	 * 투명도 값을 설정할 수 있습니다.
	 * 
	 * @param opacity 0~255 사이의 값
	 *
	 */
	void	setOpacity(BYTE opacity);
			
	/**
	 * 프레임 간의 딜레이 시간을 설정합니다.
	 */
	void	setFrameDelay(double delay);

	/**
	 * 시작 및 마지막 프레임 값을 설정합니다.
	 */
	void	setFrames(int startNum, int endNum);

	/**
	 * 현재 프레임 값을 설정합니다.
	 */
	void	setCurrentFrame(int currentFrame);
	
	/**
	 * 스프라이트 영역을 설정합니다.
	 */
	void	setRect();

	/**
	* 스프라이트 영역을 설정합니다.
	*/
	void	setRect(RECT rect);

	/**
	* 스프라이트 영역을 설정합니다.
	*/
	void	setRect(int x, int y, int width, int height);

	/**
	 * 애니메이션 반복 재생 여부를 설정합니다.
	 */
	void	setLoop(bool isLooping);

	/**
	 * 애니메이션 완료 여부를 설정합니다.
	 */
	void	setAnimComplete(bool isComplete);

	/**
	 * 회전, 확대, 축소, 이동 행렬을 다루는 행렬을 매 프레임 업데이트합니다.
	 */
	virtual void	updateTransform();

	/** 
	 * 트랜스폼 데이터를 얻습니다.
	 */
	virtual	TransformData&	getTransform();

	/**
	 * 새로운 자식 스프라이트를 추가합니다.
	 */
	void addChild(Sprite* sprite);

	/**
	 * 자식 스프라이트를 제거합니다.
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