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
	m_nOpacity(255)
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
	GameObject::~GameObject();
	release();
}


void ExperimentalFont::init()
{
	// PROOF_QUALITY�� �����ϸ� ��Ʈ�� ������ ���� �߿�� �ϰ� �ȴ� (Ʈ�� ��Ʈ���� ������� ����)
	// OUT_TT_PRECIS�� �����ϸ� Ʈ�� Ÿ�� ��Ʈ�� �����Ѵ�.
	m_hFont = CreateFontW(m_nFontSize, 0, 0, 0, 0, 0, 0, 0, DEFAULT_CHARSET, OUT_TT_PRECIS, CLIP_DEFAULT_PRECIS, ANTIALIASED_QUALITY, FF_DONTCARE, m_sFontFace.c_str());
	
	HDC hDC = GetDC(g_hWnd);

	m_hDCBackBuffer = CreateCompatibleDC(hDC);
	m_hBmpBackBuffer = createBackBuffer(App::GetInstance().GetWindowWidth(), App::GetInstance().GetWindowHeight());
	if (m_hBmpBackBuffer == NULL)
	{
		return;
	}

	m_hBmpBackBufferPrev = (HBITMAP)SelectObject(m_hDCBackBuffer, m_hBmpBackBuffer);

	ReleaseDC(g_hWnd, hDC);

	m_bInit = true;

}

void ExperimentalFont::release()
{
	if (m_hDCBackBuffer)
	{
		if (m_hBmpBackBuffer) 
		{
			SelectObject(m_hDCBackBuffer, m_hBmpBackBufferPrev);
			DeleteObject(m_hBmpBackBuffer);
		}
		DeleteDC(m_hDCBackBuffer);
	}
	
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

}

void ExperimentalFont::render(int x, int y, LPWSTR lpszText, COLORREF cr)
{
	if (!m_bInit)
	{
		return;
	}

	PAINTSTRUCT ps;
	HDC hDC;

	m_hOldFont = (HFONT)SelectObject(m_hDCBackBuffer, m_hFont);
	renderChar(m_hDCBackBuffer, m_hBmpBackBuffer, x, y, lpszText, cr);
	SelectObject(m_hDCBackBuffer, m_hOldFont);

	int width = App::GetInstance().GetWindowWidth();
	int height = App::GetInstance().GetWindowHeight();

	// ���
	hDC = App::GetInstance().GetContext().currentContext;

	App::DeviceContext& context = App::GetInstance().GetContext();
	XFORM normalTransform = { 1, 0, 0, 1, 0, 0 };
	SetGraphicsMode(context.currentContext, GM_ADVANCED);
	SetWorldTransform(context.currentContext, &normalTransform);

	BLENDFUNCTION bf;
	bf.AlphaFormat = AC_SRC_ALPHA;
	bf.BlendFlags = 0;
	bf.BlendOp = 0;
	bf.SourceConstantAlpha = (BYTE)m_nOpacity;

	AlphaBlend(context.currentContext, 0, 0, width, height, m_hDCBackBuffer, 0, 0, width, height, bf);

	// Ʈ������ ����
	SetGraphicsMode(context.currentContext, GM_ADVANCED);
	SetWorldTransform(context.currentContext, &normalTransform);

}

