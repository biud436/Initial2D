# R4. 배포용 엔진 빌드와 템플릿 묶음: 「다른 컴퓨터에 복사해도 뜨는 실행 파일 한 개」

> 작성일 2026-09-27. **권장 모델 Opus 5** (정적 링크에서 같은 실패가 두 번 나면 Fable 5). 에디터 트랙(index.md 8절)의
> 네 번째 단계이고, 에디터 쪽 짝은 E6(배포, `InitialEditor/docs/plans/e6-packaging.md`)의 마일스톤 2 다.
> E6 문서 3.1 절이 초안이고 이 문서가 정본이다. E6 의 "결정 기록 (2026-09-27)" 이 초안 본문을 바꾼 곳은 2절에 적었다.

## 1. 목표 (한 문장)

**Homebrew 가 없는 컴퓨터에 복사해도 뜨는 엔진 실행 파일 하나와, 에디터가 새 프로젝트에 복사할 템플릿을 생성물까지
한 묶음으로 만든다.** 에디터(Tauri 앱)는 이 실행 파일을 사이드카로 싣고, 템플릿 묶음에서 새 프로젝트를 만든다.

## 2. 결정

| 결정 | 이유 |
|---|---|
| **태그와 공개 릴리스를 만들지 않는다** | E6 결정 기록. `dist.yml` 은 `workflow_dispatch` 와 관련 파일을 고친 PR 에서 돌고 **워크플로 산출물**만 올린다. `v2.*` 태그 트리거는 있지만 그때도 산출물만 나온다. 릴리스는 저자가 정한다 |
| **엔진 `LICENSE` 를 더하지 않는다** | E6 결정 기록 (저자 결정). 메타데이터에도 라이선스를 적지 않는다. 제3자 고지 `THIRD-PARTY.md` 는 의무라 만든다 |
| **타깃은 `aarch64-apple-darwin` 과 `x86_64-unknown-linux-gnu` 둘** | Intel 맥은 지원하지 않는다. Windows SDL2 엔진(R5)은 이 단계 밖이고 `RS_WINDOWS`, `RSLIB`, GDI 코드는 손대지 않았다. `build_dist.sh` 는 다른 타깃에서 멈춘다 |
| **SDL 셋은 소스에서 정적으로** (`INITIAL2D_VENDORED_SDL`, 기본 OFF) | Homebrew 의 dylib 를 싣으면 libpng, jpeg, webp 같은 의존이 줄줄이 따라온다. 정적 실행 파일 하나면 Tauri 의 `externalBin` 한 줄로 끝난다. 켜면 Homebrew 를 찾지 않는다 |
| **PNG 와 JPG 는 stb_image, OGG 는 stb_vorbis** | 외부 라이브러리 없이 디코더가 들어간다. Apple 기본인 ImageIO 는 색 처리가 달라 골든을 움직일 수 있어 끈다 (`SDL2IMAGE_BACKEND_IMAGEIO=OFF`). 전체 씬 검수가 골든 대조 17건을 모두 통과하고, 골든 차이 비율이 Homebrew(libpng) 빌드와 한 자리까지 같다 (8절) |
| **포맷 스위치는 안드로이드와 같다** | 이미지 AVIF, JXL, TIF, WEBP 와 소리 FLAC, MOD, MP3, MIDI, OPUS, WAVPACK 을 끈다. 디코더가 필요한 것 가운데 png, jpg, ogg, wav 만 남는다 |
| **Linux 는 X11, Wayland, ALSA, PulseAudio 를 dlopen** | SDL 기본값(`*_SHARED` ON)을 그대로 둔다. 실행 파일은 glibc 계열과 libstdc++, libgcc_s 에만 링크되고, 창과 소리 라이브러리는 실행하는 컴퓨터의 것을 연다 |
| **배포 대상 macOS 11.0** | `CMAKE_OSX_DEPLOYMENT_TARGET` 은 `project()` 전에 둔다. rake 는 이 값을 물려받지 않으므로 `build_mruby.sh` 가 `MACOSX_DEPLOYMENT_TARGET=11.0` 을 내보낸다. libmruby 의 오브젝트도 minos 11.0 이다 |
| **mruby 는 소스 빌드** (`tools/build_mruby.sh`, 4.0.0, full-core) | tests.yml 의 대체 경로와 같은 설정이다 (`build_config/default.rb` 에서 gembox 만 바꾼다). `-D` 정의가 Homebrew 병과 같다 (`MRB_USE_BIGINT`, `MRB_USE_COMPLEX`, `MRB_USE_RATIONAL`, `MRB_USE_SET`, `MRB_USE_TASK_SCHEDULER`, `MRB_UTF8_STRING`, `HAVE_MRUBY_IO_GEM`, `HAVE_MRUBY_ENCODING_GEM`). 태그의 커밋(`831da26`)을 확인한다 |
| **`MRUBY_ROOT` 를 주면 그 폴더만 본다** (`NO_DEFAULT_PATH`) | 기본 탐색은 PATH 의 `/opt/homebrew/bin` 에서 `/opt/homebrew/lib` 까지 보므로, 배포용 빌드가 Homebrew 의 libmruby 를 줍지 않게 막는다. 배포용 빌드에서 `MRUBY_ROOT` 가 없으면 Lua 만이다 |
| **판 헤더는 빌드마다 만든다** (초안은 설정 때) | `cmake/initial2d_version.cmake` 를 사용자 정의 대상이 빌드마다 부르고, 내용이 같으면 파일을 건드리지 않는다. 설정 때 한 번 만들면 커밋한 뒤 `cmake --build` 만 할 때 옛 커밋이 찍힌다 |
| **describe 는 v2 이상의 태그만 본다** (`--match "v[2-9]*"`) | `v1.0.0`, `v1.1.0` 은 Windows GDI 판 태그라 SDL2 엔진이 `v1.1.0-215-g...` 로 보이면 틀린 말이다. 그런 태그가 없는 지금은 짧은 커밋이다 (예: `2234d67`) |
| **모르는 `--` 인자는 종료 코드 2** | 전에는 모든 인자를 무시하고 게임을 띄워, `--version` 조차 작업 폴더에 `config.setting` 을 썼다. 이제 `App::Run` 전에 사용법을 stderr 에 찍고 끝난다. `-psn_` 같은 한 줄표 인자는 그대로 무시한다 |
| **중간 산출물은 `build-dist/engine` 과 `build-dist/mruby`** (초안은 `build-dist` 하나) | 엔진의 CMake 빌드 폴더와 mruby 의 rake 빌드 폴더를 나눴다. 결과물은 `dist/` 이고 셋 다 gitignore |
| **타일맵 템플릿은 새로 그리지 않는다** | E6 결정 기록. 코드로 그린 새 도트는 저자가 받아들이지 않은 방식이다. 이미 커밋되어 `resources/maps/sample.json` 과 씬 로더 픽스처가 쓰는 `resources/tiles/tileset16-8x13.png`(2020년, RTP 아님)를 그대로 쓴다. 초안의 `tiles16.png` 와 `tools/gen_template_tiles.py` 는 만들지 않았다 (6절) |
| **표식 칸은 그리지 않고 있는 타일에서 고른다** | 타일 44(0 부터, gid 45)는 모래이고 256 픽셀 가운데 251 개가 `#d8c880` 이다. 템플릿 맵은 이 타일을 쓰지 않는다 |
| **템플릿 묶음 잡을 따로 둔다** | 플래피 그림 넷은 생성물이라 묶는 곳에서 만든다. `templates` 잡이 macOS 배포용 엔진을 받아 그 그림으로 플래피 씬 검수를 돌린 뒤 묶는다 (검수에 쓴 바로 그 그림) |
| **`lua_font.cpp` 가 `<locale>` 을 직접 포함한다** | libstdc++ 의 `<codecvt>` 는 `std::wstring_convert` 를 선언한 `<locale>` 을 들이지 않아 Linux 에서 컴파일이 실패했다. 포함 한 줄로 고쳤다 (GDI 경로가 아닌 공용 파일이고 동작은 같다) |

