# 엔진 2. 스프라이트 시트와 애니메이션 클립: 「이미지 옆의 시트 파일 하나로 새가 날고 떨어진다」

> 작성일: 2026-11-15. 에디터 완성도 계획(`InitialEditor/docs/plans/quality.md` 10절)의 엔진 짝 둘째.
> 에디터 짝은 Q3(스프라이트와 애니메이션)이다. 진행 상황은 [index.md](index.md) 9절의 표에 있다.

## 1. 목표 (한 문장)

> 이미지 옆의 시트 파일(`<이름>.sprite.json`)이 칸 자르기와 이름 있는 클립을 담고, Lua 와 Ruby 가 같은 규칙으로
> 읽고 튼다. 씬 파일의 sprite 는 시트 파일과 클립 이름만 가리킨다.

C++ 은 고치지 않는다. 포맷을 읽고 시간을 재는 일은 스크립트 층(`scripts/lua/sprite_sheet.lua`,
`scripts/ruby/sprite_sheet.rb`)이 하고, 엔진에는 지금 있는 API 로 칸(`Sprite.SetRect`)과 기준점(엔진 1 의
`Sprite.SetPivot`)을 넘긴다. 씬 포맷과 맵 포맷 v2 의 `events` 와 같은 원칙이다.

## 2. 시트 포맷 v1 (계약)

에디터와 공유하는 계약이다. 플래피버드의 새(`resources/bird.sprite.json`):

```json
{
  "version": 1,
  "image": "resources/bird_276x64.png",
  "frameWidth": 92,
  "frameHeight": 64,
  "defaultClip": "fly",
  "clips": {
    "fly": { "frames": [0, 1, 2], "duration": 110, "loop": "pingpong" },
    "fall": { "frames": [0], "loop": "once" }
  }
}
```

규칙:

1. `version` 은 1 이어야 한다. 다른 값은 그 값을 말하는 오류다 (`sheet: unsupported version 2 (expected 1)`).
2. `image` 는 프로젝트 루트 기준 `/` 상대 경로다 (씬 파일, 맵 파일과 같다). 시트 파일의 자리와는 상관없다.
3. `frameWidth`, `frameHeight` 는 칸 크기(1 이상의 정수, 필수), `margin` 은 그림 가장자리의 여백,
   `spacing` 은 칸 사이의 간격이다 (0 이상의 정수, 기본 0).
4. 열과 행의 수는 **이미지 크기에서 나온다**. 열은 `(이미지 폭 - 2 x margin + spacing) / (frameWidth + spacing)` 의
   내림, 행은 높이로 같은 식이다. 그림을 바꾸면 칸 수가 따라 바뀐다. 칸 하나도 들어가지 않으면 오류다.
5. 프레임 번호는 0 부터 왼쪽에서 오른쪽, 위에서 아래로 센다. 프레임 n 의 칸은
   `x = margin + (n % 열) x (frameWidth + spacing)`, `y = margin + (n / 열 의 내림) x (frameHeight + spacing)` 이다.
6. `pivot` `[x, y]` 는 시트의 기준점(칸 안의 비율, 엔진 1 과 같은 뜻)이다. 기본 `[0, 0]`.
7. `clips` 는 클립 이름에서 클립으로 가는 객체다. 이름은 비어 있지 않은 문자열이다. 클립은:
   - `frames`: 프레임 번호의 배열 (필수, 하나 이상). 같은 번호를 여러 번 써도 된다.
   - `duration`: 프레임 하나의 시간(ms, 0 보다 큰 수). 숫자 하나면 모든 프레임에, 배열이면 `frames` 와 같은 길이로
     프레임마다. 기본 100 (씬 로더의 `frameDelay` 기본값과 같다).
   - `loop`: `"loop"`(되풀이, 기본), `"once"`(한 번 틀고 마지막 프레임에 머문다), `"pingpong"`(끝에서 돌아온다).
   - `pivot`: 이 클립의 기준점. 있으면 시트의 것보다 먼저다.
8. `defaultClip` 은 씬의 sprite 가 클립을 정하지 않았을 때 트는 클립이다. 빈 문자열과 없는 것은 같다 (클립 없음,
   0 번 프레임에 머문다).
