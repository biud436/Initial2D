/**
 * @file utf8_test.cpp
 * @brief Initial2D::Platform의 UTF-8 변환과 경로 정규화 검증.
 *
 * 이 함수들은 Lua 문자열이 폰트 렌더링과 파일 경로에 도달하는 관문이라
 * 한글 처리 전체의 기반이다 (docs/plans/09-testing.md 7절, 1단계 매핑).
 */
#include "test_framework.h"

#include "platform/Utf8.h"

using Initial2D::Platform::NormalizePath;
using Initial2D::Platform::Utf8ToWide;
using Initial2D::Platform::WideToUtf8;

TEST(utf8_ascii_roundtrip)
{
	const std::string src = "hello, world";
	CHECK_EQ(WideToUtf8(Utf8ToWide(src)), src);
}

TEST(utf8_hangul_roundtrip)
{
	const std::string src = "안녕하세요, Initial2D!";
	CHECK_EQ(WideToUtf8(Utf8ToWide(src)), src);
}

TEST(utf8_hangul_codepoints)
{
	// '가' = U+AC00 (한글 음절 첫 글자)
	const std::wstring ga = Utf8ToWide("가");
	CHECK_EQ(ga.size(), static_cast<size_t>(1));
	CHECK_EQ(static_cast<unsigned long>(ga[0]), 0xAC00UL);

	// '힣' = U+D7A3 (한글 음절 마지막 글자) — 폰트 배열 경계의 근거 값
	const std::wstring hih = Utf8ToWide("힣");
	CHECK_EQ(hih.size(), static_cast<size_t>(1));
	CHECK_EQ(static_cast<unsigned long>(hih[0]), 0xD7A3UL);
}

TEST(utf8_invalid_sequence_replaced)
{
	// 잘못된 바이트는 U+FFFD로 대체된다는 계약 (Utf8.h 주석)
	const std::wstring wide = Utf8ToWide(std::string("a\xFF") + "b");
	bool hasReplacement = false;
	for (wchar_t c : wide) {
		if (static_cast<unsigned long>(c) == 0xFFFDUL)
			hasReplacement = true;
	}
	CHECK(hasReplacement);
	CHECK_EQ(wide.size(), static_cast<size_t>(3));
}

TEST(normalize_path_backslashes)
{
	CHECK_EQ(NormalizePath(".\\resources\\maps\\map1.json"), "./resources/maps/map1.json");
}

TEST(normalize_path_forward_slashes_unchanged)
{
	CHECK_EQ(NormalizePath("resources/tiles/tile1.png"), "resources/tiles/tile1.png");
}

TEST(normalize_path_mixed)
{
	CHECK_EQ(NormalizePath("resources\\tiles/tile1.png"), "resources/tiles/tile1.png");
}
