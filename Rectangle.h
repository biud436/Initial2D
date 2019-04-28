/**
 * @file Rectangle.h
 * @date 2018/03/26 11:40
 *
 * @author biud436
 * Contact: biud436@gmail.com
 *
 * @brief 
 *
 *
 * @note
*/

#ifndef RECTANGLE_H
#define RECTANGLE_H
namespace RS {

	/**
	* @class Rectangle
	*/
	class Rectangle
	{

	public:

		Rectangle::Rectangle(int _x = 0, int _y = 0, int _width = 0, int _height = 0) :
			x(_x), 
			y(_y),
			width(_width),
			height(_height)
		{

		}

		virtual Rectangle::~Rectangle()
		{
		}


		Rectangle& operator=(const Rectangle& ref)
		{
			x = ref.x;
			y = ref.y;
			width = ref.width;
			height = ref.height;
		}

		Rectangle operator+(const Rectangle& v) const
		{
			return Rectangle(x + v.x, y + v.y, width + v.width, height + v.height);
		}

		friend Rectangle& operator+=(Rectangle& v1, const Rectangle& v2)
		{
			v1.x += v2.x;
			v1.y += v2.y;
			v1.width += v2.width;
			v1.height += v2.height;

			return v1;
		}

		// v3 = v1 - v2;
		Rectangle operator-(const Rectangle& v) const
		{
			return Rectangle(x - v.x, y - v.y, width - v.width, height - v.height);
		}

		// v1 -= v2;
		friend Rectangle& operator-=(Rectangle& v1, const Rectangle& v2)
		{
			v1.x -= v2.x;
			v1.y -= v2.y;
			v1.width -= v2.width;
			v1.height -= v2.height;

			return v1;
		}

		// v3 = v1 * v2;
		Rectangle operator*(float n)
		{
			return Rectangle(x * n, y * n, width * n, height * n);
		}

		// v1 *= n;
		Rectangle&  operator*=(float n)
		{
			x *= n;
			y *= n;
			width *= n;
			height *= n;

			return *this;
		}

		Rectangle operator/(float n)
		{
			return Rectangle(x / n, y / n, width / n, height / n);
		}

		Rectangle& operator/=(float n)
		{
			x /= n;
			y /= n;
			width /= n;
			height /= n;

			return *this;
		}

	public:
		int x, y, width, height;
	};

}
#endif