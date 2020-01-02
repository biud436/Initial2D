/**
* @file ExperimentalFont.cpp
*
* @author biud436
* Contact: biud436@gmail.com
*
*/

#include "ExperimentalFont.h"
#include <locale>
#include <codecvt>
#include <cwchar>
#include <memory>
#include <algorithm>
#include "App.h"

extern HWND g_hWnd;

static inline std::string toString(std::wstring str)
{
	const int len = WideCharToMultiByte(CP_UTF8, 0, &str[0], (int)str.size(), NULL, 0, NULL, NULL);
	std::string ret = std::string(len, '\0');
	WideCharToMultiByte(CP_UTF8, 0, &str[0], (int)str.size(), &ret[0], (int)ret.size(), NULL, NULL);
	return ret;
}

ExperimentalFont::ExperimentalFont(std::wstring fontFace, int fontSize) :
	m_sFontFace(fontFace),
	m_nFontSize(fontSize),
	m_hFont(NULL),
	m_hOldFont(NULL),
	m_hDCBackBuffer(NULL),
	m_hBmpBackBuffer(NULL),
	m_hBmpBackBufferPrev(NULL),
	m_bInit(false),
	m_sText(L""),
	m_position(0, 0),
	m_textColor(NULL),
	m_nOpacity(255),
	m_nLastTextWidth(1),
	Sprite::Sprite()
{
	GameObject::GameObject();
	m_textColor = RGB(255, 255, 255);

	init();
}

ExperimentalFont::ExperimentalFont(const ExperimentalFont& other)
{
	*this = other;
}

ExperimentalFont::~ExperimentalFont()
{
	release();
	Sprite::~Sprite();
}

bool ExperimentalFont::initialize(float x, float y, int width, int height, int maxFrames, std::string textureId)
{
	m_spriteData.id = textureId;
	m_spriteData.position.setX(m_position.x);
	m_spriteData.position.setY(m_position.y);
	m_spriteData.width = App::GetInstance().GetWindowWidth();
	m_spriteData.height = App::GetInstance().GetWindowHeight();
	
	m_nMaxFrames = 1;

	setFrames(0, m_nMaxFrames);
	setCurrentFrame(0);

	m_spriteData.frameDelay = 0.0;
	m_fAnimationTime = 0.0;

	m_bVisible = true;

	m_bInitialized = true;
	return true;
}

void ExperimentalFont::init()
{
	// PROOF_QUALITY로 설정하면 폰트의 외형을 아주 중요시 하게 된다 (트루 폰트에는 적용되지 않음)
	// OUT_TT_PRECIS로 설정하면 트루 타입 폰트를 선택한다.
	m_hFont = CreateFontW(m_nFontSize, 0, 0, 0, 0, 0, 0, 0, DEFAULT_CHARSET, OUT_TT_PRECIS, CLIP_DEFAULT_PRECIS, ANTIALIASED_QUALITY, FF_DONTCARE, m_sFontFace.c_str());

	initialize(0, 0, 0, 0, 0, "");

	beginFont();
	
	m_bInit = true;

}

void ExperimentalFont::beginFont() {

	HDC hDC = GetDC(g_hWnd);

	m_hDCBackBuffer = CreateCompatibleDC(hDC);
	m_hBmpBackBuffer = createBackBuffer(App::GetInstance().GetWindowWidth(), App::GetInstance().GetWindowHeight());
	if (m_hBmpBackBuffer == NULL)
	{
		return;
	}

	m_hBmpBackBufferPrev = (HBITMAP)SelectObject(m_hDCBackBuffer, m_hBmpBackBuffer);

	ReleaseDC(g_hWnd, hDC);
}

void ExperimentalFont::endFont() {
	if (m_hDCBackBuffer)
	{
		if (m_hBmpBackBuffer)
		{
			SelectObject(m_hDCBackBuffer, m_hBmpBackBufferPrev);
			DeleteObject(m_hBmpBackBuffer);
		}
		DeleteDC(m_hDCBackBuffer);
	}

}

