#ifndef __TILEMAP_H_
#define __TILEMAP_H_

#include <string>
#include <vector>

namespace Initial2D {

/**
 * @class Tilemap
 * @brief 맵 포맷 v1(JSON)을 로드해 그리는 다층 타일맵 (docs/plans/02-tilemap.md).
 *
 * - 타일 ID는 Tiled 방식의 gid다. 0은 빈 칸, 타일셋마다 firstGid를 부여하고
 *   지역 ID = gid - firstGid, 아틀라스 좌표는 해당 타일셋의 columns로 계산한다.
 * - 그리기는 타일마다 Sprite를 만들지 않고 TextureManager에 소스 사각형을
 *   직접 넘기며, 카메라 오프셋 기준으로 화면 밖 타일은 건너뛴다 (컬링).
 * - 타일셋 텍스처는 TextureManager가 소유한다. Tilemap을 파괴해도 텍스처는
 *   캐시에 남아 같은 타일셋을 쓰는 다른 맵이 재사용한다.
 */
class Tilemap
{
public:
	struct Layer {
		std::string name;
		std::vector<int> data;   /** 행 우선 gid 배열 (width*height개), 0 = 빈 칸 */
	};

	struct Tileset {
		std::string image;       /** 맵 파일에 적힌 이미지 경로 */
		std::string textureId;   /** TextureManager 등록 ID (정규화된 경로) */
		int firstGid;
		int columns;
	};

	Tilemap();
	~Tilemap();

	/**
	 * @brief 맵 포맷 v1 JSON 파일을 로드한다. 타일셋 텍스처도 함께 로드한다.
	 * @return 성공 여부. 실패 시 lastError()에 원인이 남는다.
	 */
	bool load(const std::string& path);

	int width() const { return _width; }
	int height() const { return _height; }
	int tileWidth() const { return _tileWidth; }
	int tileHeight() const { return _tileHeight; }
	int layerCount() const { return static_cast<int>(_layers.size()); }
	const std::string& name() const { return _name; }
	const std::string& lastError() const { return _lastError; }

	/**
	 * @brief 타일 gid를 조회한다. x, y는 0 기준 타일 좌표, layer는 0 기준 인덱스.
	 * @return gid. 범위 밖이면 0.
	 */
	int getTileId(int x, int y, int layer) const;

	/**
	 * @brief 타일 gid를 변경한다.
	 * @return 성공 여부 (범위 밖이나 음수 gid면 false).
	 */
	bool setTileId(int x, int y, int layer, int gid);

	/**
	 * @brief collision 레이어 조회. 범위 밖은 통행 불가로 본다.
	 */
	bool isPassable(int x, int y) const;

	/**
	 * @brief layerFrom..layerTo(0 기준, 양 끝 포함)를 카메라 오프셋으로 그린다.
	 *
	 * 레이어 범위를 나눠 그릴 수 있어야 캐릭터를 층 사이에 끼워 그릴 수 있다.
	 * camX, camY는 월드 픽셀 단위 카메라 좌상단 좌표.
	 */
	void draw(int layerFrom, int layerTo, int camX, int camY) const;

private:
	Tilemap(const Tilemap&);
	Tilemap& operator=(const Tilemap&);

	bool fail(const std::string& message);
	bool inBounds(int x, int y) const;
	const Tileset* findTileset(int gid) const;

	std::string _name;
	std::string _lastError;
	int _width;
	int _height;
	int _tileWidth;
	int _tileHeight;
	std::vector<Layer> _layers;
	std::vector<int> _collision;    /** 비어 있으면 전부 통행 가능 */
	std::vector<Tileset> _tilesets; /** firstGid 오름차순 정렬 */
};

}

#endif
