# R1. 씬 로더: 「에디터가 만든 씬 파일이 게임에서 돌아간다」

> 작성일 2026-09-26. **권장 모델 Fable 5** (씬 포맷과 컴포넌트 계약은 에디터와 엔진 두 저장소가
> 함께 읽는 계약이라 이후 작업의 토대가 되는 설계 판단이다).
>
> 저자 요구 (InitialEditor 계획, 2026-09-26): "에디터가 만든 데이터가 연동되고 스크립트가 실행되면
> 인게임이 돌아가야 한다." 에디터 쪽 짝은 E2(씬과 오브젝트)와 E3(타일맵 오브젝트 타입)이며,
> 초안은 `InitialEditor/docs/plans/03-project-and-runtime.md` 5절에 있었다. **이 문서가 정본이다.**
> 초안과 다른 곳은 이 문서를 따른다.

## 1. 목표 (한 문장)

**에디터가 저장한 `resources/scenes/<이름>.json` 을 스크립트 레이어가 읽어 오브젝트를 만들고,
오브젝트에 붙은 컴포넌트가 게임을 움직인다.** C++ 은 이 포맷을 모른다 (맵 포맷 v2 의 `events` 와
같은 원칙). Lua 판(`scripts/lua/scene_loader.lua`)과 Ruby 판(`scripts/ruby/scene_loader.rb`)이 같은
파일을 같은 규칙으로 읽는다.

증명은 둘이다.

1. **플래피를 씬으로.** `resources/scenes/flappy.json` 과 `scripts/*/components/flappy/` 만으로
   플래피가 돌고, 기존 Ruby 플래피 인수(`test_mruby_flappy_scene`)와 **같은 검사**를 두 언어가
   통과한다 (`test_scene_flappy_lua`, `test_scene_flappy_mruby`).
2. **픽스처 한 장을 두 언어가 같은 그림으로.** `tests/fixtures/scenes/sample_v1.json` (타입 넷 전부)을
   두 로더가 열어 같은 골든 `scene_loader` 를 통과한다. 이 픽스처는 에디터 저장소와 공유한다.

## 2. 씬 포맷 v1 (계약)

에디터와 공유하는 계약이다. 그대로 구현했다.

```json
{
  "version": 1,
  "name": "main",
  "objects": [
    { "id": "bg", "type": "sprite", "x": 0, "y": 0, "visible": true,
      "props": { "image": "resources/images/bg.png", "width": 0, "height": 0, "frames": 1, "scale": 1, "angle": 0, "opacity": 255, "loop": true, "startFrame": 0, "endFrame": 0 },
      "scripts": [] },
    { "id": "score", "type": "text", "x": 8, "y": 8, "visible": true, "props": { "text": "0", "font": "resources/fonts/hangul.fnt" }, "scripts": [] },
    { "id": "world", "type": "node", "x": 0, "y": 0, "visible": true, "props": {}, "scripts": ["components/spawner"],
      "params": { "components/spawner": { "interval": 1500, "target": "bg" } } },
    { "id": "map", "type": "tilemap", "x": 0, "y": 0, "visible": true, "props": { "map": "resources/maps/sample.json", "groundLayers": 1 }, "scripts": [] }
  ]
}
```

규칙:

1. `version` 은 1 이어야 한다. 다른 값은 그 버전을 말하는 오류다 (`scene: unsupported version 2 (expected 1)`).
2. **모르는 키는 어디에 있든 로더가 무시한다** (에디터는 보존한다). 로더는 파일의 원본을 `scene.source` 에,
   오브젝트 항목의 원본을 `obj.spec` 에 그대로 들고 있어 모르는 키를 읽을 수는 있다.
3. `id` 는 씬 안에서 유일한 비어 있지 않은 문자열이다. 중복은 그 id 를 말하는 오류다 (`scene: duplicate id 'bg'`).
4. `type` 은 코어 타입 `node`, `sprite`, `text` 이거나 등록된 확장 타입이다. 모르는 타입은 그 타입을
   말하는 오류다 (`scene: unknown type 'ghost' (object 'g')`). 확장 타입은 `scripts/lua/scene_types/<타입>.lua`
   (Ruby 는 `scripts/ruby/scene_types/<타입>.rb` 의 `SceneTypes::<CamelCase>`) 모듈이며 로더가 처음 만날 때
   게으르게 `require` 한다. 첫 확장 타입으로 `tilemap` 을 실었다 (`map` = 엔진 맵 포맷 v2 경로,
   `groundLayers` = 스프라이트 아래에 그리는 레이어 수, 나머지는 위에).
5. 경로는 프로젝트 루트 기준 `/` 상대 경로다. 로더가 `./` 를 붙여 엔진에 넘긴다.
6. `objects` 의 순서가 그리기 순서다. `x`, `y` 기본 0, `visible` 기본 true, `props` 기본 `{}`, `scripts` 기본 `[]`.
7. `scripts` 의 항목은 언어 중립의 논리 이름이다. `"components/bird"` 는 Lua 에서 `scripts/lua/components/bird.lua`,
   Ruby 에서 `scripts/ruby/components/bird.rb` 로 풀린다.
8. sprite 의 props: `image` 필수. `width`, `height` 는 프레임 크기(0 이면 이미지 전체), `frames` 는 프레임 수
   (시트를 가로로 나눈다), `scale`, `angle`(도), `opacity` 0..255, `loop`, `startFrame`, `endFrame`(0 기준, `endFrame` 0 은
   한 프레임). 엔진 API 와의 대응은 4절.
9. text 의 props: `text`(줄바꿈과 한글 가능), `font`(.fnt 경로. 비어 있으면 게임이 준비해 둔 폰트), 선택 `color` [r, g, b, a].
10. `node` 는 아무것도 그리지 않는다. 컴포넌트를 붙이는 자리다.
11. `params` 는 컴포넌트 매개변수다. 컴포넌트 논리 이름에서 값 객체로 가는 객체이고, 기본은 없음이다.
    매개변수의 선언 파일, 로더의 의미, 검사는 5.4절. 2026-09-28 에 더한 키이며 포맷은 그대로 v1 이다
    (예전 로더는 모르는 키로 무시했다).

**계약에 더한 것 하나**: sprite 의 `frameDelay` (ms, 기본 100). 엔진의 프레임 지연 기본값이 0 이라 애니메이션이
매 틱 넘어가 버리므로 파일에서 정할 수 있게 했다. 없으면 100 이다. 에디터는 이 키를 모르는 키로 보존해도 되고
칸으로 노출해도 된다.