/**
* ��Ʈ Ŭ������ Ʈ�� Ÿ�� ��Ʈ���� ��Ʈ ������ �����Ͽ� ���� ��Ʈ�� �������ϴ� �ҽ��� Windows API�� �����Ѵ�.
* ��ȭ�� �� ���� ������ ���ڳ� Ư�� ���� �������� ������ �߻��ϰų� ���ڰ� �������� ��쵵 �ִ�.
*
* <a href="http://eternalwindows.jp/graphics/bitmap/bitmap12.html">Link 1</a>
*
* ���� ���񽺵Ǵ� ��ǰ�� ����� �� �ִ� �ڵ�� ���� ��ũ�� �ִ�.
* ���� �κа� ���� �� ȹ���ϴ� �������� �������� �ٸ���.
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
		// ���� ���̸� ȹ���Ѵ�.
		dwBufferSize = GetGlyphOutlineW(hdc, *lpszText, GGO_GRAY8_BITMAP, &gm, 0, NULL, &mat2);

		// ���۸� �Ҵ��Ѵ�.
		lpBuffer = new (std::nothrow) BYTE[dwBufferSize];

		// ������ �������� 64������ ȹ���Ѵ�.
		GetGlyphOutlineW(hdc, *lpszText, GGO_GRAY8_BITMAP, &gm, dwBufferSize, lpBuffer, &mat2);

		// stride�Ǵ� pitch �κ�; 
		// ��Ʈ���� ���� ���� ��ü�� 4����Ʈ�� ������ ���� ������ ����� ǥ�ð� ���� �ʴ´�.
		// �˷����ִ� ������ ������ ����. 
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

		// ASCII�� ������ 0���� 32������ ����ְ� �Ϻ� ���� ���ڵ鵵 ��Ʈ�� ������ ����.
		// ������ ������ ������ ���� ��쿡�� �ȼ��� ó���ؼ��� �ȵǹǷ� ���ǹ��� �ݵ�� �ʿ��ϴ�.
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
							// 0-255 �ܰ��� ������ 65 (0-64) ������ �׷��̽�����(GGO_GRAY8_BITMAP)�� ��ȯ�ϴ� �κ��̴�.
							// ���� �����ϴ� ���α׷������� ���� ������ �̸� ����� ���� �����ų�, 
							// �ȼ��� �ƴ� ������ ������ ���� ȹ���Ͽ� �׸��� ����� ����.
							// ���� �������� ���� ������ ���� Ƚ���� �� ����. ��, �̰��� ���� ���� ������ ���� �� �ִ� �ڵ��̴�.
							// �ȼ� ����ü �е��� ���, ���� ��ũ�� ���ϸ� https://en.wikipedia.org/wiki/BMP_file_format
							// 24��Ʈ�� ���, BGR�̸�, 32��Ʈ�� ���, BGRA��.
							lp[0] = (GetBValue(cr) * alpha / 64) + (lp[0] * (64 - alpha) / 64);
							lp[1] = (GetGValue(cr) * alpha / 64) + (lp[1] * (64 - alpha) / 64);
							lp[2] = (GetRValue(cr) * alpha / 64) + (lp[2] * (64 - alpha) / 64);
							lp[3] = (255 * alpha / 64) + (lp[3] * (64 - alpha) / 64);
						}

					}
				}
			}
		}


		// ���� ���� ó���� ���� ������ ���̸� ȹ���Ѵ�.
		TEXTMETRICW tm;
		GetTextMetricsW(hdc, &tm);

		// gmCellIncX�� ���� ���ڱ����� �Ÿ�
		xStart += gm.gmCellIncX;

		// ĳ���� ������ ó���Ѵ�.
		if (*lpszText == '\r') {
			xStart = lineStartX;
		}
		
		// ���� ���ڸ� ó���Ѵ�.
		if (*lpszText == '\n') {
			xStart = lineStartX;
			yStart += gm.gmCellIncY;
			yStart += tm.tmHeight;
		}

		// ���� ���ڸ� �д´�.
		lpszText++;

		delete[] lpBuffer;

	}
}


LPBYTE ExperimentalFont::getBits(HBITMAP hBMP, int x, int y)
{
	BITMAP bm;
	LPBYTE lp;

	GetObject(hBMP, sizeof(BITMAP), &bm);

	lp = (LPBYTE)bm.bmBits;

	// ������ ������ ����.
	// ��ǻ�Ϳ��� ���ڴ� 0���� �����ϱ� ������ aligment - 1�� �Ǵ� ������ ����.
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

	// GIFó�� �̹����� ���� �� �ִ� ��츦 �����ϴ� ��������, ���⿡���� 1�̴�.
	bmih.biPlanes = 1;

	// 24 ��Ʈ�� ������ ���, BGR�̹Ƿ� ���� ������ �� �� ����.
	// 32 ��Ʈ�� ���, BGRA�̹Ƿ� ���� ������ �����ϸ� ���� 2^8 (256) ���� ǥ���� �� �ִ�.
	bmih.biBitCount = 32; 

	bmi.bmiHeader = bmih;

	return CreateDIBSection(App::GetInstance().GetContext().mainContext, (LPBITMAPINFO)&bmi, DIB_RGB_COLORS, &lp, NULL, 0);
}


void ExperimentalFont::update(float elapsed)
{

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