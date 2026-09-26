# M1. 맵 오브젝트: 「알데바란의 배치가 맵 파일에 있다」

> 작성일 2026-09-26. 에디터 트랙(index.md 8절)의 단계이고, 에디터 쪽 짝은 E3(타일맵 확장의 오브젝트 레이어,
> InitialEditor `docs/plans/e3-tilemap.md`)이다. C++ 무수정.

## 1. 목표 (한 문장)

**시작 지점, 체크포인트, 몬스터, 흔적, 구간이 맵 파일의 `objects`에 있고, 에디터는 그것을 맵 위에서 보고
고치며, Lua 판과 Ruby 판이 같은 파일을 읽는다.** 스테이지 모듈은 맵에서 옮기기 전과 같은 표를 만든다.

## 2. 무엇이 어디에 있는가

| 스테이지 칸 (Lua / Ruby) | 맵 오브젝트 | 만드는 규칙 |
|---|---|---|
| `START` / `start` | `start` 점 하나 | `{ x, y }` |
| `CHECKPOINTS` / `checkpoints` | `checkpoint` 점 | `{ x, y }`, x 오름차순 (한 프레임에 둘을 지나면 먼 쪽이 부활 지점) |
| `spawns` | `spawn` 점, props `species`, `minX`, `maxX`, `boss` | 파일 순서 그대로. Ruby 키는 `min_x`, `max_x`, 종은 Symbol. `boss`는 참일 때만 둔다 |
| `LANDMARKS` / `landmarks` | `landmark` 띠, props `title`, `text`, `skill`, `hallucination` | `x0 = x`, `x1 = x + width` (양 끝 포함). id는 오브젝트 id |
| `SECTIONS` / `sections` | `section` 띠, prop `name` | `x1 = x + width`, x 오름차순. 띠는 앞 구간의 x1에서 시작한다 (첫 띠는 0) |
| `CLIMATE.stars.pillars` | `light` 점 | 그 방(구간) 안의 light x, 파일 순서 |

읽는 코드는 `scripts/lua/games/aldebaran/stages/placement.lua`와 `scripts/ruby/games/aldebaran/stages/placement.rb`
한 쌍이다. 맵은 `Json.Load` / `Json.load`로 경로마다 한 번 읽고, 표는 스테이지 모듈이 읽힐 때 한 번 만든다
(씬이 `cp.taken`을 적고 인수 씬이 `spawns`와 `CLIMATE.sun`을 바꾸므로 같은 표를 돌려줘야 한다).
시작 지점이나 구간이 없는 맵은 모듈을 읽는 순간 오류를 던진다. 구간의 섞기 규칙(`sectionAt`)도 두 스테이지가
같으므로 placement의 공용 함수가 되었다.

### 2.1 코드에 남긴 것과 이유

| 남긴 것 | 이유 |
|---|---|
| 번호, 제목, BGM, 환각 그림, 안개, 보스 종류, 도입 종류, 목숨, 시드 | 자리가 아니다 |
| 이야기 글 (`INTRO`, `EPILOGUE`, `EPILOGUE_FULL`, `GAMEOVER`) | 자리가 아니다. 흔적의 글은 자리에 붙은 글이라 오브젝트로 갔다 |
| `SECTION_FADE` (96) | 구간 경계의 규칙이다 |
| 기후 수치 (마찰, 눈송이 수, 주기, 켜짐 시간, 우박 간격과 예고와 데미지, 수위, 배율) | 방 전체에 걸리는 수치이고, 방은 구간 이름으로 찾는다. 홍수의 `low`/`high`는 y 좌표이지만 물은 방의 폭 전체에 그려지므로 x 범위가 없는 값이다. 에디터에는 가로선 모양이 없고, 사각형으로 두면 뜻 없는 x와 폭이 생긴다 |
| 빛기둥의 폭 `halfW` (44) | 세 기둥이 함께 쓰는 폭이고 그리기도 같은 폭을 쓴다. 그래서 빛기둥은 띠가 아니라 점이다 (띠로 두면 기둥마다 폭을 바꿀 수 있는 것처럼 보인다) |
| `SIGNS` (빈 표) | 두 스테이지 모두 비어 있고 씬도 읽지 않는다 (표지 글은 흔적이 대신한다). 타입을 만들지 않았다 |