## 3. 검증 규칙 (에디터의 규칙과 같은 목록)

`SceneLoader.validate(표)` 가 Lua 에서는 `ok, err` 를 돌려주고 Ruby 에서는 `SceneLoader::Error` 를 던진다.
메시지는 두 언어가 같고 전부 `scene: ` 으로 시작한다. 에디터는 저장 전에 같은 목록을 검사해야 한다.

| 검사 | 메시지 |
|---|---|
| 표가 아니다 | `scene: not an object` |
| 버전이 1 이 아니다 | `scene: unsupported version <v> (expected 1)` |
| name 이 문자열이 아니다 | `scene: name must be a string` |
| objects 가 배열이 아니다 | `scene: objects must be an array` |
| 항목이 표가 아니다 | `scene: object #<n> is not an object` |
| id 가 없거나 빈 문자열 | `scene: object #<n> needs a non-empty string id` |
| id 중복 | `scene: duplicate id '<id>'` |
| type 이 없다 | `scene: object '<id>' needs a type` |
| 모르는 type | `scene: unknown type '<type>' (object '<id>')` |
| x, y 가 숫자가 아니다 | `scene: x must be a number (<id>)` |
| visible 이 불리언이 아니다 | `scene: visible must be a boolean (<id>)` |
| props 가 표가 아니다 | `scene: props must be an object (<id>)` |
| scripts 가 배열이 아니거나 항목이 빈 문자열 | `scene: scripts must be an array (<id>)`, `scene: scripts[<i>] must be a non-empty string (<id>)` |
| sprite 에 image 가 없다 | `scene: sprite '<id>' needs props.image` |
| sprite 숫자 props 가 숫자가 아니다 | `scene: props.<key> must be a number (<id>)` |
| width, height, frames, startFrame, endFrame, opacity 가 정수가 아니다 | `scene: props.<key> must be an integer (<id>)` |
| frames < 1, width/height < 0, startFrame/endFrame < 0, opacity 밖 | `scene: props.frames must be >= 1 (<id>)` 등 |
| loop 가 불리언이 아니다 | `scene: props.loop must be a boolean (<id>)` |
| text 의 text 가 문자열(또는 숫자)이 아니다, font 가 문자열이 아니다 | `scene: props.text must be a string (<id>)` 등 |
| color 가 [r, g, b] 나 [r, g, b, a] 가 아니거나 0..255 밖 | `scene: props.color must be [r, g, b] or [r, g, b, a] (<id>)` |
| 확장 타입의 검사 (tilemap: map 필수, groundLayers >= 0) | `scene: tilemap needs props.map (<id>)` |

컴포넌트 매개변수(`params`)와 선언 파일의 검사 목록과 메시지는 5.4절의 표에 따로 있다. 같은 `validate` 가 위의
검사를 전부 통과한 뒤에 그 검사를 한다.

검증은 이미지, 폰트, 맵, 컴포넌트 모듈을 열지 않는다 (그것들의 존재는 **열 때** 확인한다). 예외는 컴포넌트의
선언 파일(`scripts/components/<경로>.json`) 하나다. params 를 검사하려면 선언이 있어야 해서 검증이 읽는다.
열 때의 오류도 이름을 말한다: `scene: component 'components/x' not found (scripts/lua/components/x.lua)`,
`scene: cannot load image ./resources/x.png`, `scene: text 'l': cannot load font resources/fonts/x.fnt`,
`scene: tilemap 'map': cannot load resources/maps/x.json (...)`, `scene: cannot open scene ./resources/scenes/x.json (...)`.

## 4. 타입과 엔진 API 의 대응

### 4.1 sprite

텍스처 id 는 **이미지 경로**다. 같은 그림을 쓰는 오브젝트가 여럿이면 씬 안에서 참조 수를 세어 한 번만 읽고
마지막 것이 사라질 때 놓는다.

| props | Lua 호출 (Ruby 는 같은 뜻의 메서드) | 메모 |
|---|---|---|
| `image` | `TextureManager.Load("./" .. image, "./" .. image)` 뒤 `Sprite.Create(x, y, w, h, frames, id)` | 못 읽으면 오류 |
| `width`, `height` | `Sprite.Create` 의 프레임 크기 | 0 이면 로더가 **PNG 헤더(IHDR)** 에서 이미지 크기를 읽는다 (엔진이 텍스처 크기를 스크립트에 주지 않는다). `width` 0 은 이미지 폭을 `frames` 로 나눈 것, `height` 0 은 이미지 높이 전체. PNG 가 아니면 오류 |
| `frames` | `Sprite.Create` 의 maxFrames, 그리고 `Sprite.SetSheetGrid(frames, 1)` | 시트는 **가로 한 줄**로 본다 (엔진 기본 4x4 격자를 쓰지 않는다). 격자 시트(CharSet)는 v1 에 없다 |
| `startFrame`, `endFrame` | `Sprite.SetFrames(startFrame, last + 1)`, `Sprite.SetCurrentFrame(startFrame)` | `last` 는 `endFrame` 이되 0 이거나 `startFrame` 보다 작으면 `startFrame`. **엔진의 둘째 인자는 끝의 다음(exclusive)** 이라 `GetEndFrame()` 은 파일의 `endFrame` 그대로 나온다. Ruby `set_frames(first, last)` 도 같은 규칙이다 (README 대응표) |
| `frameDelay` | `Sprite.SetFrameDelay(ms)` | 기본 100 |
| `loop` | `Sprite.SetLoop` | |
| `scale`, `angle`, `opacity` | `SetScale`, `SetAngle`(도), `SetOpacity`(0..255 정수, 소수는 내림) | 만들 때와 **매 틱** |
| `x`, `y`, `visible` (오브젝트의 것) | `SetPosition`, `SetVisible` | **매 틱** `obj.x`, `obj.y`, `obj.visible` 을 옮긴다 |
| 매 틱 | `Sprite.Update(elapsed)` (`obj.animate == false` 면 0) | 트랜스폼 커밋과 애니메이션 |
| 그리기 | `Sprite.Draw` | `visible` 이 false 면 부르지 않는다 |
| remove, close | `Sprite.Dispose`, 참조 수 0 이면 `TextureManager.Remove` | |

로더가 채워 주는 오브젝트 필드: `obj.sprite`(핸들 또는 Sprite 객체), `obj.frameWidth`, `obj.frameHeight`
(Ruby 는 `frame_width`, `frame_height`), `obj.texture`(텍스처 id).

