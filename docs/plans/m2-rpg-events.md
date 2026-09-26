# M2. RPG 이벤트 데이터 계약과 이전: 「에디터가 쓴 이벤트를 엔진이 검사하고 돌린다」

> 작성일 2026-09-27. **권장 모델 Fable 5** (두 저장소가 함께 읽는 데이터 계약이라 한 번 굳으면 되돌리기
> 비싸다. 마일스톤 3의 이전은 Opus 5 로 충분하다). 에디터 트랙(index.md 8절)의 단계이고, 에디터 쪽 짝은
> E5(RPG 확장, InitialEditor `docs/plans/e5-rpg.md`)다. 이 단계의 출발점은 [12-editor-events.md](12-editor-events.md)
> 이고, E5 의 2026-09-27 조사로 달라진 곳은 이 문서가 고친다.
>
> **이 문서가 계약의 정본이다** (R1, M1 과 같은 선례). 두 스키마 파일(2절), 검증 경로와 검사 목록(3절),
> 환경 변수와 trace 줄(5절), 이전 규칙(6절)이 그 대상이다. 계약을 고칠 때는 이 문서를 먼저 고치고
> E5 문서는 이 문서를 링크한다. **커맨드 인자의 목록은 `resources/schema/event-commands.json` 자체가
> 정본**이라 어느 문서에도 표로 다시 적지 않는다. C++ 무수정.

## 1. 목표 (한 문장)

**에디터가 맵 파일의 `events` 에 쓴 이벤트를, 게임이 맵을 열 때 전부 검사해 틀린 것만 건너뛰고 나머지를
Lua 정의 파일의 이벤트와 똑같이 돌린다.** 커맨드 명세는 스키마 한 장이고, 엔진 테스트가 그 스키마를
`commands.lua` 와 양방향으로 대조한다. 항구 마을과 여관의 이벤트는 맵 파일로 옮겨 에디터가 편집할 수 있게 한다.

PR 은 둘로 나눈다. 각 PR 이 따로 병합되어도 엔진과 에디터가 깨지지 않는 순서다.

| PR | 마일스톤 | 내용 |
|---|---|---|
| 1. M2 계약 | 1 | 스키마 둘과 아이템 표, 검사와 trace, auto 고치기, 테스트. 게임의 겉모습은 그대로 |
| 2. M2 이전 | 3 | 이전 도구와 항구 마을, 여관의 이벤트를 맵 파일로. 에디터 E5 마일스톤 2(모델과 교차 검사) 뒤 |

E5 의 마일스톤 2, 4, 5, 6 은 에디터 저장소의 일이다.

## 2. 데이터 계약

### 2.1 파일 셋

| 파일 | 따르는 것 | 읽는 쪽 |
|---|---|---|
| `resources/schema/event-commands.json` | RPG 프레임워크(`scripts/lua/rpg/`). RPG 프로젝트마다 같은 파일이다 | 에디터(폼, 검사), 엔진 테스트(대조) |
| `resources/data/rpg-game.json` | 게임(rpgdemo) | 에디터(맵 등록, 실행 변수), 게임(맵 등록, 아이템 표 경로) |
| `resources/data/items.json` | 게임(rpgdemo) | 게임(`items.lua`), 에디터(아이템 칸의 제안과 경고) |

`resources/schema/` 는 형식의 설명이고 `resources/data/` 는 게임이 읽는 데이터라 폴더를 가른다 (7절 결정 기록).
게임 설정은 테스트의 대조 상대도 다르다 (프레임워크 대 rpgdemo).

### 2.2 `resources/schema/event-commands.json`

| 키 | 내용 |
|---|---|
| `version` | 1. 에디터가 모르는 버전이면 이벤트 레이어를 **읽기 전용으로 잠그고 이유를 띄운다**. 파일이 없으면 이벤트 레이어가 나오지 않는다 (플래피 프로젝트) |
| `event.fields` | 이벤트 칸 11개 (`id`, `x`, `y`, `dir`, `trigger`, `charset`, `through`, `solid`, `speed`, `wander`, `commands`). 이 순서가 저장할 때의 키 순서다 (2.6) |
| `event.reserved` | 이벤트 id 로 쓸 수 없는 이름. `player` 하나 (`moveRoute` 와 `turn` 의 `target` 에서 플레이어를 가리킨다) |
| `commands` | 커맨드 17종. 항목은 `code`, `label`, `group`(팔레트의 묶음), `summary`(선택, 트리의 한 줄 요약), `ends`(선택), `args`, `lists`(선택) |
| `conditions` | 조건 세 꼴. 항목은 `kind`, `label`, `args`. 첫 인자는 `kind` 와 같은 이름의 필수 인자다 |
| `assets` | 외형(`charset`)과 얼굴(`face`)의 논리 이름과 후보 파일 목록 (`Assets.SETS` 와 같다) |
| `sheets` | CharSet(`frameW`, `frameH`, `sheetCols`, `perSheet`, `patterns`, `standPattern`, `dirRows`)과 FaceSet(`size`, `cols`, `perSheet`)의 규격 |
| `route` | 이동 루트의 걸음. `moves`(네 방향), `turnPrefix`(`"turn:"`), `waitPrefix`(`"wait:"`, 뒤에 ms) |

인자 명세(`event.fields`, `args`)의 키는 `name`, `type`, `label`, `required`, `default`, `min`, `max`,
`values`(enum 의 값), `ref`(ref 의 종류), `accept` 와 `dir`(file 의 확장자와 시작 폴더), `suggest`(자유 입력 칸의 제안)
뿐이다. 이 밖의 키는 엔진 테스트 [A] 가 거절한다. 하위 목록 명세(`lists`)는 `name`, `label`, `perOption`.

규칙:

- `conditions` 의 순서가 엔진의 판정 순서다 (`item`, `flag`, `var`, `Commands.CONDITIONS`). 키가 둘 이상인 조건을 읽으면 에디터는 앞의 것으로 보고 경고한다
- item 조건의 기본값은 `Commands.test` 그대로다: `op` 와 `value` 가 둘 다 없으면 "하나 이상", `op` 만 없으면 `>=`, `value` 만 없으면 1. 그래서 item 의 `op` 에는 `default` 를 적지 않고 칸 이름으로 알린다. var 의 `op` 는 늘 `==` 가 기본이라 `default` 를 적는다
- `ends: true` 는 "이 뒤의 커맨드는 실행되지 않는다"(`transfer`, `scene`). 에디터가 그 뒤의 커맨드를 경고한다
- `lists` 의 `perOption` 은 그 목록이 그 인자(`options`)의 항목마다 하나라는 뜻이다. `branches[i]` 가 i 번째 항목의 가지다
- `summary` 의 `{이름}` 은 그 커맨드의 인자 이름이다. 없으면 에디터가 label 과 첫 필수 인자로 요약한다
- 스키마는 `commands.lua` 가 호스트에 넘기는 인자를 적는다. 데모 호스트가 버리는 인자(`playBgm.fade`, `Bgm.play` 가 쓰지 않는다)는 칸 이름에 "(지금 데모는 쓰지 않는다)"를 붙인다
- 모르는 키는 어디서든 보존한다 (이벤트, 커맨드, 조건). 에디터는 "스키마에 없는 인자"로 보여 주되 지우지 않는다
- `sheets.charset.standPattern` 은 서 있는 자세의 열(1)이다. `Specs.charset.standPattern` 과 Ruby `Rpg::Specs::CHARSET[:stand_pattern]` 이 같은 값을 갖고 규격 테스트가 못 박는다

### 2.3 인자 타입