## 3. 바뀐 것

| 파일 | 무엇 |
|---|---|
| `CMakeLists.txt` | 옵션 `INITIAL2D_VENDORED_SDL`(켜면 배포 대상 11.0), 캐시 변수 `MRUBY_ROOT`, SDL 셋을 `add_subdirectory(... EXCLUDE_FROM_ALL)` 로 정적 빌드하는 분기와 캐시 값 전부 (`SDL_SHARED=OFF`, `SDL_STATIC=ON`, `SDL_TEST=OFF`, `BUILD_SHARED_LIBS=OFF`, `SDL2IMAGE_BACKEND_IMAGEIO=OFF`, `SDL2IMAGE_BACKEND_STB=ON`, `SDL2IMAGE_DEPS_SHARED=OFF`, `SDL2MIXER_DEPS_SHARED=OFF`, `SDL2MIXER_VORBIS=STB`, 포맷 스위치, 설치와 예제 끔), 판 헤더 대상 `initial2d_version`. Homebrew 빌드의 길은 그대로다 |
| `cmake/initial2d_version.cmake` (신규) | `generated/initial2d_version.h` 에 `INITIAL2D_VERSION_DESCRIBE` 와 `INITIAL2D_VERSION_COMMIT`. git 이 없으면 `unknown` (보통 빌드는 그대로 된다). 배포용 빌드 `tools/build_dist.sh` 는 판 정보에 커밋 40자를 실어야 하므로 git 체크아웃이 아니면 처음에 멈춘다 |
| `src/platform/sdl2/sdl2Main.cpp` | `--version` 과 모르는 `--` 인자의 종료 코드 2. 옵션은 어느 자리에 와도 같고 한 줄표 인자(macOS 의 `-psn_`)는 무시한다. 판 헤더는 `__has_include` 로 찾아 안드로이드 빌드는 손대지 않았다 (`unknown`) |
| `tools/sdl_versions.sh` (신규) | SDL2 2.30.9, SDL2_image 2.8.2, SDL2_mixer 2.8.0 의 판, 주소, tar.gz 의 sha256 |
| `tools/fetch_sdl_src.sh` (신규) | 셋을 `external/sdl-src/` 에 받고 sha256 을 확인한다. 같은 판이면 건너뛴다 |
| `android/download_sdl.sh` | 판과 주소를 `tools/sdl_versions.sh` 에서 읽는다 |
| `tools/build_mruby.sh` (신규) | mruby 4.0.0 을 `external/mruby-src/` 에 받아 `build-dist/mruby/host` 로 빌드한다. macOS 는 Homebrew 의 ruby 와 bison 을 앞에 둔다 (시스템 ruby 2.6 으로 만든 빌드는 presym 헤더가 빠질 수 있다). 결과에 `presym/id.h` 가 없으면 실패 |
| `tools/build_dist.sh` (신규) | 위 셋을 부르고 `cmake -DCMAKE_BUILD_TYPE=Release -DINITIAL2D_VENDORED_SDL=ON -DMRUBY_ROOT=...`, `--target Initial2D`, `strip`, macOS 는 ad-hoc 재서명, `dist/Initial2D-<트리플>` 과 `dist/engine-dist.json` |
| `tools/engine_dist_json.py` (신규) | `engine-dist.json` 쓰기(`add`)와 타깃별 파일 합치기(`merge`, 커밋이 다르면 실패) |
| `tools/check_dist.sh` (신규) | 4절의 검사 |
| `THIRD-PARTY.md` (신규) | 네이티브와 웹 판의 제3자 고지 (7절) |
| `resources/templates/tilemap/` (신규) | `map.json`, `scene.json`, `map-objects.json` (6절) |
| `tools/templates_list.txt` (신규) | 템플릿 묶음에 넣는 엔진 경로 32개 (5절) |
| `tools/pack_templates.py` (신규) | `dist/Initial2D-templates.zip` 과 그 안의 `MANIFEST.json` |
| `tests/tools/templates_test.py` (신규), `tests/run_all.sh` | 템플릿 검사. 3단계(도구 self-test)에서 돈다 |
| `tests/run_engine_tests.py` | 실행 파일 인자의 상대 경로를 절대 경로로 바꾼다 (씬마다 임시 작업 폴더에서 돌기 때문. 검사는 그대로) |
| `.github/workflows/dist.yml` (신규) | 9절 |
| `.gitignore` | `external/sdl-src/`, `external/mruby-src/`, `build-dist/`, `dist/` |