### 4.2 text

| props | 호출 | 메모 |
|---|---|---|
| `font` | `PreparaFont("./" .. font)` | 엔진의 비트맵 폰트는 **하나뿐**이다. 로더가 지금 준비된 경로를 기억해 다를 때만 다시 읽는다 (열 때와 그릴 때). 비어 있으면 게임이 준비해 둔 폰트를 쓴다. 못 읽으면 오류 |
| `text` | `DrawText(x, y, tostring(text))` | **줄바꿈은 엔진이 처리한다**: `Font::drawText` 가 `\n` 마다 x 로 돌아가고 y 를 lineHeight(hangul.fnt 는 32) 만큼 내린다. 숫자를 주면 문자열로 바꾼다 |
| `color` | 적용하지 않는다 | 엔진의 비트맵 폰트 API 에 색 인자가 없다 (SDL 백엔드의 `DrawText` 는 색 변조를 하지 않는다). `props.color` 에 보존되어 컴포넌트가 읽을 수는 있다. 엔진에 텍스트 색이 생기면 로더가 붙인다 (10절) |

### 4.3 node

아무것도 만들지 않고 그리지 않는다. `x`, `y`, `visible`, `props` 와 컴포넌트만 있다.

### 4.4 tilemap (확장 타입, `scene_types/tilemap`)

| props | Lua 호출 | Ruby 호출 |
|---|---|---|
| `map` | `Tilemap.Load("./" .. map)` | `Tilemap.new(path)` |
| `groundLayers` (기본 1) | 아래: `Tilemap.Draw(h, 1, ground, -x, -y)`, 위: `Tilemap.Draw(h, ground + 1, layerCount, -x, -y)` | 아래: `map.draw(0, ground - 1, -x, -y)`, 위: `map.draw(ground, layer_count - 1, -x, -y)` (레이어 0 기준) |
| 닫기 | `Tilemap.Dispose` | `map.dispose` |

`ground` 는 `groundLayers` 를 레이어 수로 자른 값이다. `obj.x`, `obj.y` 는 맵의 화면 위치이며 카메라의 반대
부호로 넘긴다. 로더가 채우는 필드: `obj.tilemap`, `obj.layerCount`, `obj.mapWidth`, `obj.mapHeight`,
`obj.tileWidth`, `obj.tileHeight` (Ruby 는 snake_case).

확장 타입 모듈의 표면 (`create` 만 필수):

| Lua | Ruby (`SceneTypes::<CamelCase>` 의 모듈 함수) | 언제 |
|---|---|---|
| `M.validate(spec) -> ok, err` | `validate(spec)` (오류면 `SceneLoader::Error`) | 검증 |
| `M.create(obj, scene)` | `create(obj, scene)` | 오브젝트를 만들 때 |
| `M.update(obj, scene, elapsed)` | `update(obj, scene, elapsed)` | 매 틱 (컴포넌트 update 뒤) |
| `M.drawBelow(obj, scene)` | `draw_below(obj, scene)` | 모든 오브젝트보다 먼저 |
| `M.draw(obj, scene)` | `draw(obj, scene)` | 오브젝트 순서 자리에서 |
| `M.drawAbove(obj, scene)` | `draw_above(obj, scene)` | 모든 오브젝트 뒤에 |
| `M.destroy(obj, scene)` | `destroy(obj, scene)` | remove, close |

코드로도 등록할 수 있다: `SceneLoader.registerType("이름", 모듈)` / `SceneLoader.register_type`.

## 5. 컴포넌트 계약

### 5.1 모듈과 훅

Lua 컴포넌트는 표 하나를 돌려주는 모듈이고, Ruby 컴포넌트는 클래스다. Ruby 클래스는 논리 이름 전체를 모듈
경로로 먼저 찾고 (`components/flappy/bird` → `Components::Flappy::Bird`), 그 상수가 없으면 파일 이름 마지막 조각의
CamelCase 클래스를 찾는다 (`components/pipe_spawner` → `PipeSpawner`, `components/flappy/bird` → `Bird`).
모듈 경로 쪽은 2026-09-28 에 더했다 (5.4절). 마지막 이름이 같은 두 컴포넌트가 함께 있을 수 있고, 예전 클래스는
그대로 찾아진다. 로더는 찾은 클래스로 **오브젝트마다 하나씩** 인스턴스를 만든다. 훅은 전부 선택이다.

```lua
-- scripts/lua/components/bird.lua
local M = {}
function M.init(obj, scene, params) end             -- 모든 오브젝트가 만들어진 뒤, 오브젝트 순서대로
function M.update(obj, scene, elapsed, params) end  -- 매 틱, elapsed 는 ms. 보이지 않는 오브젝트도 불린다
function M.render(obj, scene, params) end           -- 로더가 그 오브젝트의 스프라이트나 글자를 그린 뒤. visible 이 false 면 안 불린다
function M.destroy(obj, scene, params) end          -- remove 나 close 때
return M
```

Lua 훅의 마지막 인자 `params` 는 그 컴포넌트의 매개변수 표다 (5.4절). 2026-09-28 에 더한 인자라 받지 않는
예전 컴포넌트도 그대로 돈다.

```ruby
# scripts/ruby/components/bird.rb
class Bird
  def init(obj, scene); end
  def update(obj, scene, elapsed); end
  def render(obj, scene); end
  def destroy(obj, scene); end
end
```

Ruby 에서 훅의 유무는 `respond_to?` 가 아니라 클래스의 public 인스턴스 메서드 목록으로 본다. mruby 는
`main.rb` 의 최상위 `def init` 들을 모든 객체의 private 메서드로 만들어 `respond_to?(:init)` 이 참이 되기 때문이다.
그래서 훅은 실제로 정의된 public 메서드여야 한다 (상속은 된다).

### 5.2 obj (실행 오브젝트)

| 필드 | 뜻 |
|---|---|
| `id`, `type` | 파일의 것 |
| `x`, `y`, `visible` | 로더가 매 틱 스프라이트에 옮긴다. **컴포넌트는 `obj.x` 를 바꾸는 것으로 움직인다** |
| `props` | 파일 props 의 복사본에 기본값을 채운 것. 컴포넌트가 고쳐도 된다 (`opacity`, `scale`, `angle`, `text` 는 매 틱 반영) |
| `scripts` | 논리 이름 목록 |
| `sprite` | sprite 타입이면 엔진 핸들(Lua 숫자, Ruby `Sprite`), 아니면 nil. 엔진 API 를 직접 불러도 된다 |
| `scene` | 이 오브젝트가 속한 씬 |
| `spec` | 파일의 원본 항목 (모르는 키 포함) |
| `animate` | false 면 프레임 애니메이션만 멈춘다 (Sprite.Update 에 0 을 넘긴다). 기본 true |
| `frameWidth`, `frameHeight`, `texture` | sprite 타입에 로더가 채운다 |