| type | 값 | 위젯 | SPEC 의 Lua 타입 |
|---|---|---|---|
| `string` | 글 | 한 줄 입력 (`suggest` 가 있으면 제안 목록) | string |
| `text` | 글 (줄바꿈 포함) | 여러 줄 입력. 줄바꿈은 JSON `\n` 그대로 | string |
| `integer`, `number` | 수 | 숫자 입력, `min`/`max` | number |
| `boolean` | 참, 거짓 | 체크 상자. 필수가 아니면 세 상태(비움, 참, 거짓) | (필수 없음) |
| `enum` | `values` 중 하나 | 고르기. 파일의 값이 목록에 없으면 그 값을 덧붙여 보인다 | string |
| `scalar` | 참, 거짓, 수, 글 | 종류 고르기와 값 | (필수 없음) |
| `ref` | id 글 | 콤보 상자(제안과 자유 입력). 목록에 없으면 경고. `ref` 는 `map`, `item`, `flag`, `var`, `character` | string |
| `file` | 프로젝트 경로 (`./resources/...` 꼴로 쓴다, 2.6) | 파일 고르기 (`accept` 확장자, `dir` 시작 폴더) | string |
| `face` | `{ set 또는 file, index }` | FaceSet 4x4 격자를 눌러 고른다 | table |
| `charset` | `{ set 또는 file, index }` | CharSet 8명 격자를 눌러 고른다 (이벤트 칸) | table |
| `options` | 글 배열 | 항목 목록. 항목을 더하고 빼면 `branches` 와 `cancel` 을 함께 맞춘다 | table |
| `route` | 글 배열 | 걸음 목록 (이동, 돌기, 기다리기 ms) | table |
| `condition` | 조건 객체 | 종류 고르기와 그 종류의 칸 | table |
| `wander` | `{ minWait, maxWait, area }` | 켜기, 프레임 수 둘, 구역은 맵 위 사각형 | (이벤트 칸) |
| `json` | 아무 JSON | 글 상자와 해석 결과 (`script.args`) | (필수 없음) |
| `list` | 커맨드 배열 | 트리 | (이벤트 칸) |

`charset`, `wander`, `list` 는 이벤트 칸에만 쓴다. 마지막 열은 [C] 대조의 대응표이고, "(필수 없음)"인 타입은
필수 인자가 될 수 없다. 예외는 `script.name` 하나다 (스키마는 필수, 엔진은 SPEC 이 아니라 `validate` 의 따로 규칙으로 본다).

`ref` 의 제안 목록: `map` 은 `rpg-game.json` 의 맵 이름, `item` 은 아이템 표의 id, `character` 는 이 맵의 이벤트 id 와
`player`, `flag` 와 `var` 는 이 프로젝트의 맵 파일들에서 이미 쓰인 이름 (이름표는 나중 후보).

### 2.4 `resources/data/rpg-game.json`

```json
{
  "version": 1,
  "maps": [
    { "name": "port_town", "file": "resources/maps/port_town.json", "def": "scripts/lua/maps/port_town.lua" },
    { "name": "inn", "file": "resources/maps/inn.json", "def": "scripts/lua/maps/inn.lua" },
    { "name": "village", "file": "resources/maps/village.json", "alt": ["resources/maps/village_rtp.json"], "def": "scripts/lua/maps/village.lua" },
    { "name": "room", "file": "resources/maps/room.json", "alt": ["resources/maps/room_rtp.json"], "def": "scripts/lua/maps/room.lua" }
  ],
  "items": "resources/data/items.json",
  "play": {
    "env": {
      "INITIAL2D_SCRIPT": "lua",
      "INITIAL2D_SCENE": "rpg",
      "INITIAL2D_MAP": "{rpg.map}",
      "INITIAL2D_RPG_AT": "{cx},{cy},{dir}",
      "INITIAL2D_RPG_STATE": "{state}",
      "INITIAL2D_RPG_TRACE": "1"
    },
    "probe": { "INITIAL2D_AUTOPLAY": "1", "INITIAL2D_RPG_ROUTE": "{route}" }
  }
}
```

- 에디터만 읽는 파일이 아니다. **게임이 이 파일로 맵 등록(`MAPS`)을 만든다** (`def` 에서 `.lua` 를 뗀 모듈 경로).
  읽는 코드는 `scripts/lua/games/rpgdemo/config.lua` 하나다 (`Config.load`, `Config.mapModules`, `Config.mapEntry`,
  `Config.loadItems`). 그래서 맵 등록은 한 벌이고 따로 대조할 일이 없다. `play` 는 게임이 읽지 않는다
- `maps` 의 이름은 `transfer.map` 과 `INITIAL2D_MAP` 이 쓰는 이름이다. `file` 은 `INITIAL2D_NO_RTP` 기준으로 게임이 여는 맵,
  `alt` 는 같은 지오메트리의 RTP 판이다 (좌표와 크기가 같다)
- 경로는 프로젝트 기준 상대 경로이고 `./` 을 붙이지 않는다 (에디터 문서 경로와 같은 꼴). 정의 파일의 `map` 과 비교할 때는
  두 쪽 다 `./` 을 떼고 본다 (`Config.bare`)
- **이벤트 레이어가 붙는 맵은 여기서 정한다.** `file` 이나 `alt` 로 등록된 맵에만 붙고, `alt` 가 있는 항목(마을, 오두막)은
  두 파일에 이벤트를 두 벌 둬야 하므로 읽기 전용이다. 알데바란 맵과 `sample.json` 에는 레이어가 없다
- `INITIAL2D_SCRIPT` 를 `lua` 로 덧씌운다. RPG 이벤트 레이어는 Lua 에만 있다
- 값을 채울 수 없는 자리표시자가 든 변수는 넣지 않는다. 위치 없이 실행하면 `INITIAL2D_RPG_AT` 이 빠지고 정의 파일의 시작에
  선다. 시작 상태가 비었으면 `INITIAL2D_RPG_STATE` 가 빠진다
- `{state}` 는 에디터 실행 명령의 "시작 상태" 칸이다. `probe` 는 "이 이벤트 자동 재생"이 `env` 위에 더하는 변수다

`resources/schema/map-objects.json`(M1)의 `play` 에는 선택 칸 `maps` 를 더했다: `["aldebaran_*"]`. 맵 파일 이름(폴더 없이)과
대조하는 글롭이고 `*` 는 아무 글자열이다. 없으면 모든 맵에 걸린다. 그래서 알데바란의 실행 변수가 항구 마을에 걸리지 않는다.

### 2.5 `resources/data/items.json`

```json
{ "version": 1, "items": [
    { "id": "warehouse_key", "name": "창고 열쇠", "desc": "...", "order": 10 } ] }
```

- 칸은 `id`(겹치지 않는 글), `name`(소지품 창의 이름), `desc`(설명, 두 줄까지 보인다), `order`(목록 순서, 작은 것이 위)
- 게임의 `scripts/lua/games/rpgdemo/items.lua` 는 `rpg-game.json` 의 `items` 가 가리키는 이 파일을 읽어 id 로 찾는 표를
  돌려준다. 읽지 못하면 빈 표를 돌려주고 `rpg:error:<경로>: <이유>` 를 찍는다 (`rpg-game.json` 을 못 읽으면
  `rpg:error:rpg-game.json: <이유>`)
- 데이터베이스 패널은 두지 않는다 (E5 6절). 표는 JSON 편집으로 고치고, 에디터는 아이템 칸에서 목록으로 고르고 없는 id 를 경고한다

### 2.6 키 순서와 저장 형식

