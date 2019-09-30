#include "ExperimentalFont.h"
#include <locale>
#include <codecvt>
#include <cwchar>
#include <memory>
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
	m_hDCBackBuffer(NULL),
	m_hBmpBackBuffer(NULL),
	m_hBmpBackBufferPrev(NULL),
	m_bInit(false),
	m_sText(L""),
	m_position(0, 0),
	m_textColor(NULL)
{
	GameObject::GameObject();
	m_textColor = RGB(255, 255, 255);
	init();
}


ExperimentalFont::~ExperimentalFont()
{
	GameObject::~GameObject();
	release();
}


void ExperimentalFont::init()
{
	m_hFont = CreateFontW(m_nFontSize, 0, 0, 0, 0, 0, 0, 0, HANGUL_CHARSET, 0, 0, DEFAULT_QUALITY, 0, m_sFontFace.c_str());
	
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


void ExperimentalFont::render(int x, int y, LPWSTR lpszText, COLORREF cr)
{
	if (!m_bInit)
	{
		return;
	}

	HFONT hFontPrev;
	PAINTSTRUCT ps;
	HDC hDC;

	hFontPrev = (HFONT)SelectObject(m_hDCBackBuffer, m_hFont);
	drawImpl(m_hDCBackBuffer, m_hBmpBackBuffer, x, y, lpszText, cr);
	SelectObject(m_hDCBackBuffer, hFontPrev);

	int width = App::GetInstance().GetWindowWidth();
	int height = App::GetInstance().GetWindowHeight();

	// 출력
	hDC = App::GetInstance().GetContext().currentContext;

	App::DeviceContext& context = App::GetInstance().GetContext();
	XFORM normalTransform = { 1, 0, 0, 1, 0, 0 };
	SetGraphicsMode(context.currentContext, GM_ADVANCED);
	SetWorldTransform(context.currentContext, &normalTransform);

	TransparentBlt(context.currentContext,
		0, 0, width, height,
		m_hDCBackBuffer,
		0, 0, width, height,
		RGB(0, 0, 0));

	// 트랜스폼 복구
	SetGraphicsMode(context.currentContext, GM_ADVANCED);
	SetWorldTransform(context.currentContext, &normalTransform);

}

void ExperimentalFont::drawImpl(HDC hdc, HBITMAP hBitmap, int xStart, int yStart, LPWSTR lpszText, COLORREF cr)
{
	if (!m_bInit)
	{
		return;
	}

	int x, y;
	int width, height;
	int line;

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
		dwBufferSize = GetGlyphOutlineW(hdc, *lpszText, GGO_GRAY8_BITMAP, &gm, 0, NULL, &mat2);
		lpBuffer = new BYTE[dwBufferSize];
		GetGlyphOutlineW(hdc, *lpszText, GGO_GRAY8_BITMAP, &gm, dwBufferSize, lpBuffer, &mat2);

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

		for (int my = 0; my < height; my++)
		{
			for (int mx = 0; mx < width; mx++)
			{
				alpha = *(lpBuffer + (my * line) + mx);
				if (alpha)
				{
					lp = getBits(hBitmap, x + mx, y + my);
					lp[0] = (GetBValue(cr) * alpha / 64) + (lp[0] * (64 - alpha) / 64);
					lp[1] = (GetGValue(cr) * alpha / 64) + (lp[1] * (64 - alpha) / 64);
					lp[2] = (GetRValue(cr) * alpha / 64) + (lp[2] * (64 - alpha) / 64);
				}
			}
		}

		xStart += gm.gmCellIncX;
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

	// 음수 값이 되면 오류가 난다.
	lp += (bm.bmHeight - y - 1) * ((3 * bm.bmWidth + 3) / 4) * 4;

	lp += 3 * x;

	return lp;
}

/**
 * http://eternalwindows.jp/graphics/bitmap/bitmap12.html
 */
HBITMAP ExperimentalFont::createBackBuffer(int width, int height)
{
	LPVOID lp;
	BITMAPINFO bmi;
	BITMAPINFOHEADER bmih = { 0, };

	bmih.biSize = sizeof(BITMAPINFOHEADER);
	bmih.biWidth = width;
	bmih.biHeight = height;
	bmih.biPlanes = 1;
	bmih.biBitCount = 24;

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


//int ExperimentalFont::prepare(int sx, int sy, wchar_t* str)
//{
//	PAINTSTRUCT ps;
//	VOID *pvBits;
//	HBITMAP hBitmap;
//	HFONT hFont, hOldFont;
//
//	// 폰트 생성
//	LOGFONTW lf = { m_nFontSize, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE, HANGEUL_CHARSET, OUT_TT_ONLY_PRECIS, CLIP_DEFAULT_PRECIS, PROOF_QUALITY, DEFAULT_PITCH | FF_MODERN, L"Gulim" };
//
//	// 폰트 선택
//	hFont = CreateFontIndirectW(&lf);
//	hOldFont = (HFONT)SelectObject(App::GetInstance().GetContext().mainContext, hFont);
//
//	UINT c = (UINT)*str;
//
//	// TEXTMETRIC을 구한다
//	TEXTMETRIC tm;
//	GetTextMetrics(App::GetInstance().GetContext().mainContext, &tm);
//
//	GLYPHMETRICS gm;
//	const MAT2 mat2 = { 
//		{0,1}, {0,0},
//		{0,0}, {0,1} 
//	};
//
//	// fuFormat의 경우, GGO_GRAY8_BITMAP이 가장 깔끔하지만 생산 비용이 증가한다.
//	// pvBuffer : 비트맵 메모리 블록이 반환된다.
//	// cbBuffer : 블록 크기를 전달해야 한다.
//	// lpmat2 : 문자를 회전시키고자 할 때의 행렬 정보, NULL이면 안된다.
//	DWORD len = GetGlyphOutlineW(App::GetInstance().GetContext().mainContext, c, GGO_GRAY4_BITMAP, &gm, 0, NULL, &mat2);
//
//	BYTE *pRaw = new BYTE[len];
//	GetGlyphOutlineW(App::GetInstance().GetContext().mainContext, c, GGO_GRAY4_BITMAP, &gm, len, pRaw, &mat2);
//
//	// 비트맵 준비
//	const int fontWidth = gm.gmCellIncX;
//	const int fontHeight = tm.tmHeight;
//
//	int grad = 16; // GGO_GRAY4_BITMAP로 지정할 경우, 그라데이션이 17 단계
//
//	// 비트맵 구조체 생성
//	BITMAPINFOHEADER bmih;
//	memset(&bmih, 0, sizeof(BITMAPINFOHEADER));
//
//	bmih.biWidth = fontWidth;
//	bmih.biHeight = fontHeight;
//	bmih.biBitCount = 32;
//	bmih.biCompression = BI_RGB; 
//	bmih.biSize = sizeof(BITMAPINFOHEADER);
//	bmih.biSizeImage = fontWidth * fontHeight * 4;
//	bmih.biPlanes = 1;
//	bmih.biXPelsPerMeter = 2835; // // 72 DPI × 39.3701 인치, 2834.6472
//	bmih.biYPelsPerMeter = 2835;
//
//	BITMAPINFO* bmi = (BITMAPINFO*)&bmih;
//
//	// HBITMAP 생성
//	hBitmap = CreateDIBSection(App::GetInstance().GetContext().mainContext, bmi, DIB_RGB_COLORS, &pvBits, NULL, 0x00);
//
//	// ** NOTICE : 
//	// http://marupeke296.com/DXG_No66_OutlineFont.html
//	// http://marupeke296.com/DXG_No67_NewFont.html
//	// gmBlackBoxX와 gmBlackBoxY는 문자가 있는 직사각형 상자의 폭과 높이 (gmBlackBoxX는 글꼴 비트맵의 폭이 아님)
//	// gmptGlyphOrigin는 왼쪽 위의 좌표
//	// gmCellIncX는 다음 문자의 원점까지의 거리
//	// gmCellIncY는 다음 라인의 기준점까지의 거리, 사용되지 않으면 0.
//	// **
//	
//	// 왼쪽 위 좌표
//	const int ox = gm.gmptGlyphOrigin.x;
//	const int oy = tm.tmAscent - gm.gmptGlyphOrigin.y;
//
//	// 글꼴 비트맵의 폭과 높이 (4바이트 정렬 필요)
//	const int blockWidth = (gm.gmBlackBoxX + 3) / 4 * 4;
//	/*const int blockWidth = gm.gmBlackBoxX + (4 - (gm.gmBlackBoxX % 4)) % 4;*/
//	const int blockHeight = gm.gmBlackBoxY;
//
//	for (int y = oy; y < oy + blockHeight; y++)
//	{
//		for (int x = ox; x < ox + blockWidth; x++)
//		{
//			if ((x * 4) % 4 == 0) {
//				DWORD alpha = (pRaw[(y - oy) * blockWidth + (x - ox)] * 255) / grad;
//				((UINT32 *)pvBits)[(y - oy) * blockWidth + (x - ox)] = 0xffffff00 | (alpha);
//			}
//
//		}
//	}
//
//	// 디바이스 컨텍스트 획득
//	App::DeviceContext& context = App::GetInstance().GetContext();
//	XFORM normalTransform = { 1, 0, 0, 1, 0, 0 };
//
//	// 트랜스폼 적용
//	SetGraphicsMode(context.currentContext, GM_ADVANCED);
//	SetWorldTransform(context.currentContext, &normalTransform);
//
//	// 메모리 DC에 그린다
//	context.newContext = CreateCompatibleDC(context.mainContext);
//	HBITMAP hOldBitmap = (HBITMAP)SelectObject(context.newContext, hBitmap);
//
//	// 투명하게 출력한다
//	TransparentBlt(context.currentContext,
//		sx, sy, fontWidth, fontHeight,
//		context.newContext,
//		0, 0, fontWidth, fontHeight, RGB(0, 0, 0));
//
//	// 트랜스폼 복구
//	SetGraphicsMode(context.currentContext, GM_ADVANCED);
//	SetWorldTransform(context.currentContext, &normalTransform);
//
//	// 메모리 DC 삭제
//	SelectObject(context.newContext, hOldBitmap);
//	DeleteDC(context.newContext);
//
//	// 해제
//	SelectObject(App::GetInstance().GetContext().mainContext, hOldFont);
//
//	delete[] pRaw;
//
//	// 다음 문자열이 그려질 X 좌표
//	return gm.gmCellIncX;
//}