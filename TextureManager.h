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
	int width;			/** �� */
	int height;			/** ���� */
	HBITMAP texture;	/** �ؽ�ó */
	TextureData();		
	~TextureData();
};

using TextureGroup = std::map<std::string, TextureData*>;

/**
 * @fn LoadBMP
 * @brief BMP ������ �ҷ��ɴϴ�.
 * @return TextureData*
 */
TextureData* LoadBMP(std::string fileName);

/**
* @fn LoadPNG
* @brief PNG ������ �ҷ��ɴϴ�.
* @return TextureData*
*/
TextureData* LoadPNG(std::string fileName);

/**
 * @class TextureManager
 * @brief Texture ���� ���
 */
class TextureManager
{
public:
	TextureManager();
	virtual ~TextureManager();
public:

	/**
	* �̹��� ���Ϸκ��� ���ο� Texture�� �����մϴ�.
	*/
	bool Load(std::string fileName, std::string id, HDC *hdc);
	
	/**
	* Texture�� ĳ�ÿ��� �����մϴ�.
	*/
	bool Remove(std::string id);

	/**
	* ȭ�鿡 Texture�� ����մϴ�.
	*/
	void Draw(std::string id, int x, int y, int width, int height);

	/**
	* ȭ�鿡 Texture�� ����մϴ�.
	*/
	void DrawFrame(std::string id, int x, int y, int width, int height, RECT& rect, TransformData& transform);

	/**
	* ȭ�鿡 �ؽ�Ʈ�� ����մϴ�.
	*/
	void DrawText(std::string id, int x, int y, int width, int height, RECT& rect, TransformData& transform);

	/**
	* ��ȿ�� Texture���� üũ�մϴ�.
	*/
	bool valid(std::string id);

public:

	TextureGroup m_textureMap;
	Color m_crTransparent;

};

#endif