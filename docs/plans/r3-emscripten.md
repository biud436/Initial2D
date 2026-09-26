# R3. 엔진 Emscripten 빌드: 「같은 엔진이 브라우저 안에서 돈다」

> 작성일 2026-09-26. **권장 모델 Fable 5** ([index.md](index.md) 4절 표). 에디터 트랙(index.md 8절)의
> 세 번째 단계이고, 에디터 쪽 짝은 E4(게임 뷰, `InitialEditor/docs/plans/e4-embedded-play.md`)다.

## 1. 목표 (한 문장)

**네이티브와 같은 C++ 엔진을 WebAssembly 로 빌드해, 에디터의 게임 뷰(웹뷰)와 정적 웹 페이지가
알데바란을 그대로 띄운다.** 에디터가 PIXI 로 게임을 흉내 내는 것이 아니라 진짜 엔진이 canvas 에 그린다.
첫 목표였던 "플래피가 브라우저에서 뜬다"를 넘어, 저장소의 기본 게임인 알데바란 타이틀이 네이티브
골든과 픽셀 단위로 같다.

## 2. 결정

| 결정 | 이유 |
|---|---|
| **SDL2 는 Emscripten 포트로** (`-sUSE_SDL=2` 등. Homebrew 의 find_package 대신) | emcc 가 헤더 경로와 라이브러리를 스스로 준다. 첫 빌드에서 포트를 소스에서 컴파일하고 그 뒤로는 캐시된다. CMake 는 `if(EMSCRIPTEN)` 한 분기이고 네이티브 쪽 코드는 그대로다 |
| **루프는 `emscripten_set_main_loop_arg`, ASYNCIFY 는 쓰지 않는다** | 브라우저는 블로킹 루프를 허락하지 않는다. `App::Run` 의 while 본문을 `App::StepFrame()` 으로 떼어 네이티브는 while 이, 브라우저는 requestAnimationFrame 이 같은 함수를 부른다. 엔진에 블로킹 호출(`SDL_Delay`, `SDL_WaitEvent`)이 없어 ASYNCIFY(코드 크기와 속도 손해)가 필요 없다. fps 는 -1 (디스플레이 주사율) |
| **wasm 네이티브 예외** (`-fwasm-exceptions`, **모든 타깃**) | vendored Lua 는 C++ 로 컴파일되어 오류를 `throw` 로 던지고 `pcall` 이 catch 한다. Emscripten 기본은 catch 를 끈 상태라 첫 Lua 오류에서 abort 했을 것이다. JS 기반 예외(`-fexceptions`)보다 빠르고 최근 브라우저는 전부 지원한다. 타깃마다 방식이 다르면 Lua 오류가 `pcall` 을 지나쳐 모듈 밖으로 빠지므로 CMake 맨 위에서 모든 타깃에 준다 (8절) |
| **환경 변수는 `Platform::GetEnv`** (`src/platform/Env.h`) | 브라우저에는 프로세스 환경이 없다. C++ 의 `INITIAL2D_*` 읽기를 전부 이 함수로 모으고, Emscripten 에서는 `Module.initial2dEnv[name]` 을 먼저 본 뒤 `getenv` 로 내려간다. 네이티브는 헤더 인라인의 `std::getenv` 라 동작이 같고 Windows 프로젝트 파일에 더할 소스도 없다 |
| **Lua 의 `os.getenv` 는 `Module.ENV` 로** | 스크립트는 libc 를 거치므로 로더가 런타임이 뜨기 전(`preRun`)에 같은 값을 `Module.ENV` 에 넣는다. `INITIAL2D_SCENE`, `INITIAL2D_NO_RTP` 처럼 Lua 가 읽는 설정이 그대로 통한다 (검수 7 번이 확인) |
| **핫 리로드는 TCP 대신 export** | 소켓이 없다. `HotReloadServer.cpp` 를 빌드에서 빼고, 번들을 받은 뒤 하던 일(`Script_Destroy` 뒤 `Script_Init`)을 `Script_Restart()` 로 묶어 서버와 `initial2d_reload()` 가 같은 길을 쓴다. 파일은 로더가 MEMFS 에 다시 쓴다 |
| **파일은 MEMFS 의 `/project` 에 스테이징하고 `chdir`** | 엔진은 `./game.json`, `./scripts/lua/main.lua`(Ruby 는 `./scripts/ruby/main.rb`), `./resources/` 를 상대 경로로 연다. 프로젝트 파일을 그 모양 그대로 올리고 cwd 를 옮기면 **엔진의 파일 코드는 한 줄도 바꾸지 않는다** |
| **ES 모듈 팩토리 한 개** (`MODULARIZE` + `EXPORT_ES6`, `INVOKE_RUN=0`) | 전역을 더럽히지 않고, 에디터와 데모 페이지가 `import` 로 같은 `createInitial2D` 를 쓴다. 파일을 올린 뒤에 시작해야 하므로 `main` 은 로더가 `callMain` 으로 부른다. `EXIT_RUNTIME=0` 이라 `main` 이 돌아와도 루프와 런타임이 산다 |
| **`--features` 는 "lua mruby wasm"** | 처음에는 mruby 없이 "lua wasm" 이었다. libmruby 를 emcc 로 교차 빌드해 넣었다 (9절, 2026-09-27). mruby 없이 빌드하면(`INITIAL2D_WEB_MRUBY=0`) 전처럼 "lua wasm". 에디터는 `wasm` 을 보고 내장 실행을 연다. JS 에서는 `initial2d_features()` export 로 같은 문자열을 얻는다 |
| **키보드는 canvas 에서만** (`SDL_HINT_EMSCRIPTEN_KEYBOARD_ELEMENT` = `#canvas`) | 기본은 window 전체라 에디터의 편집기 키까지 게임이 삼킨다. canvas 가 포커스를 가진 동안만 키가 게임으로 가고, 로더가 canvas 에 `tabindex` 를 준다 |

## 3. 바뀐 것

| 파일 | 무엇 |
|---|---|
| `CMakeLists.txt` | `if(EMSCRIPTEN)` 분기. 포트 플래그(컴파일과 링크), `-fwasm-exceptions`, mruby 탐색 생략, `HotReloadServer.cpp` 대신 `src/platform/emscripten/*.cpp`, 링크 플래그(4절), 산출물 `Initial2D.js` + `Initial2D.wasm`. 네이티브 쪽은 `INITIAL2D_SDL2_AUDIO` 와 `INITIAL2D_SDL2_GAME` 변수로 조건을 정리했을 뿐 같은 파일과 같은 메시지다 |
| `src/platform/Env.h` (신규) | `Initial2D::Platform::GetEnv(name)`. 네이티브는 인라인 `std::getenv` |
| `src/platform/emscripten/Env.cpp` (신규) | Emscripten 구현. `EM_ASM_PTR` 로 `Module.initial2dEnv[name]` 을 읽어 캐시한다 |
| `src/platform/emscripten/WebMain.h`, `WebMain.cpp` (신규) | `StartMainLoop(App*)`, 프레임 콜백(종료 시 `emscripten_cancel_main_loop` 뒤 `Teardown`), export `initial2d_reload`, `initial2d_quit`, `initial2d_features` |
| `src/platform/sdl2/AppSDL2.cpp` | `Run` 을 준비, `StepFrame`, `Teardown` 으로 나눴다 (루프 변수는 파일 안의 `LoopState`). `SDL_getenv` 일곱 곳을 `GetEnv` 로. 브라우저에서는 `SDL_Delay`(바쁜 대기)와 창 제목의 FPS(`document.title` 이 바뀐다)를 건너뛰고, 렌더러 이름을 한 줄 로그로 남긴다 |
| `src/App.h` | `#ifndef RS_WINDOWS` 안에 `StepFrame()` 과 `Teardown()` 선언 |
| `src/ScriptRuntime.h`, `.cpp` | `Script_Restart()`, `INITIAL2D_SCRIPT` 를 `GetEnv` 로, Emscripten 이면 features 에 `wasm` |
| `src/platform/sdl2/TextureManagerSDL2.cpp`, `src/mrb_prot.cpp` | `INITIAL2D_DEBUG_DRAW` 와 `System.env` 를 `GetEnv` 로 |
| `tools/build_web.sh` (신규) | `emcmake cmake -S . -B build-web -DCMAKE_BUILD_TYPE=Release` 뒤 빌드, `build-web/site/` 에 js, wasm, 페이지, 로더, 프로젝트 파일을 모으고 크기를 찍는다 |
| `tools/web/index.html`, `tools/web/initial2d-loader.js` (신규) | 데모 페이지와 로더 (5절). 빌드가 `build-web/site/` 로 복사한다 |
| `tools/web_stage.py` (신규) | `game.json`, `scripts/lua/**`, `resources/**` 를 `site/project/` 에 복사하고 목록 `project.json` 을 쓴다. `RTP.zip`, `rtp/`, `*.psd`, 닷파일, `resources/aldebaran/src/gpt/` 는 뺀다 |
| `tools/web_smoke.mjs` (신규) | 헤드리스 검수 (6절) |
| `.gitignore` | `build-web/` |