9. **모르는 키는 로더가 무시한다** (에디터는 보존한다). 읽은 원본은 `sheet.source` 에 있다.
10. 파일 이름은 `<이름>.sprite.json` 이고 이미지 옆에 둔다. 로더는 이름을 따지지 않는다 (에디터가 이 꼬리로 알아본다).

에디터가 쓸 때: `duration` 은 프레임 시간이 모두 같으면 숫자 하나, 다르면 배열로 쓴다. 기본값인 키는 빼도 되고
써도 된다 (같은 뜻이다).

## 3. 재생 규칙

재생기(animator)는 오브젝트마다 하나다. 시트는 읽은 뒤 바뀌지 않으므로 같은 경로의 시트를 오브젝트끼리 나눠 쓴다
(모듈이 경로로 한 번만 읽는다).

- 프레임 시간이 **다 차는 순간** 다음 프레임으로 간다 (`duration` 100 이면 0 이상 100 미만의 시간 동안 보인다).
- 한 번의 `update` 가 여러 프레임을 넘을 수 있다. `loop` 와 `pingpong` 은 한 바퀴의 시간을 넘는 긴 시간을 받으면
  먼저 바퀴 수를 덜어 낸다 (멈췄던 게임이 큰 시간을 넘겨도 한 번에 끝난다).
- `pingpong` 은 양 끝을 두 번 보이지 않는다. `[4, 5, 6]` 은 4 5 6 5 4 5 6 5 ... 이고 돌아오는 프레임의 시간은
  그 프레임의 `duration` 이다.
- `once` 는 마지막 프레임의 시간이 다 차면 끝나고(`isDone`) 그 프레임에 머문다. 그 뒤의 `update` 는 아무것도 하지 않는다.
- `play(이름)` 은 그 클립을 처음부터 튼다 (같은 클립이어도). 없는 이름은 오류이고 상태를 바꾸지 않는다.
  `play(nil)` 은 클립을 내리고 0 번 프레임을 보인다. `restart()` 는 지금 클립을 처음부터 다시 튼다.
- 0 이나 음수의 시간은 아무것도 하지 않는다.

## 4. 검사 (에디터의 규칙과 같은 목록)

`SpriteSheet.validate(표)` 는 파일을 열지 않는 모양 검사다 (Lua 는 `ok, err`, Ruby 는 `SpriteSheet::Error`).
`fromTable`(Ruby `from_hash`)과 `load` 는 그 뒤에 이미지의 크기를 읽어 칸과 프레임 번호를 본다. 메시지는 두 언어가
같고 `sheet: ` 으로 시작하며, 파일에서 읽었으면 끝에 ` (<시트 파일 경로>)` 가 붙는다. 클립은 이름 순서로 검사한다
(첫 오류가 두 언어에서 같다). 배열의 자리는 1 부터 센다 (씬 로더, 이벤트 검사와 같다).

| 검사 | 메시지 |
|---|---|
| 객체가 아니다 | `sheet: not an object` |
| 버전이 1 이 아니다 | `sheet: unsupported version <v> (expected 1)` (없으면 `nil`) |
| image 가 없거나 빈 문자열 | `sheet: image must be a non-empty string` |
| frameWidth, frameHeight 가 1 이상의 정수가 아니다 | `sheet: frameWidth must be an integer >= 1` |
| margin, spacing 이 0 이상의 정수가 아니다 | `sheet: margin must be an integer >= 0` |
| pivot 이 숫자 둘의 배열이 아니다 | `sheet: pivot must be [x, y]` |
| clips 가 객체가 아니다 | `sheet: clips must be an object` |
| 클립 이름이 빈 문자열 | `sheet: clip names must not be empty` |
| 클립이 객체가 아니다 | `sheet: clip '<이름>' must be an object` |
| frames 가 없거나 빈 배열 | `sheet: clip '<이름>' needs frames (a non-empty array)` |
| frames 의 항목이 0 이상의 정수가 아니다 | `sheet: clip '<이름>' frames[<i>] must be an integer >= 0` |
| duration 이 0 보다 큰 수도, 그런 수의 배열도 아니다 | `sheet: clip '<이름>' duration must be a number > 0 or an array of them` |
| duration 배열의 길이가 frames 와 다르다 | `sheet: clip '<이름>' duration needs <n> values (one per frame), got <m>` |
| duration 배열의 항목이 0 보다 큰 수가 아니다 | `sheet: clip '<이름>' duration[<i>] must be a number > 0` |
| loop 가 셋 중 하나가 아니다 | `sheet: clip '<이름>' loop must be "loop", "once" or "pingpong"` |
| 클립의 pivot 이 숫자 둘의 배열이 아니다 | `sheet: clip '<이름>' pivot must be [x, y]` |
| defaultClip 이 문자열이 아니다 | `sheet: defaultClip must be a string` |
| defaultClip 이 없는 클립 | `sheet: defaultClip '<이름>' is not a clip` |
| (열 때) 이미지 크기를 읽지 못한다 (PNG 가 아니거나 없다) | `sheet: cannot read the size of <image>` |
| (열 때) 칸 하나도 들어가지 않는다 | `sheet: <image> is <w>x<h>, too small for one <fw>x<fh> frame` |
| (열 때) 프레임 번호가 시트 밖 | `sheet: clip '<이름>' frames[<i>] is <n>, but the sheet has <count> frames` |
| (열 때) 파일을 읽지 못한다 | `sheet: cannot open <path> (<파서의 설명>)` |

