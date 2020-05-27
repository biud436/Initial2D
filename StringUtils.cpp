#include "StringUtils.h"

std::string ConvertWideCharToMultiByte(std::wstring& wstr, UINT codePage)
{
	int size = WideCharToMultiByte(codePage, 0, wstr.data(), wstr.size(), NULL, 0, NULL, NULL);
	if (size == 0) {
		return std::string("");
	}

	std::string raw;
	raw.resize(size);

	WideCharToMultiByte(codePage, 0, wstr.data(), wstr.size(), &raw[0], size, NULL, NULL);

	return raw;
}

std::wstring ConvertMultiByteToWideChar(std::string& str, UINT codePage)
{
	int size = MultiByteToWideChar(codePage, 0, str.data(), str.size(), NULL, 0);
	if (size == 0) {
		return std::wstring();
	}

	std::wstring wstr;
	wstr.resize(size);

	MultiByteToWideChar(codePage, 0, str.data(), str.size(), &wstr[0], size);

	return wstr;
}

std::vector<std::string> StrSplit(std::string data, std::string find_at)
{
	std::vector<std::string> ret;
	size_t i = 0;
	size_t at = 0;

	while ((i = data.find(find_at, at)) != std::string::npos) {
		size_t len = find_at.size();
		ret.push_back(data.substr(i, len));
		at = i + len;
	}

	return ret;
}


std::string GetParentDirectory(const char* path)
{
	const char *pos = path;

	int len = strlen(path);

	if (len == 0) {
		return ".";
	}

	while (*pos != '\0') {
		pos++;
	}

	while (*pos != '\\') {
		pos--;
	}

	pos++;

	int subtract_len = strlen(pos);
	
	// c에선 동적 할당 필요, std::string은 필요 없음.
	std::string ret = path;
	ret.resize(len - subtract_len);

	return ret;
}

std::string GetFileName(const char* path)
{
	const char *pos = path;
	int len = strlen(pos);

	while (*pos != '\0') {
		pos++;
	}

	while (*pos != '\\') {
		pos--;
	}

	pos++;

	std::string ret = pos;

	return ret;

}

/**
 * 파일 확장자를 반환합니다.
 * std::string filename = GetFileExtension(".\\res\\mycomputer.png");
 * => .png
 */
std::string GetFileExtension(const char* path)
{
	const char *pos = path;
	int len = strlen(pos);

	while (*pos != '\0') {
		pos++;
	}

	while (*pos != '.') {
		pos--;
	}

	std::string ret = pos;

	return ret;
}