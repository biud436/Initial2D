
#ifndef __BITMAPTEXT_H__
#define __BITMAPTEXT_H__

#include <vector>
#include <string>
#include <memory>
#include "BitmapFont.h"

class Sprite;
struct FontDesc;

typedef struct tag_FONT
{
	std::string align;
	std::string name;
	int size;

	tag_FONT() :
		align("left"),
		name(""),
		size(0)
	{

	}

} FONT;

class BitmapText
{
public:
	BitmapText(std::string text, FONT font);
	~BitmapText();

	void setFontDesc(std::unique_ptr<FontDesc> desc);
	void drawText();

protected:

	int m_nTextWidth;
	int m_nTextHeight;
	std::vector<Sprite *> m_glyphs;

	FONT m_font;

	std::string m_text;
	int m_nMaxWidth;
	int m_nLetterSpacing;
	bool m_bDirty;

	std::unique_ptr<FontDesc> m_fontDesc;
	bool m_bInitFontDesc;

};

#endif