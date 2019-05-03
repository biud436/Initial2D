/**
 * @file TextureManager.cpp
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

#include "TextureManager.h"
#include "App.h"

#include <cstdlib>
#include <cstdio>

extern "C"
{
#include <png.h>
}

extern HWND g_hWnd;

#define CLOSE_PNG_FILE(P, P1, P2) \
	fclose(P); SAFE_DELETE(P1); LOG_D(P2)

struct libpng_func_group
{
	/* refer to SDL_image */
	png_structp(*png_create_read_struct) (png_const_charp, png_voidp, png_error_ptr, png_error_ptr);
	png_infop(*png_create_info_struct) (png_const_structrp);
	void(*png_destroy_read_struct) (png_structpp, png_infopp, png_infopp);
	void(*png_init_io) (png_structrp, png_FILE_p);
	void(*png_read_info) (png_structrp, png_inforp);
	png_uint_32(*png_get_image_width) (png_const_structrp, png_const_inforp);
	png_uint_32(*png_get_image_height) (png_const_structrp, png_const_inforp);
	png_byte(*png_get_bit_depth) (png_const_structrp, png_const_inforp);
	png_byte(*png_get_color_type) (png_const_structrp, png_const_inforp);
	void(*png_set_strip_16) (png_structrp);
	void(*png_set_palette_to_rgb) (png_structrp);
	void(*png_set_expand_gray_1_2_4_to_8)(png_structrp);
	png_uint_32(*png_get_valid)(png_const_structrp, png_const_inforp, png_uint_32);
	void(*png_set_tRNS_to_alpha)(png_structrp);
	void(*png_set_filler) (png_structrp, png_uint_32, int);
	void(*png_set_gray_to_rgb) (png_structrp);
	void(*png_set_packing)(png_structrp);
	void(*png_read_update_info)(png_structrp, png_inforp);
	png_size_t(*png_get_rowbytes)(png_const_structrp, png_const_inforp);
	void(*png_read_image)(png_structrp, png_bytepp);
	void(*png_read_end)(png_structrp, png_inforp);

	jmp_buf* (*png_set_longjmp_fn) (png_structrp, png_longjmp_ptr, size_t);

	int is_loaded;
	HMODULE handle;
};

libpng_func_group g_png_func;
#ifdef PNG_DYNAMIC_LIBRARY
#define GET_FUNC(FUNC, RET, PARAMS) g_png_func.FUNC = (RET (*) PARAMS)GetProcAddress(g_png_func.handle, #FUNC); \
if (g_png_func.FUNC == NULL) { FreeLibrary(g_png_func.handle); g_png_func.handle = NULL; return FALSE; }
#else
#define GET_FUNC(FUNC, RET, PARAMS) g_png_func.FUNC = FUNC;
#endif

int TextureManager_InitPNG()
{

#ifdef PNG_DYNAMIC_LIBRARY
	#ifdef NDEBUG
		g_png_func.handle = LoadLibrary("libpng16d");
	#else
		g_png_func.handle = LoadLibrary("libpng16");
	#endif
#endif
	g_png_func.is_loaded = FALSE;
	GET_FUNC(png_create_read_struct, png_structp, (png_const_charp, png_voidp, png_error_ptr, png_error_ptr));
	GET_FUNC(png_create_info_struct, png_infop, (png_const_structrp));
	GET_FUNC(png_destroy_read_struct, void, (png_structpp, png_infopp, png_infopp));
	GET_FUNC(png_init_io, void, (png_structrp, png_FILE_p));
	GET_FUNC(png_read_info, void, (png_structrp, png_inforp));
	GET_FUNC(png_get_image_width, png_uint_32, (png_const_structrp, png_const_inforp));
	GET_FUNC(png_get_image_height, png_uint_32, (png_const_structrp, png_const_inforp));
	GET_FUNC(png_get_bit_depth, png_byte, (png_const_structrp, png_const_inforp));
	GET_FUNC(png_get_color_type, png_byte, (png_const_structrp, png_const_inforp));
	GET_FUNC(png_set_strip_16, void, (png_structrp));
	GET_FUNC(png_set_palette_to_rgb, void, (png_structrp));
	GET_FUNC(png_set_expand_gray_1_2_4_to_8, void, (png_structrp));
	GET_FUNC(png_get_valid, png_uint_32, (png_const_structrp, png_const_inforp, png_uint_32));
	GET_FUNC(png_set_tRNS_to_alpha, void, (png_structrp));
	GET_FUNC(png_set_filler, void, (png_structrp, png_uint_32, int));
	GET_FUNC(png_set_gray_to_rgb, void, (png_structrp));
	GET_FUNC(png_set_packing, void, (png_structrp));
	GET_FUNC(png_read_update_info, void, (png_structrp, png_inforp));
	GET_FUNC(png_get_rowbytes, png_size_t, (png_const_structrp, png_const_inforp));
	GET_FUNC(png_read_image, void, (png_structrp, png_bytepp));
	GET_FUNC(png_read_end, void, (png_structrp, png_inforp));
	GET_FUNC(png_set_longjmp_fn, jmp_buf *, (png_structrp, png_longjmp_ptr, size_t));

	g_png_func.is_loaded = TRUE;

	return g_png_func.is_loaded;
}