## 4. 배포용 실행 파일과 검사

이 맥(macOS 26.5, Xcode SDK 15.5)에서 만든 `dist/Initial2D-aarch64-apple-darwin` 은 3.4 MB 이고 minos 11.0 이다.
`otool -L` 에는 `/usr/lib/libSystem.B.dylib`, `/usr/lib/libc++.1.dylib`, `/usr/lib/libobjc.A.dylib` 와
`/System/Library/Frameworks/` 의 프레임워크(Cocoa, IOKit, CoreAudio, AudioToolbox, Metal 등. GameController,
CoreHaptics, Metal, QuartzCore 는 weak)만 있다. 처음 빌드부터 링크가 됐고 후퇴안(dylib 를 `Contents/Frameworks/` 로)은 필요 없었다.

`tools/check_dist.sh [실행 파일]` 이 보는 것:

1. **의존**: macOS 는 `otool -L` 이 `/usr/lib/` 와 `/System/Library/` 뿐, `otool -l` 의 minos 가 11.0, `lipo -archs` 가
   arm64, `codesign --verify` 통과. Linux 는 `ldd` 가 `linux-vdso`, `libc`, `libm`, `libdl`, `libpthread`, `librt`,
   `ld-linux`, `libstdc++`, `libgcc_s` 뿐이고 `not found` 가 없다. 요구하는 glibc 판을 INFO 로 찍는다
