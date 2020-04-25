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