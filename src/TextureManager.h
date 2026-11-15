/**
 * @file TextureManager.h
 * @date 2018/03/26 11:43
 *
 * @author biud436
 * Contact: biud436@gmail.com
 *
 * @brief 
 *
 *
 * @note
*/

#ifndef TEXTUREMANAGER_H
#define TEXTUREMANAGER_H

#include <map>
#include <string>
#include "Constants.h"
#include "NonCopyable.h"
#include "platform/WinTypes.h"
#include "Matrix.h"

//class Texture;

// TransformData는 Matrix.h에서 플랫폼별로 정의된다.
using Color = COLORREF;

#ifdef RS_WINDOWS

/**
 * @struct TextureData
 * @brief
 *
 */
struct TextureData
{
	int width;			/** 폭 */
	int height;			/** 높이 */
	HBITMAP texture;	/** 텍스처 */
	TextureData();
	~TextureData();
};

#else

#include <SDL.h>

/**
 * @struct TextureData
 * @brief SDL2 어댑터용 텍스처 데이터.
 * @details surface는 컬러 키(TransparentBlt 대응) 파생 텍스처 생성을 위해 보관한다.
 */
struct TextureData
{
	int width;			/** 폭 */
	int height;			/** 높이 */
	SDL_Texture* texture;	/** 텍스처 (per-pixel alpha) */
	SDL_Surface* surface;	/** 원본 서피스 (렌더 타깃은 없다) */
	bool isTarget;			/** CreateTarget 으로 만든 렌더 타깃인가 */
	std::map<Uint32, SDL_Texture*> keyedTextures; /** 컬러 키별 파생 텍스처 캐시 */
	TextureData();
	~TextureData();
};

#endif

namespace Initial2D {

	class Color {
	
	public:

		BYTE red;
		BYTE green;
		BYTE blue;
		BYTE alpha;

		Color(BYTE r, BYTE g, BYTE b, BYTE a) :
			red(r),
			green(g),
			blue(b),
			alpha(a)
		{

		}

		/**
		* @method SetRGB
		* @param r
		* @param g
		* @param b
		*/
		void SetRGB(BYTE r, BYTE g, BYTE b) 
		{
			red = r;
			green = g;
			blue = b;
		}

		/**
		* @fn SetAlpha
		* @param a
		*/
		void SetAlpha(BYTE a)
		{
			alpha = a;
		}

		COLORREF GetRGBColor() {
			return RGB(red, green, blue);
		}

	};
}

using TextureGroup = std::map<std::string, TextureData*>;

#ifdef RS_WINDOWS
/**
 * @brief BMP 파일을 불러옵니다.
 * @return TextureData*
 */
TextureData* LoadBMP(std::string fileName);

/**
* @brief PNG 파일을 불러옵니다.
* @return TextureData*
*/
TextureData* LoadPNG(std::string fileName);
#endif

/**
 * @class TextureManager
 * @brief This class allows you to create textures and draw them using Win32-GDI.
 */
class TextureManager : private UnCopyable
{
public:
	TextureManager();
	virtual ~TextureManager();
public:

	/**
	 * @brief Create Texture from a specific image such as *.png 
	 * @details To call this function, PNG image has decoded as bitmap using libpng.
	 * @param std::string fileName
	 * @param std::string id
	 * @param HDC* hdc
	 */
	bool Load(std::string fileName, std::string id, HDC *hdc);
	
	/**
	 * @brief Remove the texture from Texture Cache
	 * @param std::string id
	 * @return boolean
	 */
	bool Remove(std::string id);

	/**
	 * @brief Draws the texture on the game screen.
	 * 
	 * @param std::string id
	 * @param int x
	 * @param int y
	 * @param int width
	 * @param int height
	 */
	void Draw(std::string id, int x, int y, int width, int height);

	/**
	 * @brief Draws a certain frame of the texture on the game screen.
	 * 
	 * @param std::string id
	 * @param int x
	 * @param int y
	 * @param int width
	 * @param int height
	 * @param RECT& rect
	 * @param BYTE opacity
	 * @param TransformData& transform
	 */
	void DrawFrame(std::string id, int x, int y, int width, int height, RECT& rect, BYTE opacity, TransformData& transform);