2. **인자**: `--features` 에 `lua` 와 `mruby`, `--version` 이 `Initial2D <describe> <커밋 40자>` 이고 커밋이 저장소의
   HEAD (다른 커밋과 대조하려면 `INITIAL2D_EXPECT_COMMIT`), describe 가 `-dirty` 면 WARN. `--bogus` 가 종료 코드 2 이고
   사용법은 stderr 에만. 세 실행 모두 빈 작업 폴더에 아무것도 쓰지 않는다 (게임을 띄우기 전에 끝났다는 뜻)
3. **유한 실행**: 커밋된 PNG, WAV, OGG 를 임시 프로젝트에 두고 Lua 스크립트와 Ruby 스크립트를 `INITIAL2D_EXIT_AFTER=30`
   으로 돌린다. 종료 코드 0, PNG 를 읽고(`TextureManager.Load`), Ruby 는 WAV 와 OGG 까지(`Audio.play_sound`,
   `Audio.play_music` 의 참), 마지막 destroy 훅이 불린다
4. **고지**: `THIRD-PARTY.md` 의 표에 `tools/sdl_versions.sh` 의 SDL 판과 `tools/build_mruby.sh` 의 mruby 판이 있다

실행은 모두 `mktemp -d` 의 작업 폴더에서 `perl -e 'alarm shift; exec @ARGV'` 시간 제한(인자 20초, 유한 실행 60초)으로 하고,
`SDL_VIDEODRIVER=dummy`, `SDL_AUDIODRIVER=dummy` 를 준다. Homebrew 빌드(`build/Initial2D`)에 돌리면 의존과 minos 둘이
실패하는 것을 확인했다.

`dist/engine-dist.json` 의 모양. `describe` 와 `engineCommit` 은 실행 파일의 `--version` 에서 오고, `engineTag` 는 HEAD 를
가리키는 v2 이상의 태그다 (없거나 dirty 빌드면 `null`). 같은 커밋이면 다른 타깃의 항목을 이어받는다.

```json
{
  "comment": "...",
  "engineTag": null,
  "describe": "2234d67",
  "engineCommit": "2234d673b7f2eb30b1b38f2773c2bb4f5b835b27",
  "native": {
    "aarch64-apple-darwin": { "asset": "Initial2D-aarch64-apple-darwin", "size": 3432688, "sha256": "...", "features": ["lua", "mruby"] }
  }
}
```

## 5. 템플릿 묶음

