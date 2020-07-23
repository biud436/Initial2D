#pragma once
#include "Sprite.h"
class Tile : public Sprite
{

	Tile();
	virtual ~Tile();
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
	 * 회전, 확대, 축소, 이동 행렬을 다루는 행렬을 매 프레임 업데이트합니다.
	 */
	virtual void	updateTransform();

	/**
	 * 트랜스폼 데이터를 얻습니다.
	 */
	virtual	TransformData& getTransform();

};

