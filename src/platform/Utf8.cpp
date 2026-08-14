#include "Utf8.h"

#include <cstdint>

namespace Initial2D {
namespace Platform {

	namespace {
		const uint32_t REPLACEMENT = 0xFFFD;

		// UTF-8 시퀀스 하나를 디코딩한다. 반환값은 소비한 바이트 수.
		int DecodeUtf8(const unsigned char* s, size_t remain, uint32_t& out)
		{
			if (remain == 0) { out = REPLACEMENT; return 1; }
			const unsigned char c = s[0];
			if (c < 0x80) { out = c; return 1; }
			if ((c >> 5) == 0x6 && remain >= 2 && (s[1] & 0xC0) == 0x80) {
				out = ((c & 0x1F) << 6) | (s[1] & 0x3F);
				return 2;
			}
			if ((c >> 4) == 0xE && remain >= 3 && (s[1] & 0xC0) == 0x80 && (s[2] & 0xC0) == 0x80) {
				out = ((c & 0x0F) << 12) | ((s[1] & 0x3F) << 6) | (s[2] & 0x3F);
				return 3;
			}
			if ((c >> 3) == 0x1E && remain >= 4 && (s[1] & 0xC0) == 0x80 && (s[2] & 0xC0) == 0x80 && (s[3] & 0xC0) == 0x80) {
				out = ((c & 0x07) << 18) | ((s[1] & 0x3F) << 12) | ((s[2] & 0x3F) << 6) | (s[3] & 0x3F);
				return 4;
			}
			out = REPLACEMENT;
			return 1;
		}

		void EncodeUtf8(uint32_t cp, std::string& out)
		{
			if (cp < 0x80) {
				out += static_cast<char>(cp);
			} else if (cp < 0x800) {
				out += static_cast<char>(0xC0 | (cp >> 6));
				out += static_cast<char>(0x80 | (cp & 0x3F));
			} else if (cp < 0x10000) {
				out += static_cast<char>(0xE0 | (cp >> 12));
				out += static_cast<char>(0x80 | ((cp >> 6) & 0x3F));
				out += static_cast<char>(0x80 | (cp & 0x3F));
			} else {
				out += static_cast<char>(0xF0 | (cp >> 18));
				out += static_cast<char>(0x80 | ((cp >> 12) & 0x3F));
				out += static_cast<char>(0x80 | ((cp >> 6) & 0x3F));
				out += static_cast<char>(0x80 | (cp & 0x3F));
			}
		}
	}

	std::wstring Utf8ToWide(const std::string& utf8)
	{
		std::wstring result;
		result.reserve(utf8.size());

		const unsigned char* s = reinterpret_cast<const unsigned char*>(utf8.data());
		size_t i = 0;

		while (i < utf8.size()) {
			uint32_t cp = 0;
			i += DecodeUtf8(s + i, utf8.size() - i, cp);

			if (sizeof(wchar_t) == 2 && cp > 0xFFFF) {
				// UTF-16 서로게이트 쌍 (Windows)
				cp -= 0x10000;
				result += static_cast<wchar_t>(0xD800 | (cp >> 10));
				result += static_cast<wchar_t>(0xDC00 | (cp & 0x3FF));
			} else {
				result += static_cast<wchar_t>(cp);
			}
		}

		return result;
	}

	std::string WideToUtf8(const std::wstring& wide)
	{
		std::string result;
		result.reserve(wide.size() * 3);

		for (size_t i = 0; i < wide.size(); ++i) {
			uint32_t cp = static_cast<uint32_t>(wide[i]);

			// UTF-16 서로게이트 쌍 결합 (Windows)
			if (sizeof(wchar_t) == 2 && cp >= 0xD800 && cp <= 0xDBFF && i + 1 < wide.size()) {
				const uint32_t low = static_cast<uint32_t>(wide[i + 1]);
				if (low >= 0xDC00 && low <= 0xDFFF) {
					cp = 0x10000 + ((cp - 0xD800) << 10) + (low - 0xDC00);
					++i;
				}
			}

			EncodeUtf8(cp, result);
		}

		return result;
	}

	std::string NormalizePath(std::string path)
	{
		for (char& c : path) {
			if (c == '\\') {
				c = '/';
			}
		}
		return path;
	}

} // namespace Platform
} // namespace Initial2D