void ExperimentalFont::release()
{
	endFont();
	DeleteObject(m_hFont);
}

void ExperimentalFont::setFont(std::wstring fontFace, const int fontSize, bool bold, bool italic)
{
	m_sFontFace = fontFace;
	m_nFontSize = fontSize;

	m_hFont = CreateFontW(m_nFontSize, 0, 0, 0, 
		bold ? 700 : 400, 
		italic, 
		0, 0, DEFAULT_CHARSET, OUT_TT_PRECIS, CLIP_DEFAULT_PRECIS, ANTIALIASED_QUALITY, FF_DONTCARE, m_sFontFace.c_str());

	m_hOldFont = (HFONT)SelectObject(m_hDCBackBuffer, m_hFont);

	m_bInitialized = true;

}

void ExperimentalFont::render(int x, int y, LPWSTR lpszText, COLORREF cr)
{
	if (!m_bInit)
	{
		return;
	}

	PAINTSTRUCT ps;
	HDC hDC;

	// Get Font Texture
	m_hOldFont = (HFONT)SelectObject(m_hDCBackBuffer, m_hFont);
	renderChar(m_hDCBackBuffer, m_hBmpBackBuffer, x, y, lpszText, cr);
	SelectObject(m_hDCBackBuffer, m_hOldFont);

	int width = App::GetInstance().GetWindowWidth();
	int height = App::GetInstance().GetWindowHeight();

	// Get the device context
	hDC = App::GetInstance().GetContext().currentContext;

	// Apply a default transform
	App::DeviceContext& context = App::GetInstance().GetContext();
	XFORM normalTransform = { 1, 0, 0, 1, 0, 0 };
	//SetGraphicsMode(m_hDCBackBuffer, GM_ADVANCED);
	//SetWorldTransform(m_hDCBackBuffer, &m_transform);

	// Draw a frame to Memory DC
	{
		BLENDFUNCTION bf;
		bf.AlphaFormat = AC_SRC_ALPHA;
		bf.BlendFlags = 0;
		bf.BlendOp = 0;
		bf.SourceConstantAlpha = m_nOpacity;

		AlphaBlend(context.currentContext, 0, 0, width, height, m_hDCBackBuffer, 0, 0, width, height, bf);

		// Restore default transform
		SetGraphicsMode(m_hDCBackBuffer, GM_ADVANCED);
		SetWorldTransform(m_hDCBackBuffer, &normalTransform);
	}
}

int ExperimentalFont::getTextWidth(LPWSTR lpszText)
{
	if (!m_bInit)
	{
		return 0;
	}

	PAINTSTRUCT ps;
	HDC hDC;
	int x = 0, y = 0;
	COLORREF cr = RGB(0, 0, 0);

	m_hOldFont = (HFONT)SelectObject(m_hDCBackBuffer, m_hFont);
	renderChar(m_hDCBackBuffer, m_hBmpBackBuffer, x, y, lpszText, cr);
	SelectObject(m_hDCBackBuffer, m_hOldFont);

	return m_nLastTextWidth;
}

