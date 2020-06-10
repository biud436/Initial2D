#include "Tilemap.h"
#include "App.h"
#include "GameStateMachine.h"
#include "Sprite.h"
#include "TextureManager.h"

#ifdef TEST_MODE
#include <iostream>
#endif

namespace Initial2D {


Tilemap::Tilemap(int width, int height) :
	m_nWidth(width),
	m_nHeight(height)
{
	
}


Tilemap::~Tilemap()
{

}


void Tilemap::initialize() 
{
	int x, y, j;
	j = 0;

	for (y = 0; y < m_nHeight; y++) {
		std::vector<int> yTiles;

		for (x = 0; x < m_nWidth; x++) {
			yTiles.push_back(j++);
		}
		
		m_tiles.push_back(yTiles);
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

// End
}
