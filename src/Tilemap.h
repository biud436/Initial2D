#ifndef __TILEMAP_H_
#define __TILEMAP_H_

#include <vector>
#include <string>
#include <memory>
#include "GameObject.h"
#include "Sprite.h"

class App;

namespace Initial2D {

class Tilemap : public GameObject
{
public:
	Tilemap(int width, int height);
	virtual ~Tilemap();

	void initialize();

	int width() const { return _width;};
	int height() const { return _height;};

	int getTile(int x, int y) const;
	void setTile(int x, int y, int data);

	virtual void update(float elapsed);
	virtual void draw(void);

	bool loadImages();
	void createTiles();
	void removeTiles();

private:
	Tilemap(const Tilemap&);
	Tilemap& operator=(const Tilemap&);

	int _width;
	int _height;
	bool _isLoaded;
	std::vector<std::vector<int>> _tileIds;
	std::vector<Sprite*> _tiles;
};

}

#endif