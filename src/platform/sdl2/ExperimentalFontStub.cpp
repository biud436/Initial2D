/**
 * @file ExperimentalFontStub.cpp
 * @brief ExperimentalFont의 비-Windows 스텁.
 * @details 원본은 GetGlyphOutline(Win32)으로 TrueType 글리프를 직접 래스터화한다.
 *          비-Windows에서는 아직 대응 구현이 없으므로 API 형태만 유지한 no-op으로 동작한다.
 *          (IGlyphRasterizer + SDL_ttf/stb_truetype 기반 구현은 추후 과제 — Phase 5 보고 참조.
 *           현재 데모 게임(scripts/main.lua)은 이 클래스를 사용하지 않는다.)
 */
#include "Constants.h"

#ifndef RS_WINDOWS

#include "ExperimentalFont.h"
#include "App.h"

ExperimentalFont::ExperimentalFont(std::wstring fontFace, int fontSize) :
	m_sFontFace(fontFace),
	m_nFontSize(fontSize),
	m_hFont(nullptr),
	m_hOldFont(nullptr),
	m_hDCBackBuffer(nullptr),
	m_hBmpBackBuffer(nullptr),
	m_hBmpBackBufferPrev(nullptr),
	m_bInit(false),
	m_sText(L""),
	m_position(0, 0),
	m_textColor(0),
	m_nOpacity(255),
	m_nLastTextWidth(1),
	Sprite::Sprite()
{
	m_textColor = RGB(255, 255, 255);
	init();
}

ExperimentalFont::ExperimentalFont(std::wstring fontFace, int fontSize, int width, int height) :
	m_sFontFace(fontFace),
	m_nFontSize(fontSize),
	m_hFont(nullptr),
	m_hOldFont(nullptr),
	m_hDCBackBuffer(nullptr),
	m_hBmpBackBuffer(nullptr),
	m_hBmpBackBufferPrev(nullptr),
	m_bInit(false),
	m_sText(L""),
	m_position(0, 0),
	m_textColor(0),
	m_nOpacity(255),
	m_nLastTextWidth(1),
	Sprite::Sprite()
{
	m_textColor = RGB(255, 255, 255);
	init(width, height);
}

ExperimentalFont::ExperimentalFont(const ExperimentalFont& other)
{
	*this = other;
}

ExperimentalFont::~ExperimentalFont()
{
	release();
}

bool ExperimentalFont::initialize(float x, float y, int width, int height, int maxFrames, std::string textureId)
{
	m_spriteData.id = "";
	m_spriteData.position.setX(m_position.x);
	m_spriteData.position.setY(m_position.y);
	m_spriteData.width = width;
	m_spriteData.height = height;

	m_nMaxFrames = 1;

	setFrames(0, m_nMaxFrames);
	setCurrentFrame(0);

	m_spriteData.frameDelay = 0.0;
	m_fAnimationTime = 0.0;

	m_bVisible = true;
	m_bInitialized = true;

	return true;
}

bool ExperimentalFont::initialize()
{
	return initialize(0, 0,
		App::GetInstance().GetWindowWidth(),
		App::GetInstance().GetWindowHeight(), 1, "");
}

void ExperimentalFont::update(float elapsed)
{
	Sprite::update(elapsed);
}

void ExperimentalFont::draw()
{
	// 스텁: 렌더링하지 않음
}

void ExperimentalFont::init()
{
	initialize();
	m_bInit = true;
}

void ExperimentalFont::init(int width, int height)
{
	initialize(0, 0, width, height, 1, "");
	m_bInit = true;
}

void ExperimentalFont::release()
{
}

void ExperimentalFont::beginFont()
{
}

void ExperimentalFont::endFont()
{
}

void ExperimentalFont::setFont(std::wstring fontFace, const int fontSize, bool bold, bool italic)
{
	(void)bold; (void)italic;
	m_sFontFace = fontFace;
	m_nFontSize = fontSize;
	m_bInitialized = true;
}

void ExperimentalFont::render(int x, int y, LPWSTR lpszText, COLORREF cr)
{
	(void)x; (void)y; (void)lpszText; (void)cr;
}

int ExperimentalFont::getTextWidth(LPWSTR lpszText)
{
	(void)lpszText;
	return 0;
}

ExperimentalFont& ExperimentalFont::setText(std::wstring text)
{
	m_sText = text;
	return *this;
}

ExperimentalFont& ExperimentalFont::setPosition(int x, int y)
{
	m_position.x = x;
	m_position.y = y;
	m_spriteData.position.setX(static_cast<float>(x));
	m_spriteData.position.setY(static_cast<float>(y));
	return *this;
}

ExperimentalFont& ExperimentalFont::setTextColor(BYTE red, BYTE green, BYTE blue)
{
	m_textColor = RGB(red, green, blue);
	return *this;
}

ExperimentalFont& ExperimentalFont::setOpacity(BYTE value)
{
	m_nOpacity = value;
	return *this;
}

void ExperimentalFont::updateTransform()
{
	Sprite::updateTransform();
}

TransformData& ExperimentalFont::getTransform()
{
	return Sprite::getTransform();
}

#endif // !RS_WINDOWS