Lua 의 obj 는 그냥 표라 컴포넌트가 아무 필드나 붙일 수 있다. Ruby 의 `SceneObject` 도 같게 했다: 정하지 않은
필드는 쓰면 붙고 읽으면 nil 이다 (`obj.target = ...`).

### 5.3 scene API

| Lua | Ruby | 뜻 |
|---|---|---|
| `scene:find(id)` | `scene.find(id)` | 오브젝트 또는 nil |
| `scene:spawn(spec [, afterId])` | `scene.spawn(spec, after_id = nil)` | 파일의 항목과 같은 표(Ruby 는 문자열 키 Hash)로 오브젝트를 만든다. `id` 가 없으면 `<type>_<n>` 으로 만들어 준다. 검증은 같은 규칙. `afterId` 를 주면 그 오브젝트 **바로 뒤**(그리기 순서)에 끼우고 없으면 맨 뒤. 컴포넌트 `init` 은 바로, `update` 는 다음 틱부터 |
| `scene:remove(id)` | `scene.remove(id)` | 컴포넌트 destroy, 스프라이트 해제. 없던 id 면 false |
| `scene:switch(name)` | `scene.switch(name)` | 다음 tick 에서 이 씬을 닫고 `resources/scenes/<name>.json` 을 연다 (경로도 된다) |
| `scene:objects()` | `scene.objects` | 그리기 순서의 목록 (복사본) |
| `scene.name`, `scene.state` | 같음 | `state` 는 컴포넌트들이 나눠 쓰는 빈 표/Hash |
| `scene.source`, `scene.path` | 같음 | 파일의 원본 표와 경로 |
| `scene:isClosed()` | `scene.closed?` | |

update 도중의 `spawn` 과 `remove` 는 된다. tick 은 목록의 복사본을 돌므로 이번 틱에 만든 것의 update 는 다음
틱부터고, 이번 틱에 없앤 것의 update 는 건너뛴다.

### 5.4 컴포넌트 매개변수 (params)

> 2026-09-28 추가. InitialEditor 의 `docs/plans/next-goals.md` 2절 B 의 엔진 쪽이다. 컴포넌트가 받을 값을
> 선언 파일에 적고, 씬 파일의 오브젝트가 값을 정하고, 로더가 검사해 컴포넌트에 넘긴다. 에디터는 선언 파일을
> 읽어 인스펙터의 입력 항목을 만든다. 씬 포맷은 그대로 v1 이다.

#### 선언 파일

컴포넌트 `components/<경로>` 의 매개변수는 `scripts/components/<경로>.json` 에 선언한다 (논리 이름에 `.json` 을
붙여 `scripts/` 아래에서 찾는다). 언어 중립의 JSON 이라 Lua 와 Ruby 가 한 파일을 같이 쓴다. 선언 파일이 없는
컴포넌트는 선언된 매개변수가 없다.

```json
{
  "version": 1,
  "fields": [
    { "key": "speed", "type": "number", "label": "속도", "default": 60, "min": 0 },
    { "key": "kind", "type": "enum", "values": ["ground", "pipes"], "default": "ground" },
    { "key": "target", "type": "object", "label": "대상" }
  ]
}
```

| 키 | 규칙 |
|---|---|
| `version` | 1 이어야 한다 |
| `fields` | 필드의 배열. 없으면 빈 배열이다. 배열의 순서가 에디터의 표시 순서다 |
| `key` | 필수. 식별자 `[A-Za-z_][A-Za-z0-9_]*`, 파일 안에서 유일 |
| `type` | 필수. `string`, `text`(여러 줄 문자열), `number`, `integer`, `boolean`, `enum`, `object` 중 하나. `object` 는 씬 오브젝트 id 를 가리키는 문자열이다 |
| `label` | 선택. 에디터에 보이는 이름 (문자열) |
| `default` | 선택. 타입에 맞아야 한다: string 과 text 는 문자열, number 는 숫자, integer 는 정수 값의 숫자, boolean 은 불리언, enum 은 `values` 중 하나, object 는 빈 문자열이 아닌 문자열. number 와 integer 는 `min`, `max` 안이어야 한다 |
| `values` | enum 에만 있고, enum 에는 필수. 빈 문자열이 아닌 문자열의 배열이며 하나 이상 |
| `min`, `max` | number 와 integer 에만, 선택. 숫자. 둘 다 있으면 `min <= max` |

선언 파일의 모르는 키(루트와 필드 안)는 무시한다. 에디터는 보존한다.

#### 씬 파일의 `params`

```json
{ "id": "world", "type": "node",
  "scripts": ["components/mover", "components/spawner"],
  "params": { "components/mover": { "dx": 2, "target": "bird" } } }
```

오브젝트의 `params` 는 컴포넌트 논리 이름에서 값 객체로 가는 객체다. 값 객체의 키는 선언의 `key` 다.

#### 로더의 의미 (두 언어가 같다)

1. 로더는 `scripts` 순서대로 컴포넌트마다 params 를 만든다. 선언의 `default` 들 위에 `obj.params[이름]` 의 값을
   덮는다. 기본값이 없고 씬 파일에도 없는 키는 params 에 없다 (Lua 는 nil, Ruby 는 키가 없다).
2. 컴포넌트마다 따로 만든다 (값은 깊은 복사). 한 오브젝트의 두 컴포넌트, 같은 컴포넌트를 붙인 두 오브젝트가
   같은 표를 나눠 쓰지 않는다. 컴포넌트가 제 params 를 고쳐도 다른 곳에 번지지 않는다.
3. `object` 값은 id 문자열 그대로 넘긴다. 컴포넌트가 `scene:find(params.target)` 로 찾는다.
4. 선언 파일이 없는 컴포넌트의 `params` 항목은 검사 없이 그대로 (깊은 복사로) 넘긴다. 게임은 선언을 쓰기 전에도
   params 를 쓸 수 있다.
5. JSON 의 `null` 은 없는 것으로 본다 (`"params": null`, 항목 값 null, 키 값 null, 선언의 `default: null` 등).
   Lua 의 `Json.Load` 가 null 을 nil 로 읽어 키가 사라지므로 Ruby 도 같게 한다.