픽스처 `tests/fixtures/sprites/invalid_sheets.json` 에 잘못된 시트 32개와 정확한 문장이 있다. 두 언어의 단위 테스트가
같은 파일로 문장까지 대조한다. 에디터도 이 파일로 같은 문장을 내는지 볼 수 있다.

## 5. API

| 일 | Lua (`require("scripts/lua/sprite_sheet")`) | Ruby (`require "scripts/ruby/sprite_sheet"`) |
|---|---|---|
| 파일 읽기 (경로로 한 번만) | `SpriteSheet.load(path)` | `SpriteSheet.load(path)` |
| 읽은 표에서 | `SpriteSheet.fromTable(tbl, path)` | `SpriteSheet.from_hash(hash, path)` |
| 모양 검사 | `SpriteSheet.validate(tbl)` → `ok, err` | `SpriteSheet.validate(hash)` → true 또는 `SpriteSheet::Error` |
| 읽어 둔 시트 비우기 | `SpriteSheet.clearCache()` | `SpriteSheet.clear_cache` |
| 칸 | `sheet:frameRect(n)` → `x, y, w, h` | `sheet.frame_rect(n)` → `[x, y, w, h]` |
| 클립 | `sheet:clip(name)`, `sheet:clipNames()` | `sheet.clip(name)`, `sheet.clip_names` |
| 시트의 값 | `sheet.image`, `columns`, `rows`, `frameCount`, `frameWidth`, `frameHeight`, `pivotX`, `pivotY`, `defaultClip`, `source` | `image`, `columns`, `rows`, `frame_count`, `frame_width`, `frame_height`, `pivot`, `default_clip`, `source` |
| 재생기 | `sheet:animator()` | `sheet.animator` |
| 틀기 | `anim:play(name)`, `anim:restart()` | `anim.play(name)`, `anim.restart` |
| 시간 보내기 | `anim:update(ms)` | `anim.update(ms)` |
| 상태 | `anim:clip()`, `anim:frame()`, `anim:isDone()`, `anim:pivot()` → `x, y`, `anim:rect()` | `anim.clip`, `anim.frame`, `anim.done?`, `anim.pivot` → `[x, y]`, `anim.rect` |
| 스프라이트에 옮기기 | `anim:apply(spriteHandle)` (칸과 기준점) | `anim.apply(sprite)` |

씬 로더 없이 쓸 때는 프레임 크기로 스프라이트를 만들고 (`Sprite.Create(x, y, sheet.frameWidth, sheet.frameHeight, 1, 텍스처)`)
매 틱 `anim:update(elapsed)` 와 `anim:apply(sprite)` 를 부른다.

## 6. 씬 파일 (포맷 v1 에 더한 키)

포맷은 그대로 v1 이다. 예전 로더는 모르는 키로 무시하고, 에디터는 보존한다. 정본은 [r1-scene-loader.md](r1-scene-loader.md) 2절, 3절, 4.1절.

