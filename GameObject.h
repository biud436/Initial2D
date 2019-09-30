#ifndef __GAMEOBJECT_H__
#define __GAMEOBJECT_H__

class GameObject
{
public:
	GameObject() {}
	virtual ~GameObject() {}

	virtual void	update(float elapsed) {};
	virtual void	draw(void) {};
};

#endif