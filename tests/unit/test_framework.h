/**
 * @file test_framework.h
 * @brief 외부 의존 없는 최소 단위 테스트 프레임워크 (검수 인프라, docs/plans/09-testing.md 3.1절).
 *
 * 사용법:
 *   TEST(설명적인_이름) {
 *       CHECK(조건);
 *       CHECK_EQ(값, 기대값);
 *   }
 * 테스트 파일을 tests/unit/ 에 추가하면 CMake GLOB이 자동으로 집어간다.
 * main.cpp의 testfw::run_all()이 전부 실행하고 실패 개수를 exit code로 돌려준다.
 */
#ifndef INITIAL2D_TEST_FRAMEWORK_H
#define INITIAL2D_TEST_FRAMEWORK_H

#include <cstdio>
#include <functional>
#include <sstream>
#include <string>
#include <vector>

namespace testfw {

struct Case {
	const char* name;
	std::function<void()> fn;
};

inline std::vector<Case>& cases()
{
	static std::vector<Case> c;
	return c;
}

inline int& failures()
{
	static int f = 0;
	return f;
}

inline const char*& current()
{
	static const char* n = "";
	return n;
}

struct Register {
	Register(const char* name, std::function<void()> fn) { cases().push_back({ name, fn }); }
};

inline void fail(const char* file, int line, const std::string& msg)
{
	++failures();
	std::printf("  FAIL  %s  (%s:%d)\n        %s\n", current(), file, line, msg.c_str());
}

/** 실패 메시지에 실제 값을 담기 위한 표시 변환. wstring은 코드포인트 나열로 보여준다. */
inline std::string display(const std::string& v) { return "\"" + v + "\""; }
inline std::string display(const char* v) { return display(std::string(v)); }
inline std::string display(const std::wstring& v)
{
	std::ostringstream out;
	out << "wstring{";
	for (wchar_t c : v)
		out << "U+" << std::hex << std::uppercase << static_cast<unsigned long>(c) << " ";
	out << "}";
	return out.str();
}
template <typename T>
inline std::string display(const T& v)
{
	std::ostringstream out;
	out << v;
	return out.str();
}

template <typename A, typename B>
inline void check_eq(const char* file, int line, const char* exprA, const A& a, const B& b)
{
	if (!(a == b)) {
		fail(file, line, std::string(exprA) + " == " + display(a) + ", 기대값 " + display(b));
	}
}

inline int run_all()
{
	int passed = 0;
	for (auto& c : cases()) {
		current() = c.name;
		const int before = failures();
		c.fn();
		if (failures() == before) {
			std::printf("  PASS  %s\n", c.name);
			++passed;
		}
	}
	std::printf("\n결과: %d PASS / %d FAIL\n", passed, failures());
	return failures() ? 1 : 0;
}

} // namespace testfw

#define TEST(name)                                             \
	static void test_##name();                                 \
	static testfw::Register reg_##name(#name, test_##name);    \
	static void test_##name()

#define CHECK(cond)                                                     \
	do {                                                                \
		if (!(cond))                                                    \
			testfw::fail(__FILE__, __LINE__, #cond);                    \
	} while (0)

#define CHECK_EQ(a, b) testfw::check_eq(__FILE__, __LINE__, #a, (a), (b))

#endif