TextureData::TextureData()
{
	width = 0;
	height = 0;
	texture = NULL;
}

TextureData::~TextureData()
{
	DeleteObject(texture);
}

TextureData* LoadBMP(std::string fileName)
{
	HANDLE				hFile;
	DWORD				dwFileSize, dwRead;
	BITMAPFILEHEADER	bhFileHeader;
	BITMAPINFO			*ih;
	PVOID				pRaster;
	TextureData			*pTextureData = new TextureData();

	hFile = CreateFile(fileName.c_str(), GENERIC_READ, 0, NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL);
	if (hFile == INVALID_HANDLE_VALUE) {
		MessageBox(g_hWnd, "파일을 찾을 수 없습니다", "오류", MB_OK | MB_ICONERROR);
		return pTextureData;
	}
	 
	// 파일 헤더와 정보 구조체 취득
	ReadFile(hFile, &bhFileHeader, sizeof(BITMAPFILEHEADER), &dwRead, NULL);
	dwFileSize = bhFileHeader.bfOffBits - sizeof(BITMAPFILEHEADER);
	ih = (BITMAPINFO *)malloc(dwFileSize);
	ReadFile(hFile, ih, dwFileSize, &dwRead, NULL);

	// DIB 섹션 및 버퍼 할당
	pTextureData->texture = CreateDIBSection(NULL, ih, DIB_RGB_COLORS, &pRaster, NULL, 0);

	// 래스터 데이터 취득
	ReadFile(hFile, pRaster, bhFileHeader.bfSize - bhFileHeader.bfOffBits, &dwRead, NULL);
	free(ih);
	ih = NULL;
	CloseHandle(hFile);

	pTextureData->width = ih->bmiHeader.biWidth;
	pTextureData->height = ih->bmiHeader.biHeight;

	return pTextureData;

}