/**
* 폰트 클래스는 트루 타입 폰트에서 폰트 정보를 추출하여 직접 폰트를 렌더링하는 소스로 Windows API에 의존한다.
* 묘화할 수 없는 영역의 글자나 특정 문자 범위에서 오류가 발생하거나 글자가 뭉개지는 경우도 있다.
*
* <a href="http://eternalwindows.jp/graphics/bitmap/bitmap12.html">Link 1</a>
*
* 실제 서비스되는 제품에 적용될 수 있는 코드는 다음 링크에 있다.
* 정렬 부분과 색상 값 획득하는 과정에서 디테일이 다르다.
*
* <a href="https://rsdn.org/forum/src/830679.1">Link 2</a>
*/
void ExperimentalFont::renderChar(HDC hdc, HBITMAP hBitmap, int xStart, int yStart, LPWSTR lpszText, COLORREF cr)
{
	if (!m_bInit)
	{
		return;
	}

	int x, y;
	int width, height;
	int line;
	int lineStartX = xStart;
	int tempLastTextWidth = 0;

	BYTE alpha;
	DWORD dwBufferSize;

	LPBYTE lp, lpBuffer;

	GLYPHMETRICS gm;
	MAT2 mat2 = {
		{0,1}, {0,0},
		{0,0}, {0,1} 
	};

	while (*lpszText)
	{
		// 버퍼 길이를 획득한다.
		dwBufferSize = GetGlyphOutlineW(hdc, *lpszText, GGO_GRAY8_BITMAP, &gm, 0, NULL, &mat2);

		// 버퍼를 할당한다.
		lpBuffer = new (std::nothrow) BYTE[dwBufferSize];

		// 문자의 윤곽선을 65 레벨의 그레이스케일로 획득한다.
		GetGlyphOutlineW(hdc, *lpszText, GGO_GRAY8_BITMAP, &gm, dwBufferSize, lpBuffer, &mat2);

		// stride또는 pitch 부분; 
		// 비트맵은 파일 구조 자체가 4바이트로 정렬을 하지 않으면 제대로 표시가 되지 않는다.
		// 알려져있는 공식은 다음과 같다. 
		// = (gm.gmBlackBoxX + alignment - 1) / alignment * alignment
		line = ((gm.gmBlackBoxX + 3) / 4) * 4;

		width = gm.gmBlackBoxX;
		height = gm.gmBlackBoxY;

		x = xStart + gm.gmptGlyphOrigin.x;
		y = yStart - gm.gmptGlyphOrigin.y;

		if (x < 0) {
			x = 0;
		}

		if (y < 0) {
			y = 0;
		}

		// ASCII에 따르면 0부터 32까지는 비어있고 일부 제어 문자들도 비트맵 정보가 없다.
		// 글자의 윤곽선 정보가 없을 경우에는 픽셀을 처리해서는 안되므로 조건문이 반드시 필요하다.
		if (*lpszText > ' ') {
			for (int my = 0; my < height; my++)
			{
				for (int mx = 0; mx < width; mx++)
				{
					alpha = *(lpBuffer + (my * line) + mx);
					if (alpha)
					{
						lp = getBits(hBitmap, x + mx, y + my);
						if (lp) {
							// 0-255 단계의 색상을 65 (0-64) 레벨의 그레이스케일(GGO_GRAY8_BITMAP)로 변환하는 부분이다.
							// 실제 서비스하는 프로그램에서는 성능 문제로 미리 계산한 것을 얻어오거나, 
							// 픽셀이 아닌 폴리곤 정보를 직접 획득하여 그리는 방식을 쓴다.
							// 또한 나눗셈을 하지 않으며 곱셈 횟수도 더 적다. 즉, 이것은 추후 성능 문제가 생길 수 있는 코드이다.
							// 픽셀 구조체 패딩의 경우, 다음 링크에 의하면 https://en.wikipedia.org/wiki/BMP_file_format
							// 24비트의 경우, BGR이며, 32비트의 경우, BGRA다.
							lp[0] = (GetBValue(cr) * alpha / 64) + (lp[0] * (64 - alpha) / 64);
							lp[1] = (GetGValue(cr) * alpha / 64) + (lp[1] * (64 - alpha) / 64);
							lp[2] = (GetRValue(cr) * alpha / 64) + (lp[2] * (64 - alpha) / 64);
							lp[3] = (m_nOpacity * alpha / 64) + (lp[3] * (64 - alpha) / 64);
						}

					}
				}
			}
		}


		// 개행 문자 처리를 위해 글자의 높이를 획득한다.
		TEXTMETRICW tm;
		GetTextMetricsW(hdc, &tm);

		// gmCellIncX는 다음 문자까지의 거리
		xStart += gm.gmCellIncX;

		// 임시 텍스트 폭을 저장한다.
		tempLastTextWidth = xStart;

		// 캐리지 리턴을 처리한다.
		if (*lpszText == '\r') {
			xStart = lineStartX;
		}
		
		// 개행 문자를 처리한다.
		if (*lpszText == '\n') {
			m_nLastTextWidth = tempLastTextWidth;
			xStart = lineStartX;
			yStart += gm.gmCellIncY;
			yStart += tm.tmHeight;
		}

		// 다음 문자를 읽는다.
		lpszText++;

		delete[] lpBuffer;

	}

	if (m_nLastTextWidth < xStart) {
		m_nLastTextWidth = xStart;
	}

}


