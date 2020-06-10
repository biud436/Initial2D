#include "Window.h"
#include "App.h"


Window::Window(std::string name, int width, int height) :
	m_name(name),
	m_bDone(false),
	m_rect(0, 0, width, height),
	m_pWindow(nullptr),
	m_pRenderer(nullptr)
{
	
}


Window::~Window()
{
	// Destroy
	SDL_DestroyWindow(m_pWindow);
	SDL_DestroyRenderer(m_pRenderer);
	SDL_Quit();
}


void Window::start() 
{
	// 여기에 코드 추가
	if (SDL_Init(SDL_INIT_EVERYTHING) >= 0) {
		m_pWindow = SDL_CreateWindow("SDL Window", SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, m_rect.width, m_rect.height, SDL_WINDOW_SHOWN);

		if (m_pWindow != 0) {
			m_pRenderer = SDL_CreateRenderer(m_pWindow, -1, 0);
		}

		m_bDone = true;
	}
}

void Window::update() 
{
	// hadnle events
	SDL_Event event;
	if (SDL_PollEvent(&event)) {
		switch (event.type) {
		case SDL_QUIT:
			m_bDone = false;
		}
	}

	// Render
	SDL_SetRenderDrawColor(m_pRenderer, 0, 0, 0, 255);
	SDL_RenderClear(m_pRenderer);
	SDL_RenderPresent(m_pRenderer);
}