**환경 변수를 `GetEnv` 로 바꾼 C++ 호출 자리** (전부 비 Windows 경로다):
`INITIAL2D_WINDOW`, `INITIAL2D_SCALE`, `INITIAL2D_HMR`, `INITIAL2D_DEBUG_DRAW`(AppSDL2 와 TextureManagerSDL2),
`INITIAL2D_SCREENSHOT`, `INITIAL2D_SCREENSHOT_FRAME`, `INITIAL2D_EXIT_AFTER`(이상 `AppSDL2.cpp`),
`INITIAL2D_SCRIPT`(`ScriptRuntime.cpp`), 그리고 mruby 의 `System.env(name)`(`mrb_prot.cpp`).
Lua 쪽 `os.getenv`(`INITIAL2D_SCENE`, `INITIAL2D_AUTOPLAY`, `INITIAL2D_NO_RTP`, 알데바란과 데모의
검수용 변수들)는 코드 변경 없이 `Module.ENV` 로 같은 값을 본다.

## 4. 플래그

모든 타깃의 컴파일과 링크에 (CMake 맨 위, vendored 라이브러리보다 먼저):

```
-fwasm-exceptions
```

엔진 코어와 실행 파일의 컴파일과 링크에 (포트):

```
-sUSE_SDL=2 -sUSE_SDL_IMAGE=2 -sSDL2_IMAGE_FORMATS=png,jpg
-sUSE_SDL_MIXER=2 -sSDL2_MIXER_FORMATS=ogg,wav -sUSE_OGG=1 -sUSE_VORBIS=1
```

링크에만 (`Initial2D` 타깃):

```
-sALLOW_MEMORY_GROWTH=1 -sINITIAL_MEMORY=67108864 -sSTACK_SIZE=2097152
-sMODULARIZE=1 -sEXPORT_ES6=1 -sEXPORT_NAME=createInitial2D -sENVIRONMENT=web
-sEXPORTED_RUNTIME_METHODS=FS,ccall,cwrap,callMain,ENV,UTF8ToString,stringToNewUTF8,getExceptionMessage,decrementExceptionRefcount
-sEXPORTED_FUNCTIONS=_main,_initial2d_reload,_initial2d_quit,_initial2d_features,_initial2d_frame_count,_initial2d_running,_malloc,_free
-sFORCE_FILESYSTEM=1 -sEXIT_RUNTIME=0 -sINVOKE_RUN=0
```

`ASYNCIFY` 와 `--shell-file` 은 쓰지 않는다. 산출물은 `build-web/Initial2D.js`(177 KB)와
`build-web/Initial2D.wasm`(1.8 MB, Release). Emscripten 은 6.0.10 (`~/emsdk`, `emsdk install latest`).

## 5. 로더 API

`build-web/site/initial2d-loader.js` (원본은 `tools/web/initial2d-loader.js`). 번들러 없는 ES 모듈이다.

```js
import { bootInitial2D } from "./initial2d-loader.js";

const game = await bootInitial2D({
  canvas: document.getElementById("canvas"),   // SDL 이 그린다. 포커스를 가진 동안 키보드를 받는다
  files: { "game.json": "...", "scripts/lua/main.lua": "...", "resources/x.png": new Uint8Array(...) },
  env: { INITIAL2D_SCRIPT: "lua", INITIAL2D_SCENE: "flappy" },   // 네이티브의 환경 변수와 같은 이름
  print: (line) => console.log(line),        // Lua print (stdout)
  printErr: (line) => console.error(line),   // SDL_Log, "Lua error in ...", "fatal: ..." (stderr)
  onExit: (code) => {},                      // 루프가 멈추면 한 번. 0 은 quit() 이나 정상 종료, 1 은 오류 (8절)
  wasmUrl: "./Initial2D.wasm",               // 선택. 기본은 Initial2D.js 옆
});

game.reload({ "scripts/lua/main.lua": "..." });   // 바뀐 파일만 올리고 VM 재시작 (initial2d_reload). 성공 true, 스크립트 오류 false
game.quit();                                       // initial2d_quit. 다시 띄우려면 새로 boot
game.features();                                   // "lua mruby wasm" (mruby 없이 빌드하면 "lua wasm")
game.frames();                                     // 지금까지 돈 엔진 프레임 수 (initial2d_frame_count)
game.errorText(e);                                 // 모듈 밖으로 나온 것을 읽을 수 있는 문자열로 (C++ 예외는 getExceptionMessage)
game.module;                                       // Emscripten Module (FS, ccall ...)
```

하는 일의 순서: `createInitial2D({ canvas, print, printErr, locateFile, preRun, initial2dEnv })` 로 모듈을
만들고, `files` 를 `/project` 아래에 쓰고(디렉터리는 만든다), `FS.chdir("/project")`, `callMain([])`.
`env` 값은 문자열로 바뀌어 `Module.initial2dEnv`(C++ 의 `GetEnv`)와 `Module.ENV`(libc, Lua 의 `os.getenv`)
두 곳에 들어간다. `null`, `undefined`, `false` 는 "설정 안 함"이다. `reload(files, envPatch)` 의 두 번째
인자는 `initial2dEnv` 만 바꾼다 (libc 의 environ 은 시작 때 굳는다).

데모 페이지 `index.html` 은 `project.json`(`tools/web_stage.py` 가 만든 파일 목록)을 fetch 해 파일을
모으고, "실행" 버튼(브라우저 오디오 정책상 사용자 제스처가 필요하다)으로 위 함수를 부른다.
`?env=INITIAL2D_SCENE=flappy` 처럼 URL 로 설정을 더할 수 있다 (검수가 쓴다).

## 6. 검수

```bash
tools/build_web.sh                                              # 빌드 + build-web/site
node tools/web_smoke.mjs --golden tests/golden/aldebaran_title.png   # 헤드리스 크로미움
```

`tools/web_smoke.mjs` 는 InitialEditor 저장소의 Playwright(`PLAYWRIGHT_DIR` 로 바꿀 수 있다)로
`build-web/site` 를 임의 포트에 띄워 다음을 본다. 콘솔에 `Lua error`, `abort(`, `RuntimeError`,
페이지 오류가 나오면 실패다 (15 초 안).

1. "실행" 을 눌러 엔진 시작 줄 `Initial2D web: renderer=... features=lua mruby wasm` 을 기다린다.
2. `INITIAL2D_SCREENSHOT=/project/shot.bmp` 와 `INITIAL2D_SCREENSHOT_FRAME=20` 을 설정으로 넘겨
   엔진이 20 프레임째를 MEMFS 에 쓴 것을 `FS.readFile` 로 꺼낸다 (`build-web/smoke_frame20.bmp`).
   네이티브 골든과 같은 방식(같은 프레임, `INITIAL2D_NO_RTP=1`)이다.
3. canvas 를 `build-web/smoke.png` 로 찍는다.
4. `--golden` 이면 PIL 로 20 프레임 캡처를 골든과 대조한다 (차이 픽셀 비율, 허용 25%).
5. 키보드: canvas 에 포커스를 주고 아래 화살표와 Enter 를 보내 "조작 방법" 설명 창이 뜨는지
   픽셀 변화량으로 본다 (`build-web/smoke_help.png`).
