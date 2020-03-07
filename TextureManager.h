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

//class Texture;

using TransformData = XFORM;
using Color = COLORREF;

/**
 * @struct TextureData
 * @brief
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

		void SetRGB(BYTE r, BYTE g, BYTE b) 
		{
			red = r;
			green = g;
			blue = b;
		}

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
 * @fn LoadBMP
 * @brief BMP 파일을 불러옵니다.
 * @return TextureData*
 */
TextureData* LoadBMP(std::string fileName);

/**
* @fn LoadPNG
* @brief PNG 파일을 불러옵니다.
* @return TextureData*
*/
TextureData* LoadPNG(std::string fileName);

/**
 * @class TextureManager
 * @brief Texture 관리 모듈
 */
class TextureManager
{
public:
	TextureManager();
	virtual ~TextureManager();
public:

	/**
	* 이미지 파일로부터 새로운 Texture를 생성합니다.
	*/
	bool Load(std::string fileName, std::string id, HDC *hdc);
	
	/**
	* Texture를 캐시에서 제거합니다.
	*/
	bool Remove(std::string id);

	/**
	* 화면에 Texture를 출력합니다.
	*/
	void Draw(std::string id, int x, int y, int width, int height);

	/**
	* 화면에 Texture를 출력합니다.
	*/
	void DrawFrame(std::string id, int x, int y, int width, int height, RECT& rect, BYTE opacity, TransformData& transform);

	/**
	* 화면에 텍스트를 출력합니다.
	*/
	void DrawText(std::string id, int x, int y, int width, int height, RECT& rect, TransformData& transform);


	/**
	* 유효한 Texture인지 체크합니다.
	*/
	bool valid(std::string id);


	void DrawPoint(int x, int y);
	void SetBitmapColor(BYTE r, BYTE g, BYTE b, BYTE a);

public:

	TextureGroup m_textureMap;
	Color        m_crTransparent;
	
	Initial2D::Color m_bitmapColor;

};

#endif