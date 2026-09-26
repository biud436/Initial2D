# S1. mruby 바인딩: 「같은 엔진을 Ruby 로도 쓴다」

> 작성일 2026-09-26. **권장 모델 Fable 5** (백엔드 선택 규칙, 객체 모델, 오류 정책이
> 이후 스크립트 작업의 토대가 되는 설계 판단이다).
>
> 저자 지시 (2026-09-26): "mruby 바인딩을 구현하세요. MRuby 로도 코딩할 수 있게 해보세요."

## 1. 목표 (한 문장)

**Lua 로 되는 것은 전부 mruby 로도 된다.** 스프라이트, 텍스처, 입력, 오디오, JSON, 타일맵,
비트맵 폰트, 동적 폰트. 그리고 그것을 사람이 아니라 검수 러너가 매번 다시 확인한다.

증명은 둘이다.

1. `tests/engine/scenes/mruby_assert_scene.rb` 는 `assert_scene.lua` 를 한 줄씩 옮긴 것이고,
   러너는 그 화면을 **Lua 씬과 같은 골든**(`assert_scene_f35`)에 견준다. 두 바인딩이 같은
   엔진 호출로 이어진다는 뜻이다.
2. `scripts/ruby/games/flappy.rb` 는 플래피를 Ruby 로 다시 쓴 것이고, 인수 씬이 자동 시연으로
   점수를 내고 죽고 다시 시작하는 것까지 본다.

## 2. 설계 원칙과 결정

### 2.1 범용 엔진의 원칙은 그대로

C++ 은 엔진과 어댑터만이다. mruby 바인딩은 `src/mrb_*.cpp` 여덟 파일로, `lua_*.cpp` 와
같은 배치(파일 하나에 모듈이나 클래스 하나)다. RPG 프레임워크(`scripts/rpg/`)는 Lua 그대로
두며 옮기지 않는다. 언어를 하나 더 얹는 것이지 게임 로직을 두 벌 관리하는 것이 아니다.

### 2.2 백엔드 선택 (`src/ScriptRuntime.h`)

엔진 루프는 `Lua_*` 대신 `Script_*` 를 부르고, 그 안에서 한 번 결정한 백엔드로 분기한다.

1. `INITIAL2D_SCRIPT=lua | mruby` 환경 변수
2. `game.json` 의 `"script": "mruby"`
3. `scripts/ruby/main.rb` 만 있고 `scripts/main.lua` 가 없으면 mruby, 그 밖에는 lua

**`main.lua` 가 있으면 언제나 Lua 다.** 이 저장소에는 둘 다 있으므로 기본은 여전히 Lua
(알데바란)이고, Ruby 플래피는 `INITIAL2D_SCRIPT=mruby` 로 연다. 기존 프로젝트가 깨지지
않는 것이 첫째 조건이었다.

### 2.3 Ruby 답게, 그러나 1:1 로

이름은 Ruby 관례(snake_case, 술어는 `?`, 설정은 `=`)를 따르되 Lua 함수와 하나씩 짝이 있다.
표는 README 의 「mruby 스크립팅」 절에 있다. 결정한 것들:

| 결정 | 이유 |
|---|---|
| `Sprite`, `Tilemap`, `FontEx` 는 **클래스** (mruby Data 객체) | Lua 는 포인터를 숫자로 넘기고 Dispose 를 손으로 부른다. Ruby 에서는 GC 가 거두면 dfree 가 C++ 객체를 지운다. `dispose` 도 남겨 두어 즉시 놓을 수 있고, 그 뒤의 사용은 `RuntimeError` 다 |
| 전역 함수는 `Graphics` 와 `System` 모듈로 | Lua 는 모듈이 없어 전역이었다. RGSS 를 아는 저자에게 익숙한 이름이다 (`Graphics.width`, `Input.trigger?`) |
| `Input` 은 정수 키 외에 **Symbol** 도 받는다 (`:z`, `:space`, `:escape`) | `Keys` 모듈의 상수 이름으로 찾는다. 마우스는 `:left`, `:right`, `:middle` |
| `Json.load` 는 실패하면 **예외** | Lua 는 nil + 메시지지만 Ruby 는 예외가 관례다. `Json.parse(text)` 도 덤으로 |
| `Tilemap` 의 **레이어는 0 기준** | Ruby 배열 관례. Lua 바인딩은 1 기준이며, 이 차이는 문서와 테스트에 못 박았다 |
| `Sprite#rect` 는 `{x, y, right, bottom, width, height}` | Lua 의 GetRect 는 width 칸에 오른쪽 좌표를 넣는 규칙이었다. Ruby 에서는 이름대로 돌려주고 둘 다 준다 |
| `Kernel#load`, `Kernel#require` 를 엔진이 정의 | mruby 에는 파일 읽기가 없다. `require` 는 `.rb` 를 붙이고 절대 경로로 정규화해 한 번만 읽는다 |
| **폴더는 언어별로**: Lua 는 `scripts/` 그대로, Ruby 는 `scripts/ruby/` (테스트는 `tests/lua/`, `tests/ruby/`) | 저자 요청 (2026-09-26, "루아하고 루비하고 폴더를 구분"). Lua 를 `scripts/lua/` 로 옮기는 대칭 배치는 `require("scripts/...")` 수백 곳과 에디터 브리지(다른 저장소), HMR 푸시, 안드로이드 에셋 스테이징이 `scripts/` 에 묶여 있어 미뤘다. Ruby 를 `scripts/` 아래에 두면 그 셋이 손대지 않아도 Ruby 파일을 함께 나른다 |
| 편의 메서드는 **프렐류드**(Ruby 문자열을 C++ 에 내장) | `Sprite.load(path, id, ...)` 처럼 C 로 만들 이유가 없는 것. Lua 의 `scripts/image.lua` 에 해당 |