6. `reload()` 와 `quit()` 이 콘솔에 자기 줄을 남기는지.
7. 두 번째 페이지에서 `main.lua` 한 장짜리 프로젝트를 올려 `os.getenv` 가 설정 객체를 보고,
   `INITIAL2D_EXIT_AFTER` 로 루프가 끝나는지.
8. ~ 11. 오류 처리 (8절의 표). 시작 때 문법 오류, `Update` 의 런타임 오류, `reload()` 의 고장 난 파일과
   고친 파일, `quit()` 뒤의 `onExit(0)`, `frames()`, `errorText()`. 네이티브 실행 파일(`--native`, 기본
   `build/Initial2D`)이 있으면 같은 파일을 헤드리스로 돌려 오류 줄이 글자 그대로 같은지도 본다.
12. ~ 13. mruby (9절). Ruby 판 게임과 Ruby 인수 씬의 20 프레임, Ruby 예외. `--lua-only` 는 mruby 없이 빌드한
   사이트에서 이 둘을 건너뛴다.

Playwright 는 `PLAYWRIGHT_DIR` 로 바꿀 수 있다 (기본은 InitialEditor 저장소의 `node_modules/playwright`).

**2026-09-26 결과**: 전부 통과. 헤드리스 크로미움에서 WebGL(`renderer=opengles2`)이 잡혀 소프트웨어
폴백은 쓰이지 않았다. 20 프레임 캡처는 골든 `aldebaran_title.png` 와 **차이 픽셀 0 / 688128** (평균
차이 0.01). 키보드 입력은 8.6% 의 픽셀을 바꿨다 (설명 창). 네이티브 전체 스위트(`tests/run_all.sh`, 헤드리스)는
**446 PASS / 0 FAIL** 로 무변경 통과. 새 워크트리에서는 플래피의 자리 표시 자산(`resources/*.png`, gitignore)이
없어 플래피 씬 셋이 먼저 실패했는데, `python3 tools/generate_placeholder_assets.py` 뒤 통과했다 (README 의 안내대로).

## 7. 한계와 남은 것

- ~~mruby 가 없다.~~ 2026-09-27 에 넣었다 (9절, E4 마일스톤 6).
- **핫 리로드 TCP 서버가 없다.** `tools/hmr_push.py` 는 브라우저에 닿지 않는다. 에디터는 파일을 다시
  올리고 `reload()` 를 부른다.
- **스크린샷은 호스트 디스크가 아니라 MEMFS 에 쓰인다.** `INITIAL2D_SCREENSHOT` 은 동작하지만 파일은
  wasm 의 가상 파일 시스템 안이라 JS 가 `module.FS.readFile` 로 꺼내야 한다 (검수가 그렇게 한다).
- **오디오는 사용자 제스처 뒤에 난다.** 브라우저 정책이다. 데모 페이지의 "실행" 버튼이 그 제스처이고,
  에디터는 게임 뷰 클릭이 된다. 크로미움이 SDL 의 ScriptProcessorNode 를 deprecated 로 경고하는데
  SDL2 포트의 일이다.
- **터치는 검증하지 않았다.** SDL2 포트가 핑거 이벤트를 주고 엔진의 T1 경로가 그것을 받지만,
  모바일 브라우저 실기 확인은 없다.
- **스레드가 없다.** `Thread.cpp` 는 컴파일되지만 브라우저에서 스레드를 만들면 abort 한다. 엔진 루프는
  쓰지 않는다. `PosixProcess` 도 있지만 프로세스를 띄울 수 없다.
- **파일 스테이징은 통째로다.** 이 저장소는 148 파일 5.8 MB 라 괜찮지만, RTP 변환물 같은 큰 프로젝트는
  E4 의 "목록 먼저, 데이터는 요청 시"가 필요하다. 로더의 `stage()` 로 나중에 더 올릴 수 있다.
- **canvas 크기는 게임이 정한다** (`game.json` 의 창 크기와 배율). 에디터의 게임 뷰는 정수 배율 맞춤을
  E4 마일스톤 2 에서 한다.
- Windows GDI 경로와 Android 는 손대지 않았다. Android 의 JNI 소스 목록에는 새 파일이 들어갈 필요가
  없다 (`Env.h` 는 헤더 인라인, `emscripten/` 은 브라우저 전용).

## 8. 오류 처리: 네이티브와 같게 (2026-09-27)

### 8.1 문제

`CMakeLists.txt` 에서 `add_library(vendored_lua)` 가 `add_compile_options(... -fwasm-exceptions)` 보다 앞에 있어
vendored Lua 만 예외 없이 컴파일되었다 (`add_compile_options` 는 그 뒤에 만든 타깃에만 붙는다). Lua 는 C++ 로
컴파일되어 `pcall` 이 `try`/`catch` 인데, catch 가 빠진 채 링크되어 모든 Lua 오류가 `WebAssembly.Exception` 으로
모듈 밖까지 빠졌다. 시작 때 문법 오류는 `callMain` 을, `Update` 의 `error("boom")` 은 메인 루프를, 리로드 때의 문법
오류는 `initial2d_reload` 를 JS 예외로 깨뜨렸고, `print(pcall(error, "x"))` 조차 던졌다. R3 의 검수는 오류가 없는
경로만 돌아서 드러나지 않았다.

### 8.2 네이티브의 동작 (기준)

`build/Initial2D` 를 `SDL_VIDEODRIVER=dummy`, `INITIAL2D_EXIT_AFTER` 로 작은 프로젝트(`main.lua` 한 장)에서 돌려
확인했다. 웹은 이 표와 같게 동작한다.

| 경우 | 오류 줄 (stderr, 웹은 printErr) | 네이티브 | 웹 |
|---|---|---|---|
| 시작 때 문법 오류 | `Lua error in scripts/lua/main.lua: ./scripts/lua/main.lua:3: <name> or '...' expected near 'end'` | 게임이 끝나고 종료 코드 1 | 같은 줄, `bootInitial2D` 는 정상으로 돌아오고 첫 프레임에 루프가 멈춘다. `onExit(1)` |
| `Update` 의 `error("boom")` | `Lua error in update: ./scripts/lua/main.lua:5: boom` | destroy 훅 없이 끝나고 종료 코드 1 | 같은 줄, 루프가 멈추고 `onExit(1)` |
| `pcall(error, "x")` | 없음 | Lua 가 잡는다 (`false`, `"x"`) | 같음 |
| 핫 리로드의 문법 오류 | `Lua error in scripts/lua/main.lua: ./scripts/lua/main.lua:2: ...` | **바꿨다.** 이전에는 게임이 끝났다 (종료 코드 1). 이제 게임은 두고 스크립트만 멈춘다 (8.3) | `reload()` 가 `false`, 루프는 돈다. 고친 파일로 `reload()` 하면 `true` 이고 다시 그린다 |
| `quit()`, `GameExit()`, `INITIAL2D_EXIT_AFTER` | 없음 | 종료 코드 0 | `onExit(0)` |
| 프레임 밖으로 빠지는 C++ 예외 | | `std::terminate` (abort) | 프레임 함수가 받아 `fatal: 타입: 메시지` 한 줄, 루프가 멈추고 `onExit(1)` (8.5) |

오류 줄의 형식이 같으므로 에디터가 프로세스 실행(E1)에 쓰는 오류 링크 파서가 게임 뷰(E4)에도 그대로 통한다.

### 8.3 핫 리로드의 스크립트 오류는 게임을 끝내지 않는다

에디터의 게임 뷰는 파일을 저장할 때마다 `reload()` 를 부른다. 고장 난 파일 뒤에 고친 파일로 되살아나야 하고,
"네이티브와 같다" 도 지켜야 하므로 네이티브 핫 리로드(`INITIAL2D_HMR=1`, 안드로이드 디버그)도 같이 바꿨다.

- 게임을 끝낼지는 `ScriptRuntime` 한 곳이 정한다 (`MarkFailed`). `Lua_ReportIfError` 와 mruby 의 `ReportError` 는
  오류 줄을 적고 VM 을 멈추기만 한다. 첫 오류에서 `App::Quit()` 을 부르는 것은 전과 같다.
