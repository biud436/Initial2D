# 2단계: 타일맵 시스템과 맵 포맷 v1

**권장 모델**: Claude Fable 5 (최소 Opus 5) — 렌더러 재작성과 맵 포맷 설계는 이후 모든 단계(에디터 연동, RPG 프레임워크)의 토대라 아키텍처 판단의 비중이 크다. 포맷을 한 번 잘못 정하면 두 저장소를 동시에 고쳐야 한다.

> 목표: 다층 타일맵을 그릴 수 있는 C++ 렌더러와 Lua API를 만들고, InitialEditor와 공유할 맵 파일 포맷 v1을 확정한다.
> 타일맵은 RPG 전용이 아니다. 퍼즐, 플랫포머, 로그라이크 모두 쓰는 범용 기능이므로 C++ 코어에 들어간다.

## 왜 필요한가

- 현재 C++ `src/Tilemap.cpp`는 실행 경로에서 아예 생성되지 않는 죽은 코드이며, 버그가 많다: `resize` 후 `push_back`으로 벡터가 2배가 되는 문제, 타일셋 열 수 8 하드코딩, 백슬래시 경로. **수정이 아니라 재작성 대상이다.**
- `scripts/tilemap.lua`는 타일 ID를 계산만 하고 버리는 데모 수준이다.
- 타일 하나당 `Sprite` 객체 하나를 만드는 기존 방식은 맵이 커지면 못 쓴다. 화면에 보이는 타일만 직접 그리는 방식이 필요하다.

## 맵 포맷 v1 (JSON)

에디터(3단계)와 엔진이 공유하는 계약이다. 에디터 내부의 평탄한 배열 구조(`data[z*W*H + y*W + x]`)를 레이어별 배열로 나눠 직렬화한다.

```json
{
  "version": 1,
  "name": "마을",
  "id": 1,
  "width": 50,
  "height": 38,
  "tileWidth": 16,
  "tileHeight": 16,
  "layers": [
    { "name": "ground", "data": [0, 12, 12, "…(width*height개, 행 우선)"] },
    { "name": "deco",   "data": ["…"] }
  ],
  "collision": ["…width*height개, 0=통행 가능, 1=불가"],
  "tilesets": [
    { "image": "resources/tiles/Exterior.png", "firstGid": 1, "columns": 30 }
  ]
}
```

설계 노트:

- **타일 ID는 Tiled 방식의 gid.** `0`은 빈 칸, 타일셋마다 `firstGid`를 부여하고 `지역 ID = gid - firstGid`, 아틀라스 좌표는 해당 타일셋의 `columns`로 계산한다. 에디터의 "합성 캔버스 전역 인덱스"는 내보내기 시점에 gid로 변환한다 (3단계 참고).
- **`collision`은 범용 충돌 레이어다.** "통행 불가"는 RPG만의 개념이 아니므로 포맷에 둔다. 4방향 통행이나 지형 태그 같은 RPG식 확장은 v2로 미루고, v1은 0과 1만 쓴다.
- **이벤트는 이 파일에 넣지 않는다.** 맵 파일은 타일 데이터만 담고, 엔티티 배치는 스크립트(`scripts/maps/map1.lua`)가 담당한다 (6단계). 데이터와 로직의 경계를 여기서 긋는다. → **v2에서 뒤집힌 결정이다** (아래).
- **오토타일은 v1에서 제외.** 에디터 쪽도 미구현 상태다 (룩업 테이블만 있고 로직은 주석 처리). v2 후보.
- 인코딩은 압축 없는 정수 배열로 시작한다. 50x38 x 4층이면 압축이 필요 없는 크기다.

## 맵 포맷 v2 (2026-08-19, 9단계)

v1에 `events` 배열 하나가 더해진 것이다. 나머지는 v1과 같고, 타일 렌더러가 보는 부분은 전혀 바뀌지 않는다. **v1 파일은 그대로 열린다.**

```json
{
  "version": 2,
  "…v1과 같은 필드…": "…",
  "events": [
    { "id": "sign", "x": 13, "y": 37, "trigger": "action",
      "commands": [ { "code": "message", "text": "마을 게시판이다." } ] }
  ]
}
```

