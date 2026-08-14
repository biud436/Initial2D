/**
 * @file AppSDL2.cpp
 * @brief App의 SDL2 어댑터 구현 (비-Windows).
 * @details Win32/GDI 구현(App.cpp의 RS_WINDOWS 분기)과 동일한 구조의
 *          게임 루프를 SDL2로 제공한다. 메서드 대응은 다음과 같다:
 *          - Run:            CreateWindow/PeekMessage 루프 → SDL_CreateWindow/SDL_PollEvent 루프
 *          - HandleEvent:    WndProc 메시지 → SDL_Event
 *          - RenderClear:    CreateCompatibleDC 백버퍼 → SDL_RenderClear
 *          - RenderTransform: SetMapMode(MM_ANISOTROPIC) → SDL_RenderSetLogicalSize
 *          - RenderPresent:  BitBlt → SDL_RenderPresent
 *          - Quit:           PostQuitMessage → SDL_QUIT 이벤트 푸시
 *          - SetAppIcon:     CreateIconIndirect → SDL_SetWindowIcon
 */
#include "Constants.h"

#ifndef RS_WINDOWS

#include "App.h"
#include "Input.h"
#include "TextureManager.h"

#include <SDL.h>
#include <SDL_image.h>

#include <chrono>
#include <sstream>
#include <cstdio>

#include "../Utf8.h"

int App::Run(int nCmdShow)
{
	(void)nCmdShow;

	if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO | SDL_INIT_TIMER | SDL_INIT_EVENTS) != 0) {
		std::fprintf(stderr, "SDL_Init failed: %s\n", SDL_GetError());
		return -1;
	}

	m_context.window = SDL_CreateWindow(
		GetWindowName(),
		SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED,
		GetWindowWidth(), GetWindowHeight(),
		SDL_WINDOW_SHOWN | SDL_WINDOW_ALLOW_HIGHDPI);

	if (m_context.window == nullptr) {
		std::fprintf(stderr, "SDL_CreateWindow failed: %s\n", SDL_GetError());
		SDL_Quit();
		return -1;
	}

	// PRESENTVSYNC: 디스플레이 주사율에 맞춰 Present를 블로킹시켜 프레임 간격을 고정한다.
	// 이것이 없으면 루프가 0ms/13ms 사이를 널뛰며(실측 표준편차 7.9ms) 고정 16ms 스텝
	// 업데이트와 어긋나 틱이 0~2회씩 몰리는 저더가 발생한다.
	m_context.renderer = SDL_CreateRenderer(m_context.window, -1,
		SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC);
	if (m_context.renderer == nullptr) {
		m_context.renderer = SDL_CreateRenderer(m_context.window, -1, SDL_RENDERER_ACCELERATED);
	}

	if (m_context.renderer == nullptr) {
		std::fprintf(stderr, "SDL_CreateRenderer failed: %s\n", SDL_GetError());
		SDL_DestroyWindow(m_context.window);
		SDL_Quit();
		return -1;
	}

	SDL_RenderSetLogicalSize(m_context.renderer, GetWindowWidth(), GetWindowHeight());

	// macOS 컴포지터의 첫 Present 지연(수백 ms)을 게임 루프 밖에서 흡수한다.
	// 이 지연이 루프 안에서 발생하면 첫 프레임 elapsed가 튀어 게임 오브젝트가 순간이동한다.
	for (int i = 0; i < 3; ++i) {
		SDL_SetRenderDrawColor(m_context.renderer, 255, 255, 255, 255);
		SDL_RenderClear(m_context.renderer);
		SDL_RenderPresent(m_context.renderer);
	}

	Initialize();

	bool done = false;

	int lag = 0;
	std::chrono::time_point<std::chrono::steady_clock> endTime = std::chrono::steady_clock::now();

	m_nFPS = 0;
	long tickCount = 0;
	long fpsElapsedTime = 0;

	// Win32 Run()과 동일한 구조의 게임 루프 (C++11 chrono)
	while (!done)
	{
		std::chrono::time_point<std::chrono::steady_clock> startTime = std::chrono::steady_clock::now();
		std::chrono::milliseconds elapsedTime(std::chrono::duration_cast<std::chrono::milliseconds>(startTime - endTime));
		endTime = startTime;

		// macOS에서는 창 생성 직후 첫 Present가 수백 ms~수 초 지연될 수 있어
		// 원본 루프 구조(ObjectUpdate에 프레임 elapsed를 그대로 전달)와 결합하면
		// 게임 오브젝트가 순간이동한다. 엔진 자체 상수 MAX_FRAME_TIME(0.1s)으로 클램프한다.
		// (Win32/GDI 경로는 무수정 — 이 보정은 SDL2 어댑터에만 존재)
		const long long maxFrameMs = static_cast<long long>(MAX_FRAME_TIME * 1000.0);
		if (elapsedTime.count() > maxFrameMs) {
			elapsedTime = std::chrono::milliseconds(maxFrameMs);
		}

		lag += static_cast<int>(elapsedTime.count());

		if (SDL_getenv("INITIAL2D_DEBUG_DRAW") != nullptr) {
			std::fprintf(stderr, "frame elapsed=%lldms lag=%d\n",
				static_cast<long long>(elapsedTime.count()), lag);
		}

		if (elapsedTime.count() == 0)
		{
			SDL_Delay(5);
		}
		const int fps = 60;
		const int lengthOfFrame = 1000 / fps;

		SDL_Event event;
		while (SDL_PollEvent(&event))
		{
			if (event.type == SDL_QUIT) {
				done = true;
			}
			HandleEvent(event);
		}

		while (lag >= lengthOfFrame)
		{
			UpdateInput();
			ObjectUpdate(elapsedTime.count());
			lag -= lengthOfFrame;

			tickCount++;
			m_elapsed = 1.0 / elapsedTime.count();
		}

		RenderClear();
		RenderTransform();
		Render();

		// 검증/CI용 프레임 덤프 — INITIAL2D_SCREENSHOT=<path.bmp>가 설정되면
		// 120번째 프레임을 BMP로 저장한다. INITIAL2D_EXIT_AFTER=<n>이 설정되면
		// n 프레임 후 자동 종료한다. 둘 다 없으면 아무 영향이 없다.
		{
			static long s_frameCount = 0;
			s_frameCount++;

			// INITIAL2D_SCREENSHOT_FRAME은 쉼표로 구분된 프레임 목록을 지원한다 (예: "12,35,60").
			// 여러 프레임을 지정할 때 경로에 %ld를 넣으면 프레임 번호로 치환된다.
			const char* shotPath = SDL_getenv("INITIAL2D_SCREENSHOT");
			if (shotPath != nullptr) {
				const char* shotFrame = SDL_getenv("INITIAL2D_SCREENSHOT_FRAME");
				bool hit = false;
				if (shotFrame == nullptr) {
					hit = (s_frameCount == 120);
				} else {
					const char* p = shotFrame;
					while (*p != '\0') {
						if (SDL_atoi(p) == s_frameCount) { hit = true; break; }
						while (*p != '\0' && *p != ',') { ++p; }
						if (*p == ',') { ++p; }
					}
				}

				if (hit) {
					char pathBuffer[1024];
					if (SDL_strchr(shotPath, '%') != nullptr) {
						SDL_snprintf(pathBuffer, sizeof(pathBuffer), shotPath, s_frameCount);
					} else {
						SDL_strlcpy(pathBuffer, shotPath, sizeof(pathBuffer));
					}

					int w = 0, h = 0;
					SDL_GetRendererOutputSize(m_context.renderer, &w, &h);
					SDL_Surface* shot = SDL_CreateRGBSurfaceWithFormat(0, w, h, 32, SDL_PIXELFORMAT_RGBA32);
					if (shot != nullptr) {
						if (SDL_RenderReadPixels(m_context.renderer, nullptr,
								SDL_PIXELFORMAT_RGBA32, shot->pixels, shot->pitch) == 0) {
							SDL_SaveBMP(shot, pathBuffer);
						}
						SDL_FreeSurface(shot);
					}
				}
			}

			const char* exitAfter = SDL_getenv("INITIAL2D_EXIT_AFTER");
			if (exitAfter != nullptr && s_frameCount >= SDL_atoi(exitAfter)) {
				done = true;
			}
		}

		RenderPresent();
		m_nFPS++;

		fpsElapsedTime += static_cast<long>(elapsedTime.count());

		if (fpsElapsedTime >= 1000)
		{
			std::stringstream sstr;
			sstr << m_nFPS;

			SDL_SetWindowTitle(m_context.window, sstr.str().c_str());

			fpsElapsedTime = 0;
			m_nFPS = 0;
			m_elapsed = 0;
			tickCount = 0;
		}
	}

	// 텍스처(SDL_Texture)는 렌더러보다 먼저 해제되어야 하므로
	// Destroy()를 부르는 delete this 이후에 렌더러/창을 정리한다.
	SDL_Renderer* renderer = m_context.renderer;
	SDL_Window* window = m_context.window;

	delete this;

	SDL_DestroyRenderer(renderer);
	SDL_DestroyWindow(window);
	SDL_Quit();

	return 0;
}