6. 빈 배열 `[]` 은 빈 객체로도, 빈 객체 `{}` 는 빈 배열로도 본다. Lua 는 둘을 구분하지 못하므로 Ruby 도 같게 한다.
   비어 있지 않은 배열은 객체가 아니고, 문자열 키가 있는 객체는 배열이 아니다.
7. `props` 는 그대로다. `obj.props` 를 읽는 예전 컴포넌트는 바꾸지 않아도 돈다.
8. 한 오브젝트의 `scripts` 에 같은 컴포넌트가 두 번 있으면 예전처럼 둘 다 만든다. 둘 다 같은 `params[이름]` 값을
   따로 복사해 받는다. 에디터가 이 경우를 막는다.

**Lua**: 훅이 params 를 마지막 인자로 받는다. 표는 컴포넌트 인스턴스마다 하나라 네 훅이 같은 표를 받는다.

```lua
function M.init(obj, scene, params) end
function M.update(obj, scene, elapsed, params) end
function M.render(obj, scene, params) end
function M.destroy(obj, scene, params) end
```

**Ruby**: 컴포넌트 클래스의 `initialize` 가 위치 인자를 하나 이상 받으면 (`def initialize(params)`,
`def initialize(params = {})`, `def initialize(*args)`) 로더가 `new(params)` 로 만든다. params 는 문자열 키 Hash 다.
그렇지 않으면 예전처럼 `new` 다. 훅의 모양은 그대로다 (params 는 인스턴스가 들고 있다). 판정은
`instance_method(:initialize).parameters` 에 `:req`, `:opt`, `:rest` 가 있는가이다. initialize 를 정의하지 않은
클래스는 BasicObject 의 것을 쓰고 인자를 받지 않으므로 `new` 로 만든다.

```ruby
# scripts/ruby/components/mover.rb
class Mover
  def initialize(params)
    @params = params
  end

  def update(obj, scene, elapsed)
    obj.x += @params["dx"]
  end
end
```

**Ruby 클래스 찾기**: 논리 이름의 조각마다 CamelCase 로 바꿔 `Object` 에서 한 단계씩 따라간다
(`components/flappy/bird` → `Components` → `Flappy` → `Bird`). 각 단계는 상속을 보지 않는 `const_defined?(이름, false)`
다. 끝까지 있고 클래스이면 그것이고, 아니면 예전 규칙(마지막 조각, `Bird`)이다. 둘 다 없으면
`scene: component 'components/flappy/bird' must define class Components::Flappy::Bird or Bird (scripts/ruby/components/flappy/bird.rb)`.

#### 검사

`SceneLoader.validate` 가 3절의 검사를 **모든 오브젝트에 대해** 통과한 뒤에 오브젝트 순서대로 본다. object 값이
뒤에 나오는 오브젝트를 가리킬 수 있어서 id 를 다 모은 다음에 본다. 한 오브젝트 안의 순서는 이렇다.

1. `params` 가 객체인가 (없으면 통과).
2. `scripts` 순서대로 선언 파일을 읽는다. 없으면 선언 없음이고, 깨졌으면 그 파일을 말하는 오류다.
   `params` 가 없는 오브젝트도 읽는다 (기본값이 필요하다).
3. `params` 의 항목을 이름의 바이트 순서로 본다. 그 이름이 `scripts` 에 있는가, 값이 객체인가. 선언이 있으면 값
   객체의 키를 바이트 순서로 본다. 선언된 키인가, 값이 필드에 맞는가.

`scene:spawn(spec)` 도 같은 검사를 한다. object 값은 씬에 있는 id 와 새 오브젝트 자신의 id 를 가리킬 수 있다.
값의 검사는 선언의 `default` 검사와 같은 규칙이고, object 값은 거기에 더해 씬에 그 id 가 있어야 한다.
메시지 속의 숫자(`min`, `max`)는 정수 값이면 정수로 (`0`, `10`), 아니면 `%.14g` 로 쓴다 (`0.5`).
`<id>` 는 오브젝트의 id 다.

| 검사 | 메시지 |
|---|---|
| params 가 객체가 아니다 | `scene: params must be an object (<id>)` |
| params 의 이름이 scripts 에 없다 | `scene: params '<이름>': not in scripts (<id>)` |
| params 항목의 값이 객체가 아니다 | `scene: params '<이름>' must be an object (<id>)` |
| 선언이 있는데 선언에 없는 키 | `scene: params '<이름>': unknown key '<key>' (<id>)` |
| string, text 인데 문자열이 아니다 | `scene: params '<이름>': <key> must be a string (<id>)` |
| number 인데 숫자가 아니다 | `scene: params '<이름>': <key> must be a number (<id>)` |
| integer 인데 정수 값의 숫자가 아니다 | `scene: params '<이름>': <key> must be an integer (<id>)` |
| number, integer 가 min 보다 작다, max 보다 크다 | `scene: params '<이름>': <key> must be >= <min> (<id>)`, `... must be <= <max> (<id>)` |
| boolean 인데 불리언이 아니다 | `scene: params '<이름>': <key> must be a boolean (<id>)` |
| enum 인데 values 에 없다 (문자열이 아닌 값 포함) | `scene: params '<이름>': <key> must be one of <v1>, <v2> (<id>)` |
| object 인데 문자열이 아니거나 빈 문자열이다 | `scene: params '<이름>': <key> must be an object id (<id>)` |
| object 가 가리키는 id 가 씬에 없다 | `scene: params '<이름>': <key> names no object '<값>' (<id>)` |

선언 파일의 검사. `<경로>` 는 `scripts/components/x.json` 꼴이다. 루트, version, fields 를 본 뒤 필드를 배열 순서로
보고, 한 필드 안에서는 key, key 중복, type, label, values, min, max, min 과 max, default 의 순서로 본다. min 과 max 는
그 타입에 쓸 수 있는가를 먼저, 숫자인가를 다음에 본다.

