/**
 * @file TextureManagerSDL2.cpp
 * @brief TextureManager의 SDL2 어댑터 구현 (비-Windows).
 * @details GDI 구현(TextureManager.cpp의 RS_WINDOWS 분기)과의 대응:
 *          - LoadPNG/LoadBMP + CreateDIBSection → IMG_Load + SDL_CreateTextureFromSurface
 *          - TransparentBlt(컬러 키)          → 컬러 키 파생 텍스처 캐시 + SDL_RenderCopy
 *          - AlphaBlend(per-pixel + 상수 알파) → blend mode + SDL_SetTextureAlphaMod
 *          - SetWorldTransform(XFORM)          → 회전/스케일 분해 후 SDL_RenderCopyEx
 *            (엔진의 XFORM 사용부는 Sprite::updateTransform()의 회전·스케일·이동뿐이며
 *             기울임(shear)이 없으므로 RenderCopyEx로 충분하다 — Phase 3 판별 결과)
 */
#include "Constants.h"

#ifndef RS_WINDOWS

#include "TextureManager.h"
#include "App.h"

#include <SDL.h>
#include <SDL_image.h>

#include <cmath>
#include <cstdio>
#include <set>
#include <utility>
#include <vector>

#include "../Utf8.h"
#include "../Env.h"

namespace {

	const double RAD_TO_DEG = 57.29577951308232;

	/** m_crTransparent(COLORREF)를 컬러 키로 적용한 파생 텍스처를 가져오거나 생성한다. */
	SDL_Texture* GetKeyedTexture(SDL_Renderer* renderer, TextureData* data, COLORREF cr)
	{
		const Uint32 key = static_cast<Uint32>(cr);

		auto iter = data->keyedTextures.find(key);
		if (iter != data->keyedTextures.end()) {
			return iter->second;
		}

		if (data->surface == nullptr) {
			return data->texture;
		}

		SDL_Surface* copy = SDL_ConvertSurfaceFormat(data->surface, SDL_PIXELFORMAT_RGBA32, 0);
		if (copy == nullptr) {
			return data->texture;
		}

		SDL_SetColorKey(copy, SDL_TRUE,
			SDL_MapRGB(copy->format, GetRValue(cr), GetGValue(cr), GetBValue(cr)));

		SDL_Texture* keyed = SDL_CreateTextureFromSurface(renderer, copy);
		SDL_FreeSurface(copy);

		if (keyed == nullptr) {
			return data->texture;
		}

		SDL_SetTextureBlendMode(keyed, SDL_BLENDMODE_BLEND);
		data->keyedTextures[key] = keyed;
		return keyed;
	}

	SDL_Renderer* CurrentRenderer()
	{
		return App::GetInstance().GetContext().renderer;
	}
}

TextureData::TextureData()
{
	width = 0;
	height = 0;
	texture = nullptr;
	surface = nullptr;
	isTarget = false;
}

TextureData::~TextureData()
{
	for (auto& pair : keyedTextures) {
		SDL_DestroyTexture(pair.second);
	}
	keyedTextures.clear();

	if (texture != nullptr) {
		SDL_DestroyTexture(texture);
	}
	if (surface != nullptr) {
		SDL_FreeSurface(surface);
	}
}

TextureManager::TextureManager() :
	m_crTransparent(RGB(255, 255, 255)), // 투명색
	m_bitmapColor(0, 0, 0, 255)
{
}

TextureManager::~TextureManager()
{
	TextureGroup::iterator iter;

	for (iter = m_textureMap.begin(); iter != m_textureMap.end(); iter++)
	{
		SAFE_DELETE(iter->second)
	}
}

bool TextureManager::Remove(std::string id)
{
	TextureGroup::iterator iter;

	iter = m_textureMap.find(id);

	if (iter != m_textureMap.end()) {
		// 지우는 텍스처에 그리고 있었으면 화면으로 돌아간다
		if (!m_renderTarget.empty() && m_renderTarget == id) {
			ResetRenderTarget();
		}
		SAFE_DELETE(iter->second)
	}

	m_textureMap.erase(id);

	return true;
}

bool TextureManager::valid(std::string id)
{
	TextureGroup::iterator iter;

	iter = m_textureMap.find(id);
	return iter != m_textureMap.end();
}