void App::HandleEvent(const SDL_Event& event)
{
	switch (event.type)
	{
	case SDL_MOUSEWHEEL:
		if (m_pInput != nullptr) {
			m_pInput->setMouseZ(event.wheel.y > 0 ? 1 : -1);
		}
		break;
	case SDL_WINDOWEVENT:
		if (event.window.event == SDL_WINDOWEVENT_FOCUS_GAINED) {
			m_bFocus = true;
		}
		else if (event.window.event == SDL_WINDOWEVENT_FOCUS_LOST) {
			m_bFocus = false;
		}
		break;
	}
}

void App::RenderClear()
{
	// GDI 백버퍼의 창 배경(WHITE_BRUSH)에 맞춰 흰색으로 지운다.
	SDL_SetRenderDrawColor(m_context.renderer, 255, 255, 255, 255);
	SDL_RenderClear(m_context.renderer);
}

void App::RenderTransform()
{
	// SetMapMode(MM_ANISOTROPIC) + SetWindowExtEx/SetViewportExtEx 대응
	SDL_RenderSetLogicalSize(m_context.renderer, WINDOW_WIDTH, WINDOW_HEIGHT);
}

void App::RenderPresent()
{
	SDL_RenderPresent(m_context.renderer);
}

void App::Quit()
{
	SDL_Event event;
	SDL_zero(event);
	event.type = SDL_QUIT;
	SDL_PushEvent(&event);
}

void App::SetAppIcon(std::string filename)
{
	const std::string path = Initial2D::Platform::NormalizePath(filename);

	SDL_Surface* surface = IMG_Load(path.c_str());
	if (surface == nullptr) {
		std::fprintf(stderr, "SetAppIcon: cannot load %s (%s)\n", path.c_str(), IMG_GetError());
		return;
	}

	SDL_SetWindowIcon(m_context.window, surface);
	SDL_FreeSurface(surface);
}

#endif // !RS_WINDOWS