- `Script_Restart()` 가 도는 동안의 오류는 게임을 끝내지 않는다. 반환값은 `bool` 이 되었고(새 VM 이 오류 없이
  올라왔는가), 성공하면 `Script_Failed()` 가 다시 false 가 된다. 멈춘 동안 `Update`, `Render` 는 건너뛰므로 화면은
  비어 있다.
- 네이티브 로그: 성공은 전과 같은 `HotReload: reloaded with N files`, 실패는
  `HotReload: reload failed with N files (script error), scripts stopped until the next reload`.
  웹은 `HotReload: reloaded (web)` 과 `HotReload: reload failed (web, script error), ...`.
- mruby 도 같다 (`mruby: uncaught exception in scripts/ruby/main.rb` 뒤 스크립트만 멈춘다).
- 시작 때의 오류와 `Update`, `Render` 의 오류는 전처럼 게임을 끝낸다 (`test_lua_error_scene` 무변경).

### 8.4 바뀐 것

| 파일 | 무엇 |
|---|---|
| `CMakeLists.txt` | `if(EMSCRIPTEN)` 의 `-fwasm-exceptions` 를 파일 맨 위(어느 `add_library` 보다 먼저)로. 링크에 `getExceptionMessage`, `decrementExceptionRefcount`, `_initial2d_frame_count`, `_initial2d_running` export |
| `src/ScriptRuntime.h`, `.cpp` | `MarkFailed`, `Script_Restart()` 가 `bool` |
| `src/lua_prot.cpp`, `src/mrb_prot.cpp` | 오류 보고에서 `App::Quit()` 을 뺐다 (결정은 ScriptRuntime). `Lua_Init` 이 실패 표시를 지운다 |
| `src/platform/sdl2/AppSDL2.cpp` | 핫 리로드 로그가 성패를 나눈다 |
| `src/platform/emscripten/WebMain.cpp`, `.h` | 프레임 함수의 `try`/`catch` (`fatal:`), 루프가 멈추면 `Module.initial2dOnExit(code)`, `initial2d_reload` 가 1/0, export `initial2d_frame_count`, `initial2d_running` |
| `tools/web/initial2d-loader.js` | `onExit`, `reload()` 의 `true`/`false`, `frames()`, `errorText()`, `callMain` 밖으로 나온 예외와 abort 를 `fatal:` 로 |
| `tools/web/index.html` | 멈추면 상태 줄에 알린다 |
| `tools/web_smoke.mjs` | 검수 8 ~ 11 |
| `tests/run_engine_tests.py` | `[1h] hot_reload_error` (네이티브 핫 리로드로 고장 난 파일과 고친 파일, Lua 와 mruby) |

생성된 `flags.make` 로 확인한 컴파일 플래그: `vendored_lua`, `vendored_sqlite3`, `vendored_jsoncpp`,
`vendored_tinyxml`, `initial2d_core`, `Initial2D`(그리고 빌드하지 않는 테스트 실행 파일들)가 전부 `-fwasm-exceptions`,
실행 파일의 링크도 같다. libmruby 는 CMake 밖에서 같은 예외 방식으로 만든다 (9절).

### 8.5 로더 계약

- `bootInitial2D({ ..., onExit })`: 엔진 루프가 멈추면 `onExit(code)` 를 **한 번** 부른다 (0 은 `quit()` 이나 정상
  종료, 1 은 스크립트 오류나 fatal). 엔진의 호출 스택 밖(마이크로태스크)에서 부른다. `Initial2D web: main loop stopped`
  줄은 전처럼 나온다. 창이나 렌더러를 만들지 못해 루프 없이 `main` 이 끝나도 부른다.
- Lua 오류는 JS 예외로 나오지 않는다. 오류 줄은 네이티브와 글자 그대로 같다.
- `reload(more, envPatch)`: 새 VM 이 오류 없이 올라오면 `true`, 스크립트 오류면 `false` (오류 줄은 이미 printErr 로
  나갔다). 스크립트 오류로 던지지 않는다. 루프가 멈춘 뒤에는 `false`.
- `frames()`: 지금까지 돈 엔진 프레임 수. 루프가 멈추면 마지막 값에 선다.
- `errorText(e)`: 모듈 밖으로 나온 것을 문자열로. C++ 예외(`WebAssembly.Exception`)는 `getExceptionMessage` 로
  `타입: 메시지` 를, 그 밖에는 `e.message` 나 `String(e)` 를 준다. `undefined` 를 돌려주지 않는다.
- `fatal:` 줄 (10.3): C++ 예외는 한 형식 `fatal: 타입: 메시지` 로 적는다. 프레임 밖으로 빠지려는 것은 엔진의 프레임
  함수(`WebMain.cpp` 의 `PrintFatal`, `src/ExceptionText.h`)가, `callMain` 이나 `reload()` 밖으로 나온 것은 로더가
  `errorText` 로 적는다. 타입은 디맹글한 이름이고 std::exception 이 아니면 메시지 없이 타입만 적는다. 예:
  `fatal: std::runtime_error: INITIAL2D_WEB_TEST_FATAL=frame`. 한 줄 뒤에 루프가 멈추고 `onExit(1)` 이 한 번 온다.
  C++ 예외가 아닌 것은 로더가 적는다. JS 오류(브라우저의 호출 스택 한계 등)는 `fatal: 메시지`, abort 는
  `fatal: aborted: 이유` 다. abort 는 C++ 가 잡을 수 없어 브라우저가 `RuntimeError` 를 잡히지 않은 오류로도 보고한다
  (모듈은 더 쓸 수 없다). mruby 바인딩의 C++ 예외는 fatal 이 아니라 Ruby 의 `RuntimeError` 다 (10.2).
- 검수는 `INITIAL2D_WEB_TEST_FATAL` 로 스크립트가 닿지 않는 두 자리를 연다 (`main` 이면 `main` 안에서, `frame` 이면 세
  번째 프레임에서 `std::runtime_error` 를 던진다). `tools/web_smoke.mjs` 16 이 두 줄이 같은 형식인지 본다.

### 8.6 검수 결과 (2026-09-27)

`tools/web_smoke.mjs --golden tests/golden/aldebaran_title.png` 전부 통과. 골든 차이 픽셀 0 / 688128 (골든 무변경).
8 과 9 는 네이티브 실행 파일도 같은 줄과 종료 코드 1 을 냈다. 10 에서 첫 스크립트의 빨간 칸 107584 픽셀이 고장 난
reload 뒤 0 이 되고, 고친 reload 뒤 초록 칸 107584 픽셀이 그려졌다. 예외 방식만 예전으로 되돌린 빌드에서는 8 이
`fatal: lua_longjmp*` 로 실패해 이 검수가 원래의 문제를 잡는 것을 확인했다. 네이티브 전체 스위트(`tests/run_all.sh`,
헤드리스)는 새 `[1h]`(Lua 와 mruby 18 항목)를 더해 463 PASS / 1 FAIL 이었다. 그 하나는 mruby 단위 테스트의 소리 재생
세 항목(`play_music`, `play_sound`)으로, 이 변경 전의 master 를 따로 빌드해 돌려도 같은 세 항목이 같은 값으로 실패해
이 작업 기계의 소리 장치 문제로 보았다 (Lua 단위 테스트는 소리를 흉내 내어 영향이 없다). 브리지 25 개와 RTP 검증도
통과. CI(`.github/workflows/tests.yml`)는 네이티브 스위트만 돌리므로 `[1h]` 는 CI 에서 돌고, 웹 검수(emsdk 와 Playwright
필요)는 로컬 절차였다 (10.5 에서 CI 작업 `engine-web` 을 더했다).

## 9. mruby: 같은 엔진의 두 번째 언어도 브라우저에서 (2026-09-27, E4 마일스톤 6)

`initial2d_features()` 가 `lua mruby wasm` 을 준다. `game.json` 의 `"script": "mruby"` 로 고른 Ruby 판 알데바란이
브라우저에서 네이티브와 같게 돈다. 타이틀의 20 프레임이 Lua 판과 픽셀까지 같고, Ruby 예외는 역추적까지 네이티브와
같은 줄로 나오며 JS 예외로 새지 않는다.

