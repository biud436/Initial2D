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
- **이벤트는 이 파일에 넣지 않는다.** 맵 파일은 타일 데이터만 담고, 엔티티 배치는 스크립트(`scripts/maps/map1.lua`)가 담당한다 (6단계). 데이터와 로직의 경계를 여기서 긋는다.
- **오토타일은 v1에서 제외.** 에디터 쪽도 미구현 상태다 (룩업 테이블만 있고 로직은 주석 처리). v2 후보.
- 인코딩은 압축 없는 정수 배열로 시작한다. 50x38 x 4층이면 압축이 필요 없는 크기다.

## 작업 항목

- [ ] 맵 포맷 v1을 위 명세로 확정하고, 샘플 맵 파일을 수작업으로 하나 만든다 (에디터보다 먼저, 엔진 개발용).
- [ ] `src/Tilemap.cpp` 재작성:
  - JSON 로드 (jsoncpp), 다층 지원, gid 해석, 타일셋 텍스처 로드
  - 그리기: 타일마다 `Sprite`를 만들지 않고 렌더러에 직접 소스 사각형 복사, **카메라 오프셋 인자**를 받아 화면 밖 타일은 건너뛴다 (컬링)
  - 경로는 반드시 `NormalizePath`를 통과시킨다
- [ ] Lua 바인딩 `Tilemap.*` (새 파일 `src/lua_tilemap.cpp`):
  - `Load(path)` → 핸들, `Dispose(handle)`
  - `Draw(handle, layerFrom, layerTo, camX, camY)` — 레이어 범위를 나눠 그릴 수 있어야 캐릭터를 층 사이에 끼워 그릴 수 있다 (5단계에서 사용)
  - `GetSize(handle)`, `GetTileId(handle, x, y, layer)`, `SetTileId(...)`
  - `IsPassable(handle, x, y)` — collision 레이어 조회
- [ ] 기존 죽은 코드 정리: `scripts/tilemap.lua` 데모를 새 API 기반 예제로 교체, `resources/maps/map.lua`(Tiled 잔재)와 `settings.json`의 절대 경로 정리.
- [ ] 픽셀 검증 테스트 추가 (`tests/run_engine_tests.py` 방식): 샘플 맵을 그린 스크린샷 비교.

## 완료 기준

- [ ] 화면보다 큰 샘플 맵(예: 50x38)을 2개 층으로 그리고, 방향키로 카메라를 스크롤하는 데모 씬이 60fps로 동작한다.
- [ ] `IsPassable`이 Lua에서 올바른 값을 돌려준다.
- [ ] macOS와 Android 양쪽에서 확인.

## 의존 관계

- 선행: 1단계 (JSON 바인딩. 다만 Tilemap이 자체적으로 JSON을 읽으므로 A항목 전체를 기다릴 필요는 없음)
- 후행: 3단계(포맷 공유), 5단계(통행 판정과 레이어 분할 그리기)