맵 파일은 M1 의 고정 형식(`serializeMap`, `tools/mapfile.py`)이다. `events` 안의 객체는 JSON 객체 그대로 쓰므로 **키 순서가 곧 diff** 다.

- 에디터는 손대지 않은 이벤트와 커맨드의 바이트를 바꾸지 않는다
- 고친 객체와 새 객체는 **정해진 순서**로 쓴다. 스키마에 없는 키는 어느 객체든 정해진 키 뒤에 원래 순서대로

| 객체 | 키 순서 |
|---|---|
| 이벤트 | `event.fields` 순서 (`id`, `x`, `y`, `dir`, `trigger`, `charset`, `through`, `solid`, `speed`, `wander`, `commands`) |
| 커맨드 | `code`, 그 커맨드의 `args` 순서, `lists` 순서 |
| 조건 | 그 종류의 `args` 순서 (`item`, `op`, `value` / `flag`, `equals` / `var`, `op`, `value`) |
| 외형과 얼굴 (`charset`, `face`) | `set` 또는 `file`, 그다음 `index` |
| 배회 (`wander`) | `minWait`, `maxWait`, `area` |
| 구역 (`area`) | `x`, `y`, `w`, `h` |
| 배열 (`options`, `route`, 하위 목록) | 원소 순서 그대로 |

- `file` 값은 엔진 데이터가 이미 쓰는 꼴 `./resources/...` 로 쓴다 (정의 파일의 `SE_DOOR = "./resources/audio/door.wav"`,
  `Assets` 후보 목록). 맵의 `tilesets[].image` 는 `resources/...` 꼴이지만 그것은 맵 형식이고 이벤트 인자와 따로다. 파일 위젯은
  두 꼴을 같은 파일로 보고(비교와 있는지 확인에서 `./` 을 뗀다), 새로 고른 값은 늘 `./` 을 붙여 쓴다
- 이전 도구(6절)도 같은 순서로 쓴다. 그래서 이전한 맵을 에디터로 열어 저장하면 바이트가 같다. 스키마에 없는 중첩 값(외형과 얼굴,
  배회, 구역)의 순서는 두 쪽 코드가 같은 표를 상수로 갖고, 테스트가 같은 표본 맵으로 대조한다

## 3. 검증 경로와 검사 목록

### 3.1 표기

엔진이 맵을 열 때 내는 경로와 에디터가 문제 목록에 보이는 경로를 같은 글자로 쓴다.

```
events[3].commands[2].branches[1][3].text
```

- 1부터 센다 (Lua). `events[i]` 는 맵 파일 `events` 배열의 i 번째다 (병합 전). JSON 의 `null` 도 한 칸으로 센다
- 엔진은 `MapData.validateEvents(events, env)` 가 이 꼴을 내고, 게임은 맵을 열 때 `rpg:error:<맵 파일>:<경로>: <이유>` 를 찍는다
- M1 의 오브젝트 경로(`objects[3].props.species`)는 0부터 센다. 오브젝트 경로는 에디터만 쓰고 이벤트 경로는 엔진이 내므로 엔진을 따른다
- **대조하는 것은 경로의 집합이다.** 이유 글은 대조하지 않는다. 같은 경로에 문제가 둘 이상일 수 있다

### 3.2 검사 목록 (두 저장소의 계약)

`validateEvents` 가 하는 검사다. 전부 오류이고, 에디터도 같은 것을 오류로 보며 편집 명령이 애초에 만들지 않는다.
경로 열은 `events[i]` 뒤에 붙는 꼴이다. 한 이벤트에 문제가 여럿이면 전부 낸다.

**정수**는 값이 정수인 수다 (`2.0` 도 정수로 본다, 에디터의 `Number.isInteger` 와 같다). 쓰는 도구(`mapfile.py`, 에디터)는 `2.0` 을 `2` 로 쓴다.

| 검사 | 경로 | 이 검사 전에 일어나던 일 |
|---|---|---|
| `events` 가 배열이 아니다 | `events` (앞에 붙는 것 없음) | 이벤트 읽기에서 오류 |
| 이벤트가 객체가 아니다 (`null` 포함) | `events[i]` | `spawnEvent` 에서 오류, 맵 전체 실패 |
| `id` 가 없거나 빈 글이거나 글이 아니다 | `.id` | `Event.new` assert |
| `id` 가 `player` 다 (예약) | `.id` | `characterById` 가 플레이어를 돌려줘 그 이벤트를 향한 `moveRoute` 가 플레이어를 움직인다 |
| `id` 가 같은 맵 파일의 앞 이벤트와 같다 (뒤의 것에 낸다) | `.id` | `MapData.merge` 가 앞의 것을 조용히 덮는다 |
| `x`, `y` 가 없거나 0 이상의 정수가 아니다 | `.x`, `.y` | 이상한 자리에 선다 |
| `dir` 이 네 방향이 아니다 (있을 때) | `.dir` | 외형이 있으면 `Character.new` assert, 맵 전체 실패 |
| `trigger` 가 넷(`action`, `touch`, `auto`, `parallel`)이 아니다 (있을 때) | `.trigger` | `Event.new` assert |
| `charset` 이 객체가 아니거나, `set` 과 `file` 이 둘 다 없거나 둘 다 있다 | `.charset` | `file` 이 없으면 플레이어 CharSet 으로 조용히 |
| `charset.set` 이 `assets.charset` 의 이름이 아니다 (글이 아닌 값 포함) | `.charset.set` | (새 칸) |
| `charset.file` 이 빈 글이거나 글이 아니다 | `.charset.file` | 그림을 읽지 못한다 |
| `charset.index` 가 0~7 의 정수가 아니다 (있을 때. 없으면 엔진이 0 으로 본다) | `.charset.index` | 첫 프레임의 `Specs.charsetFrameIndex` assert, 게임이 멈춘다 |
| `through`, `solid` 가 참거짓이 아니다 (있을 때) | `.through`, `.solid` | 참 같은 값으로 읽힌다 |
| `speed` 가 0 보다 큰 수가 아니다 (있을 때) | `.speed` | 0 이하면 첫 걸음을 끝내지 못하고, 수가 아니면 첫 걸음에서 산술 오류 |
| `wander` 가 객체가 아니다 | `.wander` | 배회 설정에서 오류 |
| `wander.minWait`, `wander.maxWait` 가 0 이상의 정수가 아니다 (있을 때) | `.wander.minWait`, `.wander.maxWait` | `rng:int` 가 틀린 범위를 받는다 |
| `minWait > maxWait`. 없는 쪽은 기본값(`minWait` 30, `maxWait` 120)으로 본다 | `maxWait` 가 있으면 `.wander.maxWait`, 없으면 `.wander.minWait` | 같다 |
| `wander.area` 가 객체가 아니다 (있을 때) | `.wander.area` | 구역 판정에서 오류 |
| `wander.area` 의 `x`, `y` 가 0 이상의 정수, `w`, `h` 가 1 이상의 정수가 아니다 | `.wander.area.x` (칸마다) | 구역 판정이 틀린다 |
| `commands` 가 배열이 아니다 (있을 때) | `.commands` | `Commands.validate` 가 이미 낸다 |
| 커맨드 검사: 커맨드가 객체가 아니다, 모르는 `code`, 필수 인자의 Lua 타입, `choice` 항목 0개, `script` 이름, 하위 목록(`thenDo`, `elseDo`, `branches`, `branches[k]`)이 배열이 아니다 | `.commands[j]`, `.commands[j].text`, `.commands[j].options`, `.commands[j].name`, `.commands[j].elseDo`, `.commands[j].branches[k][l].text` 꼴 | `Commands.validate` 그대로 (앞에 `events[i].commands` 를 붙인다) |
| `message.face` 가 객체가 아니거나 `set` 과 `file` 이 둘 다 없거나 둘 다 있다 | `.commands[j].face` | 얼굴이 안 나오거나 오류 |
| `face.set` 이 `assets.face` 의 이름이 아니다, `face.file` 이 빈 글이거나 글이 아니다 | `.commands[j].face.set`, `.commands[j].face.file` | 같다 |
| `message.face.index` 가 0~15 의 정수가 아니다 (있을 때. 없으면 0) | `.commands[j].face.index` | 대화 도중 `Specs.facesetRect` assert, 게임이 멈춘다 |
| `transfer.dir`, `turn.dir` 이 네 방향이 아니다 (있을 때). 글이 아닌 `turn.dir` 는 필수 인자의 타입 검사가 한 번만 낸다 | `.commands[j].dir` | transfer 는 다음 맵의 `Character.new` assert, turn 은 아무것도 안 한다 |

