/**
 * @file TextureManager.h
 * @date 2018/03/26 11:43
 *
 * @author biud436
 * Contact: biud436@gmail.com
 *
 * @brief 
 *
 *
 * @note
*/

#ifndef TEXTUREMANAGER_H
#define TEXTUREMANAGER_H

#define WIN32_LEAN_AND_MEAN

#include <map>
#include <string>
#include <Windows.h>
#include "Constants.h"
#include "NonCopyable.h"

//class Texture;

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

using TextureGroup = std::map<std::string, TextureData*>;

/**
 * @brief BMP 파일을 불러옵니다.
 * @return TextureData*
 */
TextureData* LoadBMP(std::string fileName);

/**
* @brief PNG 파일을 불러옵니다.
* @return TextureData*
*/
TextureData* LoadPNG(std::string fileName);

/**
 * @class TextureManager
 * @brief This class allows you to create textures and draw them using Win32-GDI.
 */
class TextureManager : private UnCopyable
{
public:
	TextureManager();
	virtual ~TextureManager();
public:

	/**
	 * @brief Create Texture from a specific image such as *.png 
	 * @details To call this function, PNG image has decoded as bitmap using libpng.
	 * @param std::string fileName
	 * @param std::string id
	 * @param HDC* hdc
	 */
	bool Load(std::string fileName, std::string id, HDC *hdc);
	
	/**
	 * @brief Remove the texture from Texture Cache
	 * @param std::string id
	 * @return boolean
	 */
	bool Remove(std::string id);

	/**
	 * @brief Draws the texture on the game screen.
	 * 
	 * @param std::string id
	 * @param int x
	 * @param int y
	 * @param int width
	 * @param int height
	 */
	void Draw(std::string id, int x, int y, int width, int height);

	/**
	 * @brief Draws a certain frame of the texture on the game screen.
	 * 
	 * @param std::string id
	 * @param int x
	 * @param int y
	 * @param int width
	 * @param int height
	 * @param RECT& rect
	 * @param BYTE opacity
	 * @param TransformData& transform
	 */
	void DrawFrame(std::string id, int x, int y, int width, int height, RECT& rect, BYTE opacity, TransformData& transform);

	/**
	 * @brief Draw the bitmap text on the screen.
	 * 
	 * @param id 
	 * @param x 
	 * @param y 
	 * @param width 
	 * @param height 
	 * @param rect 
	 * @param transform 
	 */
	void DrawText(std::string id, int x, int y, int width, int height, RECT& rect, TransformData& transform);

	/**
	 * @brief 유효한 Texture인지 체크합니다.
	 * 
	 * @param id 
	 * @return true 
	 * @return false 
	 */
	bool valid(std::string id);

	/**
	 * @brief Draws the point on the game screen.
	 * 
	 * @param x 
	 * @param y 
	 */
	void DrawPoint(int x, int y);

	/**
	 * @brief 비트맵 색상을 설정합니다.
	 * 
	 * @param r 
	 * @param g 
	 * @param b 
	 * @param a 
	 */
	void SetBitmapColor(BYTE r, BYTE g, BYTE b, BYTE a);

public:

	TextureGroup m_textureMap;
	Color        m_crTransparent;
	
	Initial2D::Color m_bitmapColor;

};

#endif