빛기둥 x만 옮긴 이유: 영혼은 빛 안에서만 벨 수 있으므로 영혼의 배치는 빛기둥과 함께 보아야 한다.
에디터에서 둘이 한 화면에 보이는 것이 실제로 쓸모가 있다.

## 3. 오브젝트 id와 개수

| 맵 | 오브젝트 | id |
|---|---|---|
| `aldebaran_forest.json` | 29 (start 1, checkpoint 2, spawn 16, landmark 5, section 5) | `start`, `checkpoint_1`~`2`, `spawn_1`~`16`, `tracks`, `road`, `cart`, `cage`, `altar`, `section_entrance`, `section_road`, `section_gorge`, `section_den`, `section_altar` |
| `aldebaran_tomb.json` | 34 (start 1, checkpoint 2, spawn 18, landmark 5, section 5, light 3) | `start`, `checkpoint_1`~`2`, `spawn_1`~`18`, `chest`, `moon`, `stars`, `ruin`, `sarc`, `section_chest`, `section_moon`, `section_stars`, `section_ruin`, `section_sun`, `light_1`~`3` |

`spawn_n`의 번호는 옮기기 전 `M.spawns`의 순서다. 몬스터 id와 난수 소비가 이 순서를 따른다. 띠 모양
(landmark, section)의 y는 0이고 쓰지 않는다. light의 y는 별들의 방 바닥(416)이며 표시용이다.

## 4. 정수와 실수

Lua 5.3과 mruby 모두 JSON의 `3`을 정수로, `3.0`을 실수로 읽는다. 그런데 에디터(`JSON.stringify`)와
`tools/mapfile.py`는 `3.0`을 `3`으로 쓴다. 그래서 파일의 모양에 기대지 않고 모듈이 바꾼다.

- 원래 실수였던 칸은 `hallucination` 하나다 (`3.0`). Lua는 `* 1.0`, Ruby는 `.to_f`.
- 좌표, 폭, 순찰 범위, 빛기둥 x는 원래 정수였고 JSON에서도 정수로 온다.
- 기후 수치는 코드에 남았으므로 리터럴 그대로다.

단위 테스트가 모든 숫자의 `math.type` / 클래스까지 비교한다. 변환을 빼 보면 Lua와 Ruby 모두
`hallucination: 3(integer), 기대 3.0(float)`으로 깨진다 (확인함).

## 5. 스키마와 실행 환경

`resources/schema/map-objects.json` (형식은 InitialEditor `packages/ext-tilemap/src/model/schema.ts` 머리 주석).

| 타입 | 이름 | 모양, 색 | 칸 |
|---|---|---|---|
| `start` | 시작 지점 | 점, success, unique | |
| `checkpoint` | 체크포인트 | 점, success | |
| `spawn` | 몬스터 | 점, danger | `species` enum(종별 표의 키 여덟, 정의 순서), `minX`/`maxX` number(rangeMin/rangeMax), `boss` boolean |
| `landmark` | 흔적 | 띠(기본 폭 48), warning | `title` string, `text` text, `skill` enum(`Combat.SKILL_ORDER`), `hallucination` number(0 이상) |
| `section` | 구간 | 띠(기본 폭 768), muted | `name` enum (숲 다섯, 무덤 다섯) |
| `light` | 빛기둥 | 점, accent | |

`play.env`는 에디터의 실행 버튼이 채워 넘기는 환경 변수다.

```json
{ "INITIAL2D_SCENE": "aldebaran", "INITIAL2D_SKIP_INTRO": "1",
  "INITIAL2D_ALDEBARAN_STAGE": "{map.name}", "INITIAL2D_ALDEBARAN_AT": "{x}" }
```