	/**
	 * @brief Draw the bitmap text on the screen.
	 * 
	 * @param id 
	 * @param x 
	 * @param y 
	 * @param width 
	 * @param height 
	 * @param rect 
	 * @param transform 
	 */
	void DrawText(std::string id, int x, int y, int width, int height, RECT& rect, TransformData& transform);

	/**
	 * @brief 유효한 Texture인지 체크합니다.
	 * 
	 * @param id 
	 * @return true 
	 * @return false 
	 */
	bool valid(std::string id);

	/**
	 * @brief Draws the point on the game screen.
	 * 
	 * @param x 
	 * @param y 
	 */
	void DrawPoint(int x, int y);

	/**
	 * @brief 비트맵 색상을 설정합니다.
	 * 
	 * @param r 
	 * @param g 
	 * @param b 
	 * @param a 
	 */
	void SetBitmapColor(BYTE r, BYTE g, BYTE b, BYTE a);

	/**
	 * @brief 스크립트가 바꾸는 그리기 상태(점과 도형의 색, 글자 색과 크기)를 처음 값으로 되돌린다.
	 * 스크립트가 새로 시작할 때 부른다.
	 */
	void ResetDrawState()
	{
		m_bitmapColor = Initial2D::Color(0, 0, 0, 255);
		m_textColor = Initial2D::Color(255, 255, 255, 255);
		m_textSize = 0;
	}

#ifndef RS_WINDOWS
	/** 스프라이트의 혼합 모드. 값은 Sprite::BlendMode 와 같다. */
	enum Blend { BlendNormal = 0, BlendAdd = 1, BlendMultiply = 2 };

	/**
	 * @brief 텍스처의 한 칸을 그린다. 위치는 피벗이 놓일 자리이고, 회전과 확대도 피벗을 중심으로 한다.
	 * @param src 텍스처에서 잘라 올 칸 (left, top 과 width, height)
	 * @param pivotX, pivotY 칸 안의 기준점 (0..1, 0,0 은 왼쪽 위)
	 * @param flipX, flipY 칸 안에서 좌우, 상하로 뒤집는다 (피벗 자리는 그대로)
	 */
	void DrawSprite(const std::string& id, int srcX, int srcY, int width, int height,
		float x, float y, float scale, float angleDeg, float pivotX, float pivotY,
		BYTE opacity, BYTE red, BYTE green, BYTE blue, bool flipX, bool flipY, int blend);

	/** @brief 그려 넣을 수 있는 빈 텍스처를 만든다. 같은 id 가 있으면 바꾼다. 스프라이트가 id 로 그릴 수 있다. */
	bool CreateTarget(const std::string& id, int width, int height);

	/** @brief 이후의 그리기가 들어갈 곳. 빈 문자열이면 화면. 렌더 타깃이 아닌 id 면 false. */
	bool SetRenderTarget(const std::string& id);

	/** @brief 지금 그리기가 들어가는 렌더 타깃의 id. 화면이면 빈 문자열. */
	const std::string& GetRenderTarget() const { return m_renderTarget; }

	/** @brief 그리기 대상을 화면으로 되돌린다. 엔진이 매 프레임 스크립트의 Render 뒤에 부른다. */
	void ResetRenderTarget();

	/** @brief 지금 그리기 대상을 한 색으로 지운다. 화면이면 게임 영역만 지운다. */
	void ClearTarget(BYTE r, BYTE g, BYTE b, BYTE a);

	/** @brief 사각형. fill 이 false 면 테두리 1픽셀. 색은 SetBitmapColor. */
	void DrawRect(float x, float y, float width, float height, bool fill);

	/** @brief 선분. 색은 SetBitmapColor. */
	void DrawLine(float x1, float y1, float x2, float y2);

	/** @brief 원. fill 이 false 면 테두리 1픽셀. 색은 SetBitmapColor. */
	void DrawCircle(float cx, float cy, float radius, bool fill);
#endif

public:

	TextureGroup m_textureMap;
	Color        m_crTransparent;

	Initial2D::Color m_bitmapColor;

	/** 글자 색 (비트맵 폰트의 흰 글리프에 곱한다) */
	Initial2D::Color m_textColor{ 255, 255, 255, 255 };

	/** 글자 크기 (줄 높이, 픽셀). 0 이면 폰트 파일의 크기 */
	int m_textSize = 0;

#ifndef RS_WINDOWS
private:
	std::string m_renderTarget;
#endif

};

#endif