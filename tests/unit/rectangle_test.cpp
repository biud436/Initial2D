/**
 * @file rectangle_test.cpp
 * @brief Rectangle 대입 연산자 검증.
 * operator=에 return 문이 없어 미정의 동작이던 버그의 회귀 테스트
 * (docs/porting/phase0-inventory.md에 기록되어 있던 문제).
 */
#include "test_framework.h"

#include "Rectangle.h"

TEST(rectangle_assignment)
{
	RS::Rectangle a(1, 2, 3, 4);
	RS::Rectangle b;
	b = a;
	CHECK_EQ(b.x, 1);
	CHECK_EQ(b.y, 2);
	CHECK_EQ(b.width, 3);
	CHECK_EQ(b.height, 4);
}

TEST(rectangle_chained_assignment)
{
	// return *this가 없으면 연쇄 대입이 미정의 동작이 된다
	RS::Rectangle a(5, 6, 7, 8);
	RS::Rectangle b, c;
	c = b = a;
	CHECK_EQ(c.x, 5);
	CHECK_EQ(c.height, 8);
}
