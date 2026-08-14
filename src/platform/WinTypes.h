#ifndef __PLATFORM_WINTYPES_H_
#define __PLATFORM_WINTYPES_H_

/**
 * @file WinTypes.h
 * @brief 비-Windows 플랫폼을 위한 Win32 기본 타입 호환 심(shim).
 *
 * 기존 엔진의 공개 API(RECT, BYTE, COLORREF, HDC 등)를 바꾸지 않고
 * macOS에서 컴파일하기 위해, Windows에서는 Windows.h를 그대로 쓰고
 * 그 외 플랫폼에서는 동일한 레이아웃·의미의 타입을 정의한다.
 *
 * 여기에는 "엔진이 실제로 사용하는 것"만 정의한다.
 */

#ifdef _WIN32

#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <Windows.h>

#else

#include <cstdint>

typedef unsigned char       BYTE;
typedef unsigned short      WORD;
typedef uint32_t            DWORD;
typedef unsigned int        UINT;
typedef uint32_t            UINT32;
typedef int32_t             LONG;
typedef void                VOID;
typedef void*               PVOID;
typedef void*               LPVOID;
typedef BYTE*               LPBYTE;

typedef wchar_t             WCHAR;
typedef wchar_t             TCHAR;
typedef wchar_t*            LPWSTR;
typedef const wchar_t*      LPCWSTR;
typedef const wchar_t*      LPCWCHAR;

// 불투명 핸들 — 비-Windows에서는 사용처가 없거나 어댑터 내부에서만 캐스팅된다.
typedef void*               HWND;
typedef void*               HDC;
typedef void*               HBITMAP;
typedef void*               HFONT;
typedef void*               HICON;
typedef void*               HANDLE;

typedef struct tagRECT
{
	LONG left;
	LONG top;
	LONG right;
	LONG bottom;
} RECT;

typedef struct tagPOINT
{
	LONG x;
	LONG y;
} POINT;

typedef DWORD COLORREF;

#ifndef RGB
#define RGB(r, g, b) ((COLORREF)(((BYTE)(r)) | (((DWORD)(BYTE)(g)) << 8) | (((DWORD)(BYTE)(b)) << 16)))
#endif
#define GetRValue(rgb) ((BYTE)(rgb))
#define GetGValue(rgb) ((BYTE)(((rgb) >> 8) & 0xFF))
#define GetBValue(rgb) ((BYTE)(((rgb) >> 16) & 0xFF))

inline int SetRect(RECT* lprc, int left, int top, int right, int bottom)
{
	if (lprc == nullptr) {
		return 0;
	}
	lprc->left = left;
	lprc->top = top;
	lprc->right = right;
	lprc->bottom = bottom;
	return 1;
}

#ifndef TRUE
#define TRUE 1
#endif
#ifndef FALSE
#define FALSE 0
#endif

#ifndef MAX_PATH
#define MAX_PATH 260
#endif

// 가상 키 코드 — 엔진과 Lua 스크립트의 키 코드 표준 (Win32 VK_* 값과 동일)
#define VK_LBUTTON   0x01
#define VK_RBUTTON   0x02
#define VK_MBUTTON   0x04
#define VK_BACK      0x08
#define VK_TAB       0x09
#define VK_RETURN    0x0D
#define VK_SHIFT     0x10
#define VK_CONTROL   0x11
#define VK_MENU      0x12
#define VK_PAUSE     0x13
#define VK_ESCAPE    0x1B
#define VK_SPACE     0x20
#define VK_PRIOR     0x21
#define VK_NEXT      0x22
#define VK_END       0x23
#define VK_HOME      0x24
#define VK_LEFT      0x25
#define VK_UP        0x26
#define VK_RIGHT     0x27
#define VK_DOWN      0x28
#define VK_INSERT    0x2D
#define VK_DELETE    0x2E
#define VK_NUMPAD0   0x60
#define VK_NUMPAD1   0x61
#define VK_NUMPAD2   0x62
#define VK_NUMPAD3   0x63
#define VK_NUMPAD4   0x64
#define VK_NUMPAD5   0x65
#define VK_NUMPAD6   0x66
#define VK_NUMPAD7   0x67
#define VK_NUMPAD8   0x68
#define VK_NUMPAD9   0x69
#define VK_F1        0x70
#define VK_F2        0x71
#define VK_F3        0x72
#define VK_F4        0x73
#define VK_F5        0x74
#define VK_F6        0x75
#define VK_F7        0x76
#define VK_F8        0x77
#define VK_F9        0x78
#define VK_F10       0x79
#define VK_F11       0x7A
#define VK_F12       0x7B

#endif // _WIN32

#endif