LPBYTE ExperimentalFont::getBits(HBITMAP hBMP, int x, int y)
{
	BITMAP bm;
	LPBYTE lp;

	GetObject(hBMP, sizeof(BITMAP), &bm);

	lp = (LPBYTE)bm.bmBits;

	// 공식은 다음과 같다.
	// 컴퓨터에서 숫자는 0부터 시작하기 때문에 aligment - 1이 되는 것으로 본다.
	// (numColor * width * aligment - 1) / aligment * aligment
	lp += (bm.bmHeight - y - 1) * ((4 * bm.bmWidth + 3) / 4) * 4;
	lp += 4 * x;

	return lp;
}


HBITMAP ExperimentalFont::createBackBuffer(int width, int height)
{
	LPVOID lp;
	BITMAPINFO bmi;
	BITMAPINFOHEADER bmih = { 0, };

	// https://rsdn.org/forum/src/830679.1
	bmih.biSize = sizeof(BITMAPINFOHEADER);
	bmih.biWidth = width;
	bmih.biHeight = height;

	// GIF처럼 이미지가 여러 개 있는 경우를 지정하는 것이지만, 여기에서는 1이다.
	bmih.biPlanes = 1;

	// 24 비트로 설정할 경우, BGR이므로 투명도 조절을 할 수 없다.
	// 32 비트의 경우, BGRA이므로 투명도 조절이 가능하며 각각 2^8 (256) 색을 표현할 수 있다.
	bmih.biBitCount = 32; 

	bmi.bmiHeader = bmih;

	return CreateDIBSection(App::GetInstance().GetContext().mainContext, (LPBITMAPINFO)&bmi, DIB_RGB_COLORS, &lp, NULL, 0);
}


void ExperimentalFont::update(float elapsed)
{
	Sprite::update(elapsed);
}


void ExperimentalFont::draw()
{
	if (!m_bInit)
	{
		return;
	}
	render(m_position.x, m_position.y, &m_sText[0], m_textColor);
}


ExperimentalFont& ExperimentalFont::setText(std::wstring text)
{
	if (!m_bInit) 
	{
		return *this;
	}

	m_sText = text;
	
	return *this;

}


ExperimentalFont& ExperimentalFont::setPosition(int x, int y)
{
	if (x < 0) {
		x = 0;
	}

	if (y < 0) {
		y = 0;
	}

	m_position.x = x;
	m_position.y = y;

	return *this;
}

ExperimentalFont& ExperimentalFont::setTextColor(BYTE red, BYTE green, BYTE blue)
{
	m_textColor = RGB(red, green, blue);

	return *this;
}


ExperimentalFont&  ExperimentalFont::setOpacity(BYTE value)
{
	
	if (value < 0) {
		value = 0;
	}

	if (value > 255) {
		value = 255;
	}

	m_nOpacity = value;

	return *this;
}

void ExperimentalFont::updateTransform()
{
	m_transform.eM11 = cos(m_spriteData.rotation) * m_spriteData.scale;
	m_transform.eM12 = sin(m_spriteData.rotation) * m_spriteData.scale;
	m_transform.eM21 = -sin(m_spriteData.rotation) * m_spriteData.scale;
	m_transform.eM22 = cos(m_spriteData.rotation) * m_spriteData.scale;
	m_transform.eDx = m_position.x + m_spriteData.offsetX;
	m_transform.eDy = m_position.y + m_spriteData.offsetY;
}

TransformData&	ExperimentalFont::getTransform()
{
	return Sprite::getTransform();
}