| 키 | 값 | 뜻 |
|---|---|---|
| `sheet` | 시트 파일 경로 (문자열) | 그림, 칸 크기, 프레임, 클립이 시트 파일에서 온다. 빈 문자열은 없는 것과 같다 |
| `clip` | 클립 이름 (문자열) | 틀 클립. 비어 있거나 없으면 시트의 `defaultClip` |

- `sheet` 가 있으면 `image` 가 없어도 되고, `image`, `width`, `height`, `frames`, `startFrame`, `endFrame`,
  `frameDelay`, `loop` 는 쓰지 않는다 (에디터가 기본값으로 써 둔 키가 남아 있어도 된다. 모양 검사는 그대로 한다).
- 기준점은 `props.pivot` 이 있으면 그것, 없으면 클립의 pivot, 시트의 pivot, `[0, 0]` 순서다.
- 시트 파일은 오브젝트를 만들 때 읽는다 (`image` 와 같다). 실행 중에 `props.sheet` 를 바꿔도 반영되지 않는다.
  다른 시트가 필요하면 그 시트의 오브젝트를 `scene:spawn` 으로 만든다.
- 로더는 매 틱 `props.clip` 을 본다. 지금 클립과 다르면 새 클립을 **처음부터** 틀고 그 틱에는 시간을 보내지 않는다.
  같으면 시간을 보낸다 (`obj.animate == false` 면 멈춘다). 그 다음 지금 프레임의 칸과 기준점을 스프라이트에 옮긴다.
- 컴포넌트는 `obj.props.clip = "fall"` 로 클립을 바꾼다. 같은 클립을 처음부터 다시 틀 때는 `obj.animator:restart()`.
  `obj.animator:play` 를 직접 부르면 다음 틱에 `props.clip` 의 클립으로 돌아가므로 쓰지 않는다.
- 로더가 채워 주는 필드: `obj.sheet`, `obj.animator`, `obj.frameWidth`, `obj.frameHeight`(칸 크기), `obj.texture`
  (시트 그림의 경로). Ruby 는 `obj.sheet`, `obj.animator`, `obj.frame_width`, `obj.frame_height`.
- 검사 문장: `scene: props.sheet must be a string (<id>)`, `scene: props.clip must be a string (<id>)`. 시트도 이미지도
  없으면 예전 문장 그대로 `scene: sprite '<id>' needs props.image` 다. 열 때와 실행 중의 오류는 오브젝트를 앞에 붙인
  시트의 문장이다: `scene: sprite 'bird': sheet: no clip 'run' (resources/bird.sprite.json)`.
- 씬 로더는 시트를 쓰는 sprite 를 처음 만날 때 `sprite_sheet` 모듈을 읽는다. 모듈 파일이 없는 프로젝트도 시트를 쓰지
  않으면 그대로 돈다. 쓰면 `scene: sprite '<id>': props.sheet needs scripts/lua/sprite_sheet.lua` 로 실패한다.

## 7. 플래피버드

플래피의 새가 시트 파일을 쓴다. `resources/bird.sprite.json` 의 `fly` 는 날개 위, 가운데, 아래 셋을 110ms 씩
`pingpong` 으로 (예전에는 위, 가운데, 아래를 되풀이해 아래에서 위로 건너뛰었다), `fall` 은 날개를 편 프레임 0 하나를
`once` 로 튼다. 새 컴포넌트(Lua, Ruby)는 게임 오버면 `props.clip` 을 `fall`, 아니면 `fly` 로 둔다
(예전에는 `obj.animate = false` 로 날갯짓을 그 자리에서 멈췄다). 새의 기준점은 왼쪽 위 그대로라 위치와 충돌 상자는
예전과 같다.

## 8. 템플릿 묶음

`tools/templates_list.txt` 에 셋을 더했다: 씬 로더 묶음(모든 템플릿)에 `scripts/lua/sprite_sheet.lua` 와
`scripts/ruby/sprite_sheet.rb`, 플래피 묶음에 `resources/bird.sprite.json`.

> 에디터의 `scripts/sync-engine-templates.mjs` 의 `SOURCES` 에도 같은 셋이 들어가야 한다 (`common` 그룹에 둘,
> `flappy` 그룹에 하나). 에디터는 `engine-pin.json` 의 커밋으로 엔진을 받으므로 지금은 아무것도 바뀌지 않지만,
> 이 커밋 뒤로 고정을 옮기면서 셋을 더하지 않으면 플래피 템플릿의 새가 열리지 않는다.

