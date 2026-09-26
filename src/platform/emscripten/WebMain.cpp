/**
 * @file WebMain.cpp
 * @brief 브라우저(Emscripten) 어댑터 구현: 메인 루프 콜백과 JS export (R3).
 */
#ifdef __EMSCRIPTEN__

#include "WebMain.h"

#include "App.h"
#include "ScriptRuntime.h"

#include <SDL.h>
#include <emscripten.h>

#include <string>

namespace {

	App* g_app = nullptr;

	// requestAnimationFrame 마다 한 번. 종료 요청(SDL_QUIT, Lua 오류, INITIAL2D_EXIT_AFTER)이
	// 오면 루프를 내리고 네이티브와 같은 순서로 정리한다 (Teardown 은 delete this 를 포함한다).
	void Frame(void* arg)
	{
		App* app = static_cast<App*>(arg);
		if (app->StepFrame()) {
			return;
		}
		emscripten_cancel_main_loop();
		g_app = nullptr;
		app->Teardown();
		SDL_Log("Initial2D web: main loop stopped");
	}

} // namespace

namespace Initial2D {
namespace Platform {
namespace Web {

	void StartMainLoop(App* app)
	{
		g_app = app;
		// fps -1: 브라우저의 requestAnimationFrame 박자(보통 디스플레이 주사율)를 쓴다.
		// simulate_infinite_loop 0: 바로 돌아온다. main 이 끝나도 EXIT_RUNTIME=0 이라 런타임과 루프는 산다.
		emscripten_set_main_loop_arg(Frame, app, -1, 0);
	}

	bool IsRunning()
	{
		return g_app != nullptr;
	}

} // namespace Web
} // namespace Platform
} // namespace Initial2D

extern "C" {

	EMSCRIPTEN_KEEPALIVE void initial2d_reload()
	{
		if (!Initial2D::Platform::Web::IsRunning()) {
			SDL_Log("HotReload: not running, reload ignored");
			return;
		}
		Script_Restart();
		SDL_Log("HotReload: reloaded (web)");
	}

	EMSCRIPTEN_KEEPALIVE void initial2d_quit()
	{
		if (!Initial2D::Platform::Web::IsRunning()) {
			return;
		}
		g_app->Quit();
	}

	EMSCRIPTEN_KEEPALIVE const char* initial2d_features()
	{
		static std::string features;
		features = Script_Features();
		return features.c_str();
	}

} // extern "C"

#endif // __EMSCRIPTEN__
