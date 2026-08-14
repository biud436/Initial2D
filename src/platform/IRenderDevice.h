#ifndef __PLATFORM_IRENDERDEVICE_H_
#define __PLATFORM_IRENDERDEVICE_H_

#include <string>
#include "../Rectangle.h"
#include "../Matrix.h"    // TransformData (Win32에서는 XFORM, 그 외에는 중립 구조체)

namespace Initial2D {
namespace Platform {

	/**
	 * @struct NeutralTextureInfo
	 * @brief 게임 로직에 노출되는 텍스처 정보. 플랫폼 핸들(HBITMAP/SDL_Texture*)은 노출하지 않는다.
	 */
	struct NeutralTextureInfo
	{
		int width = 0;
		int height = 0;
	};

	/**
	 * @class IRenderDevice
	 * @brief 렌더링의 플랫폼 중립 인터페이스 (Phase 1 초안 — Phase 3에서 기존
	 *        TextureManager/Renderer의 실제 호출 패턴을 기준으로 확정한다).
	 *
	 * 구현체:
	 *  - Win32 어댑터: 기존 GDI 구현 이동 (BitBlt/TransparentBlt/AlphaBlend/SetWorldTransform)
	 *  - SDL2 어댑터: SDL_RenderCopy(Ex) / SDL_RenderGeometry
	 *
	 * 텍스처는 기존 TextureManager와 동일하게 문자열 ID로 식별한다 (Lua 바인딩 호환).
	 */
	class IRenderDevice
	{
	public:
		virtual ~IRenderDevice() = default;

		virtual bool initialize(void* nativeWindowHandle) = 0;
		virtual void shutdown() = 0;

		virtual bool loadTexture(const std::string& id, const std::string& fileName) = 0;
		virtual void releaseTexture(const std::string& id) = 0;
		virtual bool getTextureInfo(const std::string& id, NeutralTextureInfo& out) const = 0;

		/** 백버퍼를 지운다. */
		virtual void clear() = 0;

		/** 백버퍼를 화면에 표시한다 (GDI: BitBlt to window DC / SDL: SDL_RenderPresent). */
		virtual void present() = 0;

		virtual void draw(const std::string& id,
			const RS::Rectangle& srcRect, const RS::Rectangle& dstRect) = 0;

		/** 컬러 키(투명색) 블리팅 — GDI TransparentBlt 대응. */
		virtual void drawTransparent(const std::string& id,
			const RS::Rectangle& srcRect, const RS::Rectangle& dstRect,
			unsigned int colorKey) = 0;

		/** 알파 블렌딩 — GDI AlphaBlend 대응. @param alpha 0~255 */
		virtual void drawBlended(const std::string& id,
			const RS::Rectangle& srcRect, const RS::Rectangle& dstRect,
			int alpha) = 0;

		/** 아핀 변환 묘화 — GDI SetWorldTransform(XFORM) 대응. */
		virtual void drawTransformed(const std::string& id,
			const RS::Rectangle& srcRect, const RS::Rectangle& dstRect,
			const TransformData& transform) = 0;
	};

} // namespace Platform
} // namespace Initial2D

#endif
