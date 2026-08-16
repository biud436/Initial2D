/**
 * @file Tilemap.cpp
 * @brief 맵 포맷 v1 로더와 컬링 렌더러 (2단계, docs/plans/02-tilemap.md).
 *
 * 이전 구현(settings.json 기반, 타일마다 Sprite 생성)은 실행 경로에서
 * 생성되지 않는 죽은 코드였고 재작성 대상이었다. 이 구현은
 * TextureManager::DrawFrame에 소스 사각형을 직접 넘겨 화면에 보이는
 * 타일만 그린다.
 */
#include "Tilemap.h"
#include "App.h"
#include "TextureManager.h"
#include "platform/Utf8.h"

#include <json/json.h>

#include <algorithm>
#include <fstream>

namespace {

	/** 음수 좌표에서도 내림 나눗셈이 되도록 한다 (카메라가 맵 밖으로 나간 경우). */
	int FloorDiv(int value, int divisor)
	{
		int q = value / divisor;
		if ((value % divisor != 0) && ((value < 0) != (divisor < 0))) {
			--q;
		}
		return q;
	}

	/** 정수 배열 필드를 읽는다. 크기가 expected와 다르면 false. */
	bool ReadIntArray(const Json::Value& node, size_t expected, std::vector<int>& out)
	{
		if (!node.isArray() || node.size() != expected) {
			return false;
		}
		out.clear();
		out.reserve(expected);
		for (const Json::Value& v : node) {
			if (!v.isIntegral()) {
				return false;
			}
			out.push_back(v.asInt());
		}
		return true;
	}
}

