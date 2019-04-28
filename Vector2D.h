/**
 * @file Vector2D.h
 * @date 2018/03/26 11:48
 *
 * @author biud436
 * Contact: biud436@gmail.com
 *
 * @brief 
 *
 *
 * @note
*/

#ifndef VECTOR2D_H
#define VECTOR2D_H

#include <math.h>

/**
*	@class Vector2D
*	@brief 2D 게임을 위한 2D 벡터 객체
*/
class Vector2D
{
public:

	/**
	 * Vector2D의 생성자
	 */
	Vector2D(float sx, float sy) :
		m_fX(sx),
		m_fY(sy),
		x(m_fX),
		y(m_fY)
	{
	
	};

	/**
	* Vector2D의 생성자
	*/
	Vector2D() :
		m_fX(0.0f),
		m_fY(0.0f),
		x(m_fX),
		y(m_fY)
	{

	};

	/**
	* Vector2D의 소멸자
	*/
	virtual ~Vector2D()
	{

	};

	/**
	* X 값을 반환합니다.
	* @return float
	*/
	float getX()
	{
		return m_fX;
	};


	/**
	* Y 값을 반환합니다.
	* @return float
	*/
	float getY()
	{
		return m_fY;
	};


	/**
	* X 값을 설정합니다.
	* @param  x
	* @return void
	*/
	void setX(float x)
	{
		m_fX = x;
	}

	/**
	* Y 값을 설정합니다.
	* @param  y
	* @return void
	*/
	void setY(float y)
	{
		m_fY = y;
	}


	/**
	* 벡터의 길이를 반환합니다.
	* @return float
	*/
	float getLength()
	{
		return sqrtf(m_fX * m_fX + m_fY * m_fY);
	}


	/**
	* 벡터를 정규화합니다.
	* @return void
	*/
	void normalize()
	{
		float len = getLength();
		if (len > 0)
		{
			// (*this) *= 1 / len;
			m_fX = m_fX / len;
			m_fY = m_fY / len;
		}
	}

	/*
	* 덧셈 연산을 수행합니다.
	* v3 = v1 + v2;
	*/
	Vector2D operator+(const Vector2D& v) const
	{
		return Vector2D(m_fX + v.m_fX, m_fY + v.m_fY);
	}

	/**
	* 덧셈 연산 및 대입을 수행합니다.
	* v1 += v2;
	*/
	friend Vector2D& operator+=(Vector2D& v1, const Vector2D& v2)
	{
		v1.m_fX += v2.m_fX;
		v1.m_fY += v2.m_fY;

		return v1;
	}

	/**
	* 감산 연산을 수행합니다.
	* v3 = v1 - v2;
	*/
	Vector2D operator-(const Vector2D& v) const
	{
		return Vector2D(m_fX - v.m_fX, m_fY - v.m_fY);
	}

	/**  
	* 감산 연산 및 대입 연산자를 수행합니다.
	* v1 -= v2;
	*/
	friend Vector2D& operator-=(Vector2D& v1, const Vector2D& v2)
	{
		v1.m_fX -= v2.m_fX;
		v1.m_fY -= v2.m_fY;

		return v1;
	}

	/**  
	* 곱셈 연산을 수행합니다.
	* v3 = v1 * v2;
	*/
	Vector2D operator*(float n)
	{
		return Vector2D(m_fX * n, m_fY * n);
	}

	/**  
	* 곱셈 연산 및 대입 연산을 수행합니다.
	* v1 *= n;
	*/
	Vector2D&  operator*=(float n)
	{
		m_fX *= n;
		m_fY *= n;

		return *this;
	}


	/**
	* 나눗셈 연산을 수행합니다.
	* v3 = v1 / v2;
	*/
	Vector2D operator/(float n)
	{
		return Vector2D(m_fX / n, m_fY / n);
	}

	/**
	* 나눗셈 연산 및 대입 연산을 수행합니다.
	* v1 /= n;
	*/
	Vector2D& operator/=(float n)
	{
		m_fX /= n;
		m_fY /= n;

		return *this;
	}

	float m_fX;
	float m_fY;

	/**
	 * @property x
	 */
	float x;

	/**
	* @property y
	*/
	float y;

private:
	Vector2D(const Vector2D&);

};

#endif