- 커맨드 쪽 검사(얼굴, 방향 포함)는 `Commands.validate` 에 있다. 그래서 정의 파일(Lua)의 이벤트도 같은 검사를 받는다.
  이벤트 칸의 검사는 `validateEvents` 가 맵 파일 이벤트에만 한다 (정의 파일은 `Event.new` 가 지금처럼 본다)
- 외형과 얼굴의 모양 검사는 `Assets.checkRef(kind, ref)` 하나를 두 쪽이 함께 쓴다. `set` 은 파일로 풀기 전의 값이고,
  검사는 풀기 전에 한다 (`MapData.resolveAssets` 는 검사 뒤에 부른다)
- 에디터만의 검사(맵 밖, 같은 칸, 없는 참조, 끝난 뒤의 커맨드, 비어 있는 조건 등, E5 3절과 4절)는 엔진이 모르는 것이라 이 표와 픽스처에 넣지 않는다

### 3.3 틀린 이벤트를 만난 엔진

- 맵 파일의 그 이벤트만 건너뛰고(스폰하지 않는다), 문제마다 `rpg:error:<맵 파일>:<경로>: <이유>` 를 TRACE 와 상관없이 찍는다.
  맵은 나머지 이벤트로 열리고 `rpg:map:<이름> events:<n> skipped:<k>` 에 건너뛴 수가 남는다
- `<맵 파일>` 과 `<정의 파일>` 은 프로젝트 기준 경로이고 `./` 을 붙이지 않는다 (`resources/maps/port_town.json`, `scripts/lua/maps/inn.lua`).
  `rpg-game.json` 의 `file`, `def` 와 같은 꼴이라 에디터가 문서 경로로 바로 쓴다. 이유 글 안의 줄바꿈은 공백 하나로 바꿔 한 줄로 찍는다
- 정의 파일의 이벤트가 틀린 경우(`Event.new` 의 assert, `charset` 에 `file` 이 없음)는 맵 전체가 "맵 로드 실패"가 되고(씬을 비워 화면에 그 글이 뜬다),
  그 글도 `rpg:error:<정의 파일>:<id>: <이유>` 로 stdout 에 찍는다
- 건너뛰는 쪽을 고른 까닭: 에디터가 저장 전에 이미 오류를 보였으므로 게임에서는 나머지를 돌려 보는 편이 쓸모 있다.
  대신 엔진 테스트 러너의 rpgdemo 검사에 "stdout 에 `rpg:error` 가 없다" 한 줄을 더해(시나리오 파일은 그대로) 건너뜀이 조용히 지나가지 않게 한다

`validateEvents(events, env)` 는 `ok, problems, valid, skipped` 를 돌려준다. `problems` 의 항목은 `{ index, path, message }`,
`valid` 는 문제가 없는 이벤트만 원래 순서로 모은 배열, `skipped` 는 뺀 이벤트 수다. `env.scripts` 는 정의 파일의 `scripts` 표다.

### 3.4 대조 픽스처

엔진 `tests/fixtures/events/invalid_events.json`(일부러 틀린 이벤트들, 3.2 표의 줄마다 하나 이상, 그리고 올바른 이벤트 둘 `ok` 와 `tail`)과
`invalid_events.paths.json`(기대하는 경로 목록 43개). 엔진 테스트와 에디터 테스트가 같은 경로 집합을 내야 한다.

- **픽스처에는 `script` 커맨드를 넣지 않는다.** 엔진은 정의 파일의 `scripts` 표로 이름을 확인하는데 에디터는 그 표를 볼 수 없어 `.name` 경로를 낼 수 없다
- 올바른 이벤트의 대사에는 줄바꿈과 따옴표와 한글이 들어 있다 (왕복 확인용)
- 에디터는 이 두 파일을 동기화 스크립트로 복사해 쓴다 (MANIFEST 에 엔진 커밋과 sha256)

## 4. 엔진의 대조 테스트

`tests/lua/cases/rpg_event_schema_test.lua` (`tests/lua/manifest.lua` 에 등록). `aldebaran_map_objects_test.lua` 와 같은 방식이다.

| 묶음 | 본다 |
|---|---|
| [A] 형식 | 스키마가 형식을 지킨다: 버전, 타입 이름, 인자 명세의 키, 겹치는 이름(인자, 목록, code, kind), enum 의 `values`, ref 의 종류, 기본값이 그 타입의 값인가, `perOption` 이 options 인자를 가리키는가, `summary` 의 이름, 후보 경로가 `./resources/` 꼴인가. 커맨드 17종, 조건 셋 |
| [B] 커맨드 목록 | `code` 집합 == `Commands.codes()`. 커맨드를 더하고 스키마를 안 고치면 깨진다 |
| [C] 필수 인자 | 커맨드마다 스키마의 `required` 집합 == `Commands.describe()[code].required` 의 키, 타입은 2.3 표의 마지막 열. 예외 `script.name` 은 테스트가 이름으로 적고, 그 따로 규칙이 실제로 도는지도 본다 |
| [D] 하위 목록 | `lists` 이름과 순서 == `describe()[code].lists`, `perOption` == `describe()[code].perOption` |
| [E] 조건 | 종류와 순서 == `Commands.CONDITIONS`. item 과 var 의 `op` 값마다 표본 조건(값 1, 2, 3 대 2)을 만들어 `Commands.test` 가 참과 거짓을 제대로 가르는지. var 의 `op` 기본값 `==`, item 의 기본값 규칙, setVar 의 `op` == `Commands.SET_VAR_OPS` |
| [F] 이벤트 칸 | 트리거 == `Event.TRIGGERS`(기본값 action), 방향(이벤트, transfer, turn) == `Character.DIR_VECTORS` 의 키, 예약 id == `MapData.RESERVED_IDS`, 칸 이름과 순서, `route.moves` == 방향, `turnPrefix` 와 `waitPrefix` 로 진짜 캐릭터의 이동 루트를 돌려 본다 |
| [G] 자산과 시트 | `assets` == `Assets.SETS` (후보 순서까지). `sheets.charset` 의 `frameW`, `frameH`, `sheetCols`, `perSheet`, `patterns`, `standPattern`, `dirRows` == `Specs.charset`, `sheets.face` 의 `size`, `cols`, `perSheet` == `Specs.faceset` |
| [H] 맵 파일 | `resources/maps/` 의 모든 맵 파일(이름을 적은 목록)의 이벤트가 `validateEvents` 를 통과한다. 정의 파일의 커맨드도 `Commands.validate` 를 통과한다. 스키마 쪽 확인(에디터가 여는 모든 이벤트가 폼으로 열린다)은 에디터의 "엔진의 모든 맵 읽고 쓰기" 테스트가 맡고, Lua 에 세 번째 스키마 검사기를 두지 않는다 |
| [I] 경로 픽스처 | `validateEvents(invalid_events)` 의 경로 집합 == `invalid_events.paths.json`, 남는 이벤트는 `ok` 와 `tail`, 픽스처에 `script` 커맨드가 없다 |
| [J] 게임 설정 | `rpg-game.json` 의 `def` 가 전부 `require` 되고, 정의 파일의 `map`(`./` 을 떼고)이 그 항목의 `file` 과 같다 (RTP 가 켜져 있으면 `alt` 중 하나여도 된다). `alt` 파일이 있고 `file` 과 크기가 같다. 등록된 파일이 [H] 의 목록에 다 있다. rpgdemo 의 시작 맵(`game.lua` 의 `START_MAP`)이 `maps` 에 있다. 맵 파일과 정의 파일의 커맨드가 쓰는 아이템 id 가 아이템 표에 다 있고 `transfer` 가 가리키는 맵이 다 등록되어 있다. 아이템 표가 Lua 에서 옮기기 전과 같은 값이다. `play.env` 와 `play.probe` 의 값, `map-objects.json` 의 `play.maps` 가 등록된 RPG 맵에 걸리지 않는다 |