### 2.4 오류 정책

씬 훅(`init`, `update`, `render`, `destroy`)에서 예외가 새어 나오면 메시지와 역추적을 stderr 에
찍고 `App::Quit()` 으로 게임을 끝내며, 프로세스 종료 코드는 1 이다. Lua 의 `lua_call` 이
오류에 그대로 멈추는 것과 같은 무게이고, 검수 러너가 `rc != 0` 과 로그의 `error` 로 잡는다.
없는 훅은 부르지 않는다 (테스트 러너처럼 `init` 만 있어도 된다).

### 2.5 빌드: Homebrew 의 mruby 를 찾는다

mruby 는 소스 트리를 vendoring 하지 않았다. mruby 의 빌드는 Ruby 와 rake 가 필요한 별도
체계라 CMake 에서 돌리기에 무겁고, Lua 처럼 `.cpp` 몇 개를 GLOB 하는 식이 안 된다.
CMake 가 `/opt/homebrew/opt/mruby` 에서 헤더와 `libmruby.a` 를 찾으면
`INITIAL2D_HAS_MRUBY` 를 정의하고 `mrb_*.cpp` 를 넣는다. 없으면 Lua 만으로 빌드된다.

주의할 것 하나. libmruby 는 빌드 때의 `-D` 옵션(정수 폭, 박싱, 태스크 스케줄러)에 따라
`mrb_state` 의 배치가 달라지므로 **같은 정의로 컴파일해야 한다.** CMake 가
`mruby-config --cflags` 의 `-D` 항목을 그대로 가져온다.

`Initial2D --features` 는 이 빌드가 실행할 수 있는 언어("lua" 또는 "lua mruby")를 찍고
끝난다. 러너는 이것으로 mruby 테스트를 돌릴지 정하고, 없으면 눈에 띄게 건너뛴다.
CI 는 `brew install mruby` 로 항상 켠다.

## 3. 작업 항목

- [x] `src/ScriptRuntime.{h,cpp}`: 백엔드 선택 규칙 셋, `Script_Init/Update/Render/Destroy`,
      `Script_Features`, `Script_Failed`. `main.cpp`, `AppSDL2.cpp`(핫 리로드), `sdl2Main.cpp`
      (`--features`, 종료 코드)가 이것을 쓴다
- [x] `src/mrb_prot.{h,cpp}`: VM 수명, 훅 호출(GC 아레나 복원 포함), 오류 보고, `Graphics`,
      `System`, `Keys`, `Kernel#load`, `Kernel#require`, 프렐류드
- [x] `src/mrb_input.cpp`: Input 14 함수 + RGSS 식 별명 셋, Symbol 키와 버튼 이름
- [x] `src/mrb_audio.cpp`: Audio 12 함수 (loop 계약은 Lua 와 같다)
- [x] `src/mrb_json.cpp`: `Json.load`, `Json.parse`
- [x] `src/mrb_sprite.cpp`: Sprite 클래스 31 메서드 (Lua 의 31 함수 전부)
- [x] `src/mrb_texture.cpp`: TextureManager 3 함수
- [x] `src/mrb_tilemap.cpp`: Tilemap 클래스 (Lua 7 함수 + width/height 등 낱개 접근자)
- [x] `src/mrb_font.cpp`: FontEx 클래스 10 메서드
- [x] CMake: mruby 탐지, `mruby-config` 의 정의 반영, `INITIAL2D_MRUBY` 옵션. Android JNI
      목록에 `ScriptRuntime.cpp` 추가 (mruby 자체는 아직 Android 에 없다. 6절)
- [x] 테스트 인프라: `tests/ruby/`(프레임워크 `test.rb`, `run_tests.rb`, `manifest.rb`,
      케이스 10 개), 러너의 `test_mruby_units`, `.rb` 씬 지원, `--features` 탐지
- [x] `tests/engine/scenes/mruby_assert_scene.rb`: Lua 씬과 같은 골든
- [x] `scripts/ruby/games/flappy.rb` + `scripts/ruby/main.rb`: Ruby 로 쓴 게임 하나와 진입점
- [x] `tests/engine/scenes/mruby_flappy_scene.rb`: 자동 시연 인수 (씨앗 고정, 스스로 끝냄)
- [x] 문서: README 의 「mruby 스크립팅」(빌드, 고르기, Lua 대응표, 예제), 이 문서, index.md
- [x] CI: `brew install mruby`

