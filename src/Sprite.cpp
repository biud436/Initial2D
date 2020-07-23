/**
 * @file Sprite.cpp
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

#include "Sprite.h"
#include "App.h"
#include "TextureManager.h"
#include "Constants.h"
#include <math.h>

SpriteData::SpriteData()
{
	offsetX = 0.0f;
	offsetY = 0.0f;
	width = 4;
	height = 4;
	scale = 1.0f;
	rotation = 0.0f;
	id = "none";			
	frameDelay = 0.0;	
	startFrame = 0; 
	endFrame = 1;	
	SetRect(&rect, 0, 0, 4, 4);
	opacity = 255;
}

Sprite::Sprite() : 
	m_bInitialized(false),
	GameObject::GameObject()
{
	m_transform.eM11 = 1.0f;
	m_transform.eM12 = 0.0f;
	m_transform.eM21 = 0.0f;
	m_transform.eM22 = 1.0f;
	m_transform.eDx = 0.0f;
	m_transform.eDy = 0.0f;
}


Sprite::~Sprite()
{

}

bool Sprite::initialize(float x, float y, int width, int height, int maxFrames, std::string textureId = "none")
{
	m_spriteData.id = textureId;
	m_spriteData.position.setX(x);
	m_spriteData.position.setY(y);
	m_spriteData.width = width;
	m_spriteData.height = height;

	m_nMaxFrames = maxFrames;

	if (m_nMaxFrames == 0)
		m_nMaxFrames = 1;

	setFrames(0, m_nMaxFrames);
	setCurrentFrame(0);
	
	m_spriteData.frameDelay = 0.0;
	m_fAnimationTime = 0.0;

	m_bVisible = true;

	if (!App::GetInstance().GetTextureManager().valid(textureId)) 
	{
		m_bInitialized = false;
	}
	else
	{
		m_bInitialized = true;
	}

	return m_bInitialized;

}

void Sprite::update(float elapsed)
{
	
	if (m_bInitialized == false)
	{
		return;
	}

	int endFrame = m_spriteData.endFrame;
	int startFrame = m_spriteData.startFrame;
	double delay = m_spriteData.frameDelay;

	if (endFrame - startFrame > 0)
	{
		m_fAnimationTime += elapsed;

		// 프레임 딜레이 처리 이후 다음 프레임으로 전환
		if (m_fAnimationTime > delay)
		{
			m_fAnimationTime -= delay;
			m_nCurrentFrame++;

			if (m_nCurrentFrame < startFrame || m_nCurrentFrame > endFrame)
			{
				if (m_bLoop == true) {
					m_nCurrentFrame = startFrame;
				} else
				{
					m_nCurrentFrame = endFrame;
					m_bAnimComplete = true;
				}
			}
			setRect();
		}
	}

	updateTransform();

}

void Sprite::draw(void)
{

	// 초기화 여부 확인
	if (m_bInitialized == false)
		return;

	App::GetInstance().GetTextureManager().DrawFrame
	(
		m_spriteData.id,
		m_spriteData.position.getX(),
		m_spriteData.position.getY(),
		m_spriteData.width,
		m_spriteData.height,
		m_spriteData.rect,
		m_spriteData.opacity,
		m_transform
	);

}

const SpriteData& Sprite::getSpriteData()
{
	return m_spriteData;
}

float Sprite::getX()
{
	return m_spriteData.position.getX();
}

float Sprite::getY()
{
	return m_spriteData.position.getY();
}

float Sprite::getScale()
{
	return m_spriteData.scale;
}

int Sprite::getWidth()
{
	return m_spriteData.width;
}

int Sprite::getHeight()
{
	return m_spriteData.height;
}

float Sprite::getAngle()
{
	return (180.0 / PI) * m_spriteData.rotation;
}

float Sprite::getRadians()
{
	return m_spriteData.rotation;
}

bool Sprite::getVisible()
{
	return m_bVisible;
}

BYTE Sprite::getOpacity()
{
	return m_spriteData.opacity;
}

float Sprite::getFrameDelay()
{
	return m_spriteData.frameDelay;
}

int Sprite::getStartFrame()
{
	return m_spriteData.startFrame;
}

int Sprite::getEndFrame()
{
	return m_spriteData.endFrame;
}

int Sprite::getCurrentFrame()
{
	return m_nCurrentFrame;
}

RECT Sprite::getRect()
{
	return m_spriteData.rect;
}

bool Sprite::getAnimComplete()
{
	return m_bAnimComplete;
}

void Sprite::setX(float x)
{
	m_spriteData.position.setX(x);
}

void Sprite::setY(float y)
{
	m_spriteData.position.setY(y);
}

void Sprite::setScale(float scale)
{
	m_spriteData.scale = scale;
}

void Sprite::setAngle(float degree)
{
	m_spriteData.rotation = (PI / 180.0f) * degree;
}

void Sprite::setRadians(float rad)
{
	m_spriteData.rotation = rad;
}

void Sprite::setVisible(bool visible)
{
	m_bVisible = visible;
}

void Sprite::setOpacity(BYTE opacity)
{
	
	if (opacity < 0)
		opacity = 0;

	if (opacity > 255)
		opacity = 255;

	m_spriteData.opacity = opacity;

}

void Sprite::setFrameDelay(double delay)
{
	m_spriteData.frameDelay = delay;
}

void Sprite::setFrames(int startNum, int endNum)
{
	m_spriteData.startFrame = startNum;

	if (endNum <= 0)
		endNum = 1;

	if (endNum > m_nMaxFrames)
		endNum = m_nMaxFrames;

	// 0 ~ nMaxFrames - 1
	m_spriteData.endFrame = endNum - 1;

}

void Sprite::setCurrentFrame(int currentFrame)
{
	if (currentFrame >= 0)
	{
		m_nCurrentFrame = currentFrame;
		m_bAnimComplete = false;
		m_fAnimationTime = 0.0;
		setRect();
	}
}

void Sprite::setRect()
{
	// 바꾸려면 상속 받아서 변경...
	m_spriteData.rect.left = (m_nCurrentFrame % SPRITE_SHEET_COLS) * m_spriteData.width;
	m_spriteData.rect.right = m_spriteData.rect.left + m_spriteData.width;
	m_spriteData.rect.top = (m_nCurrentFrame / SPRITE_SHEET_ROWS) * m_spriteData.height;
	m_spriteData.rect.bottom = m_spriteData.rect.top + m_spriteData.height;
}

void Sprite::setRect(RECT rect)
{
	m_spriteData.rect = rect;
}

void Sprite::setRect(int x, int y, int width, int height)
{
	m_spriteData.rect.left = x;
	m_spriteData.rect.top = y;
	m_spriteData.rect.right = width;
	m_spriteData.rect.bottom = height;
}

void Sprite::setLoop(bool isLooping)
{
	m_bLoop = isLooping;
}

void Sprite::setAnimComplete(bool isComplete)
{
	m_bAnimComplete = isComplete;
}

void Sprite::updateTransform()
{
	// 회전, 이동, 스케일이 모두 포함된 행렬
	m_transform.eM11 = cos(m_spriteData.rotation) * m_spriteData.scale;
	m_transform.eM12 = sin(m_spriteData.rotation) * m_spriteData.scale;
	m_transform.eM21 = -sin(m_spriteData.rotation) * m_spriteData.scale;
	m_transform.eM22 = cos(m_spriteData.rotation) * m_spriteData.scale;
	m_transform.eDx = m_spriteData.position.getX() + m_spriteData.offsetX;
	m_transform.eDy = m_spriteData.position.getY() + m_spriteData.offsetY;
}

TransformData&	Sprite::getTransform()
{
	return m_transform;
}