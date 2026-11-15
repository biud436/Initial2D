# 엔진 1. 기본 렌더링: 「셰이더 없이 되는 그리기를 스크립트가 다 쓴다」

> 작성일: 2026-11-15. 에디터 완성도 계획(`InitialEditor/docs/plans/quality.md` 10절)의 엔진 짝 첫째.
> 에디터 짝은 Q2(씬 편집)와 Q8(효과)이다. 진행 상황은 [index.md](index.md) 9절의 표에 있다.

## 1. 목표 (한 문장)

> SDL_Renderer 로 되는 기본 그리기(색 입히기, 기준점, 뒤집기, 혼합 모드, 글자 색과 크기, 도형, 렌더 타깃)를
> Lua 와 Ruby 가 같은 뜻으로 쓰고, 씬 파일의 sprite 와 text 가 그 값을 싣는다.

플래피버드에도 말이 되는 것들이라 C++ 코어에 둔다. 새가 기울며 떨어질 때 회전의 중심은 새의 가운데여야 하고(기준점),
점수 글자는 크고 색이 있어야 하며, 부딪히면 화면이 번쩍여야 한다(도형).

## 2. 무엇을 더했나

| 기능 | Lua | Ruby | 메모 |
|---|---|---|---|
| 색 입히기 | `Sprite.SetColor(id, r, g, b)`, `GetColor` | `set_color(r, g, b)`, `color` | 텍스처 색에 r/255, g/255, b/255 를 곱한다 (`SDL_SetTextureColorMod`) |
| 기준점 | `Sprite.SetPivot(id, x, y)`, `GetPivot` | `set_pivot(x, y)`, `pivot` | 칸 안의 비율. 위치는 이 점이 놓일 자리, 회전과 확대의 중심. 기본 0, 0 (예전 동작 그대로) |
| 뒤집기 | `Sprite.SetFlip(id, x, y)`, `GetFlip` | `set_flip(x, y)`, `flip` | 칸 안에서 뒤집는다. 기준점의 자리는 그대로 |
| 혼합 모드 | `Sprite.SetBlendMode(id, "add")`, `GetBlendMode` | `blend_mode = :add`, `blend_mode` | `normal`(알파), `add`, `multiply`(`SDL_BLENDMODE_MUL`). 다른 값은 오류 |
| 글자 색 | `SetTextColor(r, g, b, a)`, `GetTextColor` | `Graphics.set_text_color`, `text_color` | 흰 글리프에 곱한다. 기본 흰색 |
| 글자 크기 | `SetTextSize(px)`, `GetTextSize` | `Graphics.text_size=`, `text_size` | 줄 높이 픽셀. 0 은 폰트 파일의 크기. 글리프를 늘여 그린다 |
| 도형 | `DrawRect`, `FillRect`, `DrawLine`, `DrawCircle`, `FillCircle` | `Graphics.draw_rect` 등 | 색은 점의 색(`draw_set_color`, `Graphics.set_color`), 알파 혼합 |
| 렌더 타깃 | `TextureManager.CreateTarget(id, w, h)`, `SetRenderTarget(id)`, `GetRenderTarget`, `ClearRenderTarget` | `TextureManager.create_target`, `Graphics.set_render_target`, `render_target`, `clear` | 스프라이트가 그 id 로 그린다 |
| 텍스처 크기 | `TextureManager.GetSize(id)` | `TextureManager.size(id)` | 없는 id 는 nil |

명세는 `resources/api/initial2d-api.json` 에 있고 스텁은 `tools/gen_api_stubs.py` 가 다시 만들었다.

## 3. 동작의 세부

### 3.1 스프라이트

- 위치, 확대, 회전은 예전처럼 `Update` 가 만든 변환에서 읽는다. 색, 기준점, 뒤집기, 혼합 모드는 `Draw` 때의 값이다.
- 기준점 (px, py) 와 확대 s 에서 그리는 사각형은 `(x - px*w*s, y - py*h*s, w*s, h*s)` 이고 회전 중심은 그 안의
  `(px*w*s, py*h*s)` 다. 기준점 0, 0 이면 예전 그림과 픽셀까지 같다 (기존 골든이 그대로 통과한다).
- 텍스처 하나를 여러 스프라이트가 나눠 쓰므로 색과 알파와 혼합 모드는 그릴 때만 걸고 바로 되돌린다.

### 3.2 글자

- 글자 색과 크기는 전역 상태다 (`TextureManager::m_textColor`, `m_textSize`). 폰트를 바꿔도 남고, 스크립트가 다시
  시작하면(`Script_Init`) 점의 색과 함께 기본값으로 돌아간다.
- 크기를 바꾸면 커서를 실수로 진행하고 글리프의 네 변을 각각 반올림한다. 배율이 정수가 아니어도 글자 사이가 고르다.
  잘라 오는 칸은 폰트 파일의 크기 그대로다 (예전 코드는 확대하면 잘라 오는 칸까지 커져 옆 글자를 물고 나왔다).
- 폭 재기(`GetTextWidth`)도 같은 크기로 잰다. 크기 64 의 폭은 32 의 정확히 두 배다 (검수에서 확인).

### 3.3 도형

- 원은 반지름을 반올림한 정수로 그린다. 칠한 원은 가로 줄을 쌓고, 테두리는 중점 원 알고리즘으로 점을 찍는다.
  렌더러(Metal, OpenGL, 소프트웨어)마다 같은 픽셀이 나오고, 반투명 색에서 겹쳐 칠하는 픽셀이 없다.