v1의 "이벤트는 맵 파일에 넣지 않는다"를 뒤집은 이유는 하나다. **맵 에디터가 이벤트를 만들 수 있어야 하기 때문이다** (이슈 24). Lua 함수는 에디터가 만들 수도 읽을 수도 없지만, 커맨드 목록(`scripts/rpg/commands.lua`)은 순수 데이터라 맵 파일에 그대로 실린다.

데이터와 로직의 경계는 사라진 것이 아니라 옮겨 갔다.

| 어디에 | 무엇이 | 누가 만드는가 |
|---|---|---|
| 맵 파일의 `events` | 좌표, 트리거, 커맨드 목록 | 에디터 (사람이 손으로 적어도 된다) |
| `scripts/maps/<이름>.lua` | 배회 설정, `script` 함수, BGM, 시작 위치 | 사람 |

둘은 `id`로 합쳐지며, 같은 `id`면 Lua 쪽이 이긴다 (`scripts/rpg/mapdata.lua`) — 에디터가 놓은 이벤트에 사람이 살을 붙이는 길이다. 엔진은 `events`를 읽지 않는다. C++ 타일맵 로더는 버전만 받아들이고, 이벤트는 Lua가 `Json.Load`로 읽는다.

계약 픽스처는 `tests/fixtures/maps/sample_v2.json`이며 두 저장소가 같은 파일을 검증한다 (09-testing.md 3.5절).

## 작업 항목

- [x] 맵 포맷 v1을 위 명세로 확정하고, 샘플 맵 파일을 수작업으로 하나 만든다 (에디터보다 먼저, 엔진 개발용). — `resources/maps/sample.json` (80x70, ground+deco 2층, tileset16-8x13). 계약 픽스처는 `tests/fixtures/maps/sample_v1.json` (4x3, 09-testing.md 3.5절)
- [x] `src/Tilemap.cpp` 재작성:
  - JSON 로드 (jsoncpp), 다층 지원, gid 해석, 타일셋 텍스처 로드
  - 그리기: 타일마다 `Sprite`를 만들지 않고 렌더러에 직접 소스 사각형 복사, **카메라 오프셋 인자**를 받아 화면 밖 타일은 건너뛴다 (컬링)
  - 경로는 반드시 `NormalizePath`를 통과시킨다
- [x] Lua 바인딩 `Tilemap.*` (새 파일 `src/lua_tilemap.cpp`):
  - `Load(path)` → 핸들, `Dispose(handle)`
  - `Draw(handle, layerFrom, layerTo, camX, camY)` — 레이어 범위를 나눠 그릴 수 있어야 캐릭터를 층 사이에 끼워 그릴 수 있다 (5단계에서 사용)
  - `GetSize(handle)`, `GetTileId(handle, x, y, layer)`, `SetTileId(...)`
  - `IsPassable(handle, x, y)` — collision 레이어 조회
- [x] 기존 죽은 코드 정리: `scripts/tilemap.lua` 데모를 새 API 기반 예제로 교체(`scripts/games/tilemap_demo.lua`, 메뉴 허브에 등록), `resources/maps/map.lua`(Tiled 잔재)와 `settings.json`(절대 경로) 삭제.
- [x] 픽셀 검증 테스트 추가 (`tests/run_engine_tests.py` 방식): 샘플 맵을 그린 스크린샷 비교. — 카메라 좌상단/우하단 두 실행, 골든 2장 + 특징색 영역 카운트, Lua 단위 테스트 49건

## 완료 기준

