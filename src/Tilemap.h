#ifndef __TILEMAP_H_
#define __TILEMAP_H_

#include <vector>
#include <string>
#include <memory>
#include "GameObject.h"

class App;
class Sprite;

namespace Initial2D {

class Tilemap : public GameObject
{
public:
	Tilemap(int width, int height);
	virtual ~Tilemap();

	void initialize();
	
	int width() const { return m_nWidth; };

	int height() const { return m_nHeight; };

	int getTile(int x, int y) const;
	void setTile(int x, int y, int data);

	virtual void update(float elapsed);
	virtual void draw(void);

	void createTiles();

private:
	Tilemap(const Tilemap&);
	Tilemap& operator=(const Tilemap&);

	int m_nWidth;
	int m_nHeight;
	std::vector<std::vector<int>> m_tiles;
	std::vector<Sprite*> m_sprites;
};

}

#endif