`tools/templates_list.txt` 는 InitialEditor 의 `scripts/sync-engine-templates.mjs`(next 와 feat/e4-play 가 같다)가 복사하는
원본(`from`) 28개 전부와 타일맵 템플릿 넷이다: 씬 로더 두 언어와 `scene_types/tilemap`, `hangul.fnt` 와 그 그림, API 명세,
진입 파일 둘과 빈 프로젝트의 씬, 플래피의 씬과 컴포넌트 열과 그림 넷과 효과음 셋, 그리고 타일맵의 맵, 씬, 스키마, 타일셋.
새 프로젝트 안의 경로(`to`)와 템플릿 그룹은 에디터가 정한다.

`python3 tools/pack_templates.py [--list ...] [--out ...] [--allow-dirty]` 는 목록의 파일을 엔진 경로 그대로
`dist/Initial2D-templates.zip` 에 넣고 맨 앞에 `MANIFEST.json` 을 둔다.

```json
{
  "comment": "...",
  "engineCommit": "<40자>",
  "describe": "2234d67",
  "files": [ { "path": "resources/background_768x896.png", "size": 86170, "sha256": "...", "generated": true } ]
}
```

- `generated` 는 `git ls-files` 에 없는 파일이다. 지금은 플래피 그림 넷뿐이다 (`templates_test.py` 가 그 넷뿐인지 본다)
- 목록의 파일이 하나라도 없으면 종료 코드 1. 목록의 추적 파일이 HEAD 와 다르면 종료 코드 1 이고, `--allow-dirty` 면
  MANIFEST 에 `"dirty": true` 를 적고 계속한다
- zip 안의 날짜와 권한을 고정해 같은 파일이면 같은 바이트가 나온다 (두 번 묶어 sha256 이 같은 것을 확인했다)

## 6. 타일맵 템플릿

| 파일 | 내용 |
|---|---|
| `resources/templates/tilemap/map.json` | 맵 포맷 v2, 이름 `start`, 16px 타일 48x56 칸(화면 768x896). 레이어 `ground`(전부 gid 46, 민 잔디)와 `deco`(한 칸 안쪽의 울타리 테두리: 모서리 73 과 75, 가로 74, 세로 57 과 65 번갈아), 통행 레이어(울타리와 그 바깥이 1), 오브젝트와 이벤트 없음. 타일셋은 `resources/tiles/tileset16-8x13.png`(firstGid 1, 8열). 쓴 타일은 모두 `sample.json` 이 쓰는 것이다. `tools/mapfile.py` 의 고정 형식이다 |
| `resources/templates/tilemap/scene.json` | 씬 포맷 v1, 이름 `main`, 오브젝트 `map` 하나: 타입 `tilemap`, `props.map` 은 `resources/maps/start.json`, `groundLayers` 1 |
| `resources/templates/tilemap/map-objects.json` | 오브젝트 스키마 v1. 타입 `marker`(표식) 하나: 점 모양, 색 `accent`, 칸 `label`(글). `play` 절은 없다 |

빈 `objects` 배열은 `mapfile.py` 가 쓰지 않으므로(비어 있지 않을 때만 쓴다) 맵 파일에 키가 없는 것이 "빈 objects" 다.

**새 프로젝트 안의 자리** (에디터가 `sync-engine-templates.mjs` 에 더할 때의 제안이고 `templates_test.py` 가 이 자리로 늘어놓고 돌린다):
`map.json` 은 `resources/maps/start.json`, `scene.json` 은 `resources/scenes/main.json`(진입 파일의 기본 씬이 `main` 이라
`game.json` 없이 열린다), `map-objects.json` 은 `resources/schema/map-objects.json`, 타일셋은 같은 경로
`resources/tiles/tileset16-8x13.png`. 그리고 공통 그룹(씬 로더, `scene_types/tilemap`, `hangul.fnt`)과 진입 파일.