TextureData* LoadPNG(std::string fileName)
{

	TextureData			*pTextureData =	new TextureData();  

	int					width, height;
	png_byte			color_type;
	png_byte			bit_depth;		
	png_bytep*			row_pointers;

	VOID				*pvBits;	
	
	BITMAPINFOHEADER	bmih;

	// 파일을 불러옵니다
	FILE *fp = fopen(fileName.c_str(), "rb");

	if (fp == NULL)
	{
		MessageBox(g_hWnd, "이미지 파일을 찾을 수 없습니다", "오류", MB_OK | MB_ICONERROR);
		CLOSE_PNG_FILE(fp, pTextureData,"파일을 불러오는데 실패했습니다")
		return pTextureData;
	}

	// PNG 파일을 읽을 구조체를 생성합니다.
	png_structp png_ptr = g_png_func.png_create_read_struct(PNG_LIBPNG_VER_STRING, NULL, NULL, NULL);
	
	if (png_ptr == NULL) {
		CLOSE_PNG_FILE(fp, pTextureData, "png_ptr 실패")
		return pTextureData;
	}

	png_infop info_ptr = g_png_func.png_create_info_struct(png_ptr);

	if (info_ptr == NULL) {
		CLOSE_PNG_FILE(fp, pTextureData, "info_ptr 실패")
		g_png_func.png_destroy_read_struct(&png_ptr, NULL, NULL);
		return pTextureData;
	}

#ifdef PNG_DYNAMIC_LIBRARY
	if (setjmp( *g_png_func.png_set_longjmp_fn(png_ptr, longjmp, sizeof(jmp_buf)) ))
#else
	if (setjmp(png_jmpbuf(png_ptr)))
#endif
	{
		MessageBox(NULL, "setjmp 실패", "", MB_OK);
		CLOSE_PNG_FILE(fp, pTextureData, "setjmp 실패")
		g_png_func.png_destroy_read_struct(&png_ptr, &info_ptr, NULL);
		return pTextureData;
	}

	g_png_func.png_init_io(png_ptr, fp);
	g_png_func.png_read_info(png_ptr, info_ptr);

	// 이미지의 폭
	width		= g_png_func.png_get_image_width(png_ptr, info_ptr);

	// 이미지의 높이
	height		= g_png_func.png_get_image_height(png_ptr, info_ptr);

	// 컬러 타입
	color_type	= g_png_func.png_get_color_type(png_ptr, info_ptr);

	// 비트 깊이
	bit_depth	= g_png_func.png_get_bit_depth(png_ptr, info_ptr);

	if (bit_depth == 16)
	{
		g_png_func.png_set_strip_16(png_ptr);
	}

	if (color_type == PNG_COLOR_TYPE_PALETTE)
	{
		g_png_func.png_set_palette_to_rgb(png_ptr);
	}

	if (color_type == PNG_COLOR_TYPE_GRAY && bit_depth < 8)
	{
		g_png_func.png_set_expand_gray_1_2_4_to_8(png_ptr);
	}

	// 알파값 처리
	if (g_png_func.png_get_valid(png_ptr, info_ptr, PNG_INFO_tRNS))
	{
		g_png_func.png_set_tRNS_to_alpha(png_ptr);
	}
		
	if (color_type == PNG_COLOR_TYPE_RGB ||
		color_type == PNG_COLOR_TYPE_GRAY ||
		color_type == PNG_COLOR_TYPE_PALETTE)
	{
		g_png_func.png_set_filler(png_ptr, 0xFF, PNG_FILLER_AFTER);
	}

	if (color_type == PNG_COLOR_TYPE_GRAY ||
		color_type == PNG_COLOR_TYPE_GRAY_ALPHA)
	{
		g_png_func.png_set_gray_to_rgb(png_ptr);
	}

	if (bit_depth < 8)
	{
		g_png_func.png_set_packing(png_ptr);
	}

	g_png_func.png_read_update_info(png_ptr, info_ptr);

	// 비트 깊이
	bit_depth = g_png_func.png_get_bit_depth(png_ptr, info_ptr);

	// 색상 타입
	color_type = g_png_func.png_get_color_type(png_ptr, info_ptr);

	// 비트맵 스캔 라인을 위한 메모리 할당
	row_pointers = (png_bytep*)malloc(sizeof(png_bytep) * height);

	for (int y = 0; y < height; y++)
	{
		row_pointers[y] = (png_byte*)malloc(g_png_func.png_get_rowbytes(png_ptr, info_ptr));
	}

	g_png_func.png_read_image(png_ptr, row_pointers);
	g_png_func.png_read_end(png_ptr, NULL);
	g_png_func.png_destroy_read_struct(&png_ptr, &info_ptr, 0);

	fclose(fp);

	memset(&bmih, 0, sizeof(BITMAPINFOHEADER));

	// 비트맵 구조체 정의
	bmih.biWidth = width;
	bmih.biHeight = -height; // 비트맵은 상하 반전이므로 음수 값으로 반전 처리
	bmih.biBitCount = 32; // 32비트
	bmih.biCompression = BI_RGB;
	bmih.biSize = sizeof(BITMAPINFOHEADER);
	bmih.biSizeImage = width * height * 4;
	bmih.biPlanes = 1;
	bmih.biXPelsPerMeter = 2835; // 72 DPI × 39.3701 인치, 2834.6472
	bmih.biYPelsPerMeter = 2835;

	BITMAPINFO* bmi = (BITMAPINFO*)&bmih;

	// DIB 영역을 만든다.
	pTextureData->width = width;
	pTextureData->height = height;
	pTextureData->texture = CreateDIBSection(App::GetInstance().GetContext().mainContext, bmi, DIB_RGB_COLORS, &pvBits, NULL, 0x0);

	// 비트맵을 색상 값으로 채운다.
	// @link MSDN - https://msdn.microsoft.com/ko-kr/library/windows/desktop/dd183353(v=vs.85).aspx
	for (int y = 0; y < height; y++)
	{

		png_bytep row = row_pointers[y];

		for (int x = 0; x < width; x++)
		{
			png_bytep px = &(row[x * 4]); // 4-Byte Alignments

			// 4바이트라면,
			if ((x * 4) % 4 == 0) {

				// 비트 플래그로 RGBA -> ARGB로 변환한다.
				((UINT32 *)pvBits)[y * width + x] = (px[3]<< 24)|(px[0]<<16)|(px[1]<<8)|(px[2]);

			}
		}

	}

	// 메모리 정리
	free(row_pointers);

	row_pointers = NULL;

	// 비트맵 반환
	return pTextureData;

}


