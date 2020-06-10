#include "Tilemap.h"

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

	for (y = 0; y < m_nHeight; y++) {
		for (x = 0; x < m_nWidth; x++) {
			
#ifdef TEST_MODE
			std::cout << "x : " << x << " y : " << y << "  :  " << m_tiles[y][x] << std::endl;
#endif

		}
	}
}

int Tilemap::getTile(int x, int y) const 
{
	return m_tiles[y][x];
}

}
