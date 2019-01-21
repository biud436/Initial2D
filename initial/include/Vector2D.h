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
*	@brief 2D ������ ���� 2D ���� ��ü
*/
class Vector2D
{
public:

	/**
	 * Vector2D�� ������
	 */
	Vector2D(float sx, float sy) :
		m_fX(sx),
		m_fY(sy),
		x(m_fX),
		y(m_fY)
	{
	
	};

	/**
	* Vector2D�� ������
	*/
	Vector2D() :
		m_fX(0.0f),
		m_fY(0.0f),
		x(m_fX),
		y(m_fY)
	{

	};

	/**
	* Vector2D�� �Ҹ���
	*/
	virtual ~Vector2D()
	{

	};

	/**
	* X ���� ��ȯ�մϴ�.
	* @return float
	*/
	float getX()
	{
		return m_fX;
	};


	/**
	* Y ���� ��ȯ�մϴ�.
	* @return float
	*/
	float getY()
	{
		return m_fY;
	};


	/**
	* X ���� �����մϴ�.
	* @param  x
	* @return void
	*/
	void setX(float x)
	{
		m_fX = x;
	}

	/**
	* Y ���� �����մϴ�.
	* @param  y
	* @return void
	*/
	void setY(float y)
	{
		m_fY = y;
	}


	/**
	* ������ ���̸� ��ȯ�մϴ�.
	* @return float
	*/
	float getLength()
	{
		return sqrtf(m_fX * m_fX + m_fY * m_fY);
	}


	/**
	* ���͸� ����ȭ�մϴ�.
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
	* ���� ������ �����մϴ�.
	* v3 = v1 + v2;
	*/
	Vector2D operator+(const Vector2D& v) const
	{
		return Vector2D(m_fX + v.m_fX, m_fY + v.m_fY);
	}

	/**
	* ���� ���� �� ������ �����մϴ�.
	* v1 += v2;
	*/
	friend Vector2D& operator+=(Vector2D& v1, const Vector2D& v2)
	{
		v1.m_fX += v2.m_fX;
		v1.m_fY += v2.m_fY;

		return v1;
	}

	/**
	* ���� ������ �����մϴ�.
	* v3 = v1 - v2;
	*/
	Vector2D operator-(const Vector2D& v) const
	{
		return Vector2D(m_fX - v.m_fX, m_fY - v.m_fY);
	}

	/**  
	* ���� ���� �� ���� �����ڸ� �����մϴ�.
	* v1 -= v2;
	*/
	friend Vector2D& operator-=(Vector2D& v1, const Vector2D& v2)
	{
		v1.m_fX -= v2.m_fX;
		v1.m_fY -= v2.m_fY;

		return v1;
	}

	/**  
	* ���� ������ �����մϴ�.
	* v3 = v1 * v2;
	*/
	Vector2D operator*(float n)
	{
		return Vector2D(m_fX * n, m_fY * n);
	}

	/**  
	* ���� ���� �� ���� ������ �����մϴ�.
	* v1 *= n;
	*/
	Vector2D&  operator*=(float n)
	{
		m_fX *= n;
		m_fY *= n;

		return *this;
	}


	/**
	* ������ ������ �����մϴ�.
	* v3 = v1 / v2;
	*/
	Vector2D operator/(float n)
	{
		return Vector2D(m_fX / n, m_fY / n);
	}

	/**
	* ������ ���� �� ���� ������ �����մϴ�.
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