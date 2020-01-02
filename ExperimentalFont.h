/**
* @file ExperimentalFont.h
*
* @author biud436
* Contact: biud436@gmail.com
*
*/
//! @cond SuppressGuard
#ifndef __EXPERIMENTALFONT_H__
#define __EXPERIMENTALFONT_H__
//! @endcond
#define WIN32_LEAN_AND_MEAN

#include <Windows.h>
#include <sstream>
#include <string>
#include "Sprite.h"
#include "Point.h"

// @def USE_ANTIALIASING 
#define USE_ANTIALIASING TRUE

/**
 * @class ExperimentalFont
 * ��Ʈ Ŭ������ Ʈ�� Ÿ�� ��Ʈ���� ��Ʈ ������ �����Ͽ� ���� ��Ʈ�� �������ϴ� �ҽ��� Windows API�� �����Ѵ�.
 * ��κ��� �ҽ��� �Ʒ����� ���������� Ʃ�丮�� ���� �ҽ��� �׷��� ���� ������ ��Ÿ����.
 * ��ȭ�� �� ���� ������ ���ڳ� Ư�� ���� �������� ������ �߻��ϰų� ���ڰ� �������� ��쵵 �ִ�.
 *
 * <a href="http://eternalwindows.jp/graphics/bitmap/bitmap12.html">Link 1</a>
 *
 * ���� ���񽺵Ǵ� ��ǰ�� ����� �� �ִ� �ڵ�� ���� ��ũ�� �ִ�.
 * ���� �κа� ���� �� ȹ���ϴ� �������� �������� �ٸ���.
 * 
 * <a href="https://rsdn.org/forum/src/830679.1">Link 2</a>
 */

using TransformData = XFORM;

class ExperimentalFont : public Sprite
{
public:
	ExperimentalFont(std::wstring fontFace, int fontSize);
	virtual ~ExperimentalFont();

	ExperimentalFont(const 	ExperimentalFont& other);

	ExperimentalFont& operator=(const ExperimentalFont& rhs)
	{
		if (this != &rhs)
		{
			m_sFontFace = rhs.m_sFontFace;
			m_nFontSize = rhs.m_nFontSize;
		}
		return *this;
	}

	ExperimentalFont(const ExperimentalFont&& other)
	{
		// static_cast<ExperimentalFont&&>(other); �� ����.
		*this = std::move(other);
	}

	ExperimentalFont& operator=(const ExperimentalFont&& rhs)
	{
		if (this != &rhs)
		{
			m_sFontFace = rhs.m_sFontFace;
			m_nFontSize = rhs.m_nFontSize;
		}
		return *this;
	}

	void init();
	void release();

	/**
	 * ��Ʈ ������ ���߿� �����Ϸ��� ��Ʈ ������Ʈ�� ������ؾ� �Ѵ�.
	 * ���� ���, �߰��� ����� ���̳� ���� ��Ʈ �Ǵ� ����� �����ϰ��� �� �� ��Ʈ ������Ʈ�� ������ؾ� �Ѵ�.
	 *
	 * @param fontFace ��Ʈ ��
	 * @param fontSize ��Ʈ ũ��
	 * @param bold ����
	 * @param italic ����Ӳ�
	 */
	void setFont(std::wstring fontFace, const int fontSize, bool bold = false, bool italic = false);

	virtual bool initialize(float x, float y, int width, int height, int maxFrames, std::string textureId);
	virtual void update(float elapsed);
	virtual void draw();

	void render(int x, int y, LPWSTR lpszText, COLORREF cr);

	int getTextWidth(LPWSTR lpszText);

	ExperimentalFont& setText(std::wstring text);
	ExperimentalFont& setPosition(int x, int y);
	ExperimentalFont& setTextColor(BYTE red, BYTE green, BYTE blue);
	ExperimentalFont& setOpacity(BYTE value);

	virtual	TransformData&	getTransform();

private:
	void	renderChar(HDC hdc, HBITMAP hBitmap, int xStart, int yStart, LPWSTR lpszText, COLORREF cr);

	/**
	 * ���õ� ��Ʈ���� raw �ȼ� ������(BGRA)�� ���ϴ� �Լ��� 
	 * �� ������ 8��Ʈ�� �����ϴ� 256 �����̾�� �ϸ� 4����Ʈ �������� ���ĵǾ��־�� �Ѵ�.
	 */
	LPBYTE	getBits(HBITMAP hBMP, int x, int y);

	/**
	 * �޸� ���۸� �����.
	 * �޸� ���۴� �ϼ��� ���� �ϳ��� �޸� ���ۿ� �� ��, ���������� �ϼ��� ���ڿ����� ȭ�鿡 �� ���� ����� �� ����Ѵ�.
	 */
	HBITMAP createBackBuffer(int width, int height);

private:

	std::wstring  m_sFontFace;
	int		      m_nFontSize;

	HFONT	      m_hFont;
	HFONT	      m_hOldFont;
	HDC		      m_hDCBackBuffer;
	HBITMAP       m_hBmpBackBuffer;
	HBITMAP       m_hBmpBackBufferPrev;

	bool          m_bInit;

	std::wstring  m_sText;
	Point         m_position;

	BYTE          m_nOpacity;

	COLORREF      m_textColor;
	int           m_nLastTextWidth;


};

using AntiAliasingFont = ExperimentalFont;

//! @cond SuppressGuard
#endif
//! @endcond

