/**
 * @file Point.h
 * @date 2018/03/26 11:36
 *
 * @author biud436
 * Contact: biud436@gmail.com
 *
 * @brief 
 *
 *
 * @note
*/

//! @cond DO_NOT_INCLUDE
#ifndef POINT_H
#define POINT_H
//! @endcode

/**
*	@class Point
*	@author biud436
*	@brief 
*/
class Point
{
public:

	virtual ~Point()
	{
	}

	Point(int _x = 0, int _y = 0) : x(_x), y(_y)
	{
	}

	Point& operator=(const Point& ref)
	{
		x = ref.x;
		y = ref.y;
	}

	Point operator+(const Point& v) const
	{
		return Point(x + v.x, y + v.y);
	}

	friend Point& operator+=(Point& v1, const Point& v2)
	{
		v1.x += v2.x;
		v1.y += v2.y;

		return v1;
	}

	// v3 = v1 - v2;
	Point operator-(const Point& v) const
	{
		return Point(x - v.x, y - v.y);
	}

	// v1 -= v2;
	friend Point& operator-=(Point& v1, const Point& v2)
	{
		v1.x -= v2.x;
		v1.y -= v2.y;

		return v1;
	}

	// v3 = v1 * v2;
	Point operator*(float n)
	{
		return Point(x * n, y * n);
	}

	// v1 *= n;
	Point&  operator*=(float n)
	{
		x *= n;
		y *= n;

		return *this;
	}

	Point operator/(float n)
	{
		return Point(x / n, y / n);
	}

	Point& operator/=(float n)
	{
		x /= n;
		y /= n;

		return *this;
	}
public:
	int x, y;
};


//! @cond DO_NOT_INCLUDE
#endif
//! @endcond