### 9.1 결정

| 결정 | 이유 |
|---|---|
| **mruby 4.0.0 을 `MRuby::CrossBuild` 로** (설정 `tools/web/mruby_build_config.rb`) | 네이티브 CI 의 소스 빌드 폴백(`.github/workflows/tests.yml`)과 같은 태그다. 4.0.0 에는 Emscripten 툴체인(`toolchain :emscripten`, emcc 와 emar)이 들어 있다. 호스트 빌드는 mrbc 만 만든다 (크로스 빌드의 gem 에 든 Ruby 소스를 바이트코드로 굽는다) |
| **예외는 setjmp/longjmp 를 wasm 예외로** (`-fwasm-exceptions`, 링크 `-sSUPPORT_LONGJMP=wasm`) | mruby 는 C 로 컴파일되고 `raise` 가 longjmp 다. 툴체인이 `-fwasm-exceptions` 를 주면 setjmp/longjmp 가 wasm 예외 명령으로 바뀌어, 엔진의 나머지(C++ 로 컴파일된 Lua 의 throw 와 catch)와 같은 방식이 된다 (8절의 교훈). C++ 예외 모드(`enable_cxx_exception`)는 쓰지 않았다. 네이티브(Homebrew)가 setjmp 모드라 동작이 같고, 업스트림 툴체인의 기본 조합이다. 링크의 `SUPPORT_LONGJMP=wasm` 은 `-fwasm-exceptions` 에서의 기본값이지만 명시한다. C++ 바인딩이 일으킨 예외가 C++ 프레임을 지나 Ruby 의 `rescue` 에 닿는 것과 잡히지 않은 채 끝나는 것은 검수 13a, 13b 가 본다 |
| **gem 은 네이티브와 같게, 브라우저에 맞지 않는 것만 뺀다** | 네이티브는 Homebrew 의 gembox `full-core` 다. 뺀 것: `mruby-socket`(BSD 소켓이 없다), `mruby-task`(시그널과 타이머로 도는 선점형 스케줄러), config 가 아닌 `mruby-bin-*`(실행 파일), `mruby-test-inline-struct`(테스트용). `mruby-io` 와 `mruby-dir` 은 넣는다. `scene_loader.rb` 가 `File.open`, `File.exist?` 를 쓰고, MEMFS 위에서 돈다. 결과 정의는 네이티브에서 `MRB_USE_TASK_SCHEDULER` 만 빠진 `MRB_USE_BIGINT`, `MRB_USE_COMPLEX`, `MRB_USE_RATIONAL`, `MRB_USE_SET`, `MRB_UTF8_STRING`, `HAVE_MRUBY_IO_GEM`, `HAVE_MRUBY_ENCODING_GEM` 이다 |
| **`MRB_INT64` 와 `MRB_NO_BOXING`** | wasm32 의 기본은 32비트 정수라 2^31 을 넘는 정수가 네이티브에서는 Integer, 브라우저에서는 Bigint 가 된다. 32비트 포인터에서 64비트 정수를 쓰려면 boxing 을 꺼야 한다 (`mrbconf.h` 가 강제한다). 실수는 네이티브의 64비트 word boxing 도 손실이 없으므로 같다. 알데바란 게임 플레이는 헤드리스 크로미움에서 Lua 판과 같은 60 프레임이었다 |
| **CMake 는 산출물을 경로로 확인한다** (`INITIAL2D_MRUBY_WEB_DIR`, 기본 `build-web/mruby/emscripten`) | Emscripten 툴체인의 `find_*` 는 sysroot 안만 본다. 엔진을 libmruby 와 같은 정의로 컴파일하도록 `lib/libmruby.flags.mak` 의 `MRUBY_CFLAGS` 에서 `-D` 항목을 가져온다 (네이티브가 `mruby-config --cflags` 에서 가져오는 것과 같다). 그 파일을 만들려고 크로스 빌드에 `mruby-bin-config` 를 남긴다. 산출물이 없으면 전처럼 Lua 만 빌드된다 |
| **`tools/build_web.sh` 가 mruby 를 먼저 빌드한다** | 소스는 저장소에 넣지 않고 태그를 `build-web/mruby-src` 에 clone 한다 (CI 폴백과 같은 방식). `MRUBY_SRC` 로 받아 둔 소스를 쓸 수 있고, `include/mruby/version.h` 로 4.0.0 인지 본다. rake 는 Homebrew ruby 를 먼저 쓴다. `INITIAL2D_WEB_MRUBY=0` 이면 건너뛰고 `-DINITIAL2D_MRUBY=OFF` 로 Lua 만 빌드한다. rake 출력은 `build-web/mruby-build.log`. mruby 가 설정 파일 옆에 쓰는 잠금 파일은 끈다 (`MRuby::Lockfile.disable`) |
| **스테이징에 `scripts/ruby/**`** | `tools/web_stage.py`. 데모 페이지에는 언어 고르기 상자를 두었다 (`INITIAL2D_SCRIPT`, `?env=INITIAL2D_SCRIPT=mruby` 면 Ruby 가 골라진 채로 열린다) |

### 9.2 바뀐 것

| 파일 | 무엇 |
|---|---|
| `tools/web/mruby_build_config.rb` (신규) | 호스트(mrbc)와 `emscripten` 크로스 빌드. gem 목록, `MRB_INT64`, `MRB_NO_BOXING` |
| `tools/build_web.sh` | [1/4] mruby (clone, 버전 확인, rake), [2/4] 에 `-DINITIAL2D_MRUBY=ON -DINITIAL2D_MRUBY_WEB_DIR=...`. rake 앞에서 `CFLAGS`, `CXXFLAGS`, `LDFLAGS` 를 비운다 (툴체인은 그 값이 있으면 해당 단계에 `-fwasm-exceptions` 를 넣지 않는다) |
| `CMakeLists.txt` | `if(INITIAL2D_MRUBY AND EMSCRIPTEN)` 분기 (경로 확인, flags.mak 의 `-D`), `Initial2D` 링크에 `-sSUPPORT_LONGJMP=wasm`. 바인딩 소스(`src/mrb_*.cpp`)는 네이티브와 같은 목록을 그대로 쓴다. 네이티브 분기는 무변경 |
| `tools/web_stage.py` | `scripts/ruby/**` 도 스테이징 |
| `tools/web/index.html` | 언어 고르기 상자, 상태 줄에 고른 언어 |
| `tools/web/initial2d-loader.js`, `src/platform/emscripten/WebMain.h`, `src/ScriptRuntime.h` | 주석 (features 문자열, Ruby 의 오류 줄, 언어 고르는 순서) |
| `tools/web_smoke.mjs` | 검수 12 ~ 13, `--lua-only`, 대조 규칙을 네이티브 골든 검사와 같게 하는 `goldenDiff`, JS 쪽 오류 판정에서 엔진 출력 줄은 `fatal:` 과 abort 만 본다 (Ruby 의 `RuntimeError` 는 스크립트 오류 줄의 일부다) |

엔진 C++ 코드는 주석(`ScriptRuntime.h`, `WebMain.h`) 말고는 바꾸지 않았다. 네이티브와 같은 바인딩(`src/mrb_*.cpp`)이
그대로 컴파일된다.

### 9.3 네이티브와 같은 오류

`build/Initial2D`(Homebrew mruby)를 `SDL_VIDEODRIVER=dummy`, `INITIAL2D_EXIT_AFTER` 로 `main.rb` 한 장짜리 프로젝트에서
돌린 것이 기준이다. 웹은 이 표와 같다 (검수 13 이 두 쪽을 다 돌려 줄 묶음을 대조한다).

