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
 * @details
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
	ExperimentalFont(std::wstring fontFace, int fontSize, int width, int height);
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

	/**
	 * rhs�� �캯�̶�� ������ ���� rhs�� �ٿ�����. 
	 */
	ExperimentalFont& operator=(const ExperimentalFont&& rhs)
	{
		if (this != &rhs)
		{
			m_sFontFace = rhs.m_sFontFace;
			m_nFontSize = rhs.m_nFontSize;
		}
		return *this;
	}

	virtual bool initialize(float x, float y, int width, int height, int maxFrames, std::string textureId);
	virtual bool initialize();

	virtual void update(float elapsed);
	virtual void draw();

	void init();
	void init(int width, int height);
	void release();

	void beginFont();
	void endFont();

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

	void render(int x, int y, LPWSTR lpszText, COLORREF cr);

	int getTextWidth(LPWSTR lpszText);

	ExperimentalFont& setText(std::wstring text);
	ExperimentalFont& setPosition(int x, int y);
	ExperimentalFont& setTextColor(BYTE red, BYTE green, BYTE blue);
	ExperimentalFont& setOpacity(BYTE value);

	virtual void updateTransform();

	virtual	TransformData&	getTransform();

private:


	/**
	 * @brief 
	 * 
	 * @param hdc 
	 * @param hBitmap 
	 * @param xStart 
	 * @param yStart 
	 * @param lpszText 
	 * @param cr 
	 */
	void	renderChar(HDC hdc, HBITMAP hBitmap, int xStart, int yStart, LPWSTR lpszText, COLORREF cr);

	/**
	 * @brief ���õ� ��Ʈ���� raw �ȼ� ������(BGRA)�� ���ϴ� �Լ�
	 * @details
	 * �� ������ 8��Ʈ�� �����ϴ� 256 �����̾�� �ϸ� 4����Ʈ �������� ���ĵǾ��־�� �Ѵ�.
	 * 
	 * @param hBMP 
	 * @param x 
	 * @param y 
	 * @return LPBYTE 
	 */
	LPBYTE	getBits(HBITMAP hBMP, int x, int y);

	/**
	 * @brief �޸� ���۸� �����.
	 * @details
	 * �޸� ���۴� �ϼ��� ���� �ϳ��� �޸� ���ۿ� �� ��, ���������� �ϼ��� ���ڿ����� ȭ�鿡 �� ���� ����� �� ����Ѵ�.
	 * 
	 * @param width 
	 * @param height 
	 * 
	 * @return HBITMAP 
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

