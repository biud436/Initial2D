/**
 * @file WebMain.cpp
 * @brief 브라우저(Emscripten) 어댑터 구현: 메인 루프 콜백과 JS export (R3).
 */
#ifdef __EMSCRIPTEN__

#include "WebMain.h"

#include "App.h"
#include "ExceptionText.h"
#include "ScriptRuntime.h"
#include "platform/Env.h"

#include <SDL.h>
#include <emscripten.h>

#include <cstdio>
#include <cstring>
#include <stdexcept>
#include <string>

namespace {

	App* g_app = nullptr;
	// 끝까지 돈 StepFrame 의 수 (initial2d_frame_count). 루프가 내려간 뒤에도 마지막 값을 둔다.
	double g_frames = 0;

	// catch 블록 안에서 부른다. 처리 중인 C++ 예외를 "fatal: 타입: 메시지" 한 줄로 stderr 에 적는다.
	// 로더(initial2d-loader.js)가 callMain 밖으로 나온 예외에 적는 줄과 같은 형식이다 (errorText).
	void PrintFatal()
	{
		std::fprintf(stderr, "fatal: %s\n", Initial2D::CurrentExceptionText().c_str());
		std::fflush(stderr);
	}

	// 검수용 (tools/web_smoke.mjs 16): 스크립트로는 닿지 않는 fatal 경로를 C++ 예외로 연다.
	//   INITIAL2D_WEB_TEST_FATAL=main   main 안에서 던진다. callMain 밖으로 나가 로더가 fatal 줄을 적는다
	//   INITIAL2D_WEB_TEST_FATAL=frame  세 번째 프레임에서 던진다. 프레임 함수가 fatal 줄을 적는다
	void ThrowIfTestFatal(const char* where)
	{
		const char* value = Initial2D::Platform::GetEnv("INITIAL2D_WEB_TEST_FATAL");
		if (value != nullptr && std::strcmp(value, where) == 0) {
			throw std::runtime_error(std::string("INITIAL2D_WEB_TEST_FATAL=") + where);
		}
	}

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
		catch (...) {
			PrintFatal();
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
	// 오면 루프를 내린다. 프레임 밖으로 빠지려는 C++ 예외는 여기서 받아 "fatal: 타입: 메시지" 한 줄을
	// stderr 에 적고 루프를 내린다 (JS 로 새지 않는다).
	void Frame(void* arg)
	{
		App* app = static_cast<App*>(arg);
		bool running = false;
		try {
			if (g_frames == 2) {
				ThrowIfTestFatal("frame");
			}
			running = app->StepFrame();
			g_frames += 1;
		}
		catch (...) {
			PrintFatal();
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
		ThrowIfTestFatal("main");
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
	// 또는 재시작 중의 C++ 예외(Script_Restart 가 받는다). 그 뒤에도 루프는 돌고 스크립트만 멈춘다
	// (네이티브 핫 리로드와 같다).
	EMSCRIPTEN_KEEPALIVE int initial2d_reload()
	{
		if (!Initial2D::Platform::Web::IsRunning()) {
			SDL_Log("HotReload: not running, reload ignored");
			return 0;
		}
		if (Script_Restart()) {
			SDL_Log("HotReload: reloaded (web)");
			return 1;
		}
		SDL_Log("HotReload: reload failed (web, script error), scripts stopped until the next reload");
		return 0;
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
