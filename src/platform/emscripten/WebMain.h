/**
 * @file WebMain.h
 * @brief 브라우저(Emscripten) 어댑터 (R3, docs/plans/r3-emscripten.md).
 * @details 브라우저에는 블로킹 게임 루프가 없다. AppSDL2 의 Run 은 창과 렌더러를 만든 뒤
 *          여기의 StartMainLoop 에 프레임 함수를 맡기고 바로 돌아오며, 그 뒤로는
 *          requestAnimationFrame 이 매 프레임 App::StepFrame 을 부른다.
 *
 *          JS 로 내보내는 함수 (WebMain.cpp, EMSCRIPTEN_KEEPALIVE):
 *            initial2d_reload()   스크립트 VM 재시작 (핫 리로드 서버가 번들을 받은 뒤 하는 것과 같다)
 *            initial2d_quit()     게임 종료 (SDL_QUIT 을 넣고, 다음 프레임에 루프를 내리고 정리한다)
 *            initial2d_features() 이 빌드의 언어 목록 ("lua wasm")
 */
#pragma once

#ifdef __EMSCRIPTEN__

class App;

namespace Initial2D {
namespace Platform {
namespace Web {

	/** emscripten_set_main_loop_arg 로 App::StepFrame 을 건다. 돌아온 뒤 main 이 끝나도 런타임은 산다 (EXIT_RUNTIME=0). */
	void StartMainLoop(App* app);

	/** 루프가 걸려 있고 App 이 살아 있는가. export 함수가 정리된 App 을 건드리지 않게 한다. */
	bool IsRunning();

} // namespace Web
} // namespace Platform
} // namespace Initial2D

#endif // __EMSCRIPTEN__