Ruby 에는 이벤트 레이어가 없어 커맨드 대조는 Lua 만 한다. 대신 `tests/ruby/cases/rpg_assets_test.rb` 가 [G] 의 자산 목록 대조
(`Rpg::Assets::SETS` 대 스키마)를 하고, `rpg_specs_test.rb` 가 `stand_pattern` 을 못 박는다. Ruby 이벤트 레이어는 나중 후보다.

## 5. 엔진에 더하는 것

### 5.1 프레임워크 (마일스톤 1, 들어갔다)

| 모듈 | 더한 것 |
|---|---|
| `scripts/lua/rpg/specs.lua`, `scripts/ruby/rpg/specs.rb` | `charset.standPattern = 1` / `stand_pattern: 1` |
| `scripts/lua/rpg/assets.lua` | `SETS`(charset 의 player, npc, face 의 npc), `resolveRef(kind, ref)`(논리 이름이나 파일을 경로로), `checkRef(kind, ref)`(모양 검사, 3.2 의 외형과 얼굴 줄) |
| `scripts/ruby/rpg/assets.rb` | `SETS` (Symbol 키) |
| `scripts/lua/rpg/commands.lua` | `describe()`(필수 인자와 Lua 타입, 하위 목록과 `perOption`), `CONDITIONS`(판정 순서이자 `test` 가 도는 순서), `SET_VAR_OPS`, `walk(list, visit)`(하위 목록까지 경로와 함께), `problems(list, env, prefix)`(경로와 이유를 따로). `validate` 에 얼굴과 방향 검사. 실행 동작은 그대로다 |
| `scripts/lua/rpg/event.lua` | auto 를 병합 순서대로 전부 돌리는 기다림 목록, `hasPendingAuto()` (5.3) |
| `scripts/lua/rpg/interpreter.lua` | `leaveCount()`: 받은 `transfer` 와 `scene` 요청의 수. `opts.onStart(event)`: 시작이 받아들여졌을 때 첫 재개 전에 부른다 (`rpg:event:` 줄이 그 이벤트의 첫 대사보다 먼저 나온다) |
| `scripts/lua/rpg/mapdata.lua` | `RESERVED_IDS`, `validateEvents(events, env)`(3.3), `resolveAssets(events, assets)`(외형과 `message.face` 의 `set` 을 `file` 로, 하위 목록 안까지, 사본을 돌려준다), `merge` 와 `eventsFor` 가 정의 파일이 덮어쓴 id 배열도 돌려준다 |
| `scripts/lua/games/rpgdemo/config.lua` | `rpg-game.json` 읽기 (`load`, `mapModules`, `mapEntry`, `loadItems`, `projectPath`, `bare`) |
| `scripts/lua/games/rpgdemo/items.lua` | `items.json` 을 읽는다 (2.5) |
| `scripts/lua/games/rpgdemo/playenv.lua` | `INITIAL2D_RPG_AT`, `INITIAL2D_RPG_STATE`, `INITIAL2D_RPG_ROUTE` 의 해석 (`parseAt`, `parseState`, `parseRoute`)과 trace 글(`escape`). 엔진에 닿지 않는 순수 함수라 `rpgdemo_playenv_test.lua` 가 꼴마다 본다 |
| `scripts/lua/games/rpgdemo/game.lua` | 아래 순서로 맵을 열고, 5.2 의 환경 변수와 trace 줄 |

게임(`game.lua` 의 `loadMap`)이 맵을 여는 순서는 이렇다: 정의 파일을 `require` 하고 → 맵을 세우고 → 맵 파일의 `events` 를 읽어
`validateEvents` 로 틀린 것을 빼며 `rpg:error` 를 찍고 → `resolveAssets` 로 풀고 → 정의 파일의 이벤트와 `merge` 하고(`rpg:map:`, 덮인 id 마다
`rpg:override:<id>`) → 플레이어를 세우고(`rpg:player:`) → 스폰하고 → `onMapStart`(첫 auto 의 `rpg:event:`). 이벤트를 데이터로 다루는 앞 단계를
플레이어보다 먼저 옮긴 것 말고는 순서가 전과 같다 (배회 난수의 소비 순서도 같다).

### 5.2 환경 변수와 trace 줄 (게임 쪽, `scripts/lua/games/rpgdemo/game.lua`)

| 환경 변수 | 하는 일 |
|---|---|
| `INITIAL2D_RPG_AT=x,y[,dir]` | 첫 맵의 시작 칸과 방향을 덮는다 (알데바란의 `INITIAL2D_ALDEBARAN_AT` 과 같은 자리) |
| `INITIAL2D_RPG_STATE=arrived,booked=false,silver=2,item:shell=1` | 새 게임의 시작 상태. 쉼표로 가른 항목마다: `이름` 은 참, `이름=값` 은 값(`true`, `false`, 수, 그 밖은 글), `item:<id>=<n>` 은 소지품. Lua 에는 JSON 글을 읽는 함수가 없고(`Json.Load` 는 파일만) 내장 실행의 스테이징은 숨은 폴더를 빼므로 파일 대신 이 꼴이다. 틀린 항목은 `rpg:error:state:<항목>: <이유>` 를 찍고 건너뛴다 |
| `INITIAL2D_RPG_ROUTE=talk,up,...` | `INITIAL2D_AUTOPLAY` 의 경로를 덮는다. **한 번만** 걷고, 마지막 걸음 뒤 실행기와 대화창이 한가하고 기다리는 auto 가 없으면(`hasPendingAuto()`) `rpg:route:done` 을 찍고 `GameExit()`. 빈 값이면 걸음 없이 그 조건만 기다린다 (auto 이벤트의 자동 재생). 그래서 검사가 프레임 속도에 기대지 않는다 |
| `INITIAL2D_RPG_TRACE=1` | 아래 줄을 stdout 에 찍는다 |

```
rpg:map:port_town events:18 skipped:0
rpg:override:crates
rpg:player:port_town,15,40,left
rpg:event:arrival
rpg:message:선장|짐은 다 내렸네. 저녁 물때에 배가 다시 뜨니, ...
rpg:event:e2e_sign
rpg:choice:예|아니요
rpg:transfer:inn,10,12,up
rpg:map:inn events:6 skipped:0
rpg:player:inn,10,12,up
rpg:route:done
```