namespace Initial2D {

Tilemap::Tilemap() :
	_width(0),
	_height(0),
	_tileWidth(0),
	_tileHeight(0)
{
}

Tilemap::~Tilemap()
{
	// 타일셋 텍스처는 TextureManager 소유라 여기서 해제하지 않는다.
}

bool Tilemap::fail(const std::string& message)
{
	_lastError = message;
	LOG_D("Tilemap: " << message);
	return false;
}

bool Tilemap::load(const std::string& path)
{
	const std::string normalized = Platform::NormalizePath(path);

	std::ifstream file(normalized, std::ifstream::binary);
	if (!file.good()) {
		return fail("cannot open " + normalized);
	}

	Json::Value root;
	try {
		file >> root;
	}
	catch (const std::exception& e) {
		return fail("parse error in " + normalized + ": " + e.what());
	}

	if (root["version"].asInt() != 1) {
		return fail("unsupported map version in " + normalized);
	}

	const int width = root["width"].asInt();
	const int height = root["height"].asInt();
	const int tileWidth = root["tileWidth"].asInt();
	const int tileHeight = root["tileHeight"].asInt();
	if (width <= 0 || height <= 0 || tileWidth <= 0 || tileHeight <= 0) {
		return fail("invalid map size in " + normalized);
	}
	const size_t cells = static_cast<size_t>(width) * static_cast<size_t>(height);

	const Json::Value& layersNode = root["layers"];
	if (!layersNode.isArray() || layersNode.empty()) {
		return fail("no layers in " + normalized);
	}
	std::vector<Layer> layers;
	for (const Json::Value& layerNode : layersNode) {
		Layer layer;
		layer.name = layerNode["name"].asString();
		if (!ReadIntArray(layerNode["data"], cells, layer.data)) {
			return fail("layer \"" + layer.name + "\" data size != width*height in " + normalized);
		}
		layers.push_back(std::move(layer));
	}

	std::vector<int> collision;
	if (root.isMember("collision")) {
		if (!ReadIntArray(root["collision"], cells, collision)) {
			return fail("collision size != width*height in " + normalized);
		}
	}

	const Json::Value& tilesetsNode = root["tilesets"];
	if (!tilesetsNode.isArray() || tilesetsNode.empty()) {
		return fail("no tilesets in " + normalized);
	}
	std::vector<Tileset> tilesets;
	for (const Json::Value& tilesetNode : tilesetsNode) {
		Tileset tileset;
		tileset.image = tilesetNode["image"].asString();
		tileset.firstGid = tilesetNode["firstGid"].asInt();
		tileset.columns = tilesetNode["columns"].asInt();
		if (tileset.image.empty() || tileset.firstGid < 1 || tileset.columns < 1) {
			return fail("invalid tileset entry in " + normalized);
		}
		tileset.textureId = Platform::NormalizePath(tileset.image);
		if (!TheTextureManager.valid(tileset.textureId)) {
			if (!TheTextureManager.Load(tileset.image, tileset.textureId, 0)) {
				return fail("cannot load tileset image " + tileset.image);
			}
		}
		tilesets.push_back(std::move(tileset));
	}
	std::sort(tilesets.begin(), tilesets.end(),
		[](const Tileset& a, const Tileset& b) { return a.firstGid < b.firstGid; });

	// 전부 검증된 뒤에야 멤버를 교체한다 (실패 시 기존 상태 유지)
	_name = root["name"].asString();
	_width = width;
	_height = height;
	_tileWidth = tileWidth;
	_tileHeight = tileHeight;
	_layers = std::move(layers);
	_collision = std::move(collision);
	_tilesets = std::move(tilesets);
	_lastError.clear();
	return true;
}

bool Tilemap::inBounds(int x, int y) const
{
	return x >= 0 && x < _width && y >= 0 && y < _height;
}

const Tilemap::Tileset* Tilemap::findTileset(int gid) const
{
	// firstGid 오름차순에서 gid를 넘지 않는 마지막 타일셋
	const Tileset* found = nullptr;
	for (const Tileset& tileset : _tilesets) {
		if (tileset.firstGid > gid) {
			break;
		}
		found = &tileset;
	}
	return found;
}

int Tilemap::getTileId(int x, int y, int layer) const
{
	if (!inBounds(x, y) || layer < 0 || layer >= layerCount()) {
		return 0;
	}
	return _layers[layer].data[static_cast<size_t>(y) * _width + x];
}

bool Tilemap::setTileId(int x, int y, int layer, int gid)
{
	if (!inBounds(x, y) || layer < 0 || layer >= layerCount() || gid < 0) {
		return false;
	}
	_layers[layer].data[static_cast<size_t>(y) * _width + x] = gid;
	return true;
}

bool Tilemap::isPassable(int x, int y) const
{
	if (!inBounds(x, y)) {
		return false;
	}
	if (_collision.empty()) {
		return true;
	}
	return _collision[static_cast<size_t>(y) * _width + x] == 0;
}

void Tilemap::draw(int layerFrom, int layerTo, int camX, int camY) const
{
	if (_width <= 0 || _layers.empty()) {
		return;
	}

	layerFrom = std::max(layerFrom, 0);
	layerTo = std::min(layerTo, layerCount() - 1);
	if (layerFrom > layerTo) {
		return;
	}

	// 컬링: 카메라 사각형과 겹치는 타일 범위만 그린다
	const App& app = App::GetInstance();
	const int screenW = app.GetWindowWidth();
	const int screenH = app.GetWindowHeight();
	const int x0 = std::max(0, FloorDiv(camX, _tileWidth));
	const int y0 = std::max(0, FloorDiv(camY, _tileHeight));
	const int x1 = std::min(_width - 1, FloorDiv(camX + screenW - 1, _tileWidth));
	const int y1 = std::min(_height - 1, FloorDiv(camY + screenH - 1, _tileHeight));

	TransformData transform;
	transform.eM11 = 1.0f;
	transform.eM12 = 0.0f;
	transform.eM21 = 0.0f;
	transform.eM22 = 1.0f;

	for (int layer = layerFrom; layer <= layerTo; ++layer) {
		const std::vector<int>& data = _layers[layer].data;

		for (int y = y0; y <= y1; ++y) {
			const size_t rowBase = static_cast<size_t>(y) * _width;

			for (int x = x0; x <= x1; ++x) {
				const int gid = data[rowBase + x];
				if (gid <= 0) {
					continue;
				}
				const Tileset* tileset = findTileset(gid);
				if (tileset == nullptr) {
					continue;
				}

				const int local = gid - tileset->firstGid;
				const int srcX = (local % tileset->columns) * _tileWidth;
				const int srcY = (local / tileset->columns) * _tileHeight;

				RECT rect;
				rect.left = srcX;
				rect.top = srcY;
				rect.right = srcX + _tileWidth;
				rect.bottom = srcY + _tileHeight;

				transform.eDx = static_cast<float>(x * _tileWidth - camX);
				transform.eDy = static_cast<float>(y * _tileHeight - camY);

				TheTextureManager.DrawFrame(tileset->textureId, 0, 0,
					_tileWidth, _tileHeight, rect, 255, transform);
			}
		}
	}
}

// End
}