bool TextureManager::Load(std::string fileName, std::string id, HDC* hdc)
{
	(void)hdc; // SDL2 어댑터에서는 디바이스 컨텍스트가 필요 없다

	const std::string path = Initial2D::Platform::NormalizePath(fileName);

	SDL_Surface* loaded = IMG_Load(path.c_str());
	if (loaded == nullptr) {
		std::fprintf(stderr, "TextureManager::Load: cannot load %s (%s)\n", path.c_str(), IMG_GetError());
		return false;
	}

	// 컬러 키 적용을 일관되게 하기 위해 RGBA32로 통일한다.
	SDL_Surface* surface = SDL_ConvertSurfaceFormat(loaded, SDL_PIXELFORMAT_RGBA32, 0);
	SDL_FreeSurface(loaded);
	if (surface == nullptr) {
		return false;
	}

	SDL_Texture* texture = SDL_CreateTextureFromSurface(CurrentRenderer(), surface);
	if (texture == nullptr) {
		SDL_FreeSurface(surface);
		return false;
	}
	SDL_SetTextureBlendMode(texture, SDL_BLENDMODE_BLEND);

	TextureData* data = new TextureData();
	data->width = surface->w;
	data->height = surface->h;
	data->texture = texture;
	data->surface = surface;

	m_textureMap[id] = data;
	return true;
}

void TextureManager::Draw(std::string id, int x, int y, int width, int height)
{
	TextureData* currentTexture = m_textureMap[id];
	if (currentTexture == nullptr) {
		return;
	}

	SDL_Renderer* renderer = CurrentRenderer();
	SDL_Texture* keyed = GetKeyedTexture(renderer, currentTexture, m_crTransparent);

	SDL_Rect src = { 0, 0, width, height };
	SDL_Rect dst = { x, y, width, height };
	SDL_RenderCopy(renderer, keyed, &src, &dst);
}

void TextureManager::DrawFrame(std::string id, int x, int y, int width, int height, RECT& rect, BYTE opacity, TransformData& transform)
{
	(void)x; (void)y; // GDI 구현과 동일하게 위치는 transform(eDx/eDy)에서 온다

	TextureData* currentTexture = m_textureMap[id];
	if (currentTexture == nullptr || currentTexture->texture == nullptr) {
		return;
	}

	SDL_Renderer* renderer = CurrentRenderer();

	// XFORM 분해: Sprite::updateTransform()은 회전·스케일·이동만 생성한다.
	const double scale = std::sqrt(static_cast<double>(transform.eM11) * transform.eM11 +
		static_cast<double>(transform.eM12) * transform.eM12);
	const double angle = std::atan2(static_cast<double>(transform.eM12),
		static_cast<double>(transform.eM11)) * RAD_TO_DEG;

	SDL_Rect src = { static_cast<int>(rect.left), static_cast<int>(rect.top), width, height };
	SDL_FRect dst = {
		static_cast<float>(transform.eDx),
		static_cast<float>(transform.eDy),
		static_cast<float>(width * scale),
		static_cast<float>(height * scale)
	};

	SDL_FPoint center = { 0.0f, 0.0f }; // GDI 월드 트랜스폼은 원점 기준 회전

	if (Initial2D::Platform::GetEnv("INITIAL2D_DEBUG_DRAW") != nullptr) {
		std::fprintf(stderr, "DrawFrame id=%s src=(%d,%d,%d,%d) dst=(%.1f,%.1f,%.1f,%.1f) angle=%.1f opacity=%d\n",
			id.c_str(), src.x, src.y, src.w, src.h, dst.x, dst.y, dst.w, dst.h, angle, opacity);
	}

	SDL_SetTextureAlphaMod(currentTexture->texture, opacity);
	SDL_RenderCopyExF(renderer, currentTexture->texture, &src, &dst, angle, &center, SDL_FLIP_NONE);
	SDL_SetTextureAlphaMod(currentTexture->texture, 255);
}

void TextureManager::DrawText(std::string id, int x, int y, int width, int height, RECT& rect, TransformData& transform)
{
	(void)transform; // GDI 구현도 트랜스폼 적용을 주석 처리한 상태

	TextureData* currentTexture = m_textureMap[id];
	if (currentTexture == nullptr) {
		return;
	}

	SDL_Renderer* renderer = CurrentRenderer();
	SDL_Texture* keyed = GetKeyedTexture(renderer, currentTexture, m_crTransparent);

	// Font::drawText 는 rect 에 (x, y, 칸 폭, 칸 높이) 를 넣고 width, height 에 글자 크기만큼 늘인 크기를 준다
	SDL_Rect src = { static_cast<int>(rect.left), static_cast<int>(rect.top),
		static_cast<int>(rect.right), static_cast<int>(rect.bottom) };
	SDL_Rect dst = { x, y, width, height };

	SDL_SetTextureColorMod(keyed, m_textColor.red, m_textColor.green, m_textColor.blue);
	SDL_SetTextureAlphaMod(keyed, m_textColor.alpha);
	SDL_RenderCopy(renderer, keyed, &src, &dst);
	SDL_SetTextureColorMod(keyed, 255, 255, 255);
	SDL_SetTextureAlphaMod(keyed, 255);
}

