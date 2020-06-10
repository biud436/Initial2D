#ifndef _FONT_H_
#define _FONT_H_

#include <string>
#include <sstream>
#include <vector>
#include <map>
#include <fstream>
#include <unordered_map>

class Sprite;

#define MIN_CHAR 32
#define MAX_CHAR 255

/**
 * @brief 
 * 
 */
struct CharDescriptor
{
	int x, y;
	int Width, Height;
	int XOffset, YOffset;
	int XAdvance;
	int Page;
	std::map<int, int> kerning;

	CharDescriptor() : x(0), y(0), Width(0), Height(0), XOffset(0), YOffset(0), XAdvance(0), Page(0)
	{

	}
};

/**
 * @brief 
 * 
 */
struct Charset
{
	int		LineHeight;
	int		Base;
	int		Width, Height;
	int		Pages;
	CharDescriptor Chars[55203];
	
	bool    IsReady;
	bool	IsTextureReady;

};

using TextureNames = std::vector<std::string>;
using TextureIds = std::unordered_map<int, std::string>;

/**
 * @class Font
 * This class allows you to draw the text from the bitmap font.
 * you must need to prepare the *.fnt file in the ./resources folder
 */
class Font
{

public:
	Font();
	Font(std::string fntName);
	~Font();

	/**
	 * @brief 
	 * 
	 */
	void initMembers();

	/**
	 * @brief 
	 * 
	 * @return true 
	 * @return false 
	 */
	bool load();

	/**
	 * @brief 
	 * 
	 * @return true 
	 * @return false 
	 */
	bool remove();

	/**
	 * @brief 
	 * 
	 * @return true 
	 * @return false 
	 */
	bool isValid();

	/**
	 * @brief 
	 * 
	 * @param fntName 
	 * @return true 
	 * @return false 
	 */
	bool open(std::string fntName);

	/**
	 * @brief 
	 * 
	 * @param fntName 
	 * @return true 
	 * @return false 
	 */
	bool ParseFont(std::string fntName);

	/**
	 * @brief Get the Desc object
	 * 
	 * @return Charset& 
	 */
	Charset& getDesc();

	/**
	 * @brief 
	 * 
	 * @param x 
	 * @param y 
	 * @param text 
	 * @return int 
	 */
	int drawText(int x, int y, std::wstring text);

	/**
	 * @brief Get the Text Width object
	 * 
	 * @param x 
	 * @param y 
	 * @param text 
	 * @return int 
	 */
	int getTextWidth(int x, int y, std::wstring text);

private:

	Charset      m_charsetDesc;
	std::string  m_filename[2];
	double       m_scale;
	double       m_fontSize;
	TextureNames m_textureNames;
	TextureIds   m_textureIds;

	bool isUsedTextWidth;

};

using BitmapFont = Font;

#endif