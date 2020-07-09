#ifndef __MATRIX_H_
#define __MATRIX_H_

#include "Constants.h"

#ifdef RS_WINDOWS
#include <Windows.h>
using TransformData = XFORM;
#else
typedef sturct _TRANSFORM_DATA
{
	float eM11;
	float eM12;
	float eM21;
	float eM22;
	float eDx;
	float eDy;
} TransformData;
#endif

class Matrix
{
public:
	Matrix();
	virtual ~Matrix();

	Matrix(float mD11, float mD12, float mD21, float mD22, float mDX, float mDY);

	const Matrix& setScale(float scale);
	const Matrix& rotate(float radian);
	const Matrix& translate(float x, float y);

	/// <summary>
	/// if the type of main renderer is a type for Win32 GDI, 
	/// it allows this method to create a transform data for Windows GDI.
	/// </summary>
	/// <returns></returns>
	TransformData toTransformData();

	/**
	 * @biref
	 * Calls this method if you need to update a matrix.
	 */ 
	void update();

private:
	float m_f11;
	float m_f12;
	float m_f21;
	float m_f22;
	float m_fX;
	float m_fY;

	float m_fRotation;
	float m_fScale;
};

#endif