위는 줄의 꼴을 보이는 예다 (에디터가 `e2e_sign` 을 더한 항구 마을). 지금 항구 마을은 `events:17` 이고, 정의 파일이 덮는 id 가 없어
`rpg:override:` 줄이 나오지 않는다. 한 맵을 열 때의 순서는 `rpg:error`(검사), `rpg:map`, `rpg:override`, `rpg:player`, 그리고 auto 의 `rpg:event` 다.

- `rpg:player:<맵>,<x>,<y>,<dir>` 는 `loadMap` 이 플레이어를 세운 **직후, 실제 캐릭터의 값**(`playerChar.tx`, `ty`, `dir`)으로 찍는다.
  첫 맵이든 `transfer` 뒤든 맵을 세울 때마다 한 번이다. `rpg:transfer:` 줄은 커맨드의 인자를 되풀이할 뿐이라 방향이 정말 적용되었는지는
  이 줄로만 안다 (`transfer` 의 `dir` 을 데모가 버리던 문제)
- 대사 안의 줄바꿈은 `\n` 두 글자로 찍는다. `rpg:error:...` 는 TRACE 와 상관없이 늘 찍는다 (3.3)
- `MAPS` 는 씬을 열 때마다 `rpg-game.json` 에서 만든다 (2.4). 그 파일을 못 읽으면 `rpg:error:rpg-game.json: <이유>` 를 찍고 씬 오류로 띄운다.
  등록되지 않은 맵(`INITIAL2D_MAP`, `transfer.map`)도 `rpg:error:rpg-game.json: 등록되지 않은 맵 <이름>` 이다
- `charset` 에 `file` 이 없으면 플레이어 CharSet 으로 조용히 그리던 것(`def.charset.file or charsetPath`)을 오류로 바꾼다 (3.3 의 정의 파일 오류)
- `transfer` 의 `dir` 을 다음 맵에서 쓴다. 없으면 정의 파일의 `start.dir` 이다. `rpg:transfer:` 줄은 빠진 인자를 빈칸으로 찍는다 (`rpg:transfer:inn,,,`)
- `INITIAL2D_RPG_AT` 은 첫 맵에만 걸린다. `x`, `y` 는 0 이상의 정수, `dir` 은 네 방향이고, 틀리면 `rpg:error:at:<값>: <이유>` 를 찍고 정의 파일의 시작에 선다
- `INITIAL2D_RPG_STATE` 의 `item:<id>` 는 `item:<id>=1` 과 같다. 아이템 표에 없는 id, 0 이상의 정수가 아닌 개수, 빈 이름과 빈 값, `item:` 이 아닌
  접두사(`foo:bar`), 소지품 자리 이름(`items`)은 틀린 항목이다. 뒤의 항목이 앞의 것을 덮는다
- `INITIAL2D_RPG_ROUTE` 가 있으면 `INITIAL2D_AUTOPLAY` 없이도 이 씬이 자동 재생으로 돈다. 걸음은 `talk`, `up`, `down`, `left`, `right` 이고 모르는
  걸음은 `rpg:error:route:<걸음>: <이유>` 를 찍고 뺀다. 맵을 옮겨도 남은 걸음을 이어서 걷는다. `rpg:route:done` 은 TRACE 와 상관없이 찍는다

### 5.3 auto 를 전부 돌린다 (`event.lua`)

`Manager:onMapStart` 는 parallel 을 지금처럼 시작하고, auto 는 병합 순서대로 **기다림 목록**에 넣은 뒤 첫 것을 시작한다.
`Manager:update` 는 실행기가 한가해지면 목록의 다음 auto 를 시작한다 (touch 판정보다 먼저, 한 번에 하나). 꺼진(`enabled` 거짓) 이벤트는
시작할 때 건너뛴다. 맵을 떠나는 요청(`transfer`, `scene`)이 있었으면 남은 목록을 버린다: `onMapStart` 때의 `Interpreter:leaveCount()` 를
적어 두고 값이 달라지면 버린다. 그래서 첫 auto 가 `transfer` 하면 페이드가 끝나 새 맵이 열리기 전이라도 둘째는 돌지 않는다.

전에는 병합 순서의 첫 auto 하나만 돌았다 (주석의 "나머지는 다음 진입에"도 실제로는 다음 진입에도 첫 것만 돌았다).
에디터로 더한 auto 이벤트가 영영 돌지 않는 문제였다. R2K3 의 자동 실행 이벤트도 여럿이면 차례로 돈다.
지금 모든 맵에 auto 가 하나씩뿐이라 인수 시나리오와 `rpg_event_scene` 은 달라지지 않는다 (확인함).

## 6. 데모 이벤트의 이전 (마일스톤 3, PR 2)

에디터가 편집할 수 있으려면 이벤트가 맵 파일에 있어야 한다. 이전은 **에디터 모델의 왕복이 증명된 뒤**(E5 마일스톤 2), 이벤트 레이어를
만들기 **전에** 한다. 그래야 레이어와 편집기를 이벤트 한 개가 아니라 진짜 데이터 17개와 22개로 만든다.

도구: `tools/export_events.py <맵 이름>...` 와 `tools/export_events.lua`.

1. 테스트 러너처럼 작업 폴더를 세우고 `export_events.lua` 를 `main.lua` 자리에 넣어 **엔진 VM 에서** 돈다 (게임과 같은 Lua 5.3.5, 도구에 Lua 를 따로 깔지 않는다)
2. `package.loaded["scripts/lua/rpg/assets"]` 를 가짜로 바꿔 `npcCharset()` 는 `"@charset:npc"`, `faceset()` 은 `"@face:npc"` 를 돌려주게 한 뒤
   정의 파일을 `require` 한다. 플레이스홀더 경로는 플레이어와 NPC 가 같은 파일이라 경로를 거꾸로 풀면 구분이 안 된다. 표식으로 받아
   `{ "set", "index" }` 로 바꾼다. 가짜 모듈은 진짜 모듈을 `__index` 로 두고 두 함수만 덮는다. 정의 파일이 모듈 머리에서 부르는 다른 함수,
   곧 여관의 `INN_BGM = Assets.pick{...}` 과 마을, 오두막의 `Assets.mapPath(...)` 는 진짜 것이 그대로 돈다
3. `MapData.merge` 로 맵 파일 것과 합친 **순서 그대로** 쓴다 (`crates` 가 먼저). 순서는 auto 이벤트의 실행 순서이자 배회 난수의 소비 순서다
4. 함수(`script`, `run`)나 스키마에 없는 칸을 만나면 그 이벤트를 옮기지 않고 목록을 알린다. 지금 데모에는 없다
5. JSON 은 2.6 의 키 순서로 찍고, 정수와 실수를 가린다 (`seconds = 2.5`). 파이썬이 받아 `mapfile.write_map` 으로 `events` 만 바꿔 쓴다

옮긴 뒤 정의 파일에서 `events` 와 그것만 쓰던 지역 값(얼굴 표, 효과음 경로, `departure()`, `handKey()`)을 지운다. 남기지 않으면 같은 id 의 Lua 가
이겨 에디터의 편집이 게임에 안 보인다.

