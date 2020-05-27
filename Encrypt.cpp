#include "Encrypt.h"

namespace Initial2D {

	/**
	* @author ������
	* @brief Ư�� ������ �ִ� ��� ������ ��ȯ�մϴ�.
	*/
	void ReadDirectory(std::vector<std::string>& dirs, std::string parent)
	{
		WIN32_FIND_DATA findData;
		HANDLE hFind = FindFirstFile(parent.data(), &findData);

		// �θ� ������ ��ȯ�մϴ�.
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

				// ����� Ž��
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