- `INITIAL2D_ALDEBARAN_STAGE`는 스테이지 id(`tomb`) 말고도 맵 이름(`aldebaran_tomb`, 파일 이름이나 맵의
  `name`), 파일 이름(`aldebaran_tomb.json`), 프로젝트 기준 경로(`resources/maps/aldebaran_tomb.json`,
  `./`로 시작해도 된다), 그 경로로 끝나는 절대 경로(역슬래시도 된다)를 받는다. `Stages.get`이 이름을
  풀기 때문에 `game.lua`와 `game.rb`의 부르는 쪽은 그대로다. 다른 폴더의 같은 이름 파일은 받지 않는다.
- `INITIAL2D_ALDEBARAN_AT`은 x만 준다. y는 시작 지점의 y(384)인데, 그 x의 지면이 더 높으면 캐릭터가
  땅속에서 시작해 움직이지 못했다 (숲의 턱과 절벽 대부분). 그래서 발이 지면 속이면 한 칸씩 올려 지면
  위에 세운다 (`Placement.standY` / `stand_y`). 지면이 더 낮으면 그대로 두어 떨어진다. 기존 검수가 쓰는
  x(무덤 2480, 4300)는 지면이 더 낮은 자리라 결과가 같다.
- 구덩이 위의 x는 그대로 두면 떨어져 목숨을 잃고 앞 체크포인트에서 다시 시작했다 (숲 협곡의 발판
  열 128~131, 135~139와 빈 구덩이 열 132~134). 그래서 씬은 `Placement.startSpot` / `start_spot`으로 설
  자리를 고른다. 떨어져 닿는 땅 위에 몸(20px)이 들어가면 `standY`의 y를 그대로 쓰고, 아래가 바닥까지
  비었거나 닿는 땅 위가 좁으면 그 칸 위쪽의 가장 가까운 설 자리(발판)에 세운다. 그 칸에 설 자리가
  없으면 좌우 16칸 안에서 가장 가까운 칸의 가운데로 옮기고(거리가 같으면 왼쪽), 로그에 한 줄
  `알데바란: 시작 x 2120 → 2104 (구덩이 위라 가까운 땅으로)`를 남긴다. 16칸 안에 없으면 예전처럼 그대로
  둔다. 무덤 2480, 4300은 여전히 384라 인수 씬의 로그와 골든이 같다.
- `INITIAL2D_SCENE=aldebaran`과 `INITIAL2D_SKIP_INTRO`는 두 언어의 진입 파일(`main.lua`, `main.rb`)과
  씬이 이미 받는다.

## 6. 맵 파일의 형식과 생성기

맵 파일은 에디터의 `serializeMap`과 바이트 단위로 같은 형식으로 쓴다 (정해진 규칙은
[02-tilemap.md](02-tilemap.md)의 "저장 형식"). 쓰는 코드는 `tools/mapfile.py` 하나이고 두 생성기가 함께 쓴다.

- `write_map(path, data)`: 정해진 형식으로 쓰고 `"version": 2`. 기존 파일의 `objects`, `events`,
  생성기가 만들지 않는 최상위 키를 이어받는다. 타일, collision, tilesets는 생성기가 새로 쓰므로
  **손으로 칠한 타일은 덮인다.** 기존 파일이 JSON이 아니면 오브젝트를 잃지 않도록 쓰지 않고 멈춘다.
- `selftest`: 작은 맵 하나(정수 모양의 키, 한글과 제어 문자, 실수와 지수 표기, 빈 props, 모르는 키)를
  에디터가 쓴 텍스트와 비교한다. 기대 텍스트는 InitialEditor의 `format.ts`를 esbuild로 묶어 node로 돌린
  결과를 그대로 옮긴 것이다. 실수 표기는 무작위 실수 2만 개로 `JSON.stringify`와 대조했다.
- `check`/`format`: 파일이 정해진 형식인가 / 정해진 형식으로 다시 쓴다.

