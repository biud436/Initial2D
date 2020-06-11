#include "Tilemap.h"
#include "App.h"
#include "GameStateMachine.h"
#include "Sprite.h"
#include "TextureManager.h"
#include "File.h"

#ifdef TEST_MODE
#include <iostream>
#endif

namespace Initial2D {


Tilemap::Tilemap(int width, int height) :
	m_nWidth(width),
	m_nHeight(height),
	GameObject()
{
	
}


Tilemap::~Tilemap()
{

}


void Tilemap::initialize() 
{
	int x, y, j;
	j = 0;

	// 타일을 설정합니다 (임시)
	// 각 타일 ID는 불러올 타일 이미지와 연관됩니다.
	for (y = 0; y < m_nHeight; y++) {
		std::vector<int> yTiles;

		for (x = 0; x < m_nWidth; x++) {
			yTiles.push_back(j++);
		}
		
		m_tiles.push_back(yTiles);
	}

	// 타일맵 로드
	File file;
	std::string filename = "resources\\tiles\\tileset.png";
	file.open(filename, Initial2D::FileMode::BinrayRead);
	if (!file.isOpen()) {
		throw new std::exception("tilemap image is not existed!");
	}
	
	if (!TheTextureManager.Load(filename, "main_tileset", 0)) {

	}

	file.close();

	for (y = 0; y < m_nHeight; y++) {

		for (x = 0; x < m_nWidth; x++) {
			
		}

	}

}


int Tilemap::getTile(int x, int y) const 
{
	return m_tiles[y][x];
}


void Tilemap::setTile(int x, int y, int data)
{
	m_tiles.at(y).at(x) = data;
}

void Tilemap::createTiles()
{
	App& app = App::GetInstance();
}

void Tilemap::update(float elapsed)
{

}

void Tilemap::draw(void)
{

}

// End
}
