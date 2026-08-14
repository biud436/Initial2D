#include "Encrypt.h"

#ifdef _WIN32

#define WIN32_LEAN_AND_MEAN
#include <Windows.h>

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

#else // 비-Windows: std::filesystem 기반 구현 (동작 동일 — 하위 디렉터리 재귀 탐색)

#include <filesystem>
#include "platform/Utf8.h"

namespace Initial2D {

	void ReadDirectory(std::vector<std::string>& dirs, std::string parent)
	{
		// Win32 호출 규약의 ".\\res\\*.*" 형태 패턴에서 디렉터리 부분만 취한다.
		std::string root = Platform::NormalizePath(parent);
		const std::size_t wildcard = root.find('*');
		if (wildcard != std::string::npos) {
			root = root.substr(0, wildcard);
		}
		if (root.empty()) {
			root = ".";
		}

		std::error_code ec;
		for (std::filesystem::recursive_directory_iterator it(root, ec), end; it != end && !ec; it.increment(ec)) {
			if (it->is_regular_file(ec)) {
				dirs.push_back(it->path().string());
			}
		}
	}

}

#endif // _WIN32