namespace {

	void UseDrawColor(SDL_Renderer* renderer, const Initial2D::Color& color)
	{
		SDL_SetRenderDrawBlendMode(renderer, SDL_BLENDMODE_BLEND);
		SDL_SetRenderDrawColor(renderer, color.red, color.green, color.blue, color.alpha);
	}

	SDL_BlendMode ToSdlBlend(int blend)
	{
		switch (blend) {
		case TextureManager::BlendAdd:
			return SDL_BLENDMODE_ADD;
		case TextureManager::BlendMultiply:
			return SDL_BLENDMODE_MUL;
		default:
			return SDL_BLENDMODE_BLEND;
		}
	}
}

void TextureManager::DrawPoint(int x, int y)
{
	SDL_Renderer* renderer = CurrentRenderer();

	UseDrawColor(renderer, m_bitmapColor);
	SDL_RenderDrawPoint(renderer, x, y);
}

void TextureManager::DrawSprite(const std::string& id, int srcX, int srcY, int width, int height,
	float x, float y, float scale, float angleDeg, float pivotX, float pivotY,
	BYTE opacity, BYTE red, BYTE green, BYTE blue, bool flipX, bool flipY, int blend)
{
	auto iter = m_textureMap.find(id);
	if (iter == m_textureMap.end() || iter->second == nullptr || iter->second->texture == nullptr) {
		return;
	}
	SDL_Texture* texture = iter->second->texture;
	SDL_Renderer* renderer = CurrentRenderer();

	const float w = width * scale;
	const float h = height * scale;
	SDL_FPoint center = { pivotX * w, pivotY * h };
	SDL_FRect dst = { x - center.x, y - center.y, w, h };
	SDL_Rect src = { srcX, srcY, width, height };

	int flip = SDL_FLIP_NONE;
	if (flipX) {
		flip |= SDL_FLIP_HORIZONTAL;
	}
	if (flipY) {
		flip |= SDL_FLIP_VERTICAL;
	}

	if (Initial2D::Platform::GetEnv("INITIAL2D_DEBUG_DRAW") != nullptr) {
		std::fprintf(stderr, "DrawSprite id=%s src=(%d,%d,%d,%d) dst=(%.1f,%.1f,%.1f,%.1f) angle=%.1f opacity=%d\n",
			id.c_str(), src.x, src.y, src.w, src.h, dst.x, dst.y, dst.w, dst.h, angleDeg, opacity);
	}

	SDL_SetTextureAlphaMod(texture, opacity);
	SDL_SetTextureColorMod(texture, red, green, blue);
	SDL_SetTextureBlendMode(texture, ToSdlBlend(blend));
	SDL_RenderCopyExF(renderer, texture, &src, &dst, angleDeg, &center, static_cast<SDL_RendererFlip>(flip));
	SDL_SetTextureBlendMode(texture, SDL_BLENDMODE_BLEND);
	SDL_SetTextureColorMod(texture, 255, 255, 255);
	SDL_SetTextureAlphaMod(texture, 255);
}

bool TextureManager::CreateTarget(const std::string& id, int width, int height)
{
	if (id.empty() || width <= 0 || height <= 0) {
		return false;
	}

	SDL_Renderer* renderer = CurrentRenderer();
	SDL_Texture* texture = SDL_CreateTexture(renderer, SDL_PIXELFORMAT_RGBA8888,
		SDL_TEXTUREACCESS_TARGET, width, height);
	if (texture == nullptr) {
		std::fprintf(stderr, "TextureManager::CreateTarget: %s (%s)\n", id.c_str(), SDL_GetError());
		return false;
	}
	SDL_SetTextureBlendMode(texture, SDL_BLENDMODE_BLEND);

	// 새 텍스처의 내용은 정해져 있지 않으므로 투명하게 지워 둔다. 지우는 동안만 대상을 바꾸고 되돌린다
	SDL_Texture* previous = SDL_GetRenderTarget(renderer);
	SDL_SetRenderTarget(renderer, texture);
	SDL_SetRenderDrawBlendMode(renderer, SDL_BLENDMODE_NONE);
	SDL_SetRenderDrawColor(renderer, 0, 0, 0, 0);
	SDL_RenderClear(renderer);
	SDL_SetRenderTarget(renderer, previous);

	Remove(id);

	TextureData* data = new TextureData();
	data->width = width;
	data->height = height;
	data->texture = texture;
	data->isTarget = true;
	m_textureMap[id] = data;
	return true;
}

