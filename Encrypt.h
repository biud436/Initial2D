#pragma once
#ifndef _ENCRYPT_H_
#define _ENCRYPT_H_

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
	void ReadDirectory(std::vector<std::string>& dirs, std::string parent = ".\\res\\")
	{
		WIN32_FIND_DATA findData;
		HANDLE hFind = FindFirstFile(parent.data(), &findData);

		// 부모 폴더를 반환합니다.
		std::string root = GetParentDirectory(parent.c_str());

		while (FindNextFile(hFind, &findData) != 0)
		{
			if (findData.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) 
			{
				std::string filename = findData.cFileName;

				if (filename == "..") 
				{
					continue;
				}
				
				std::string subDirectories = root;
				subDirectories += filename;
				subDirectories += "\\*.*";

				// 디버깅 용 출력
				//LOG_D(subDirectories);
				
				// 재귀적 탐색
				ReadDirectory(dirs, subDirectories);
			}
			else {
				std::string filename = root;
				filename += findData.cFileName;

				// 디버깅 용 출력
				//LOG_D(filename);

				dirs.push_back(filename);
			}
		}

		FindClose(hFind);
	}

}
#endif