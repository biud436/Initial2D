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

	void initMembers();
	bool load();
	bool remove();
	bool isValid();
	bool open(std::string fntName);
	bool ParseFont(std::string fntName);
	Charset& getDesc();
	int drawText(int x, int y, std::wstring text);
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