bool TextureManager::SetRenderTarget(const std::string& id)
{
	SDL_Renderer* renderer = CurrentRenderer();

	if (id.empty()) {
		ResetRenderTarget();
		return true;
	}

	auto iter = m_textureMap.find(id);
	if (iter == m_textureMap.end() || iter->second == nullptr || !iter->second->isTarget) {
		return false;
	}
	if (SDL_SetRenderTarget(renderer, iter->second->texture) != 0) {
		std::fprintf(stderr, "TextureManager::SetRenderTarget: %s (%s)\n", id.c_str(), SDL_GetError());
		return false;
	}
	m_renderTarget = id;
	return true;
}

void TextureManager::ResetRenderTarget()
{
	if (m_renderTarget.empty()) {
		return;
	}
	SDL_SetRenderTarget(CurrentRenderer(), nullptr);
	m_renderTarget.clear();
}

void TextureManager::ClearTarget(BYTE r, BYTE g, BYTE b, BYTE a)
{
	SDL_Renderer* renderer = CurrentRenderer();
	SDL_SetRenderDrawBlendMode(renderer, SDL_BLENDMODE_NONE);
	SDL_SetRenderDrawColor(renderer, r, g, b, a);

	if (m_renderTarget.empty()) {
		// 화면에서는 레터박스 여백을 남기고 게임 영역만 지운다 (App::RenderClear 와 같다)
		App& app = App::GetInstance();
		SDL_Rect gameArea = { 0, 0, app.GetWindowWidth(), app.GetWindowHeight() };
		SDL_RenderFillRect(renderer, &gameArea);
	} else {
		SDL_RenderClear(renderer);
	}
}

void TextureManager::DrawRect(float x, float y, float width, float height, bool fill)
{
	if (width <= 0 || height <= 0) {
		return;
	}
	SDL_Renderer* renderer = CurrentRenderer();
	UseDrawColor(renderer, m_bitmapColor);

	SDL_FRect rect = { x, y, width, height };
	if (fill) {
		SDL_RenderFillRectF(renderer, &rect);
	} else {
		SDL_RenderDrawRectF(renderer, &rect);
	}
}

void TextureManager::DrawLine(float x1, float y1, float x2, float y2)
{
	SDL_Renderer* renderer = CurrentRenderer();
	UseDrawColor(renderer, m_bitmapColor);
	SDL_RenderDrawLineF(renderer, x1, y1, x2, y2);
}

void TextureManager::DrawCircle(float cx, float cy, float radius, bool fill)
{
	const int r = static_cast<int>(std::lround(radius));
	if (r <= 0) {
		return;
	}
	SDL_Renderer* renderer = CurrentRenderer();
	UseDrawColor(renderer, m_bitmapColor);

	if (fill) {
		// 가로 줄 하나씩. 렌더러마다 결과가 같고, 반투명 색에서도 겹쳐 칠하는 픽셀이 없다
		std::vector<SDL_FRect> rows;
		rows.reserve(2 * r + 1);
		for (int dy = -r; dy <= r; ++dy) {
			const int half = static_cast<int>(std::floor(std::sqrt(static_cast<double>(r) * r - static_cast<double>(dy) * dy)));
			rows.push_back({ cx - half, cy + dy, static_cast<float>(2 * half + 1), 1.0f });
		}
		SDL_RenderFillRectsF(renderer, rows.data(), static_cast<int>(rows.size()));
		return;
	}

	// 중점 원 알고리즘. 팔분원의 경계에서 겹치는 점은 한 번만 찍는다 (반투명 색이 진해지지 않게)
	std::set<std::pair<int, int>> offsets;
	int x = r;
	int y = 0;
	int err = 1 - r;
	while (x >= y) {
		offsets.insert({ x, y });
		offsets.insert({ y, x });
		offsets.insert({ -y, x });
		offsets.insert({ -x, y });
		offsets.insert({ -x, -y });
		offsets.insert({ -y, -x });
		offsets.insert({ y, -x });
		offsets.insert({ x, -y });
		++y;
		if (err < 0) {
			err += 2 * y + 1;
		} else {
			--x;
			err += 2 * (y - x) + 1;
		}
	}
	std::vector<SDL_FPoint> points;
	points.reserve(offsets.size());
	for (const auto& o : offsets) {
		points.push_back({ cx + o.first, cy + o.second });
	}
	SDL_RenderDrawPointsF(renderer, points.data(), static_cast<int>(points.size()));
}

void TextureManager::SetBitmapColor(BYTE r, BYTE g, BYTE b, BYTE a)
{
	m_bitmapColor.SetRGB(r, g, b);
	m_bitmapColor.SetAlpha(a);
}

#endif // !RS_WINDOWS
