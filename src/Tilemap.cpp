#include "Tilemap.h"
#include "App.h"
#include "GameStateMachine.h"
#include "TextureManager.h"
#include "File.h"

#ifdef TEST_MODE
#include <iostream>
#endif

namespace Initial2D {


Tilemap::Tilemap(int width, int height) :
	_width(width),
	_height(height),
	_isLoaded(false),
	GameObject()
{
	
}


Tilemap::~Tilemap()
{
	removeTiles();
}

void Tilemap::removeTiles() 
{
	for (auto iter : _tiles) {
		delete iter;
	}

	_tiles.clear();

	if (TheTextureManager.valid("main_tileset") && _isLoaded) {
		TheTextureManager.Remove("main_tileset");
		_isLoaded = false;
	}
		
}

bool Tilemap::loadImages() 
{
	// ��Ŀ�ø� �ʿ�
	std::string filename = ".\\resources\\tiles\\tileset16-8x13.png";

	// Ÿ�ϼ��� �ҷ��ɴϴ�.
	if (!TheTextureManager.Load(filename, "main_tileset", 0)) {
		LOG_D("Ÿ�ϼ� �ؽ��� �ε忡 �����Ͽ����ϴ�.");
		return false;
	}

	// ���� �ݱ�
	//file.close();

	LOG_D("Ÿ�ϼ� �̹����� ���������� �ε��Ͽ����ϴ�");

	return true;
}


void Tilemap::initialize() 
{
	try 
	{
		int	x, y, tempTileId;
		
		tempTileId = 46 - 1;

		// Ÿ���� �����մϴ� (��Ŀ�ø� �ʿ�)
		// �� Ÿ�� ID�� �ҷ��� Ÿ�� �̹����� �����˴ϴ�.
		for (y = 0; y < _height; y++) {
			std::vector<int> yTiles;

			for (x = 0; x < _width; x++) {
				yTiles.push_back(tempTileId);
			}

			_tileIds.push_back(yTiles);
		}

		if (!loadImages()) {
			LOG_D("Ÿ�ϼ� �̹����� �ε��ϴ� �� �����߽��ϴ�.");
			throw new std::exception("importing tileset image is failed");
		}

		createTiles();

	}
	catch (std::exception& err) 
	{
		LOG_D(err.what());
	}

}


int Tilemap::getTile(int x, int y) const 
{
	return _tileIds[y][x];
}


void Tilemap::setTile(int x, int y, int data)
{
	_tileIds.at(y).at(x) = data;
}

void Tilemap::createTiles()
{
	int cols = 8;
	int tileWidth = 16;
	int tileHeight = 16;

	_tiles.resize(_width * _height);

	for (int y = 0; y < _height; y++) {

		for (int x = 0; x < _width; x++) {

			Sprite* tile = new Sprite();

			int tileId = getTile(x, y);

			std::cout << "Ÿ�� " << tileId << "�� �����Ͽ����ϴ�" << std::endl;

			tile->initialize(x * tileWidth, y * tileHeight, tileWidth, tileHeight, 1, "main_tileset");

			int mx = (tileId % cols) * tileWidth;
			int my = static_cast<int>(tileId / cols) * tileHeight;
			tile->setRect(mx, my, mx + tileWidth, my + tileHeight);

			_tiles.push_back(tile);

		}

	}

	_isLoaded = true;
}

void Tilemap::update(float elapsed)
{
	if (!_isLoaded) {
		return;
	}

	for (auto i : _tiles) {
		if(i != nullptr) 
			i->update(elapsed);
	}
}

void Tilemap::draw(void)
{
	if (!_isLoaded) {
		return;
	}

	for (auto i : _tiles) {
		if (i != nullptr)
			i->draw();
	}
}

// End
}
