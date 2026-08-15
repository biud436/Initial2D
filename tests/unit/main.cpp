/**
 * @file main.cpp
 * @brief engine_unit_tests 진입점. 등록된 모든 TEST를 실행한다.
 */
#include "test_framework.h"

int main()
{
	std::printf("[engine_unit_tests]\n");
	return testfw::run_all();
}
