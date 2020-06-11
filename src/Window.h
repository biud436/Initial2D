#ifndef __WINDOW_H_
#define __WINDOW_H_

#define WIN32_LEAN_AND_MEAN

#include <SDL.h>
#include <string>
#include <memory>
#include "Rectangle.h"

/**
 * @brief 새로운 창을 만드는 클래스
 */
class Window
{
public:
	Window(std::string name, int width, int height);
	virtual ~Window();

	void start();

	void update();

	bool isDone() const { return _isDone; }

	void destroy();

	bool isRemoved() const { return _isRemoved; }

private:
	std::string m_name;
	bool _isDone;
	bool _isRemoved;

	SDL_Window* m_pWindow;
	SDL_Renderer* m_pRenderer;
	SDL_Texture* m_pTexture;

	RS::Rectangle m_rect;
};

#endif