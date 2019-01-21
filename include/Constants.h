/**
 * @file Constants.h
 * @date 2018/03/26 11:19
 *
 * @author biud436
 * Contact: biud436@gmail.com
 *
 * @brief 
 *
 *
 * @note
*/

#pragma once
#ifndef CONSTANTS_H
#define CONSTANTS_H

// DLL 출력
#ifndef _RSDLL_
#define RSLIB __declspec(dllexport)
#else
#define RSLIB __declspec(dllimport)
#endif

/**
 * Detect the platform
 * https://stackoverflow.com/questions/5919996/how-to-detect-reliably-mac-os-x-ios-linux-windows-in-c-preprocessor
 */

namespace RS {
	namespace PLATFORM {
#ifdef _WIN64
#define RS_PLATFORM "win64"
#define RS_WINDOWS
#elif _WIN32
#define RS_PLATFORM "win32"
#define RS_WINDOWS
#elif __APPLE__
#include "TargetConditionals.h"
#if TARGET_IPHONE_SIMULATOR
		// iOS Simulator
#define RS_PLATFORM "iphone"
#define RS_IOS
#elif TARGET_OS_IPHONE
		// iOS device
#define RS_PLATFORM "iphone"
#define RS_IOS
#elif TARGET_OS_MAC
		// Other kinds of Mac OS
#define RS_PLATFORM "mac"
#define RS_OSX
#else
#   error "Unknown Apple platform"
#endif
#elif __linux__
#define RS_PLATFORM "linux"
#define RS_LINUX
#elif __unix
#define RS_PLATFORM "unix"
#define RS_UNIX
#elif __ANDROID__ 
#define RS_PLATFORM "android"
#define RS_ANDROID
#elif __posix
#define RS_PLATFORM "posix"
#define RS_POSIX
#endif
		/*const char* type = RS_PLATFORM;*/
	}
}

#define OS_TYPE RS::PLATFORM::type;

/**
* @def WINDOW_NAME
*/
#define WINDOW_NAME	"test"

/**
* @def CLASS_NAME
*/
#define CLASS_NAME	"test"

/**
* @def WINDOW_WIDTH
*/
#define WINDOW_WIDTH	640

/**
* @def WINDOW_HEIGHT
*/
#define WINDOW_HEIGHT	480

const float FPS1 = 240.0f;            
const float FPS2 = 10.0f;             
const float MIN_FRAME_TIME = 1.0f / FPS1;
const float MAX_FRAME_TIME = 1.0f / FPS2;
const float MS_PER_UPDATE = 1.0f / 60.0f;

/**
* @def PI
*/
#define PI				3.141592653589793

/**
* @def SPRITE_SHEET_COLS
* 스프라이트 시트 열 갯수
*/
#define SPRITE_SHEET_COLS	4

/**
* @def SPRITE_SHEET_COLS
* 스프라이트 시트 행 갯수
*/
#define SPRITE_SHEET_ROWS	4

/**
* @def SAFE_DELETE(p)
*/
#define SAFE_DELETE(p) {\
	if(( p )!=nullptr) { \
		delete (p); \
		( p )=nullptr; \
	} \
}

#endif