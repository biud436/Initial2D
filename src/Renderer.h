#ifndef __TEXTUREMANAGER_WIN32_IMPL_H_
#define __TEXTUREMANAGER_WIN32_IMPL_H_

#define WIN32_LEAN_AND_MEAN

#include <map>
#include <string>
#include "Constants.h"
#include "NonCopyable.h"

#ifndef RS_SDL_RENDERER
#include <Windows.h>
#else
#include <SDL.h>
#endif

namespace Initial2D 
{
	namespace Win32 
	{
		using TransformData = XFORM;
		using Color = COLORREF;

		/**
		 * @struct TextureData
		 * @brief
		 *
		 */
		struct TextureData
		{
			int width;			/** 폭 */
			int height;			/** 높이 */
			HBITMAP texture;	/** 텍스처 */
			TextureData();
			~TextureData();
		};

		namespace Initial2D {

			class Color {

			public:

				BYTE red;
				BYTE green;
				BYTE blue;
				BYTE alpha;

				Color(BYTE r, BYTE g, BYTE b, BYTE a) :
					red(r),
					green(g),
					blue(b),
					alpha(a)
				{

				}

				/**
				* @method SetRGB
				* @param r
				* @param g
				* @param b
				*/
				void SetRGB(BYTE r, BYTE g, BYTE b)
				{
					red = r;
					green = g;
					blue = b;
				}

				/**
				* @fn SetAlpha
				* @param a
				*/
				void SetAlpha(BYTE a)
				{
					alpha = a;
				}

				COLORREF GetRGBColor() {
					return RGB(red, green, blue);
				}

			};
		}

		class Renderer : private UnCopyable
		{
		public:
			Renderer();
			virtual ~Renderer();

			void Draw(std::string id, int x, int y, int width, int height);
			void DrawFrame(std::string id, int x, int y, int width, int height, RECT& rect, BYTE opacity, TransformData& transform);
			void DrawText(std::string id, int x, int y, int width, int height, RECT& rect, TransformData& transform);
		};

	}
}




#endif