| 경우 | 오류 줄 (stderr, 웹은 printErr) | 네이티브 | 웹 |
|---|---|---|---|
| `update` 의 `raise "boom"` | `mruby: uncaught exception in update`, `trace (most recent call last):`, `[1] scripts/ruby/main.rb:21`, `scripts/ruby/main.rb:17:in update: boom (RuntimeError)` | destroy 없이 종료 코드 1 | 같은 네 줄, 루프가 멈추고 `onExit(1)` |
| `render` 에서 바인딩의 TypeError (`Graphics.set_color("red", 0, 0)`) | `mruby: uncaught exception in render`, 역추적 두 줄, `scripts/ruby/main.rb:8:in set_color: String cannot be converted to Integer (TypeError)` | 종료 코드 1 | 같음, `onExit(1)` |
| 시작 때 문법 오류 | `scripts/ruby/main.rb:3:3: syntax error, unexpected "'end'", expecting ')'`, `mruby: uncaught exception in scripts/ruby/main.rb`, `(unknown):0: syntax error (SyntaxError)` | 종료 코드 1 | 같음, `onExit(1)` |
| `rescue` (Ruby 의 `raise`, 바인딩의 `raise`) | 없음 | Ruby 가 잡는다 | 같음 |
| `reload()` 의 문법 오류 | 위의 세 줄 (줄 번호만 다르다) | 스크립트만 멈춘다 (8.3) | `false`, 루프는 돈다. 고친 파일이면 `true` 이고 다시 그린다 |
| `exit` (mruby-exit) | `SystemExit` 예외라 `update` 의 raise 와 같은 줄 묶음 | 종료 코드 1 | 같음 |

역추적의 `[1] scripts/ruby/main.rb:21` 은 파일의 마지막 `def` 줄을 가리킨다. mruby 4.0 이 최상위 프레임을 그렇게
적으며, 네이티브도 같다.

### 9.4 검수 결과 (2026-09-27)

`tools/web_smoke.mjs --golden tests/golden/aldebaran_title.png` 전부 통과 (1 ~ 11 도 그대로).

- **12a.** 사이트의 파일에서 `scripts/lua/` 를 빼고 `game.json` 의 `"script": "mruby"` 로 띄운 Ruby 판의 20 프레임이
  같은 브라우저의 Lua 판 캡처와 **차이 0**(채널 최대 차이 0), 골든과도 0 (최대 3).
- **12b.** Ruby 인수 씬(`mruby_aldebaran_scene.rb`, `INITIAL2D_ALDEBARAN_STOP=title`)을 같은 파일로 웹과 네이티브에서
  돌려 20 프레임을 견주었다. 네이티브와 1.44%, 골든과 1.44% (허용 2%). 다른 곳은 메뉴 커서 칸(108,627 ~ 393,669)
  뿐이고 커서 깜빡임의 위상이다. 네이티브 골든 검사도 같은 칸 차이를 같은 허용치로 받는다. 게임 그대로를
  네이티브와 견주지 않는 이유: 헤드리스 네이티브는 프레임 간격이 짧아 20 프레임에 메뉴 창이 덜 열린다 (6%).
- **13.** 위 표의 경우가 전부 네이티브와 같은 줄, 같은 종료 코드. `reload()` 는 빨간 칸 107584 픽셀이 고장 난
  reload 뒤 0, 고친 reload 뒤 초록 칸 107584 픽셀. JS 쪽 오류 없음.
- 크기: `Initial2D.wasm` 1.9 MB 에서 2.95 MB, `Initial2D.js` 178 KB 에서 187 KB. mruby 빌드는 약 20 초
  (`libmruby.a` 8.2 MB 는 디버그 정보를 담은 오브젝트이고 링크가 버린다).
- 예외 방식이 어긋나면: 툴체인의 `-fwasm-exceptions` 를 빼고(`CFLAGS` 를 주어) 만든 libmruby 는 Emscripten 기본의
  JS 기반 setjmp/longjmp 로 컴파일되어, 엔진과 링크하면 `wasm-ld: error: ... undefined symbol: emscripten_longjmp` 로
  빌드가 멈춘다. 8.1 의 Lua 처럼 조용히 링크되어 실행 중에 새는 일은 없다. `tools/build_web.sh` 가 rake 앞에서
  `CFLAGS`, `CXXFLAGS`, `LDFLAGS` 를 비우는 이유다.

### 9.5 한계

- **`exit!` 와 Lua 의 `os.exit` 는 브라우저에서 네이티브와 다르다.** 네이티브는 프로세스가 그 종료 코드로 끝나지만,
  브라우저의 `exit()` 는 `EXIT_RUNTIME=0` 에서 그 프레임만 끊고 루프는 이어 돈다 (`onExit` 도 오지 않는다).
  고치지 않은 이유와 정확한 동작은 10.4. 스크립트는 `System.exit`, `GameExit()` 를 쓴다.
- `Socket` 과 `Task` 는 브라우저 빌드에 없다.
- 첫 빌드는 mruby 소스를 내려받는다 (인터넷). CI 작업 `engine-web` 이 12 ~ 16 까지 돌린다 (10.5).

### 9.6 네이티브 스위트

CI 와 같은 `SDL_VIDEODRIVER=dummy tests/run_all.sh` 가 463 PASS / 1 FAIL 로, 8.6 과 같은 결과다. 그 하나는 같은
mruby 단위 테스트의 소리 재생 세 항목(`play_music`, `play_sound`)이며 이 작업 전의 master 에서도 이 기계에서 같게
실패한다 (8.6). run_all 이 [4/6] 에서 멈추므로 뒤의 둘은 따로 돌렸다: 브리지 25/25 통과, `verify_rtp.py` 통과.
네이티브 쪽 CMake 분기, 소스, 실행 파일은 바뀌지 않았다 (새 분기는 `INITIAL2D_MRUBY AND EMSCRIPTEN` 안).

## 10. C 를 거치는 재귀, 바인딩의 C++ 예외, fatal 줄, CI (2026-09-27, 검증 뒤 보강)

검증에서 나온 문제: 문자열 보간 안의 `to_s` 처럼 C 를 거쳐 VM 을 다시 부르는 mruby 재귀가 2 MB wasm 스택을 넘쳐
메모리를 깨뜨렸다 (네이티브는 `SystemStackError`). 바인딩 안의 C++ 예외(`Tilemap.new` 의 `Json::LogicError`)는 VM 의
C 프레임을 지나가 브라우저에서는 `fatal:` 이나 반쯤 풀린 VM 으로, 네이티브에서는 abort(update)나 SIGSEGV(핫 리로드)로
끝났다. 두 `fatal:` 줄은 형식이 달랐고, CI 는 웹 검수를 돌리지 않았다.

### 10.1 wasm 스택과 mruby 의 호출 깊이 한도

mruby 4.0 에서 네이티브의 `MRB_FUNCALL_DEPTH_MAX` 에 해당하는 것은 `MRB_CALL_LEVEL_MAX` 다 (`src/vm.c`, 기본 512).
호출 정보(ci) 스택의 깊이를 세며, `mrb_funcall` 로 C 에서 VM 을 다시 부를 때도 이 한도를 본다. 한도에 닿으면
미리 만들어 둔 `SystemStackError` 를 raise 한다. 결정:

- 웹의 libmruby 는 `MRB_CALL_LEVEL_MAX=512` 로 고정한다 (`tools/web/mruby_build_config.rb`, 네이티브 Homebrew 의 기본값과
  같다). 깊이 500 의 재귀가 네이티브에서 되면 브라우저에서도 된다.
- wasm 스택(`-sSTACK_SIZE`)을 2 MB 에서 8 MB 로 (`CMakeLists.txt`). 한도까지 가도 스택이 먼저 바닥나지 않는다.

실측 방법: 측정용 빌드(스크래치에만)에 `System.stack_used`(`emscripten_stack_get_base() - emscripten_stack_get_current()`)와
`System.ci_depth` 를 더하고, 재귀의 바닥에서 두 값을 적었다. 깊이 30 과 90(중첩 자료는 100 과 300)의 차이를 단계 수로
나눈 값이 한 단계의 wasm 스택이다. 헤드리스 크로미움(Playwright 1.63), `-O3`, `MRB_NO_BOXING`.

