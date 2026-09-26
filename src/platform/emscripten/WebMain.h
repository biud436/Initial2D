/**
 * @file WebMain.h
 * @brief 브라우저(Emscripten) 어댑터 (R3, docs/plans/r3-emscripten.md).
 * @details 브라우저에는 블로킹 게임 루프가 없다. AppSDL2 의 Run 은 창과 렌더러를 만든 뒤
 *          여기의 StartMainLoop 에 프레임 함수를 맡기고 바로 돌아오며, 그 뒤로는
 *          requestAnimationFrame 이 매 프레임 App::StepFrame 을 부른다.
 *
 *          JS 로 내보내는 함수 (WebMain.cpp, EMSCRIPTEN_KEEPALIVE):
 *            initial2d_reload()      스크립트 VM 재시작 (핫 리로드 서버가 번들을 받은 뒤 하는 것과 같다).
 *                                    1 이면 성공, 0 이면 스크립트 오류 (루프는 돌고 스크립트만 멈춘다)
 *            initial2d_quit()        게임 종료 (SDL_QUIT 을 넣고, 다음 프레임에 루프를 내리고 정리한다)
 *            initial2d_features()    이 빌드의 언어 목록 ("lua mruby wasm", mruby 없이 빌드하면 "lua wasm")
 *            initial2d_frame_count() 지금까지 돈 엔진 프레임 수
 *            initial2d_running()     루프가 걸려 있으면 1
 *
 *          루프가 내려가면 Module.initial2dOnExit(code) 를 부른다 (0 은 정상 종료, 1 은 스크립트
 *          오류나 fatal). 프레임 밖으로 빠지려는 C++ 예외는 "fatal: 타입: 메시지" 한 줄로 stderr 에 적는다
 *          (로더가 callMain 밖으로 나온 예외에 적는 줄과 같은 형식). 검수는 INITIAL2D_WEB_TEST_FATAL 로
 *          그 경로를 연다 (main 또는 frame, WebMain.cpp).
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
