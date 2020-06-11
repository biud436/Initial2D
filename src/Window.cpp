#include "Window.h"
#include "App.h"
#include <SDL_image.h>

Window::Window(std::string name, int width, int height) :
	m_name(name),
	_isDone(false),
	m_rect(0, 0, width, height),
	m_pWindow(nullptr),
	m_pRenderer(nullptr),
	m_pTexture(nullptr),
	_isRemoved(false)
{
	
}

Window::~Window()
{

}

void Window::destroy()
{
	SDL_DestroyTexture(m_pTexture);
	SDL_DestroyWindow(m_pWindow);
	SDL_DestroyRenderer(m_pRenderer);
	SDL_Quit();
	
	_isRemoved = true;
}


void Window::start() 
{
	// 여기에 코드 추가
	if (SDL_Init(SDL_INIT_EVERYTHING) >= 0) {

		m_pWindow = SDL_CreateWindow("SDL Window", SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, m_rect.width, m_rect.height, SDL_WINDOW_SHOWN);

		if (m_pWindow != 0) {
			m_pRenderer = SDL_CreateRenderer(m_pWindow, -1, 0);
		}

		SDL_Surface* pTempSurface = IMG_Load("resources/titles/title.png");

		if (pTempSurface == 0) {
			throw new std::exception("image error");
		}

		m_pTexture = SDL_CreateTextureFromSurface(m_pRenderer, pTempSurface);
		SDL_FreeSurface(pTempSurface);

		_isDone = true;
	}
}

void Window::update() 
{
	if (!_isDone) {
		return;
	}

	// hadnle events
	SDL_Event event;
	if (SDL_PollEvent(&event)) {
		switch (event.type) {
		case SDL_QUIT:
			_isDone = false;
			break;
		case SDL_KEYUP:
			if (event.key.keysym.sym == SDLK_ESCAPE)
			{
				exit(1);
			}
			break;
		}

	}

	// Render
	SDL_Rect srcRect;
	SDL_Rect destRect;

	srcRect.x = 0;
	srcRect.y = 0;
	srcRect.w = destRect.w = 640;
	srcRect.h = destRect.h = 480;

	SDL_RenderClear(m_pRenderer);

	SDL_RenderCopyEx(m_pRenderer, m_pTexture, &srcRect, &destRect, 0, 0, SDL_FLIP_NONE);
	SDL_RenderPresent(m_pRenderer);
}