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
	// 이미 파싱이 끝났으면 다시 하지 않는다.
	// (기존에는 조건이 반대로 되어 있어 첫 호출이 파싱 없이 true를 반환했고,
	//  Lua_PreparaFont가 App::LoadFont를 먼저 불러 우회하고 있었다.)
	if (isValid()) {
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
		return false;
	}

	// 재호출(핫 리로드 등) 시 이전 파싱 결과가 누적되지 않도록 비운다
	m_textureNames.clear();

	TiXmlElement *pRoot = xmlDoc.RootElement();
	TiXmlElement *pCommon = nullptr;
	TiXmlElement *pChars = nullptr;
	TiXmlElement *pPages = nullptr;
	TiXmlElement *pKernings = nullptr;

	for (TiXmlElement *e = pRoot->FirstChildElement(); e != NULL; e = e->NextSiblingElement())
	{
		if (e->Value() == std::string("common"))
		{
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
			if (id < 0 || id >= GLYPH_TABLE_SIZE) {
				continue;
			}
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

			if (second < 0 || second >= GLYPH_TABLE_SIZE) {
				continue;
			}
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
		// append는 resourcePath 자체를 오염시켜 두 번째 항목부터 경로가 깨진다
		std::string path = resourcePath + iter[0];
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

	// 최대 텍스트 폭을 반환합니다. 빈 문자열이면 시작 위치를 그대로 반환한다
	// (기존에는 빈 벡터의 max_element를 역참조하는 미정의 동작이었다).
	if (lineWidth.empty()) {
		return x;
	}
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