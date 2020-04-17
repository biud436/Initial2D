#include "Font.h"
#include "Sprite.h"
#include "App.h"
#include "TextureManager.h"
#include <tinyxml.h>
#include <memory>
#include <algorithm>

Font::Font()
{
	initMembers();
}

Font::Font(std::string fntName)
{
	initMembers();
	open(fntName);
}

Font::~Font()
{

}

void Font::initMembers()
{
	m_charsetDesc.IsTextureReady = false;
	m_charsetDesc.IsReady = false;
	isUsedTextWidth = false;
	m_scale = 1.0;
	m_fontSize = 32.0;
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
	TiXmlElement *pCommon = nullptr;
	TiXmlElement *pChars = nullptr;
	TiXmlElement *pPages = nullptr;
	TiXmlElement *pKernings = nullptr;

	for (TiXmlElement *e = pRoot->FirstChildElement(); e != NULL; e = e->NextSiblingElement())
	{
		if (e->Value() == std::string("common"))
		{
			LOG_D("== common");
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
			LOG_D("== chars");
			pChars = e;
		}
		else if (e->Value() == std::string("kernings"))
		{
			pKernings = e;
		}
	}

	// Parse Page
	for (TiXmlElement *e = pPages->FirstChildElement(); e != NULL; e = e->NextSiblingElement()) {
		if (e->Value() == std::string("page")) {
			m_textureNames.push_back(e->Attribute("file"));
		}
	}

	int count;
	pChars->Attribute("count", &count);

	// Parse char
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

	// Parse kerning
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
	std::string resourcePath = ".\\resources\\fonts\\";
	std::string textureId = "font";

	TextureNames::iterator iter = m_textureNames.begin();
	TextureManager &tm = App::GetInstance().GetTextureManager();
	int i = 0;

	for (TextureNames::iterator iter = m_textureNames.begin(); iter != m_textureNames.end(); iter++)
	{
		std::string path = resourcePath.append(iter[0]);
		std::string id = textureId + std::to_string(i);
		m_textureIds[i++] = id;
		m_charsetDesc.IsTextureReady = tm.Load(path, id, NULL);
	}

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

	//int lineWidth = 0;
	std::vector<int> lineWidth;
	lineWidth.push_back(0);

	std::string textureId = "font";

	if (!m_charsetDesc.IsTextureReady) {
		LOG_D("폰트 아틀라스가 준비되지 않았습니다.");
		return lineWidth.back();
	}

	TextureManager &tm = App::GetInstance().GetTextureManager();

	// 검정색을 투명색으로 설정한다.
	COLORREF tempColor = tm.m_crTransparent;
	tm.m_crTransparent = RGB(0, 0, 0);
	
	int prevCode = 0;

	// Set the scale with font.
	m_scale = m_fontSize / static_cast<double>(lineHeight);

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
			int ox = static_cast<int>(desc.XOffset * m_scale);
			int oy = static_cast<int>(desc.YOffset * m_scale);
			int page = desc.Page;
			std::string textureId = m_textureIds[page];

			transform.eDx = cursorX + ox;
			transform.eDy = cursorY + oy;

			RECT rt;
			SetRect(&rt, cx, cy, cw, ch);

			if (!isUsedTextWidth) 
			{
				tm.DrawText(textureId,
					cursorX + ox, 
					cursorY + oy,
					static_cast<int>(cw * m_scale), 
					static_cast<int>(ch * m_scale), 
					rt, transform);
			}
			
			if (prevCode != 0 && desc.kerning[prevCode] > 0) 
			{
				cursorX += desc.kerning[prevCode];
			}

			cursorX += static_cast<int>(desc.XAdvance * m_scale);

			lineWidth.push_back(cursorX);

			prevCode = c;

		}
		else {
			if (c == '\n') 
			{
				cursorX = x;
				cursorY += lineHeight;
			}

			lineWidth.push_back(cursorX);

		}
	}

	// 투명색 설정을 이전으로 되돌린다.
	tm.m_crTransparent = tempColor;

	// 최대 텍스트 폭을 반환합니다.
	std::vector<int>::iterator iter = std::max_element(lineWidth.begin(), lineWidth.end());

	return *iter;

}

int Font::getTextWidth(int x, int y, std::wstring text)
{
	int width = 0;

	// Draw Call을 줄이기 위해, isUsedTextWidth 플래그를 설정한다.
	isUsedTextWidth = true;
	width = drawText(x, y, text);
	isUsedTextWidth = false;

	return width;

}