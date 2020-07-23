#pragma once
#include "Sprite.h"
class Tile : public Sprite
{

	Tile();
	virtual ~Tile();
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
	 * ȸ��, Ȯ��, ���, �̵� ����� �ٷ�� ����� �� ������ ������Ʈ�մϴ�.
	 */
	virtual void	updateTransform();

	/**
	 * Ʈ������ �����͸� ����ϴ�.
	 */
	virtual	TransformData& getTransform();

};