## 9. 검수

- 단위 테스트 `sprite_sheet_file_test` (Lua, Ruby, 라벨이 같고 검사가 각각 114개): 읽기(열과 행, 프레임 수, 정렬한
  클립 이름, 모르는 키, 한 번만 읽기), 칸, 클립의 정규화, 재생(loop 의 경계와 여러 프레임 넘기와 긴 시간, pingpong 의
  순서, once 의 끝, restart, 같은 클립의 play, 없는 클립, `play(nil)`, 재생기끼리 따로), `apply`, 잘못된 시트 32개의
  문장, 씬 검사와 씬 실행(defaultClip, 매 틱 칸과 기준점, 클립 바꾸기, 기준점의 순서, 멈춤, 비운 clip, 실행 중 없는
  클립, spawn).
- 엔진 씬 `sheet_clips_scene.lua`, `mruby_sheet_clips_scene.rb`: 픽스처 씬 `tests/fixtures/scenes/sheet_v1.json` 을
  열고 20ms 틱 26번 동안 클립을 바꾸고 멈추고 다시 튼다. 러너(`test_sheet_clips_lua`, `test_sheet_clips_mruby`)가
  stdout 10줄을 순서까지, 칸 셋의 픽셀 27개(가운데의 색, 모서리 안쪽 2px 의 색, 칸 밖의 바탕), 골든 `sheet_clips` 를 본다.
  모서리 검사가 여백과 간격의 검정이 묻어 나오지 않는 것을, 칸 밖 검사가 크기와 기준점 자리를 확인한다.
- 픽스처 그림 `tests/fixtures/sprites/frames.png` (74x38): 16x16 칸 8개(4열 2행, 여백 2, 간격 2)를 빨강, 초록, 파랑,
  노랑, 자홍, 청록, 주황 (255, 128, 0), 보라 (128, 0, 255) 로 칠하고 나머지는 불투명 검정이다.
- 플래피: 컴포넌트 테스트(두 언어)가 대기의 `fly` 와 게임 오버의 `fall` 을 보고, 씬 플래피(두 언어)와 mruby 플래피가
  자동 시연으로 돈다. 스크린샷에서 새가 시트의 칸으로 그려지는 것을 눈으로 확인했다.
- `tools/check_luals.sh` 진단 0건, `tests/tools/templates_test.py` 통과.
- 확인하지 못한 것: Windows GDI 판. GDI 의 `DrawFrame` 도 스프라이트의 칸(rect)을 쓰므로 프레임은 맞게 나올 것이고
  기준점은 GDI 판이 그리지 않는다 (엔진 1 과 같다).

## 10. v1 에 없는 것

- 칸마다 자리와 크기가 다른 아틀라스 (TexturePacker 꼴의 프레임별 사각형과 잘라 낸 여백)
- 프레임마다 붙는 값 (오프셋, 이벤트 표식), 재생 속도, 거꾸로 틀기, 클립이 끝날 때의 다음 클립
- 에디터 쪽 Q3 (가져오기, 이미지 보기, 시트 자르기 화면, 클립 편집과 미리보기)는 에디터 저장소의 일이다

## 체크리스트

- [x] 시트 포맷 v1 과 검사 문장 (이 문서 2절, 4절)
- [x] `scripts/lua/sprite_sheet.lua`, `scripts/ruby/sprite_sheet.rb` (읽기, 검사, 재생기)
- [x] 씬 로더 두 언어: `props.sheet`, `props.clip`, 매 틱 클립과 칸과 기준점, r1 문서
- [x] 공유 픽스처 (`tests/fixtures/sprites/`, `tests/fixtures/scenes/sheet_v1.json`)
- [x] 단위 테스트 두 언어, 엔진 씬 두 언어와 골든 `sheet_clips`
- [x] 플래피의 새를 시트 파일과 클립으로
- [x] 템플릿 목록, README
- [ ] 에디터의 `SOURCES` 에 셋 더하기 (에디터가 엔진 고정을 옮길 때)
