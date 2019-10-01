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

// DLL Ãâ·Â
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
#define WINDOW_NAME "test"

/**
* @def CLASS_NAME
*/
#define CLASS_NAME "test"

/**
* @def WINDOW_WIDTH
*/
const int WINDOW_WIDTH = 640;

/**
* @def WINDOW_HEIGHT
*/
const int WINDOW_HEIGHT = 480;


typedef float IFLOAT;

const IFLOAT FPS1 = 240.0f;
const IFLOAT FPS2 = 10.0f;
const IFLOAT MIN_FRAME_TIME = 1.0f / FPS1;
const IFLOAT MAX_FRAME_TIME = 1.0f / FPS2;
const IFLOAT MS_PER_UPDATE = 1.0f / 60.0f;

/**
* @def PI
*/
const IFLOAT PI = 3.141592653589793f;

// @def SPRITE_SHEET_COLS
const int SPRITE_SHEET_COLS = 4;

// @def SPRITE_SHEET_ROWS
const int SPRITE_SHEET_ROWS = 4;

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