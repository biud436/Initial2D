#include "Matrix.h"
#include <math.h>

Matrix::Matrix() :
	m_f11(1.0f),
	m_f12(0.0f),
	m_f21(0.0f),
	m_f22(1.0f),
	m_fX(0.0f),
	m_fY(0.0f),
	m_fRotation(0.0f),
	m_fScale(1.0f)
{
	
}

Matrix::Matrix(float mD11, float mD12, float mD21, float mD22, float mDX, float mDY) :
	m_f11(mD11),
	m_f12(mD12),
	m_f21(mD21),
	m_f22(mD22),
	m_fX(mDX),
	m_fY(mDY),
	m_fRotation(0.0f),
	m_fScale(1.0f)
{

}

const Matrix& Matrix::setScale(float scale)
{
	m_fScale = scale;
	return *this;
}

const Matrix& Matrix::rotate(float radian)
{
	m_fRotation = radian;
	return *this;
}

const Matrix& Matrix::translate(float x, float y)
{
	m_fX = x;
	m_fY = y;
	return *this;
}

void Matrix::update() 
{
	m_f11 = cos(m_fRotation) * m_fScale;
	m_f12 = sin(m_fRotation) * m_fScale;
	m_f21 = -sin(m_fRotation) * m_fScale;
	m_f22 = cos(m_fRotation) * m_fScale;
}

TransformData Matrix::toTransformData()
{
	// 스택에 지역 변수를 할당합니다.
	TransformData tx = 
	{
		m_f11, m_f12, 
		m_f21, m_f22,
		m_fX, m_fY
	};
	
	// 스택 프레임이 반환될 때 반환 값이 레지스터 등에 복사됩니다 (복사 비용 발생)
	return tx;
}