- 점(`draw_point`)도 이제 알파 혼합을 한다. 예전에는 알파를 무시했다 (알파 255 에서는 같은 그림).

### 3.4 렌더 타깃

- `CreateTarget` 은 투명하게 지운 텍스처를 만든다. 같은 id 가 있으면 바꾼다.
- 엔진은 매 프레임 스크립트의 `Render` 뒤에 대상을 화면으로 되돌린다. 화면 캡처와 내보내기가 언제나 화면을 본다.
- 지금 그리는 렌더 타깃을 `TextureManager.Remove` 하면 먼저 화면으로 돌아간다.
- 렌더 타깃 안에서는 텍스처의 픽셀 좌표를 쓴다 (화면의 논리 해상도와 렌더 배율은 화면에만 걸린다).

### 3.5 Windows (GDI)

GDI 경로(`RS_WINDOWS`)는 고치지 않는다. 공용 코드는 `#ifndef RS_WINDOWS` 로 나눠 GDI 판에서는 예전 그리기를 그대로 부른다.
GDI 판은 새 값을 저장만 하고 그리지 않으며, `CreateTarget` 과 `SetRenderTarget(id)` 는 false 다.

## 4. 씬 파일 (포맷 v1 에 더한 키)

포맷은 그대로 v1 이다. 예전 로더는 모르는 키로 무시하고, 에디터는 보존한다. 정본은 [r1-scene-loader.md](r1-scene-loader.md) 2절과 3절.

| 타입 | 키 | 값 | 없을 때 |
|---|---|---|---|
| sprite | `color` | `[r, g, b]` 0..255 | 원래 색 |
| sprite | `pivot` | `[x, y]` 칸 안의 비율 | `[0, 0]` |
| sprite | `flipX`, `flipY` | 불리언 | false |
| sprite | `blend` | `"normal"`, `"add"`, `"multiply"` | `"normal"` |
| text | `color` | `[r, g, b]` 또는 `[r, g, b, a]` (예전부터 있던 키, 이제 적용한다) | 흰색 |
| text | `size` | 0 이상의 정수 (줄 높이 픽셀) | 0 (폰트 파일의 크기) |

로더는 sprite 의 넷을 만들 때와 **매 틱** 옮긴다 (컴포넌트가 `obj.props.color` 를 바꾸면 다음 틱에 보인다).
text 는 그리는 동안만 글자 색과 크기를 바꾸고 기본값으로 되돌린다.

## 5. 검수

- `tests/engine/scenes/render_basics_scene.lua` 와 `mruby_render_basics_scene.rb` 가 같은 그림을 그린다. 러너
  (`test_render_basics_lua`, `test_render_basics_mruby`)가 로그 16줄, 픽셀 검사 23개, 글자 폭, 골든 `render_basics` 를 본다.
  혼합 모드는 회색 (100, 100, 100) 위의 기대값(더하기 (255, 245, 137), 곱하기 (85, 57, 15))으로 확인한다.
- 씬 로더 단위 테스트(Lua, Ruby)에 새 키의 검사 메시지 여덟, 만들 때와 매 틱의 적용, 키를 지웠을 때의 기본값,
  text 를 그린 뒤 글자 상태가 돌아오는 것을 더했다.
- `api_surface_test` (Lua, Ruby)의 목록에 새 함수를 더했고 명세와 양방향으로 대조한다.
- 골든 `scene_loader` 를 갱신했다. 픽스처의 label 이 `color: [255, 255, 0, 255]` 를 가지고 있어 이제 노랗게 그려진다
  (바뀐 곳은 글자 두 줄뿐이다).

## 6. 남은 것

- **부모와 자식 좌표** (Q2 의 엔진 짝에 함께 적힌 것): 씬 포맷에 계층이 생겨야 한다. 에디터와 포맷을 먼저 맞춘다.
- **화면 효과의 묶음** (Q8): 페이드, 번쩍임, 흔들기, 입자는 이 단계의 도형과 혼합 모드로 스크립트 층에서 만든다.
- 음수 커닝: 폰트 파일의 커닝 쌍은 전부 음수인데 `Font::drawText` 는 양수만 쓴다. 고치면 모든 글자의 자리가 바뀌므로
  골든을 함께 갱신하는 별도 작업으로 둔다.

## 체크리스트

- [x] C++: `TextureManager::DrawSprite`, `CreateTarget`, `SetRenderTarget`, `ClearTarget`, 도형, 글자 색과 크기 (SDL2)
- [x] C++: `Sprite` 의 색, 기준점, 뒤집기, 혼합 모드. GDI 경로는 그대로
- [x] 매 프레임 렌더 타깃 되돌리기, 스크립트 시작 때 그리기 상태 되돌리기
- [x] Lua 바인딩과 mruby 바인딩
- [x] 명세와 스텁, `api_surface_test` 두 언어
- [x] 씬 로더 두 언어 (검사, 적용, 단위 테스트), r1 문서
- [x] 검증 씬 두 언어와 골든 `render_basics`
- [x] README (Image, TextureManager, Bitmap Text, 도형과 렌더 타깃, Ruby 대응표)
- [ ] 부모와 자식 좌표 (에디터와 포맷 합의 뒤)