| 검사 | 메시지 |
|---|---|
| JSON 으로 읽히지 않는다 | `scene: declaration <경로>: not valid JSON (<파서의 설명>)` |
| 루트가 객체가 아니다 | `scene: declaration <경로>: not an object` |
| version 이 1 이 아니다 | `scene: declaration <경로>: unsupported version <v> (expected 1)` |
| fields 가 배열이 아니다 | `scene: declaration <경로>: fields must be an array` |
| 필드가 객체가 아니다 | `scene: declaration <경로>: fields[<n>] is not an object` |
| key 가 없거나 식별자가 아니다 | `scene: declaration <경로>: fields[<n>] needs a key ([A-Za-z_][A-Za-z0-9_]*)` |
| key 중복 | `scene: declaration <경로>: duplicate key '<key>'` |
| type 이 없거나 문자열이 아니다 | `scene: declaration <경로>: field '<key>' needs a type` |
| 모르는 type | `scene: declaration <경로>: field '<key>': unknown type '<type>'` |
| label 이 문자열이 아니다 | `scene: declaration <경로>: field '<key>': label must be a string` |
| enum 의 values 가 없거나, 비었거나, 문자열이 아니거나 빈 문자열인 항목이 있다 | `scene: declaration <경로>: field '<key>': values must be a non-empty array of strings` |
| enum 이 아닌데 values 가 있다 | `scene: declaration <경로>: field '<key>': values is only for enum` |
| min, max 가 숫자가 아니다 | `scene: declaration <경로>: field '<key>': min must be a number` (max 도 같다) |
| number, integer 가 아닌데 min, max 가 있다 | `scene: declaration <경로>: field '<key>': min is only for number and integer` (max 도 같다) |
| min > max | `scene: declaration <경로>: field '<key>': min must be <= max` |
| default 가 타입에 맞지 않다 | `scene: declaration <경로>: field '<key>': default must be a string` 등 (params 값의 문장과 같다. object 는 `must be an object id` 이고 씬의 id 는 보지 않는다) |

`<n>` 은 1 부터 센다 (3절의 `scripts[<i>]` 와 같다). `<파서의 설명>` 은 엔진의 JSON 파서(jsoncpp)가 준 문장을 한
줄로 줄인 것이다. `<v>` 는 없으면 `nil` 이다.

선언은 컴포넌트 이름마다 한 번 읽어 VM 이 살아 있는 동안 기억한다 (없음도 기억하고, 깨진 파일은 기억하지 않는다). 핫 리로드는 VM 을 새로
만드므로 다시 읽는다.

#### 로더 API 에 더한 것

| Lua | Ruby | 뜻 |
|---|---|---|
| `SceneLoader.declarationPath(name)` | `SceneLoader.declaration_path(name)` | `scripts/components/x.json` 꼴의 경로 |
| `SceneLoader.declaration(name)` | `SceneLoader.declaration(name)` | 검사를 통과한 선언 표(Ruby 는 Hash), 파일이 없으면 nil. 깨졌으면 위 표의 오류 |
| | `SceneLoader.component_class_path(name)` | `"Components::Flappy::Bird"` 꼴의 모듈 경로 |
| | `SceneLoader.takes_params?(klass)` | 그 클래스를 `new(params)` 로 만드는가 |

## 6. 로더 API

| Lua | Ruby | 뜻 |
|---|---|---|
| `SceneLoader.open(nameOrPath)` | `SceneLoader.open(name_or_path)` | `Json.Load`/`Json.load` 로 읽고 검증하고 오브젝트를 만들고 컴포넌트 init 을 순서대로 부른다. 이름이면 `resources/scenes/<이름>.json`, `/` 가 있거나 `.json` 으로 끝나면 경로 |
| `SceneLoader.fromTable(tbl [, opts])` | `SceneLoader.from_hash(hash, name = nil, path = nil)` | 이미 읽은 표에서 |
| `SceneLoader.validate(tbl) -> ok, err` | `SceneLoader.validate(hash)` (오류면 `SceneLoader::Error`) | 3절의 목록 |
| `scene:tick(elapsed) -> scene` | `scene.tick(elapsed)` | 컴포넌트 update → 확장 타입 update → 스프라이트에 값 반영과 `Sprite.Update` → 예약된 switch. **다음 프레임에 쓸 씬을 돌려준다** (전환이면 옛 씬을 닫고 새 씬) |
| `scene:draw()` | `scene.draw` | 확장 타입 `drawBelow` 전부 → 오브젝트 순서대로 (스프라이트, 글자, 확장 타입 `draw`, 컴포넌트 `render`) → 확장 타입 `drawAbove` 전부. `visible` 이 false 인 오브젝트는 전부 건너뛴다 |
| `scene:close()` | `scene.close` | 오브젝트 순서대로 컴포넌트 destroy, 확장 타입 destroy, 스프라이트 해제. 그 뒤 텍스처 해제. 두 번 불러도 된다 |
| `SceneLoader.scenePath(name)`, `componentPath(name)`, `componentModule(name)`, `resolveType(type)`, `registerType(name, mod)` | `scene_path`, `component_path`, `component_class_name`, `resolve_type`, `register_type` | 이름 풀기와 확장 |
| `SceneLoader.declarationPath(name)`, `declaration(name)` | `declaration_path`, `declaration`, `component_class_path`, `takes_params?(klass)` | 컴포넌트 매개변수 (5.4절) |

오류는 Lua 에서 `error("scene: ...", 0)`, Ruby 에서 `SceneLoader::Error` 다. 엔진은 잡지 않은 오류를 stderr 에
찍고 종료 코드 1 로 끝내므로 씬 파일의 잘못은 게임을 띄우자마자 이름과 함께 드러난다.

## 7. 새 프로젝트의 진입점 (템플릿)

에디터가 새 프로젝트에 복사하는 파일 셋이 `resources/templates/` 에 있다.

- `main.lua` → `scripts/lua/main.lua`. Lua 의 씬 계약은 `Initialize`, `Update`, `Render`, `Destroy` 다
  (초안의 `init` 은 Ruby 이름이었다).
- `main.rb` → `scripts/ruby/main.rb`. 엔진이 mruby 를 고르게 하려면 `game.json` 에 `"script": "mruby"`.
- `scene.json` → `resources/scenes/main.json`. "새 프로젝트" 라고 쓴 text 하나.

```lua
local SceneLoader = require("scripts/lua/scene_loader")
local scene
function Initialize()
	local game = Json.Load("./game.json") or {}
	local wanted = (os.getenv ~= nil) and os.getenv("INITIAL2D_SCENE") or nil
	scene = SceneLoader.open(wanted or game.startScene or "main")
end
function Update(elapsed) scene = scene:tick(elapsed) end
function Render() scene:draw() end
function Destroy() scene:close() end
```

`INITIAL2D_SCENE=<이름>` 이 `game.json` 의 `startScene` 보다 우선한다. 에디터의 "현재 씬부터 실행"이 환경 변수
하나로 된다. `game.json` 이 없어도 된다 ("main").

