#include "Font.h"
#include "Sprite.h"
#include "App.h"
#include "TextureManager.h"
#include <tinyxml.h>

Font::Font()
{
	m_charsetDesc.IsTextureReady = false;
	m_charsetDesc.IsReady = false;
	isUsedTextWidth = false;
}

Font::Font(std::string fntName)
{
	m_charsetDesc.IsTextureReady = false;
	m_charsetDesc.IsReady = false;
	isUsedTextWidth = false;
	open(fntName);
}

Font::~Font()
{

}

bool Font::isValid()
{
	return m_charsetDesc.IsReady == true;
}

bool Font::open(std::string fntName)
{

	if (!isValid()) {
		return true;
	}

	if (ParseFont(fntName))
	{
		return true;
	}
	
	return false;
}

bool Font::ParseFont(std::string fntName)
{

	TiXmlDocument xmlDoc;
	
	if (!xmlDoc.LoadFile(fntName))
	{
		LOG_D(xmlDoc.ErrorDesc());
		return false;
	}

	TiXmlElement *pRoot = xmlDoc.RootElement();
	TiXmlElement *pCommon = 0;
	TiXmlElement *pChars = 0;
	TiXmlElement *pPages = 0;
	TiXmlElement *pKernings = 0;

	for (TiXmlElement *e = pRoot->FirstChildElement(); e != NULL; e = e->NextSiblingElement())
	{
		if (e->Value() == std::string("common"))
		{
			LOG_D("common을 찾았습니다.");
			pCommon = e;
			e->Attribute("lineHeight", &m_charsetDesc.LineHeight);
			e->Attribute("base", &m_charsetDesc.Base);
			e->Attribute("scaleW", &m_charsetDesc.Width);
			e->Attribute("scaleH", &m_charsetDesc.Height);
			e->Attribute("pages", &m_charsetDesc.Pages);

		}
		else if (e->Value() == std::string("pages"))
		{
			pPages = e;
		}
		else if (e->Value() == std::string("chars"))
		{
			LOG_D("chars을 찾았습니다.");
			pChars = e;
		}
		else if (e->Value() == std::string("kernings"))
		{
			pKernings = e;
		}
	}

	//for (TiXmlElement *e = pPages->FirstChildElement(); e != NULL; e = e->NextSiblingElement()) {
	//	if (e->Value() == std::string("page"))
	//	{
	//		int id;
	//		e->Attribute("id", &id);
	//		m_filename[id] = e->Attribute("file");
	//	}
	//}

	int count;
	pChars->Attribute("count", &count);

	for (TiXmlElement *e = pChars->FirstChildElement(); e != NULL; e = e->NextSiblingElement()) {
		if (e->Value() == std::string("char"))
		{
			int id;
			e->Attribute("id", &id);
			e->Attribute("x", &m_charsetDesc.Chars[id].x);
			e->Attribute("y", &m_charsetDesc.Chars[id].y);
			e->Attribute("width", &m_charsetDesc.Chars[id].Width);
			e->Attribute("height", &m_charsetDesc.Chars[id].Height);
			e->Attribute("xoffset", &m_charsetDesc.Chars[id].XOffset);
			e->Attribute("yoffset", &m_charsetDesc.Chars[id].YOffset);
			e->Attribute("xadvance", &m_charsetDesc.Chars[id].XAdvance);
			e->Attribute("page", &m_charsetDesc.Chars[id].Page);
		}
	}

	for (TiXmlElement *e = pKernings->FirstChildElement(); e != NULL; e = e->NextSiblingElement()) {
		if (e->Value() == std::string("kerning"))
		{
			int first, second, amount;
			e->Attribute("first", &first);
			e->Attribute("second", &second);
			e->Attribute("amount", &amount);
			
			m_charsetDesc.Chars[second].kerning[first] = amount;
		}
	}

	if (!pCommon) {
		return false;
	}

	if (!pChars) {
		return false;
	}

	m_charsetDesc.IsReady = true;

	return true;
}

Charset& Font::getDesc()
{
	return m_charsetDesc;
}


bool Font::load()
{
	std::string resourcePath = ".\\resources\\hangul_0.png";
	LOG_D(resourcePath);
	std::string textureId = "font";

	TextureManager &tm = App::GetInstance().GetTextureManager();
	m_charsetDesc.IsTextureReady = tm.Load(resourcePath, textureId, NULL);

	return m_charsetDesc.IsTextureReady;
}

bool Font::remove()
{
	if (!m_charsetDesc.IsTextureReady)
		return false;

	TextureManager &tm = App::GetInstance().GetTextureManager();
	std::string textureId = "font";

	if (tm.valid(textureId)) {
		tm.Remove(textureId);
		m_charsetDesc.IsTextureReady = false;
	}
	
	return true;
}

int Font::drawText(int x, int y, std::wstring text)
{
	int base = m_charsetDesc.Base;
	int lineHeight = m_charsetDesc.LineHeight;
	int width = m_charsetDesc.Width;
	int height = m_charsetDesc.Height;

	int cursorX = x;
	int cursorY = y;
	int prevCursorX = 0;

	int lineWidth = 0;

	std::string textureId = "font";

	if (!m_charsetDesc.IsTextureReady) {
		LOG_D("폰트 아틀라스가 준비되지 않았습니다.");
		return lineWidth;
	}

	TextureManager &tm = App::GetInstance().GetTextureManager();

	// 검정색을 투명색으로 설정한다.
	COLORREF tempColor = tm.m_crTransparent;
	tm.m_crTransparent = RGB(0, 0, 0);
	
	int prevCode = 0;

	for (std::size_t i = 0; i < text.length(); i++)
	{
		int c = text.at(i);

		TransformData transform = { 1,0,0,1,0,0 };

		if ((c >= MIN_CHAR && c <= MAX_CHAR) || (c >= 0xAC00 && c <= 0xD7A3))
		{
			CharDescriptor desc = m_charsetDesc.Chars[c];

			int cx = desc.x;
			int cy = desc.y;
			int cw = desc.Width;
			int ch = desc.Height;
			int ox = desc.XOffset;
			int oy = desc.YOffset;

			transform.eDx = cursorX + ox;
			transform.eDy = cursorY + oy;

			RECT rt;
			SetRect(&rt, cx, cy, cw, ch);

			if (!isUsedTextWidth) 
			{
				tm.DrawText(textureId, cursorX + ox, cursorY + oy, cw, ch, rt, transform);
			}
			
			if (prevCode != 0 && desc.kerning[prevCode] > 0) 
			{
				cursorX += desc.kerning[prevCode];
			}

			cursorX += desc.XAdvance;

			lineWidth = cursorX;

			prevCode = c;

		}
		else {
			if (c == '\n') 
			{
				cursorX = x;
				cursorY += lineHeight;
			}

			lineWidth = cursorX;

		}
	}

	// 투명색 설정을 이전으로 되돌린다.
	tm.m_crTransparent = tempColor;

	return lineWidth;

}