| 맵 | 옮기는 것 | 남는 것 (Lua) | 이유 |
|---|---|---|---|
| 항구 마을 | 16개 (맵 파일은 17개가 된다) | `map`, `start`, `groundLayers`, `bgm`, `autoRoute` | 이벤트가 아니다. 맵 속성으로 옮기는 것은 나중 후보 |
| 여관 | 6개 (`inn.json` 에 `events` 가 생긴다. 형식은 마일스톤 1 에서 이미 v2 다) | 위와 같고, `INN_BGM` 의 `Assets.pick` | 개인 소장 곡이 있으면 쓰는 규칙은 코드다 |
| 마을, 오두막 | 옮기지 않는다 | 전부 | `Assets.mapPath` 가 RTP 판과 기본 판 두 파일 중 하나를 연다. 이벤트를 옮기면 두 파일에 같은 이벤트를 두 벌 둬야 한다. 6단계 회귀 맵(`rpg_event_scene`)이기도 하다 |
| (전부) | | 정의 파일 자체 (`rpg-game.json` 의 `def`) | 맵 등록은 이미 `rpg-game.json` 이지만 맵 속성이 Lua 에 있다. 새 맵을 에디터만으로 만드는 것은 나중 후보 |

같은 흐름을 두 가지에서 쓰는 지역 함수 둘은 JSON 에서 두 벌로 펼쳐진다 (지금도 게임이 받는 데이터는 두 벌이다): 항구 마을 배 이벤트의
`departure()`, 여관 주인의 `handKey()`. 에디터에서 한쪽만 고치면 두 벌이 어긋나므로 이벤트 인스펙터가 "같은 커맨드 묶음이 이 이벤트에
두 번 있다"를 정보로 띄운다. 합치는 길은 `call` 커맨드 후보다.

**한 줄 설명은 옮기지 않는다** (결정 기록). 이벤트마다 붙어 있던 짧은 설명(`-- 도착: ...`)은 엔진 VM 이 볼 수 없으므로, 이전 도구는 옮긴
이벤트 목록만 보고하고 설명은 `docs/design/port-town.md` 에 남는다.

확인: 인수 시나리오(`rpgdemo_scene`)가 **한 줄도 안 고치고** 통과하고 골든 세 장(title, town, bag)과 벽 앞 픽셀 검사(wall)가 그대로다.
`rpg_event_scene` 도 그대로다. 이전한 두 맵을 에디터 모델로 읽고 쓰면 바이트가 같다.

## 7. 결정 기록 (2026-09-27)

E5 초안의 물음 열한 개는 저자가 자리에 없는 동안 리드가 아래처럼 정했다. 저자가 바꾸면 이 표와 해당 절을 함께 고친다.

| 물음 | 결정 |
|---|---|
| 아이템 표를 JSON 으로 | 옮긴다. `resources/data/items.json`, `items.lua` 는 그 파일을 읽는다 (2.5) |
| 마을과 오두막 | Lua 에 남기고 에디터에서는 읽기 전용이다 (6절). 옮기는 일은 나중 후보 |
| `departure()`, `handKey()` | JSON 에서 두 벌로 펼친다. `call` 커맨드(공통 이벤트)는 나중 후보 |
| 경로 표기 | 이벤트는 엔진과 같은 1부터 세는 표기, M1 오브젝트는 0부터 그대로 둔다. 사람이 보는 이벤트 오류가 엔진 콘솔과 같은 글이어야 하기 때문이다 |
| 검사용 장치 | `INITIAL2D_RPG_ROUTE`, `INITIAL2D_RPG_TRACE`, `INITIAL2D_RPG_AT`, `INITIAL2D_RPG_STATE` 를 둔다 (선례 `INITIAL2D_AUTOPLAY`) |
| 한 줄 설명을 `comment` 커맨드로 | 하지 않는다. 설명 글 읽기 과정을 빼고, 이벤트마다의 설명은 이전 보고와 `docs/design/port-town.md` 에만 남긴다 |
| `map-objects.json` 의 `play.maps` | 더한다 (선택 칸 하나) |
| auto 이벤트 | 병합 순서대로 전부 돌린다. 인수 시나리오와 `rpg_event_scene` 이 달라지면 멈추고 보고한다 |
| 틀린 맵 파일 이벤트 | 그 이벤트만 건너뛰고 `rpg:error` 를 찍는다 |
| 게임 설정 파일의 자리 | `resources/data/rpg-game.json`. 게임이 읽는 데이터이므로 스키마(`resources/schema/`, 형식의 설명)와 가른다 |
| `INITIAL2D_RPG_STATE` 의 꼴 | 쉼표 목록 그대로 |

구현하면서 정한 것 (이 문서가 처음 적는다):

| 물음 | 결정 |
|---|---|
| 아이템 표의 모양 | `{ "version": 1, "items": [ { id, name, desc, order } ] }`. 배열이라 순서가 안정적이고 맵 파일의 `events` 와 같은 모양이다 |
| 맵 등록을 읽는 코드 | `scripts/lua/games/rpgdemo/config.lua` 하나. `items.lua` 와 `game.lua` 가 함께 쓴다 |
| 첫 auto 가 떠난 뒤 | 실행기의 `leaveCount()` 로 안다. 게임 쪽 호스트가 따로 알려 줄 필요가 없다 |
| 검사 표에 더한 줄 | `events` 가 배열이 아니다, `charset.file`/`face.file` 이 빈 글이거나 글이 아니다, `wander`/`wander.area` 가 객체가 아니다, 하위 목록이 배열이 아니다. `minWait > maxWait` 는 없는 쪽을 기본값으로 보고, 경로는 있는 쪽(`maxWait` 먼저)이다 |
| 인자 명세의 키 | 2.2 의 목록으로 닫는다. 새 키가 필요하면 이 문서와 테스트 [A] 를 함께 고친다 |
| `rpg:event:` 를 찍는 자리 | 실행기의 `onStart` 훅. 게임이 실행기의 시작 규칙(도는 중이면 거절, 이미 도는 parallel)을 다시 적지 않는다 |
| 환경 변수 해석 | `playenv.lua` 로 떼어 순수 함수로 둔다. 게임 씬은 부르기만 한다 |
| ROUTE 와 AUTOPLAY | ROUTE 만으로 자동 재생이 된다. 빠뜨려서 안전망 프레임까지 멈춰 있는 실행을 막는다 |
| `rpg:error` 의 경로 꼴 | 프로젝트 기준, `./` 없이 (3.3). 그 밖의 자리는 `rpg-game.json`, `state:<항목>`, `at:<값>`, `route:<걸음>`, 아이템 표 경로 |
| RPG 맵의 저장 형식 | 항구 마을, 여관, 마을, 오두막(두 벌)과 `sample.json` 을 `mapfile.py format` 으로 맞췄다. 바뀐 값은 `version`(1 에서 2)뿐이다. 생성기 둘(`generate_port_maps.py`, `generate_demo_maps.py`)은 `write_map` 으로 쓰고 `events` 를 이어받으며, 다시 돌리면 커밋된 파일과 바이트가 같다. `crates` 는 이제 맵 파일에만 있다 |

## 8. 작업 항목

### 마일스톤 1: 계약 (PR 1)

