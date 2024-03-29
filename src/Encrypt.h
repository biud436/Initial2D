#pragma once
#ifndef _ENCRYPT_H_
#define _ENCRYPT_H_

#define WIN32_LEAN_AND_MEAN

#include <iostream>
#include <fstream>
#include <cstdio>
#include <cstring>
#include <Windows.h>
#include <vector>
#include "StringUtils.h"
#include "App.h"

/**
 * @file Encrypt.h
 * @brief 리소스 파일을 하나의 패키지 파일로 만드는 기능을 제공합니다.
 */

namespace Initial2D {

	typedef struct _RES_FILE_HEADER {
		union {
			unsigned int magic;
			char magic_name[4];
		};
		unsigned int size;
		unsigned int count;
	} RES_FILE_HEADER;

	typedef struct _RES_CHUNK_HEADER {
		union {
			unsigned int chunk_type;
			char chunk_name[4];
		};
		unsigned int size;
	} RES_CHUNK_HEADER;

	typedef struct _RES_DATA {
		RES_CHUNK_HEADER header;

		char path[256];
		unsigned int type;
		unsigned int size;
		unsigned int offset;
	} RES_HEADER;

	/**
	* @author 어진석
	* @brief 특정 폴더에 있는 모든 파일을 반환합니다.
	*/
	void ReadDirectory(std::vector<std::string>& dirs, std::string parent = ".\\res\\");

}
#endif