**표식 칸**: 타일 44(0 부터 센 번호, gid 45, 5행 4열의 모래)는 256 픽셀 가운데 251 개가 `#d8c880` 이고 나머지 다섯은
모래 알갱이 점이다 (가운데 8x8 은 전부 그 색). 템플릿 맵에는 이 타일이 없고, 칸 (24, 28) 은 deco 가 비고 통행할 수 있다.
에디터의 스크린샷 검사는 그 칸을 gid 45 로 칠하고 칸 안의 픽셀이 `#d8c880` 인지 보면 된다. `templates_test.py` 가 같은 일을
엔진에서 해 본다 (칠하기 전은 잔디, 칠한 뒤는 표식 색 251/256 이상).

`tests/tools/templates_test.py [엔진]` 이 보는 것: 맵이 `mapfile.dumps` 로 바이트 그대로 다시 쓰인다, 크기와 레이어와 통행과
타일셋(git 이 추적, 열 수, gid 범위), 표식 타일의 색과 맵에 없음, 씬과 스키마의 모양, 새 프로젝트처럼 늘어놓은 임시 폴더에서
템플릿의 진입 파일로 씬을 열어(Lua 와 Ruby) 종료 코드 0 과 오류 줄 없음과 화면(잔디, 위에 그린 울타리, 칠한 표식), 그리고
`templates_list.txt` 와 `pack_templates.py`. 씬을 일부러 틀리게(`groundLayers` -1) 고치면 두 언어의 로더 검사가 잡는 것을 확인했다.

## 7. 제3자 고지 (`THIRD-PARTY.md`)

네이티브와 웹 판이 한 파일을 쓴다. 표(이름, 판, 라이선스, 네이티브, 웹)와 원문. 초안의 목록(SDL 셋, stb, Lua, mruby, JsonCpp,
SQLite, TinyXML, 나눔고딕)에 실제로 들어가는 것을 더했다:

- SDL2_image 안의 NanoSVG(zlib), QOI(MIT), miniz(PNG 저장, 퍼블릭 도메인), TinyJPEG(JPG 저장, 퍼블릭 도메인)
- SDL2 안의 HIDAPI(BSD 를 고름), yuv2rgb(BSD 3조항), SDL_rotate(zlib), controller_type(zlib), Linux 의 edid-parse 와 imKStoUCS(MIT)
- mruby 와 함께 든 gem 의 저작권자(IIJ, yui-knk)
- 웹 판의 emsdk 6.0.10 포트: SDL2 2.32.10, SDL2_image 2.6.0, libpng 1.6.58, zlib 1.3.2, IJG libjpeg 9f(문서에 적어야 하는
  문장 포함), libogg 1.3.5, libvorbis 1.3.7, Emscripten 런타임, musl. LLVM libc++ 등은 LLVM 예외로 원문을 싣지 않는다

SQLite 는 코어 라이브러리와 함께 빌드하지만 지금 실행 파일에는 링크되지 않는다 (`nm` 으로 확인). 판을 올리면 표와 해당 절을
고치고, `check_dist.sh` 가 네이티브의 SDL 셋과 mruby 판이 표에 있는지 본다.

## 8. 검수 결과 (이 맥, 2026-09-27)

| 무엇 | 결과 |
|---|---|
| `tools/build_dist.sh` | Apple M1 8코어에서 mruby 약 30초, SDL 셋과 엔진 약 40초. 새 경고는 `ld: warning: ignoring duplicate libraries: '-lm'` 하나다 (나머지 경고는 엔진과 SDL 의 기존 코드에서 나온다) |
| `tools/check_dist.sh` | 27 PASS / 0 FAIL |
| 배포용 실행 파일로 전체 씬 검수 (`python3 tests/run_engine_tests.py dist/Initial2D-aarch64-apple-darwin`) | 575 PASS / 0 FAIL, 골든 대조 17건(그림 11장) 전부 허용 안 (RTP 가 없는 작업 트리라 RTP 검사 하나는 SKIP, Homebrew 빌드와 같다) |
| `tests/tools/templates_test.py` (배포용 실행 파일, Homebrew 빌드) | 44 PASS / 0 FAIL |
| `tools/pack_templates.py` | 파일 32개, 980 KB, 생성물 넷 |
| `SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy tests/run_all.sh` (Homebrew 빌드) | 전체 검수 통과 (엔진 씬 575 PASS / 0 FAIL, `templates_test.py` 44 PASS). 오디오 드라이버를 주지 않으면 mruby 단위의 소리 검사 셋(`play_music`, `play_sound` 둘)이 거짓으로 실패하는데, 같은 맥에서 master `fab4710` 을 빌드해도 똑같이 실패해 이 단계와 무관하다 (이 맥의 기본 출력 장치가 가상 장치 `Blackhole+` 다) |
| 골든 차이 비율 (배포용 대 Homebrew) | 두 빌드가 같다: 골든 검사 17건 가운데 15건이 0.0000%, `assert_scene_f35` 를 보는 두 건이 0.4139% (허용 2%). stb 디코더가 libpng 와 다른 픽셀을 내지 않는다 |
| actionlint 1.7.12 (shellcheck 0.11.0 연동) | `dist.yml` 경고 없음. 새 셸 스크립트들도 shellcheck 경고 없음 |
| GCC 14 와 libstdc++ 로 엔진 소스의 문법 검사 (Linux 의 위험을 미리 본 것) | `lua_font.cpp` 하나가 `std::wstring_convert` 로 실패, `#include <locale>` 한 줄로 통과 |