## 8. 플래피를 씬으로

`resources/scenes/flappy.json` 은 스프라이트 다섯(배경 둘, 지면 둘, 새), 노드 둘(파이프, 감독), 글자 일곱이다.
컴포넌트는 `scripts/lua/components/flappy/` 와 `scripts/ruby/components/flappy/` 에 한 파일씩 짝이 있다.

| 오브젝트 | 컴포넌트 | 하는 일 |
|---|---|---|
| `bg1`, `bg2`, `ground1`, `ground2` (sprite) | `components/flappy/scroller` (`props.kind` 가 background 또는 ground) | 두 장을 이어붙여 왼쪽으로 흘린다. 지면은 파이프 속도, 게임 오버에는 멈춘다 |
| `bird` (sprite, 3 프레임, frameDelay 110) | `components/flappy/bird` | 대기 부유, 플레이 중력과 날갯짓, 게임 오버 추락. `obj.animate` 로 죽으면 날갯짓을 멈춘다 |
| `pipes` (node, `props.after = "bg2"`) | `components/flappy/pipes` | 파이프 3쌍을 `scene:spawn(spec, "bg2")` 로 배경 바로 뒤에 끼우고, 흘리고 되돌리고 점수를 세고 충돌을 본다. 새보다 뒤에 놓여 원래 게임과 같은 순서(새 물리 → 파이프)로 돈다 |
| `director` (node) | `components/flappy/director` | 상태 기계 ready → play → dead → ready, 조작, 자동 시연, 글자 오브젝트 켜고 끄기, 로그 |
| `title`, `best`, `score`, `over`, `result`, `hint1`, `hint2` (text) | 없음 | 감독이 `visible` 과 `props.text` 를 바꾼다 |

상수와 도우미는 `components/flappy/common` (컴포넌트가 아닌 모듈)에 있고 상태는 `scene.state.flappy` 한 표다
(Ruby 는 `scene.state[:flappy]`). 수치와 규칙은 `scripts/lua/games/flappy.lua` 와 같다. 자동 시연
(`INITIAL2D_AUTOPLAY`)이면 난수 씨앗을 `INITIAL2D_FLAPPY_SEED`(기본 1)로 고정하고, 상태 전이와 점수를
`flappy:state:<상태>`, `flappy:score:<점수>` 로 알린 뒤 900틱에 `flappyFinal state=... score=... best=... ticks=...`
를 찍고 스스로 끝낸다. 기존 `mruby_flappy_scene.rb` 가 하던 일을 감독 컴포넌트가 한다.

기존 `scripts/*/games/flappy.*` 와 그 인수 테스트는 손대지 않았다. 씬 판은 두 언어의 인수 씬
(`tests/engine/scenes/scene_flappy_scene.lua`, `mruby_scene_flappy_scene.rb`, 둘 다 템플릿 main 과 같은 내용)이
`INITIAL2D_SCENE=flappy` 로 열어 같은 검사를 통과한다.

## 9. 검수

- **단위** (엔진 VM 에서, 진짜 스프라이트와 텍스처): `tests/lua/cases/scene_loader_test.lua` 와
  `tests/ruby/cases/scene_loader_test.rb`. 검증(버전, 중복 id, 모르는 타입, 없는 컴포넌트, 기본값), 훅 순서
  (임시 컴포넌트 파일을 실제 경로에 써서 require 까지), spawn/remove/find (update 도중 포함), switch, 이름 풀기
  (언어별 폴더, Ruby CamelCase), sprite props 대응 (frames, startFrame/endFrame, width 0, 텍스처 id 와 해제),
  text, 픽스처 파일. Lua 121건 (전체 1794건), Ruby 126건 (전체 1769건).
- **씬**: `test_scene_loader_lua` / `test_scene_loader_mruby` 가 픽스처를 열어 순서, 모르는 키 보존, 프레임 크기,
  mover 의 이동과 멈춤을 stdout 으로 보고 골든 `tests/golden/scene_loader.png` 에 견준다 (두 언어가 같은 골든,
  각 17건). `test_scene_flappy_lua` / `test_scene_flappy_mruby` 는 `test_mruby_flappy_scene` 과 같은 검사 12건씩.
  전체 스위트(`tests/run_all.sh`)는 엔진 씬 442 PASS / 0 FAIL, C++ 단위 18, 브리지 25 로 통과했고 기존 테스트는
  손대지 않았다.
- **params (5.4절, 2026-09-28)**: 픽스처 `tests/fixtures/scenes/params_v1.json` 을 `test_scene_params_lua` /
  `test_scene_params_mruby` 가 열어 두 언어가 같은 stdout 13줄을 찍는지 본다 (각 16건). 기본값만, 모든 타입의 덮어쓰기와
  뒤의 오브젝트를 가리키는 object, 한 오브젝트의 두 컴포넌트(`probe` 와 `drift`), 선언이 없는 `loose`, `props` 를 읽는 예전
  `mover`(Ruby 는 인자 없는 `new`), params 로 움직인 오브젝트, 네 훅이 받은 값, 한 표를 고쳐도 번지지 않음, 검증 오류 한 문장.
  단위 케이스는 5.4절 두 표의 문장을 전부 글자 그대로 본다 (null 과 빈 배열, spawn, 키와 이름의 순서, Ruby 의
  `new(params)` 판정 여섯 가지와 모듈 경로 클래스 찾기 포함). scene_loader 케이스가 Lua 121 에서 208건 (전체 2569건),
  Ruby 126 에서 227건 (전체 2029건). 전체 스위트는 엔진 씬 621 PASS / 0 FAIL, C++ 단위 18, 브리지 25, 템플릿 44,
  스테이징 56 으로 통과했다.
- **픽스처**: `tests/fixtures/scenes/sample_v1.json`. 타입 넷 전부, 줄바꿈과 한글이 든 text, 컴포넌트가 움직이는
  node, `resources/maps/sample.json` 위의 tilemap, 루트와 오브젝트 안의 모르는 키 `editorOnly`. 에디터는 이 파일을
  열어 저장하면 같아야 한다 (모르는 키 보존).

## 10. v1 에 없는 것

- **카메라**: 씬 전체를 옮기는 카메라가 없다. tilemap 의 `x`, `y` 로 맵만 옮길 수 있고, 스프라이트는 컴포넌트가 직접 옮긴다.
- **레이어와 z 순서**: `objects` 의 순서뿐이다. 확장 타입의 아래/위 층은 tilemap 을 위한 것이고 화면 고정 UI 층이 없어
  tilemap 의 위 레이어가 글자를 덮는다 (픽스처의 label 이 장식 없는 띠에 있는 이유).
