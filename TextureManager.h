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
	void DrawFrame(std::string id, int x, int y, int width, int height, RECT& rect, TransformData& transform);

	/**
	* 화면에 텍스트를 출력합니다.
	*/
	void DrawText(std::string id, int x, int y, int width, int height, RECT& rect, TransformData& transform);

	/**
	* 유효한 Texture인지 체크합니다.
	*/
	bool valid(std::string id);

public:

	TextureGroup m_textureMap;
	Color m_crTransparent;

};

#endif