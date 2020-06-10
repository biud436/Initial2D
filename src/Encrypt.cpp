#include "Encrypt.h"

namespace Initial2D {

	/**
	* @author 어진석
	* @brief 특정 폴더에 있는 모든 파일을 반환합니다.
	*/
	void ReadDirectory(std::vector<std::string>& dirs, std::string parent)
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

				// 재귀적 탐색
				ReadDirectory(dirs, subDirectories);
			}
			else {
				std::string filename = root;
				filename += findData.cFileName;

				dirs.push_back(filename);
			}
		}

		FindClose(hFind);
	}

}