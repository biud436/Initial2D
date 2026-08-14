#ifndef __PLATFORM_IGLYPHRASTERIZER_H_
#define __PLATFORM_IGLYPHRASTERIZER_H_

#include <string>
#include <vector>

namespace Initial2D {
namespace Platform {

	/**
	 * @struct GlyphBitmap
	 * @brief 래스터화된 단일 글리프. pixels는 8비트 알파(커버리지) 값이다.
	 */
	struct GlyphBitmap
	{
		int width = 0;
		int height = 0;
		int offsetX = 0;   /** 펜 위치 기준 X 오프셋 */
		int offsetY = 0;   /** 베이스라인 기준 Y 오프셋 */
		int advance = 0;   /** 다음 글리프까지의 전진 폭 */
		std::vector<unsigned char> pixels;
	};

	/**
	 * @class IGlyphRasterizer
	 * @brief TrueType 글리프 래스터화의 플랫폼 중립 인터페이스 (Phase 1 초안, Phase 5에서 확정).
	 *
	 * 구현체:
	 *  - Win32 어댑터: 기존 ExperimentalFont의 GetGlyphOutline 코드 이동
	 *  - SDL2 어댑터: SDL_ttf 또는 stb_truetype
	 */
	class IGlyphRasterizer
	{
	public:
		virtual ~IGlyphRasterizer() = default;

		virtual bool open(const std::string& fontName, int pixelSize, bool antialias) = 0;
		virtual void close() = 0;

		/** @param codepoint 유니코드 코드포인트 (UTF-32) */
		virtual bool rasterize(unsigned int codepoint, GlyphBitmap& out) = 0;
	};

} // namespace Platform
} // namespace Initial2D

#endif