## 4. 완료 기준

- [x] `INITIAL2D_SCRIPT=mruby ./build/Initial2D` 로 Ruby 플래피가 뜬다 (헤드리스 유한 실행으로 확인)
- [x] Lua 검증 씬을 옮긴 Ruby 씬이 **같은 골든**을 통과한다
- [x] mruby 단위 테스트가 Lua 의 바인딩 테스트(API 표면, 폰트 폭, JSON, 시트 분할, 타일맵)를
      전부 덮고 통과한다
- [x] 스크립트 예외가 종료 코드 1 과 역추적으로 드러난다 (수동 확인: update 안의 raise,
      문법 오류, dispose 뒤 사용, main.rb 없음)
- [x] mruby 가 없는 빌드도 그대로 빌드되고 Lua 게임이 돈다 (`INITIAL2D_MRUBY=OFF`)
- [x] 기존 전체 스위트가 무변경 통과한다 (C++ 무수정 원칙은 이 단계에 해당 없음. 엔진에
      스크립트 백엔드를 더하는 일이 곧 목적이다)

## 5. 구현 메모

1. **훅 호출은 `mrb_funcall_argv` + 아레나 복원.** VM 밖에서 부르는 호출은 mruby 가 스스로
   보호하므로 예외는 `mrb->exc` 에 남는다. 매 프레임 부르는 자리라 `mrb_gc_arena_save/restore`
   로 아레나를 되돌리지 않으면 아레나가 넘친다.
2. **`Kernel#load` 안의 예외는 다시 던진다.** 중첩 실행(`mrb_load_file_cxt`)에서 새어 나온
   예외는 `mrb->exc` 로 돌아오므로 `mrb_exc_raise` 로 호출자에게 올려야 `rescue` 가 잡는다.
   문법 오류도 같은 길로 `SyntaxError` 가 된다.
3. **엔진 계약 둘이 테스트에서 드러났다.** `Sprite#set_frames(first, last)` 의 `last` 는
   "끝의 다음"(Sprite.cpp: `endFrame = endNum - 1`)이고, `Audio.volume=` 는 0..255 를 받아
   SDL_mixer 의 0..128 로 바꾼다 (`SoundManager.cpp`). 둘 다 Lua 와 같은 계약이라 바인딩을
   고치지 않고 테스트 라벨에 근거를 적었다.
4. **헤드리스는 초당 1000 프레임 가까이 돈다.** 틱은 벽시계 60Hz 라 `INITIAL2D_EXIT_AFTER`
   로는 게임 시간을 잴 수 없다. 플래피 인수 씬은 틱을 스스로 세어 900 틱에 끝내고,
   `EXIT_AFTER` 는 안전망이다. 파이프 간격은 난수라 `srand(1)` 로 고정했다 (씨앗 1..6 전부
   1 점 이상을 냈고, 1 은 5 점을 내고 한 번 죽어 다시 시작한다).
5. **`mrb_obj_respond_to` 는 비공개 메서드도 찾는다.** 최상위 `def init` 은 Object 의 비공개
   메서드라 `respond_to?` 로는 안 보이지만 C API 는 가시성을 보지 않는다. Ruby 쪽 테스트는
   `respond_to?(:load, true)` 로 본다 (mruby 에는 `private_method_defined?` 가 없다).
6. **libmruby 의 macOS 배포 대상 경고**(bottle 은 26.0, 링크는 15.5)는 무해하다. 필요하면
   `CMAKE_OSX_DEPLOYMENT_TARGET` 을 올린다.

## 6. 남은 것

- **Android 에는 mruby 가 아직 없다.** JNI 빌드는 `ScriptRuntime.cpp` 를 넣어 Lua 만으로
  그대로 돌고, `INITIAL2D_SCRIPT=mruby` 는 "이 빌드에는 mruby 가 없다"로 끝난다. NDK 로
  libmruby 를 교차 빌드해 `android/app/jni` 에 얹는 일이 다음이다.
- **Windows(GDI) 는 손대지 않았다.** `main.cpp` 가 `Script_*` 를 부르므로 vcxproj 에
  `ScriptRuntime.cpp` 를 더해야 링크되는데, 그 프로젝트는 이미 `lua_json.cpp`,
  `lua_tilemap.cpp` 도 빠져 있어 별도 정리가 필요하다 (GDI 무수정 원칙과 별개의 빌드 파일 문제).
- **핫 리로드**는 `.rb` 도 같은 경로로 받아 VM 을 다시 만든다. `tools/hmr_push.py` 가
  확장자를 가리지 않는지는 실기에서 확인하지 않았다.
- 다른 데모(알데바란, 마을)를 Ruby 로 옮기는 것은 이 단계의 목표가 아니다. 필요해지면
  `scripts/rpg/` 를 Ruby 로 다시 쓰는 것이 아니라 어느 한 언어로 정하는 결정이 먼저다.
