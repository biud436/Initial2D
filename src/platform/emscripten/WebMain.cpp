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

#include <cstdio>
#include <exception>
#include <string>

namespace {

	App* g_app = nullptr;
	// 끝까지 돈 StepFrame 의 수 (initial2d_frame_count). 루프가 내려간 뒤에도 마지막 값을 둔다.
	double g_frames = 0;

	// 루프를 내리고 네이티브와 같은 순서로 정리한 뒤 로더에 종료 코드를 알린다.
	// fatal 이 아니면 종료 코드는 네이티브 main 과 같은 식이다 (스크립트 오류로 멈췄으면 1, 아니면 0).
	// Teardown 이 destroy 훅을 부르므로 코드는 그 뒤에 정한다.
	void StopLoop(App* app, bool fatal)
	{
		emscripten_cancel_main_loop();
		g_app = nullptr;
		try {
			app->Teardown(); // delete this 를 포함한다
		}
		catch (const std::exception& e) {
			std::fprintf(stderr, "fatal: %s\n", e.what());
			fatal = true;
		}
		catch (...) {
			std::fprintf(stderr, "fatal: unknown exception during teardown\n");
			fatal = true;
		}
		const int code = (fatal || Script_Failed()) ? 1 : 0;
		SDL_Log("Initial2D web: main loop stopped");
		// 로더(initial2d-loader.js)가 Module.initial2dOnExit 에 onExit 을 한 번만 부르는 함수를 둔다
		EM_ASM({
			if (typeof Module["initial2dOnExit"] === "function") {
				Module["initial2dOnExit"]($0);
			}
		}, code);
	}

	// requestAnimationFrame 마다 한 번. 종료 요청(SDL_QUIT, 스크립트 오류, INITIAL2D_EXIT_AFTER)이
	// 오면 루프를 내린다. 프레임 밖으로 빠지려는 C++ 예외는 여기서 받아 "fatal: 메시지" 한 줄을
	// stderr 에 적고 루프를 내린다 (JS 로 새지 않는다).
	void Frame(void* arg)
	{
		App* app = static_cast<App*>(arg);
		bool running = false;
		try {
			running = app->StepFrame();
			g_frames += 1;
		}
		catch (const std::exception& e) {
			std::fprintf(stderr, "fatal: %s\n", e.what());
			StopLoop(app, true);
			return;
		}
		catch (...) {
			std::fprintf(stderr, "fatal: unknown exception in the frame\n");
			StopLoop(app, true);
			return;
		}
		if (!running) {
			StopLoop(app, false);
		}
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

	// 1: 새 VM 이 오류 없이 올라왔다. 0: 스크립트 오류(메시지는 이미 stderr 에 나갔다), 루프가 없음,
	// 또는 재시작 중의 C++ 예외. 스크립트 오류 뒤에도 루프는 돌고 스크립트만 멈춘다 (네이티브 핫 리로드와 같다).
	EMSCRIPTEN_KEEPALIVE int initial2d_reload()
	{
		if (!Initial2D::Platform::Web::IsRunning()) {
			SDL_Log("HotReload: not running, reload ignored");
			return 0;
		}
		try {
			if (Script_Restart()) {
				SDL_Log("HotReload: reloaded (web)");
				return 1;
			}
			SDL_Log("HotReload: reload failed (web, script error), scripts stopped until the next reload");
			return 0;
		}
		catch (...) {
			// 네이티브 핫 리로드 서버와 같은 처리
			SDL_Log("HotReload: reload failed — restart the app");
			return 0;
		}
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

	EMSCRIPTEN_KEEPALIVE double initial2d_frame_count()
	{
		return g_frames;
	}

	EMSCRIPTEN_KEEPALIVE int initial2d_running()
	{
		return Initial2D::Platform::Web::IsRunning() ? 1 : 0;
	}

} // extern "C"

#endif // __EMSCRIPTEN__