| 재귀 경로 (한 단계) | wasm 스택 / 단계 | ci / 단계 | wasm 스택 / ci |
|---|---|---|---|
| 문자열 보간 안의 `to_s` (`"#{child}"`) | 5,360 B | 1 | **5,360 B (최악)** |
| `format("%s", child)` | 6,528 B | 2 | 3,264 B |
| `String(child)`, `[child].inspect`, `{a: child}.inspect` | 5,312 ~ 5,504 B | 2 | 2,656 ~ 2,752 B |
| `[child] == [other]` (사용자 `==`), `respond_to_missing?` | 5,552 ~ 5,568 B | 2 | 약 2,780 B |
| `sort { }` 블록 안의 재귀 | 5,440 B | 4 | 1,360 B |
| 중첩 배열, Hash, Struct, Set 의 `inspect`, `==`, `<=>`, `Object#inspect`(인스턴스 변수) | 800 ~ 1,152 B | 1 | 800 ~ 1,152 B |
| `send`, `each`, `map`, `times`, `loop`, `inject`, `instance_eval`, `Proc#call`, `Method#call`, `define_method`, `method_missing`, `Class#new`, `eval`, `gsub` 블록, `catch` | 0 B | 1 ~ 5 | 0 B (VM 안에서 돈다) |
| 중첩 `Fiber` (`Fiber.new { 재귀 }.resume`) | 0 B | 0 (파이버마다 ci 스택이 따로다) | 0 B |

`init` 에서의 기본 사용량은 8,144 B. 한도 512 에서 최악 경로는 512 × 5,360 B = 약 2.75 MB 라 2 MB 로는 약 390 단계에서
넘쳤다 (검증: 380 성공, 400 에서 엉뚱한 `NoMethodError` 와 `fatal: null function`). 8 MB 는 한도에서 쓰는 양의 약 3 배다.

브라우저 자신의 호출 스택도 재어 두었다 (한도를 100000 으로 올린 측정용 libmruby, wasm 스택 64 MB). 크로미움(V8)은 wasm
프레임을 제 네이티브 스택(약 1 MB)에 쌓으므로 이것이 C 재귀의 진짜 천장이다.

| 경로 | 브라우저 호출 스택이 다하는 깊이 | 그때의 wasm 스택 |
|---|---|---|
| `to_s` 보간, `init` (시작 직후) | 704 성공, 720 실패 | 3.8 MB |
| `to_s` 보간, `update` 두 번째 프레임 | 736 성공, 768 실패 | 3.95 MB |
| `to_s` 보간, 600 프레임 데운 뒤 | 800 성공, 900 실패 | 4.3 MB |
| 중첩 배열 `join` (C 안의 재귀, ci 가 늘지 않는다, 단계마다 368 B) | 5,000 성공, 6,000 실패 | 약 2.2 MB |

그래서 한도 512 는 브라우저 천장(704)의 약 73% 에서 걸리고, 8 MB 는 잰 경로 모두에서 브라우저 천장보다 먼저 바닥나지
않는다 (wasm 스택이 조용히 넘쳐 메모리를 깨뜨리는 대신 브라우저의 `RangeError` 가 먼저 난다). 남는 차이: ci 를 늘리지
않는 C 안의 재귀(수천 단계로 중첩된 배열의 `join`)는 네이티브(60,000 단계도 된다)와 달리 약 5,000 단계에서
`RangeError: Maximum call stack size exceeded` 로 끝난다. `init` 이면 로더가 `fatal: Maximum call stack size exceeded` 와
`onExit(1)` 을 내고, 프레임 안이면 잡히지 않은 오류로 루프가 멈춘다 (`onExit` 은 오지 않는다. Emscripten 의 메인 루프가
그 오류를 다시 던진다). 스택 넘침 검사(`-sSTACK_OVERFLOW_CHECK=2`)는 wasm 을 3.8% (111 KB) 키우고, 위의 이유로 먼저
걸릴 일이 없어 넣지 않았다. 한도를 올리거나 mruby 를 다른 최적화로 빌드하면 이 표를 다시 잰다.

### 10.2 바인딩의 C++ 예외는 바인딩 경계에서 Ruby 예외로

- `src/mrb_prot.h` 의 `MRuby_Guarded<F>` 가 바인딩 함수를 `try` 로 감싸고, C++ 예외를 `RuntimeError`("타입: 메시지",
  `src/ExceptionText.h`)로 바꿔 raise 한다. raise(longjmp)는 catch 블록을 벗어난 뒤에 해서 C++ 예외 객체가 먼저 정리된다.
  바인딩을 등록하는 `mrb_define_*` 112 곳이 전부 `MRUBY_GUARD(함수)` 를 넘긴다 (`src/mrb_*.cpp`). C++ 예외는 더 이상 VM 의
  C 프레임을 지나가지 않으므로 VM 이 반쯤 풀리는 일이 없고, Ruby 의 `rescue` 로 잡힌다. 프렐류드의 `Tilemap.load` 는
  `RuntimeError` 를 받아 `nil` 을 준다.
- wasm 에서 C++ 의 `catch (...)` 는 C++ 예외 태그만 잡고 mruby 의 raise(`SUPPORT_LONGJMP=wasm` 의 longjmp)는 지나간다
  (작은 C, C++ 프로그램으로 emcc 6.0.10 과 네이티브 clang 에서 확인). 그래서 바인딩이 부른 `mrb_raise` 는 전처럼 Ruby 에 닿는다.
- 결과 (네이티브와 웹이 같다): 잡지 않으면 `scripts/ruby/main.rb:13:in initialize: Json::LogicError: Value is not
  convertible to Int. (RuntimeError)` 와 역추적, 종료 코드 1 (`onExit(1)`). 전에는 네이티브가 abort(종료 코드 134, libc++abi
  terminating)였다. 핫 리로드의 `init` 에서 나면 `reload()` 가 `false` 이고 스크립트는 멈춘다 (전에는 네이티브가 이어서
  SIGSEGV).
- `Script_Restart()` 는 바인딩 밖의 엔진 코드가 던진 C++ 예외도 안에서 받는다. `script restart failed: 타입: 메시지` 를
  적고 VM 은 닫지 않고 버린 채(상태를 믿을 수 없다) 스크립트를 멈추고 `false` 를 돌려준다. 그래서 네이티브 핫 리로드와
  `initial2d_reload` 의 `catch (...)`("reload failed, restart the app")는 없앴다. 이 길은 가드를 하나 뺀 빌드로 확인했다
  (재시작이 `false`, 다음 재시작이 되살린다).
- Lua 는 이미 바꾼다. vendored Lua 는 C++ 로 컴파일되어 `pcall` 의 `catch (...)` 가 C++ 예외도 받아 오류로 만든다.
  오류 값은 그때 스택 꼭대기의 값이라 알아보기 어렵지만(`Lua error in update: maps/bad.json`) 두 빌드가 같고 VM 은 온전하다.
  이번에 바꾸지 않았다.

### 10.3 fatal 줄 한 형식

8.5 의 형식으로 맞췄다. 엔진 쪽은 `e.what()` 만 적던 것을 로더의 `errorText`(Emscripten 의 `getExceptionMessage`)와 같은
`타입: 메시지` 로 바꾸었다 (`src/ExceptionText.h` 의 `DescribeCurrentException`, 타입은 `abi::__cxa_demangle`).
프레임 함수와 정리(`Teardown`)의 catch 가 같은 함수를 쓴다. 검증에서는 `update` 의 같은 예외가 엔진에서
`fatal: Value is not convertible to Int.`, `init` 에서는 로더가 `fatal: Json::LogicError: Value is not convertible to Int.`
였다. 이제 스크립트로는 이 두 자리에 닿지 않으므로(10.2) 검수 16 이 `INITIAL2D_WEB_TEST_FATAL` 로 연다.

### 10.4 `os.exit` 와 `exit!` (바꾸지 않음)

브라우저에서 Lua 의 `os.exit(code)` 와 Ruby 의 `exit!(code)` 는 libc `exit()` 에 닿고, Emscripten 은 `EXIT_RUNTIME=0`
에서 JS 예외(`ExitStatus`)를 던진다. 이 예외는 C++ 예외가 아니므로 `pcall` 과 `rescue` 가 잡지 않는다 (네이티브처럼
`pcall(os.exit, 0)` 은 돌아오지 않는다). 그 프레임의 나머지(`Render` 포함)를 건너뛰고 메인 루프가 예외를 삼키므로
다음 프레임부터 게임은 계속 돈다. `onExit` 은 오지 않고 종료 코드는 버려진다. 네이티브는 그 자리에서 프로세스가 끝난다
(destroy 훅 없이, 주어진 종료 코드).

