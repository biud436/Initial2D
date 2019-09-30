#ifndef __EXPERIMENTALFONT_H__
#define __EXPERIMENTALFONT_H__

#define WIN32_LEAN_AND_MEAN

#include <Windows.h>
#include <sstream>
#include <string>
#include "GameObject.h"
#include "Point.h"

/**
 * This class allows us to make the font for doing the anti-aliasing.
 * However, it's an experimental in a lot of the functionality.
 * In additional, It is depended on the Windows API called 'GetGlyphOutline'.
 * 
 * @link http://eternalwindows.jp/graphics/bitmap/bitmap12.html
 *
 */

class ExperimentalFont : public GameObject
{
public:
	ExperimentalFont(std::wstring fontFace, int fontSize);
	virtual ~ExperimentalFont();

	void init();
	void release();
	virtual void update(float elapsed);
	virtual void draw();
	void render(int x, int y, LPWSTR lpszText, COLORREF cr);

	ExperimentalFont& setText(std::wstring text);
	ExperimentalFont& setPosition(int x, int y);
	ExperimentalFont& setTextColor(BYTE red, BYTE green, BYTE blue);

private:
	void drawImpl(HDC hdc, HBITMAP hBitmap, int xStart, int yStart, LPWSTR lpszText, COLORREF cr);
	LPBYTE getBits(HBITMAP hBMP, int x, int y);
	HBITMAP createBackBuffer(int width, int height);

private:

	std::wstring m_sFontFace;
	int m_nFontSize;
	
	HFONT m_hFont;
	HDC m_hDCBackBuffer;
	HBITMAP m_hBmpBackBuffer;
	HBITMAP m_hBmpBackBufferPrev;

	bool m_bInit;

	std::wstring m_sText;
	Point m_position;

	COLORREF m_textColor;

};

using AntiAliasingFont = ExperimentalFont;

#endif