- [x] 문서: 이 문서(E5 초안 1절, 5.1절, 7절, 결정 기록을 옮겼다), [12-editor-events.md](12-editor-events.md) 머리의 "E5 와 M2 가 이어받았다", [10-demo-v2.md](10-demo-v2.md) 3.2 의 커맨드 표를 스키마를 가리키는 한 줄로, [index.md](index.md) 진행 표
- [ ] E5 문서의 1절, 5.1절, 7절을 한 단락 요약과 이 문서로의 링크로 줄인다 (에디터 저장소 쪽 커밋)
- [x] `resources/schema/event-commands.json`: 17종, 조건 셋, 이벤트 칸, `assets`, `sheets`(`standPattern` 포함), `route`
- [x] `resources/data/rpg-game.json`: 맵 넷(`file`, `alt`, `def`), 아이템 표 경로, `play.env` 와 `play.probe`
- [x] `resources/schema/map-objects.json` 의 `play` 에 `"maps": ["aldebaran_*"]`
- [x] `resources/data/items.json` 과 `items.lua`(그 파일을 읽는다, 못 읽으면 빈 표와 오류 줄), `config.lua`
- [x] `specs.lua` 의 `charset.standPattern`, `specs.rb` 의 `stand_pattern`, 두 규격 테스트
- [x] `commands.lua`: `describe()`, `CONDITIONS`, 얼굴과 방향 검사, `walk`, `problems`
- [x] `event.lua`: auto 를 병합 순서대로 전부, `hasPendingAuto()`, `rpg_event_test.lua` 에 두 경우 (auto 둘이 순서대로 한 번씩, 첫 auto 가 transfer 하면 둘째는 돌지 않는다)
- [x] `assets.lua`: `SETS`, `resolveRef`, `checkRef`. `assets.rb` 에 `SETS`
- [x] `mapdata.lua`: `validateEvents`(3.2 표 전부), `resolveAssets`, `merge` 가 덮인 id 도 돌려준다
- [x] 테스트: `rpg_event_schema_test.lua`(4절), `rpg_mapdata_test.lua`(3.2 표의 줄마다), `rpg_commands_test.lua`(새 검사와 계약 함수), `rpg_event_test.lua`, `rpg_assets_test.lua` 와 `.rb`, 규격 테스트 두 벌, `tests/fixtures/events/invalid_events.json` 과 `.paths.json`
- [x] `game.lua`: `MAPS` 를 `rpg-game.json` 에서(`Config.mapModules`), 맵 파일 이벤트를 검사하고 틀린 것은 건너뛰며 `rpg:error` 줄(정의 파일의 오류도 stdout 으로), `resolveAssets`, `transfer` 의 `dir`, `charset.file` 이 없으면 오류, `INITIAL2D_RPG_AT`, `INITIAL2D_RPG_STATE`, `INITIAL2D_RPG_ROUTE`, `INITIAL2D_RPG_TRACE` 와 trace 줄(`rpg:player` 포함). 해석은 `playenv.lua`(단위 테스트 `rpgdemo_playenv_test.lua`), `rpg:event:` 는 실행기의 `onStart`
- [x] 맵 형식: RPG 맵과 `sample.json` 을 `mapfile.py format` 으로, `tools/generate_port_maps.py` 와 `tools/generate_demo_maps.py` 를 `write_map` 으로 (이벤트를 이어받고 `crates` 를 코드에서 뺀다). 테스트 러너가 모든 맵에 `mapfile.py check`
- [x] `tests/run_engine_tests.py`: 진짜 허브로 띄우는 작업 폴더 함수 `make_game_workdir`, 그것을 쓰는 `test_rpg_play_here`, rpgdemo 검사에 "stdout 에 `rpg:error` 가 없다" 한 줄.
  `test_rpg_play_here` 는 실행 변수를 `rpg-game.json` 의 `play.env` 와 `play.probe` 에서 만들고 다섯 판을 돈다: crates 옆에서 말 걸기, 시작 상태 `arrived`,
  여관 출입구(`rpg:player:port_town,13,30,down`, transfer 의 방향), 틀린 맵 파일 이벤트 건너뛰기, 정의 파일의 `file` 없는 외형
- [x] 인수 시나리오와 골든 세 장과 벽 앞 픽셀 검사 무변경 (`game.lua` 까지 고친 뒤. `transfer` 방향 고치기는 따로 커밋했고, 그 앞뒤로 시나리오의 stdout 이 바이트까지 같다)
- [x] README 의 환경 변수와 스키마 (이벤트 절의 스키마와 맵 파일 검사, 아이템 표 `items.json`, 데모 절의 "맵 등록과 여기서 실행")

### 마일스톤 3: 이전 (PR 2)

- [ ] `tools/export_events.py`, `tools/export_events.lua` (6절). 가짜 자산 모듈은 진짜 모듈 위에 두 함수만 덮는다
- [ ] 항구 마을 16개, 여관 6개를 맵 파일로. 정의 파일 정리 (`departure()`, `handKey()` 포함)
- [ ] 인수 시나리오와 골든 세 장과 벽 앞 픽셀 검사와 `rpg_event_scene` 무변경, 에디터 왕복 바이트 같음, 사람이 브리지 왕복 한 번
- [ ] 에디터 픽스처 다시 동기화, 에디터의 `yarn test:engine-events` 가 이전한 항구 마을로 다시 통과
- [ ] README 에 `tools/export_events.py`

## 9. 검수

| 무엇 | 결과 |
|---|---|
| Lua 단위 (헤드리스, `INITIAL2D_NO_RTP=1`) | 전체 2296건 통과. `rpg_event_schema_test` 164건 새로, `rpg_mapdata_test`, `rpg_commands_test`, `rpg_event_test`, `rpg_assets_test`, `rpg_specs_test` 확장. 게임 쪽에서 `rpgdemo_playenv_test`(환경 변수 해석) 새로, `rpg_interpreter_test` 에 `onStart` |
| mruby 단위 | 전체 1926건 통과 (`rpg_assets_test.rb` 의 스키마 대조, `rpg_specs_test.rb` 의 `stand_pattern`) |
| 깨지는 것을 보았다 | 커맨드를 하나 더하면 [B] 와 커맨드 집합 테스트가, 스키마의 필수 표시를 지우면 [C] 가, 목록 이름을 바꾸면 [D] 가, 후보 목록을 바꾸면 [G] 와 Ruby 대조가, 경로 하나를 픽스처에서 빼면 [I] 가, auto 를 첫 하나만 돌리게 되돌리면 `rpg_event_test` 가 깨진다. `transfer` 의 `dir` 을 다시 버리게 하면 `test_rpg_play_here` [C] 가, 외형의 `file` 이 없을 때 플레이어 그림으로 되돌리면 [E] 가, 항구 마을 맵 파일에 틀린 이벤트를 넣으면 rpgdemo 검사의 "stdout 에 `rpg:error` 가 없다" 가 깨진다 (전부 확인하고 되돌렸다) |
| 인수 시나리오와 `rpg_event_scene` | `transfer` 방향 고치기(따로 커밋) 앞뒤로 두 씬의 stdout 이 바이트까지 같다 (`tickUntil` 의 프레임 수 포함). `game.lua` 를 다 고친 뒤에도 그대로 통과 (골든 세 장, 벽 앞 픽셀 검사 포함) |
| `test_rpg_play_here` (진짜 허브) | 36건 통과. 실행 변수는 `rpg-game.json` 의 `play.env` 와 `play.probe` 에서 만든다. 판마다 `rpg:route:done` 으로 스스로 끝난다 |
| 맵 형식 | 모든 맵이 `mapfile.py check` 를 통과하고 `tests/run_all.sh` 가 `resources/maps/*.json` 을 본다. 생성기 둘을 다시 돌리면 커밋된 맵과 바이트가 같다 |
| 전체 스위트 (`tests/run_all.sh`, 헤드리스, `INITIAL2D_NO_RTP=1`) | 통과. C++ 단위 18, 엔진 씬 483, 브리지 25 (이 기계는 오디오 장치가 없어 `SDL_AUDIODRIVER=dummy` 를 함께 준다. 없으면 mruby `audio_test` 셋이 master 에서도 실패한다) |