루프를 그 종료 코드로 내리려면 `exit` 를 가로채(링커 `--wrap` 이나 스크립트의 `os.exit`, `exit!` 재정의) destroy 훅을
부르지 않는 정리(소리와 WebGL 을 닫는 `SDL_Quit`)를 새로 만들고, `callMain` 과 `reload()` 에서 `ExitStatus` 를 종료로
다루도록 로더도 고쳐야 한다. 작고 안전한 변경이 아니어서 한계로 두고 README 에 적었다. 게임을 끝낼 때는 Lua 는
`GameExit()`, Ruby 는 `System.exit` 이나 `exit`(`SystemExit` 예외라 네이티브와 같다)를 쓴다.

### 10.5 CI 작업 `engine-web`

`.github/workflows/tests.yml` 에 두 번째 작업을 더했다 (기존 `engine-macos` 는 그대로). 골든을 만든 작업과 같은
`macos-26` 러너에서 돈다. 단계는 `tools/web_ci.sh` 의 명령이라 로컬에서도 같다.

| 단계 | 명령 | 하는 일 |
|---|---|---|
| 의존성, mruby, 플레이스홀더 | `engine-macos` 와 같은 절차 | 네이티브 대조용 엔진을 위한 SDL2 와 mruby 4.0.0, `pillow` |
| emsdk | `tools/web_ci.sh emsdk` | `$EMSDK`(기본 `~/emsdk`)가 없으면 emsdk 저장소의 `6.0.10` 태그를 받고, `emsdk install/activate 6.0.10`. CI 는 `~/emsdk` 를 `actions/cache` 에 둔다 (포트 컴파일 결과 포함) |
| Playwright | `tools/web_ci.sh playwright` | `build-web/playwright` 에 `playwright@1.63.0`, `playwright install chromium` |
| 네이티브 | `tools/web_ci.sh native` | `build/Initial2D` (검수가 같은 파일을 네이티브로도 돌린다) |
| 웹 빌드 | `tools/web_ci.sh build` | `tools/build_web.sh` (mruby 4.0.0 포함) |
| 웹 검수 | `tools/web_ci.sh smoke` | `node tools/web_smoke.mjs --golden tests/golden/aldebaran_title.png` (1 ~ 16) |

`tools/web_smoke.mjs` 는 Playwright 를 `PLAYWRIGHT_DIR`, `build-web/playwright`, 저장소의 `node_modules`, 옆 저장소
`../InitialEditor` 순서로 찾는다 (전에는 `/Users/u/InitialEditor` 고정). 실패하면 캡처와 mruby 빌드 로그를 아티팩트로
남긴다. push 할 수 없어 CI 에서 돌려 보지는 못했다. 대신 워크플로를 actionlint 1.7.12(shellcheck 0.11.0 포함)로 검사해
새 작업에는 지적이 없고(기존 작업의 mruby 단계에 있던 SC2155 경고 하나는 그대로), 다섯 명령을 로컬에서 차례로 돌려 통과했다.

### 10.6 검수 결과

- `tools/web_smoke.mjs --golden tests/golden/aldebaran_title.png` 1 ~ 16 통과. 골든 차이 0 / 688128 (골든 무변경).
  - 14a: `update` 의 무한 `to_s` 재귀가 네이티브와 같은 514 줄(역추적 511 단계 포함)과 `onExit(1)`. 14b, 14c: `init` 에서
    rescue 되고 깊이 500 이 끝까지 간다 (네이티브도 종료 코드 0). 14d: `reload()` 의 무한 재귀가 `false`, 다음 `reload()` 는 `true`.
  - 15a: `rescue` 가 `RuntimeError: Json::LogicError: Value is not convertible to Int.`, `Tilemap.load` 는 `nil`, 잡지 않으면
    네이티브와 같은 다섯 줄과 `onExit(1)`. 15b: `reload()` 의 `init` 에서 나면 `false`, 스크립트는 멈추고 다음 `reload()` 는 `true`.
  - 16: `fatal: std::runtime_error: INITIAL2D_WEB_TEST_FATAL=frame`(엔진, 프레임 2 에서 멈춤)과 `...=main`(로더) 이 같은 형식,
    각각 `onExit(1)` 한 번, JS 예외 없음.
- 검수가 원래 문제를 잡는지: 같은 오브젝트를 `STACK_SIZE=2097152` 로만 다시 링크한 사이트에서 14a 가
  `pageerror: memory access out of bounds` 로 실패했다. `Tilemap#initialize` 의 가드만 뺀 빌드에서는 15a 가
  `fatal: Json::LogicError: ...` 로 실패했다.
- 검증의 재현 스크립트(`to_s` 깊이 320 ~ 500, 잡은 것과 잡지 않은 것, reload 의 무한 재귀, 바인딩의 C++ 예외와 그 뒤의
  destroy, reload 의 C++ 예외)가 전부 네이티브와 같은 줄과 종료 코드를 냈다.
- 네이티브: `[0g] mruby_binding_guard`(등록 112 곳이 전부 가드를 거치는가), `[1c] mruby_cpp_exception`(rescue, `Tilemap.load`,
  잡지 않은 예외의 줄 묶음과 종료 코드 1), `[1h]` 에 `mruby_cpp`(핫 리로드의 C++ 예외, 스크립트가 멈추고 고친 파일로 되살아남),
  mruby 단위 `tilemap` 에 두 항목. 가드 하나를 뺀 네이티브 빌드에서 이 중 6 항목이 실패했다 (그중 종료 코드 -6, abort).
- 네이티브 전체 스위트 `SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy tests/run_all.sh`: 엔진 테스트 483 PASS / 0 FAIL,
  C++ 단위 18, 브리지 25, RTP 검증 통과. 소리 장치를 dummy 로 두면 8.6 의 mruby 소리 세 항목도 통과한다.
- 크기: `Initial2D.wasm` 약 2.95 MB 에서 2,963,062 B (가드 112 곳), `Initial2D.js` 187,004 B 그대로.

## 11. 체크리스트

- [x] CMake `EMSCRIPTEN` 분기 (포트, 예외, HotReloadServer 와 mruby 제외, 링크 플래그)
- [x] `emscripten_set_main_loop_arg` 프레임 루프, `EXIT_RUNTIME=0`, ASYNCIFY 없음
- [x] export `initial2d_reload`, `initial2d_quit`, `initial2d_features`
- [x] `Platform::GetEnv` 와 `Module.initial2dEnv`, `Module.ENV`
- [x] `tools/build_web.sh`, `tools/web_stage.py`, `tools/web/index.html`, `tools/web/initial2d-loader.js`
- [x] `tools/web_smoke.mjs` (Playwright, 골든 대조, 키보드, export, os.getenv)
- [x] 네이티브 스위트 무변경 통과
- [x] README 「웹 빌드 (Emscripten)」, index.md 갱신
- [x] 오류 처리를 네이티브와 같게 (8절): 모든 타깃 `-fwasm-exceptions`, `onExit`, `reload()` 의 성패, `frames()`, `errorText()`, `fatal:` 줄, 네이티브 핫 리로드의 오류가 게임을 끝내지 않음, 검수 8 ~ 11 과 `[1h]`
- [x] mruby (libmruby 교차 빌드, 9절): `lua mruby wasm`, Ruby 판 게임, Ruby 예외가 네이티브와 같은 줄, 검수 12 ~ 13
- [x] C 를 거치는 재귀의 `SystemStackError`(`MRB_CALL_LEVEL_MAX` 512, `STACK_SIZE` 8 MB, 실측 10.1), 바인딩의 C++ 예외를 Ruby 예외로(10.2), `fatal:` 한 형식(10.3), 검수 14 ~ 16, 네이티브 `[0g]`, `[1c]`
- [x] CI 작업 `engine-web` 과 `tools/web_ci.sh` (10.5)
- [ ] 모바일 브라우저 터치 실기
- [ ] 웹 데모 배포 (저자 결정, README 의 실행 링크 자리)
