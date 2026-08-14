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

#include "../Utf8.h"

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

	if (SDL_getenv("INITIAL2D_DEBUG_DRAW") != nullptr) {
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

	SDL_Rect src = { static_cast<int>(rect.left), static_cast<int>(rect.top), width, height };
	SDL_Rect dst = { x, y, width, height };
	SDL_RenderCopy(renderer, keyed, &src, &dst);
}

void TextureManager::DrawPoint(int x, int y)
{
	SDL_Renderer* renderer = CurrentRenderer();

	SDL_SetRenderDrawColor(renderer,
		m_bitmapColor.red, m_bitmapColor.green, m_bitmapColor.blue, m_bitmapColor.alpha);
	SDL_RenderDrawPoint(renderer, x, y);
}

void TextureManager::SetBitmapColor(BYTE r, BYTE g, BYTE b, BYTE a)
{
	m_bitmapColor.SetRGB(r, g, b);
	m_bitmapColor.SetAlpha(a);
}

#endif // !RS_WINDOWS