옮긴 맵 두 장은 옮기기 전과 타일, collision, tilesets의 값이 같고(파싱해 비교), 에디터의 `parseMap` +
`serializeMap`에 넣었다 빼도 한 바이트도 다르지 않으며, 생성기를 다시 돌려도 바이트가 같다.

## 7. 검수

| 무엇 | 결과 |
|---|---|
| Lua 단위 `aldebaran_map_objects_test` | 120건 (스키마 형식, 두 맵의 오브젝트 검사와 검사기 자체의 검사, 종과 힘과 구간 이름 목록, 고정값 대조, 스테이지 이름, 지면 위로 올리기, 구덩이 위의 시작 자리) |
| mruby 단위 `aldebaran_map_objects_test.rb` | 104건 (같은 내용. 종 목록은 정의 순서까지) |
| 고정값 대조 | 옮기기 전 표를 테스트에 리터럴로 적고, **옮기기 전 코드에 먼저 돌려 통과**시킨 뒤 옮겼다 |
| 알데바란 인수 씬 (Lua, Ruby) | 각 80건, 골든 세 장 그대로. 인수 씬, 무덤 주파, 홍수 넓은 화면의 로그가 옮기기 전과 한 글자도 다르지 않다 |
| `tests/run_all.sh` [3/6] | `mapfile.py selftest`와 두 맵의 `check`를 더했다 |
| 전체 스위트 (헤드리스) | 통과. C++ 단위 18, 엔진 씬 446 (Lua 단위 1919건, mruby 단위 1885건 포함), 브리지 25 |

## 8. 작업 항목

- [x] 스키마 `resources/schema/map-objects.json` (타입 여섯, `play.env`)
- [x] 두 맵에 `objects`를 넣고 v2와 정해진 형식으로 다시 쓰기 (타일 값 무변경 확인)
- [x] 스테이지 모듈(Lua, Ruby)이 맵에서 같은 표를 만든다 (`stages/placement.*`)
- [x] `INITIAL2D_ALDEBARAN_STAGE`가 맵 이름과 맵 파일 경로를 받는다 (두 언어)
- [x] 옮긴 시작 x가 지면 속이면 지면 위로 올린다 (두 언어)
- [x] 옮긴 시작 x가 구덩이 위면 그 칸의 발판이나 가까운 칸의 땅에 세운다 (두 언어)
- [x] 공용 쓰기 모듈 `tools/mapfile.py`와 self-test, 생성기 둘이 그것을 쓰고 `objects`를 보존
- [x] 단위 테스트 두 벌, 전체 스위트
- [x] 문서: 02-tilemap.md, aldebaran-7-tomb.md, README, index.md

## 9. 남은 것

- **에디터 쪽 기본값.** 스키마에서 `default`가 없는 enum 칸은 에디터가 새 오브젝트에 첫 값을 넣는다
  (`schema.ts`의 `defaultProps`). 그래서 새 흔적에는 `skill: "edge"`가 들어간다. 무덤의 흔적처럼 힘을
  주지 않는 흔적은 그 칸을 지워야 하므로, 에디터의 인스펙터에 선택 칸을 비우는 방법이 필요하다.
- **구간과 지형의 경계.** 구간 띠를 옮겨도 생성기의 `SECTIONS`/`ROOMS`(지형과 타일의 성격)는 따라오지
  않는다. 방을 옮기려면 둘을 함께 고쳐야 한다.
- **AT의 y.** 설 자리는 x 한 줄만 보고 고른다. 몸 높이는 보지만 몸 폭(12px)이 옆 칸에 걸치는지는 보지
  않는다. 한 칸에 설 자리가 여럿이면 384 근처를 먼저 고르므로 에디터가 고른 층과 다를 수 있다. 에디터가
  고른 y까지 쓰려면 `INITIAL2D_ALDEBARAN_AT`이 `x,y`를 받게 하고 `play.env`를 `"{x},{y}"`로 바꾸면 된다.