- [x] 화면보다 큰 샘플 맵을 2개 층으로 그리고, 방향키로 카메라를 스크롤하는 데모 씬이 60fps로 동작한다. — 2026-08-15 확인: 300프레임 6.1초(vsync 상한 ~59fps), CPU 프레임당 약 5.7ms. 샘플은 50x38 대신 80x70으로: 기본 논리 해상도 768x896보다 양 축 모두 커야 스크롤이 검증된다
- [x] `IsPassable`이 Lua에서 올바른 값을 돌려준다.
- [x] macOS와 Android 양쪽에서 확인. — 2026-08-15 Galaxy S24 실기: 타일맵 데모 진입, 62fps, 탭으로 꽃 심기, 가상 D-패드 홀드로 카메라 스크롤(112→224→47), 뒤로가기로 메뉴 복귀 확인. **실기 검수에서 드러난 것**: 키보드가 없는 플랫폼에서 방향키 데모는 쓸 수 없으므로 터치 D-패드 공용 모듈 `scripts/ui/vpad.lua`(에셋 `resources/ui/dpad.png`, 생성기 `tools/generate_ui_assets.py`)를 만들고 데모에 연결했다. 5단계 캐릭터 이동에서 같은 모듈을 쓴다

## 구현 노트 (2026-08-15)

- **좌표 규약**: `x`, `y`는 0 기준 타일 좌표(맵 데이터·에디터와 동일), `layer`는 1 기준 인덱스(Lua 배열 관례), `camX`, `camY`는 월드 픽셀. C++ 내부는 레이어도 0 기준이고 바인딩에서 변환한다.
- **범위 밖 계약**: `GetTileId`는 0, `IsPassable`은 false(맵 밖으로 못 나감), `SetTileId`는 false를 돌려준다. `collision`이 없는 맵은 전부 통행 가능.
- **그리기 경로**: 플랫폼 코드를 새로 만들지 않고 기존 `TextureManager::DrawFrame`에 항등 트랜스폼(+이동)을 넘긴다. GDI와 SDL2 어댑터가 이미 있으므로 Tilemap은 플랫폼 중립으로 유지된다.
- **텍스처 소유권**: 타일셋 텍스처의 ID는 정규화된 이미지 경로다. `TextureManager`가 소유하고 캐시하므로 `Dispose` 후에도 남아 같은 타일셋을 쓰는 다른 맵이 재사용한다.
- **테스트 씬의 카메라 전환은 환경 변수로 한다** (`INITIAL2D_TEST_CAM`): 고정 스텝 루프에서 Lua `Update`는 렌더 프레임당 0~N회 실행되므로 Update 횟수 기반 전환은 스크린샷 프레임과 어긋난다. `GetFrameCount()`도 초마다 리셋되는 값(m_nFPS)이라 대안이 못 된다 (09-testing.md 4절).
- `src/win32Main.cpp`(RS_WINDOWS 전용, 무수정 원칙)는 옛 Tilemap API를 참조하지만 master의 어느 CMake 타겟에도 들어가지 않는다. Windows GDI 빌드는 `archive/windows-gdi` 브랜치가 보존한다.
- **터치 입력은 별도 API 없이 마우스 API로 받는다.** SDL이 첫 손가락 터치를 마우스로 매핑하므로 단일 터치 D-패드는 `Input.GetMouseX/Y`, `IsMousePress`로 충분하다. 방향 이동과 동시에 누르는 액션 버튼(6단계 말 걸기)이 필요해지면 그때 `Input`에 다중 터치 API를 더한다. 표시 여부는 `GetPlatform()`(신규 Lua 유틸)이 android/ios일 때, 또는 `INITIAL2D_VPAD=1`(데스크톱 확인용).
- Android 뒤로가기(SDL `AC_BACK`)는 `InputSDL2`에서 `VK_ESCAPE`로 매핑했다. 스크립트는 ESC 하나만 다루면 된다.
- **알려진 한계**: 키보드 상태는 프레임마다 SDL 상태 배열을 샘플링하므로 한 프레임(16ms)보다 짧은 누름은 놓친다. 사람 손가락은 문제없지만 `adb shell input keyevent` 같은 합성 입력은 `--longpress`로 보내야 잡힌다 (실기 검수 중 확인). 이벤트 래칭이 필요해지면 `Input`에 추가한다.

## 의존 관계

- 선행: 1단계 (JSON 바인딩. 다만 Tilemap이 자체적으로 JSON을 읽으므로 A항목 전체를 기다릴 필요는 없음)
- 후행: 3단계(포맷 공유), 5단계(통행 판정과 레이어 분할 그리기)