## 9. `dist.yml`

- 트리거: `workflow_dispatch`, PR 에서 `CMakeLists.txt`, `cmake/**`, `sdl2Main.cpp`, `tools/` 의 배포 도구와 목록,
  `resources/templates/**`, `templates_test.py`, `THIRD-PARTY.md`, 이 워크플로가 바뀔 때, `v2.*` 태그. 릴리스 단계는 없다
- `native` 행렬 (`macos-26` aarch64, `ubuntu-22.04` x86_64): 의존(macOS 는 `ruby bison`, Linux 는 SDL 소스 빌드용
  `libx11-dev` 등과 `ruby bison`), `tools/build_dist.sh`(판 헤더가 dirty 가 되지 않게 그림 생성보다 먼저),
  `tools/check_dist.sh`, 그림 생성, 씬 검수(macOS 는 전체, Linux 는 `--only=flappy` 로 플래피 씬 셋),
  `templates_test.py`, 산출물 `engine-<트리플>`
- `templates` (`macos-26`, native 뒤): macOS 엔진 산출물을 받아(zip 이 잃은 실행 권한을 되돌린다) 그림을 만들고, 그 그림으로
  플래피 씬 검수와 `templates_test.py` 를 돈 뒤 `pack_templates.py`. 산출물 `templates`
- `collect` (`ubuntu-22.04`): 엔진 둘, 템플릿 묶음, `engine_dist_json.py merge` 로 합친 `engine-dist.json`,
  `THIRD-PARTY.md`, `SHA256SUMS.txt` 를 산출물 `initial2d-dist-<커밋>` 하나로. 에디터 CI 가 `yarn engine:fetch --from` 으로 쓸 폴더다
- 판 정보를 만드는 잡(네이티브 둘과 템플릿)은 `git describe` 가 태그를 보도록 `fetch-depth: 0`. 모으는 잡은 git 을 쓰지 않아 기본 체크아웃이다. `SDL_VIDEODRIVER=dummy`, `SDL_AUDIODRIVER=dummy`
- 기존 `tests.yml`(Homebrew 빌드의 전체 검수)은 그대로다

## 10. 확인하지 못한 것과 저자에게 남긴 것

**CI 에서만 볼 수 있는 것 (이 맥에서 돌리지 못했다)**

- Linux 잡 전체. 엔진은 Linux 에서 빌드된 적이 없다. 로컬에서 본 것은 GCC 와 libstdc++ 의 문법 검사(macOS 헤더 위, `__linux__`
  분기는 빼고)와 스크립트의 Linux 분기(`nproc`, `sha256sum`, `ldd`, `objdump`)를 읽어 본 것뿐이다. 링크(정적 SDL 의 `-ldl`,
  `-lpthread`, `-lrt`), `ldd` 허용 목록, dlopen 으로 뜨는 dummy 드라이버, Linux 의 플래피 씬 셋, 요구 glibc(ubuntu-22.04 라 2.35 이하일 것)는 첫 CI 실행이 보여 준다