TextureManager::TextureManager() : m_crTransparent(RGB(255, 255, 255)) // 투명색
{
	if (!TextureManager_InitPNG()) {
		MessageBox(NULL, "제대로 초기화되지 않았습니다", "", MB_OK);
	}
}


TextureManager::~TextureManager()
{
	
	TextureGroup::iterator iter;

	for (iter = m_textureMap.begin(); iter != m_textureMap.end(); iter++)
	{
		SAFE_DELETE(iter->second)
	}

#ifdef PNG_DYNAMIC_LIBRARY
	if (g_png_func.is_loaded) {
		FreeLibrary(g_png_func.handle);
	}
#endif
}


bool TextureManager::Remove(std::string id)
{
	TextureGroup::iterator iter;

	iter = m_textureMap.find(id);

	if (iter != m_textureMap.end()) {
		SAFE_DELETE(iter->second)
	}

	m_textureMap.erase(id);
		
	return true;
}


bool TextureManager::valid(std::string id)
{
	TextureGroup::iterator iter;

	iter = m_textureMap.find(id);
	return iter != m_textureMap.end();
}

bool TextureManager::Load(std::string fileName, std::string id, HDC *hdc)
{
	
	TextureData *tempTexture = NULL;
	
	std::string fmt = fileName.substr(fileName.size() - 4, 4);

	// 파일이 PNG인가?
	if (fmt == ".png")
	{
		tempTexture = LoadPNG(fileName.c_str());
	}

	// 파일이 BMP인가?
	if (fmt == ".bmp")
	{
		tempTexture = LoadBMP(fileName.c_str());
	}

	// 텍스처가 있으면 텍스처 맵에 복사
	if (tempTexture->texture != 0) {
		m_textureMap[id] = tempTexture;
		return true;
	}
		
	SAFE_DELETE(tempTexture)
		
	return false;

}


void TextureManager::Draw(std::string id, int x, int y, int width, int height)
{
	TextureData *currentTexture = m_textureMap[id];

	// 디바이스 컨텍스트 획득
	App::DeviceContext& context = App::GetInstance().GetContext();

	// 메모리 DC에 그린다
	context.newContext = CreateCompatibleDC(context.mainContext);
	Texture hOldBitmap = (Texture)SelectObject(context.newContext, currentTexture->texture);

	// 투명하게 출력한다
	TransparentBlt(context.currentContext, x, y, width, height, context.newContext, 0, 0, width, height, m_crTransparent);

	// 메모리 DC 삭제
	SelectObject(context.newContext, hOldBitmap);
	DeleteDC(context.newContext);

}

void TextureManager::DrawFrame(std::string id, int x, int y, int width, int height, RECT& rect, TransformData& transform)
{

	TextureData *currentTexture = m_textureMap[id];		// 텍스처 풀에서 텍스처를 가져온다

	// 디바이스 컨텍스트 획득
	App::DeviceContext& context = App::GetInstance().GetContext();
	XFORM normalTransform = { 1, 0, 0, 1, 0, 0 };

	// 트랜스폼 적용
	SetGraphicsMode(context.currentContext, GM_ADVANCED);
	SetWorldTransform(context.currentContext, &transform);

	// 메모리 DC에 그린다
	context.newContext = CreateCompatibleDC(context.mainContext);
	Texture hOldBitmap = (Texture)SelectObject(context.newContext, currentTexture->texture);

	// 투명하게 출력한다
	TransparentBlt(context.currentContext,
		0, 0, width, height, 
		context.newContext,
		rect.left, rect.top, width, height, 
		m_crTransparent);

	// 트랜스폼 복구
	SetGraphicsMode(context.currentContext, GM_ADVANCED);
	SetWorldTransform(context.currentContext, &normalTransform);

	// 메모리 DC 삭제
	SelectObject(context.newContext, hOldBitmap);
	DeleteDC(context.newContext);
}