- **계층(부모 자식)과 프리팹**: 오브젝트는 평탄하다. 프리팹은 `spawn` 에 표를 넘기는 것으로 대신한다.
- **텍스트 색과 크기**: 엔진 API 에 없다. `color` 는 보존만 한다.
- **격자 시트(CharSet)**: `frames` 는 가로 한 줄이다. `columns`/`rows` 는 v2 후보.
- **소리, 입력, 저장**: 씬 파일에 없다. 컴포넌트가 엔진 API 로 한다.
- **리소스 고르기**(RTP 유무로 갈리는 논리 이름): 초안 5번의 후반부. v1 은 경로 그대로다.

## 11. 구현 메모 (배운 것)

1. **이미지 크기**: 엔진이 텍스처 크기를 스크립트에 주지 않아 `width`/`height` 0 을 풀려면 PNG 헤더를 24바이트 읽는다
   (Lua `io.open`, Ruby `File`). PNG 만 된다. C++ 을 고치지 않기 위한 선택이다.
2. **mruby 의 `respond_to?`**: 5.1절. 최상위 def 가 모든 객체의 private 메서드가 되어 `respond_to?(:init)` 이 참이다.
   `Class#instance_methods` 와 `Module#singleton_methods` 로 본다.
3. **텍스처 id 는 경로**: 같은 그림을 여러 오브젝트가 쓰는 것(파이프 여섯)을 참조 수로 처리한다. `TextureManager.Load` 는
   같은 id 를 두 번 읽어도 true 를 돌려주므로 세지 않으면 먼저 사라진 오브젝트가 남은 것의 텍스처를 놓는다.
4. **update 순서와 그리기 순서가 다를 때**: `spawn` 의 둘째 인자로 끼우는 자리를 정한다. 플래피의 파이프가 그 예다.
5. **헤드리스에서 프레임은 틱보다 빠르다** (60Hz 고정 스텝, 프레임은 초당 수백). 스크린샷 프레임 150 은 틱 몇 개다.
   골든에 찍히는 움직임은 첫 틱 둘 안에 끝나게 픽스처의 mover 가 102 씩 두 번 움직여 300 에서 멈춘다.
6. **엔진의 프레임 지연 기본값 0**: `frameDelay` 를 더한 이유. 없으면 새가 매 틱 날갯짓 프레임을 넘겼다.
7. **Lua 의 씬 계약 이름**: `Initialize`/`Update`/`Render`/`Destroy`. 초안의 소문자는 Ruby 이름이다.
8. **params 의 JSON 모양 (5.4절)**: 엔진의 `Json.Load` 는 null 을 nil 로 읽어 키가 사라지고, `[]` 과 `{}` 를 같은 빈 표로
   읽는다. 두 로더가 같은 결과를 내도록 Ruby 쪽이 null 을 없는 것으로, 빈 배열과 빈 객체를 서로 같게 본다. jsoncpp 는
   객체의 키를 정렬해 넘기므로 Ruby Hash 의 순서는 사전 순이고 Lua 표는 순서가 없다. 그래서 여러 오류 중 무엇을 먼저
   말할지는 이름과 키의 바이트 순서로 정했다.
9. **mruby 의 initialize 판정**: `instance_method(:initialize).arity` 는 initialize 를 정의하지 않은 클래스(BasicObject 의
   것)에서 -1 이라 쓸 수 없다. `parameters` 는 그 경우 `[]` 이므로 `:req`, `:opt`, `:rest` 가 있는지로 본다. 그 클래스에
   `new(params)` 를 부르면 ArgumentError 다.
10. **mruby 의 모듈 경로**: `Module#const_defined?(이름, false)` 로 한 단계씩 따라간다. mruby 에는 정규식이 없어 선언의
    key 식별자 검사는 바이트를 직접 본다.
11. **mruby 의 `String#gsub`**: 한글이 든 문자열에서 문자열 패턴을 바꾸면 그 뒤를 잃는다 (`"첫 줄\n둘째 줄".gsub("\n", "\\n")`
    이 `"첫 줄\\n"`). params 픽스처 씬은 `split` 과 `join` 을 쓴다. 로더는 gsub 을 쓰지 않는다.

## 체크리스트

- [x] 씬 포맷 v1 계약을 이 문서에 정본으로 적었다 (2절, 3절)
- [x] `scripts/lua/scene_loader.lua`: open, fromTable, validate, tick, draw, close, find, spawn, remove, switch, objects
- [x] `scripts/ruby/scene_loader.rb`: 같은 표면 (Ruby 이름)
- [x] 확장 타입 `scene_types/tilemap` 두 언어
- [x] 템플릿 `resources/templates/main.lua`, `main.rb`, `scene.json`
- [x] 플래피를 씬으로: `resources/scenes/flappy.json`, 컴포넌트 넷 + common, 두 언어
- [x] 픽스처 `tests/fixtures/scenes/sample_v1.json` 과 골든 `tests/golden/scene_loader.png`
- [x] 단위 케이스 두 언어, 씬 테스트 넷, 러너 함수 넷
- [x] README 「씬 파일과 씬 로더」, index.md R1 행
- [x] 컴포넌트 매개변수 (5.4절, 2026-09-28): 선언 파일 `scripts/components/<경로>.json`, 씬 파일의 `params`, 두 로더의
      같은 의미와 검사, Lua 훅의 마지막 인자, Ruby 의 `new(params)` 와 모듈 경로 클래스
- [x] params 픽스처 `tests/fixtures/scenes/params_v1.json`, 예제 컴포넌트 `components/sample/probe`, `drift`, `loose`
      두 언어, 씬 테스트 둘(`test_scene_params_lua`, `test_scene_params_mruby`), 단위 케이스 두 언어
- [x] `tools/web_stage.py`, `tools/hmr_push.py`, 브리지의 `POST /api/reload` 가 선언 파일을 싣는다, README 「씬 파일과 씬 로더」
- [ ] 에디터 쪽 E2/E3 가 같은 픽스처를 왕복한다 (InitialEditor 저장소)
- [ ] 에디터의 인스펙터가 선언 파일로 params 입력 항목을 만들고 5.4절의 문장으로 검사한다 (InitialEditor 저장소)
- [ ] 텍스트 색 (엔진에 색 인자가 생기면 `color` 를 붙인다)
