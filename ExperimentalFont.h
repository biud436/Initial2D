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
 * 폰트 클래스는 트루 타입 폰트에서 폰트 정보를 추출하여 직접 폰트를 렌더링하는 소스로 Windows API에 의존한다.
 * 대부분의 소스를 아래에서 참고했지만 튜토리얼 급의 소스라 그런지 많은 문제가 나타난다.
 * 묘화할 수 없는 영역의 글자나 특정 문자 범위에서 오류가 발생하거나 글자가 뭉개지는 경우도 있다.
 *
 * <a href="http://eternalwindows.jp/graphics/bitmap/bitmap12.html">Link 1</a>
 *
 * 실제 서비스되는 제품에 적용될 수 있는 코드는 다음 링크에 있다.
 * 정렬 부분과 색상 값 획득하는 과정에서 디테일이 다르다.
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
		// static_cast<ExperimentalFont&&>(other); 와 같다.
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
	 * 폰트 설정을 도중에 변경하려면 폰트 오브젝트를 재생성해야 한다.
	 * 예를 들면, 중간에 기울임 꼴이나 굵은 폰트 또는 사이즈를 변경하고자 할 땐 폰트 오브젝트를 재생성해야 한다.
	 *
	 * @param fontFace 폰트 명
	 * @param fontSize 폰트 크기
	 * @param bold 굵게
	 * @param italic 기울임꼴
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
	 * 선택된 비트맵의 raw 픽셀 데이터(BGRA)를 구하는 함수로 
	 * 각 색상은 8비트를 차지하는 256 색상이어야 하며 4바이트 간격으로 정렬되어있어야 한다.
	 */
	LPBYTE	getBits(HBITMAP hBMP, int x, int y);

	/**
	 * 메모리 버퍼를 만든다.
	 * 메모리 버퍼는 완성된 문자 하나를 메모리 버퍼에 쓴 후, 최종적으로 완성된 문자열만을 화면에 한 번에 출력할 때 사용한다.
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

