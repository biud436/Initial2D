/**
 * @file ExceptionText.h
 * @brief 처리 중인 C++ 예외를 "타입: 메시지" 한 줄로 적는다.
 * @details 브라우저 로더의 errorText()(Emscripten 의 getExceptionMessage)와 같은 형식이다.
 *          타입은 디맹글한 이름이고, std::exception 이 아니면 메시지 없이 타입만 적는다.
 *          mruby 바인딩의 경계(mrb_prot.h), 스크립트 재시작(ScriptRuntime.cpp), 브라우저의
 *          fatal 줄(WebMain.cpp)이 쓴다. 헤더 인라인이라 Windows 프로젝트 파일에 더할 소스가 없다.
 */
#pragma once

#include <cstddef>
#include <cstdio>
#include <cstdlib>
#include <exception>
#include <string>
#include <typeinfo>

#if defined(__GNUC__) || defined(__clang__)
#include <cxxabi.h>
#endif

namespace Initial2D {

	/** 맹글된 타입 이름을 사람이 읽는 이름으로. 풀 수 없으면 그대로 돌려준다. */
	inline std::string DemangleTypeName(const char* mangled)
	{
#if defined(__GNUC__) || defined(__clang__)
		int status = 0;
		char* name = abi::__cxa_demangle(mangled, nullptr, nullptr, &status);
		if (status == 0 && name != nullptr)
		{
			std::string result(name);
			std::free(name);
			return result;
		}
#endif
		return mangled;
	}

	/**
	 * catch 블록 안에서 부른다. 처리 중인 예외를 out 에 "타입: 메시지" 로 적는다
	 * (메시지가 없으면 타입만, 타입을 모르면 "C++ exception"). 길면 자른다.
	 */
	inline void DescribeCurrentException(char* out, std::size_t size)
	{
		std::string type = "C++ exception";
		std::string message;
		try
		{
			throw;
		}
		catch (const std::exception& e)
		{
			type = DemangleTypeName(typeid(e).name());
			message = e.what();
		}
		catch (...)
		{
#if defined(__GNUC__) || defined(__clang__)
			const std::type_info* current = abi::__cxa_current_exception_type();
			if (current != nullptr)
			{
				type = DemangleTypeName(current->name());
			}
#endif
		}
		if (message.empty())
		{
			std::snprintf(out, size, "%s", type.c_str());
		}
		else
		{
			std::snprintf(out, size, "%s: %s", type.c_str(), message.c_str());
		}
	}

	/** DescribeCurrentException 의 std::string 판. catch 블록 안에서 부른다. */
	inline std::string CurrentExceptionText()
	{
		char text[1024];
		DescribeCurrentException(text, sizeof(text));
		return text;
	}

} // namespace Initial2D