- GCC 가 알린 경고 하나: `src/Point.h` 의 `operator=` 에 `return *this;` 가 없다 (정의되지 않은 동작. clang 최적화 빌드는
  전체 검수를 통과했다)
- macOS 잡의 러너(Xcode 판)에서의 링크와 minos. 이 맥은 SDK 15.5 다
- `templates` 잡에서 다시 만든 효과음 WAV 가 커밋된 것과 바이트가 다르면 `pack_templates.py` 가 "HEAD 와 다르다" 로 멈춘다
  (로컬에서는 같았다. 그림 생성기는 표준 라이브러리의 시드 난수와 `math.sin` 만 쓴다)

**저자에게 남긴 것** (2026-09-27 저자가 판단을 맡겨 정했다)

- 태그 `v2.0.0-alpha.1` 과 공개 릴리스: 에디터 E5 와 E6 이 병합되고 CI 가 녹색이면 두 저장소에 프리릴리스로 낸다. 엔진에는 라이선스를
  더하지 않는다 (오픈 소스 라이선스는 사실상 되돌릴 수 없고, 엔진은 저자의 에디터 안에 실려 나가므로 없어도 된다)
- `resources/tiles/tileset16-8x13.png`: 저자의 2020년 커밋이다. 타일맵 템플릿에 그대로 두고 출처는 모른다고 적는다
- 나눔고딕: 구운 비트맵 글꼴의 이름을 `Initial2D Hangul` 로 바꿨다 (PR #55). `THIRD-PARTY.md` 에 나눔고딕의 OFL 고지가 있다

## 작업 항목 (E6 마일스톤 2)

- [x] `tools/sdl_versions.sh`, `tools/fetch_sdl_src.sh`, `android/download_sdl.sh` 가 같은 판 번호를 읽는다
- [x] `CMakeLists.txt` 의 `INITIAL2D_VENDORED_SDL` 과 캐시 값 전부 (정적, ImageIO 끔, 의존 공유 끔, 포맷 스위치, Linux 의 dlopen 기본값 유지), `MRUBY_ROOT` 힌트, 배포 대상 11.0, 판 생성 헤더
- [x] `tools/build_mruby.sh` (`MACOSX_DEPLOYMENT_TARGET=11.0`, `mruby-config --cflags` 의 정의를 엔진이 그대로)
- [x] `sdl2Main.cpp` 의 `--version` 과 모르는 `--` 인자의 종료 코드 2
- [x] `tools/build_dist.sh`, `tools/check_dist.sh` (시간 제한과 임시 작업 폴더, `minos` 11.0, `--bogus` 가 2)
- [x] `THIRD-PARTY.md`
- [x] 타일맵 템플릿 `resources/templates/tilemap/` (있는 타일셋, `mapfile.py` 형식의 맵, 씬, 스키마)와 `tests/tools/templates_test.py`
- [x] `tools/templates_list.txt`, `tools/pack_templates.py` (`generated` 표시, 빠진 파일이면 실패)
- [x] macOS: 배포용 실행 파일로 전체 씬 검수 통과
- [x] Linux: 플래피 씬 셋 (첫 CI 실행. `dist.yml` 실행 36297974450 의 `native (ubuntu-22.04)` 잡: 씬 셋이 스스로 끝났고 템플릿 씬을 Lua 와 Ruby 로 열어 종료 코드 0, 동적 의존은 glibc 계열과 libstdc++, libgcc_s 뿐, 요구 glibc 는 `GLIBC_2.35`)
- [x] `.github/workflows/dist.yml` (native 둘, templates, collect. 산출물만, 릴리스 없음)
- [x] `dist.yml` 의 첫 CI 실행 (macOS 와 Linux). PR #53(36281586493)과 #55(36297974450)에서 네 잡(native 둘, templates, collect)이 모두 통과했다. 에디터 `release.yml` 도 핀의 커밋에서 같은 스크립트로 엔진을 만들어 설치본 자가 검사에 싣는다
- [x] 기존 `tests.yml` 과 전체 검수가 무변경으로 통과한다 (Homebrew 빌드 경로는 그대로)
- [x] 엔진 문서 (이 문서, index 의 R4 행, README 의 "배포용 빌드")
