# R2. 엔진 API 명세와 스텁: 「바인딩이 늘고 명세를 안 고치면 테스트가 깨진다」

> 작성일 2026-09-26. **권장 모델 Opus 5** ([index.md](index.md) 4절 표). 에디터 트랙(index.md 8절)의
> 두 번째 단계이고, 에디터 쪽 짝은 E1(Monaco 자동완성)이다.

## 1. 목표 (한 문장)

**에디터 자동완성의 원천이 되는 스크립트 API 명세를 한 장으로 두고, 바인딩과 어긋나면 테스트가
깨지게 한다.** 엔진이 Lua와 Ruby에 내놓는 함수 전부(이름의 짝, 인자와 타입, 반환 타입, 한 줄 설명)가
`resources/api/initial2d-api.json`에 있고, 에디터는 그것을 읽는다.

## 2. 결정

| 결정 | 이유 |
|---|---|
| **명세는 JSON 한 장, 손으로 유지한다** | 커맨드 스키마([12-editor-events.md](12-editor-events.md) 3.1절)와 같은 방식이다. 이름은 VM에서 뽑을 수 있지만 인자의 뜻(레이어가 1 기준인지, 실패하면 nil인지 예외인지)은 C++에서 뽑을 수 없다. 그래서 사람이 적고 테스트가 이름과 반환 타입을 대조한다 |
| **스텁은 명세에서 만든다** (계획에서 바뀐 점) | 8절의 계획은 "스텁을 손으로 유지"였다. 명세와 스텁 둘을 손으로 두면 어긋날 자리가 둘이 된다. 스텁 두 장(`initial2d.lua`, `initial2d.rb`)은 `tools/gen_api_stubs.py`가 쓰고, `--check`가 신선도를 본다 |
| **에디터는 스텁 대신 JSON을 읽는다** | 두 언어가 한 항목에 짝으로 있어 Monaco 완성 항목을 만들기 쉽다. 스텁은 VS Code의 LuaLS와 Solargraph 같은 기성 도구를 위한 것이다 |
| **한 항목에 두 언어** | `lua`와 `ruby` 이름을 나란히 적고, 한쪽에만 있으면 `null`이다. Lua 전역 함수는 `lua`가 `null`인 모듈(`Graphics`, `System`, `Kernel`) 아래에 두고, 모듈 이름은 Ruby 쪽을 따른다 |
| **Lua의 클래스는 핸들 방식** (`"luaStyle": "handle"`) | Lua의 `Sprite`, `Tilemap`, `FontEx`는 숫자 핸들을 첫 인자로 받는 함수 표다. 명세의 메서드 인자에는 핸들을 적지 않고, Lua 스텁이 `handle` 인자를 앞에 붙인다 |
| **대조는 엔진 VM 안에서** | 바인딩의 진실은 실행 중인 VM이다. 두 단위 테스트가 명세를 엔진의 `Json.Load`와 `Json.load`로 읽는다. 명세 파일 자체의 규칙(타입 이름, 키 오타, 문장 부호)은 생성 도구가 본다 |
| **엔진 것을 가려내는 기준** | Lua는 C 함수인가(`debug.getinfo(f).what == "C"`), Ruby는 정의 위치가 C이거나 `<prelude>`인가(`source_location`). 스크립트가 덧붙인 함수는 엔진 표면이 아니다 |

## 3. 명세의 모양

```json
{
  "version": 1, "engine": "Initial2D", "generatedFrom": "...",
  "types": ["number", "integer", "string", "boolean", "table", "array", "function", "nil", "any",
            "Sprite", "Tilemap", "FontEx", "symbol"],
  "modules": [{ "name": "Graphics", "lua": null, "ruby": "Graphics", "doc": "...", "functions": [...] }],
  "classes": [{ "name": "Sprite", "lua": "Sprite", "ruby": "Sprite", "doc": "...", "luaStyle": "handle",
                "constructors": [...], "methods": [...] }],
  "constants": [{ "module": "Keys", "lua": null, "ruby": "Keys", "doc": "...", "names": [...], "values": {...} }],
  "sceneContract": [{ "name": "update", "lua": "Update", "ruby": "update",
                      "params": [{ "name": "elapsed_ms", "type": "number" }], "doc": "...", "luaRequired": true }]
}
```

함수 한 항목의 키 (`lua`, `ruby`, `params`, `returns`, `doc`은 늘 있고, `rubyKind`는 Ruby 이름이 있을 때, 나머지는 필요할 때만):

| 키 | 뜻 |
|---|---|
| `lua`, `ruby` | 이름. 없는 쪽은 `null`. 클래스 생성자는 `"Sprite.Create"`, `"Sprite.new"`처럼 점 경로 |
| `params` | `[{ "name", "type", "optional", "default", "variadic", "luaType", "rubyType", "doc" }]` |
| `returns` | 타입 식 하나. Lua에서 값을 여럿 돌려주면 `luaReturns`에 목록으로 |
| `doc` | 한 줄 한국어 설명 |
| `rubyKind` | `method`, `getter`(인자 없는 값), `setter`(`=`로 끝남), `predicate`(`?`로 끝남), `module_function`(받는 쪽 없이 부르는 `Kernel` 메서드). `ruby`가 `null`이면 없다 |
| `luaParams`, `rubyParams` | 두 언어의 인자가 다를 때 그 언어의 인자 목록 (예: Lua의 `draw_set_color`는 넷 다 필수, Ruby의 `set_color`는 `a = 255`) |
| `luaReturns`, `rubyReturns` | 두 언어의 반환이 다를 때 (예: Lua의 `GetPosition`은 값 둘, Ruby의 `position`은 배열) |
| `overloads` | 다른 인자 꼴의 목록 (`SetRect`의 표 하나짜리 꼴) |
| `alias`, `aliasOf` | 별명 (`trigger?`는 `key_down?`의 별명, Lua의 `draw_text`는 `DrawText`의 별명) |
| `prelude` | Ruby 쪽을 C++이 아니라 엔진의 Ruby 프렐류드가 정의한다 (`Sprite.load`, `Tilemap.load`, `Input.touches`, `Sprite#x=` 등) |

타입 식은 `types`의 이름 하나, 배열이면 `string[]`, 여럿이면 `integer|nil`이다. `number`는 수 전부
(Ruby의 Integer와 Float), `integer`는 정수만, `table`은 Lua 표이자 Ruby Hash, `array`는 배열,
클래스 이름은 Ruby 객체이자 Lua 숫자 핸들이다.

## 4. 어떻게 지키는가

### 4.1 단위 테스트 (엔진 VM 안에서, 두 방향)

`tests/lua/cases/api_surface_test.lua`의 `checkSpec`과 `tests/ruby/cases/api_surface_test.rb`의
`api_surface_spec` 케이스. 두 파일에 원래 있던 명시적 목록은 두 번째 의견으로 그대로 두었다.

| 방향 | Lua | Ruby |
|---|---|---|
| 명세 → VM | `lua` 이름마다 전역이나 표의 함수가 있다 | `ruby` 이름마다 `respond_to?`, `method_defined?`, `Kernel`은 `respond_to?(name, true)` |
| VM → 명세 | `_G`를 훑어 Lua 표준 전역 밖의 C 함수, 그리고 C 함수를 담은 표준 밖의 표를 찾는다. 찾은 것이 전부 명세에 있어야 한다 (**명세에 없는 새 모듈도 잡는다**) | 명세에 있는 모듈의 `singleton_methods`, 클래스의 `instance_methods(false)`와 `singleton_methods`가 전부 명세에 있어야 한다 |
| 상수 | 없음 (Lua에는 `Keys`가 없다) | `Keys.constants`와 명세의 `names`가 같고, 값도 같다 |
| 반환 타입 | `rubyKind`가 getter나 predicate이고 필수 인자가 없는 함수를 불러 보고 명세의 타입 식과 견준다. 클래스는 싸게 만든 인스턴스로 (`Sprite.Create`, 픽스처 맵의 `Tilemap.Load`) | 같은 규칙. 생성자 `Sprite.new`, `Tilemap.new`, `FontEx.new`의 반환 타입도 본다 |
| 정의 위치 | | `prelude` 표시가 실제 정의 위치(`<prelude>` 또는 C)와 맞는지 |

빠진 이름은 실패 메시지에 모두 찍힌다 (`VM -> 명세: Input 의 C 함수 14개가 모두 명세에 있다 | 명세에 없음: GetTouch`).

### 4.2 명세 도구 (`tools/gen_api_stubs.py`)

`--check`는 `tests/run_all.sh`의 3단계(도구 self-test)에서 돈다. 스텁을 쓰기 전에 명세의 규칙을 본다.
모르는 키(오타), `types`에 없는 타입, 비었거나 여러 줄인 `doc`, `doc`의 가운뎃점과 em-dash,
`?`로 끝나는 이름과 `predicate`의 짝, `=`로 끝나는 이름과 `setter`의 짝, 필수 인자가 있는 getter
(테스트가 인자 없이 부르므로), 인자가 하나가 아닌 setter, 같은 이름의 중복, 별명이 가리키는 항목의 존재,
`Keys`의 `names`와 `values`의 일치.

### 4.3 일부러 틀려 본 결과

통과만 보고 믿지 않도록 명세와 VM을 일부러 어긋나게 해서 두 테스트가 모두 깨지는 것을 확인했다
(확인 뒤 되돌렸다).

| 바꾼 것 | 잡은 곳 |
|---|---|
| 명세에서 `Input.GetTouch`, `touch` 항목을 지움 | Lua `VM -> 명세: Input`, Ruby `VM -> 명세: Input` |
| 명세에 없는 함수 `TextureManager.Bogus`, `bogus`를 더함 | 두 언어의 `명세 -> VM` |
| `WindowWidth`의 반환을 `string`으로 | 두 언어의 getter 반환 타입 |
| `Sprite`의 `visible?` 반환을 `number`로 | 두 언어의 인스턴스 getter 반환 타입 |
| `Input.touches`의 `prelude`를 지움 | Ruby의 정의 위치 검사 |
| `Keys`에서 `F12`를 지움 | Ruby의 상수 검사 |
| VM에 새 C 전역(`NewEngineFn = print`), 새 표(`FakeModule`), 표에 새 C 함수를 더함 | Lua의 전역 훑기, 모듈 발견, 표 훑기 |
| Ruby에서 C 메서드의 별명을 모듈과 클래스에 더함, 스크립트로 `def Graphics.script_added` | 앞의 둘은 잡고, 스크립트 정의는 엔진 것이 아니라 건너뛴다 |
| 스텁 파일 끝에 한 줄을 덧붙임 | `gen_api_stubs.py --check` 종료 코드 1 |
| `doc`에 가운뎃점, `width`를 `predicate`로, 타입 `int`, 키 오타 | `gen_api_stubs.py`의 규칙 위반 4건 |

## 5. 명세에 적은 것 (2026-09-26 기준)

| 묶음 | 항목 | Lua 이름 | Ruby 이름 | 비고 |
|---|---|---|---|---|
| `Graphics` (Lua 전역) | 11 | 11 | 10 | Lua `draw_text`는 `DrawText`의 별명 |
| `System` (Lua 전역) | 8 | 6 | 8 | Ruby 전용 `env`, `script` |
| `Kernel` (Lua 전역) | 4 | 2 | 2 | Lua 전용 `LoadScript`, `print`. Ruby 전용 `load`, `require` |
| `Input` | 18 | 14 | 18 | Ruby 별명 `trigger?`, `press?`, `release?`, 프렐류드 `touches` |
| `Audio` | 12 | 12 | 12 | |
| `Json` | 2 | 1 | 2 | Ruby 전용 `parse` |
| `TextureManager` | 3 | 3 | 3 | |
| 모듈 합계 | **58** | 49 | 55 | Lua 전역 함수는 19개 (`print` 포함) |
| `Sprite` | 생성자 2, 메서드 36 | 31 (생성자 1 + 30) | 38 (생성자 2 + 36) | Ruby 전용 `x`, `y`, `x=`, `y=`, `position=`, `disposed?` |
| `Tilemap` | 생성자 2, 메서드 12 | 7 (1 + 6) | 14 (2 + 12) | Ruby 전용 낱개 접근자 다섯과 `disposed?` |
| `FontEx` | 생성자 1, 메서드 10 | 10 (1 + 9) | 11 (1 + 10) | Ruby 전용 `disposed?` |
| 클래스 합계 | 생성자 5, **메서드 58** | 48 | 63 | |
| 상수 `Keys` | **82** | | 82 | 편집 키 24, 숫자 10, 숫자판 10, 알파벳 26, F1~F12 |
| 씬 계약 | 4 | `Initialize`, `Update`, `Render`, `Destroy` | `init`, `update`, `render`, `destroy` | Lua는 넷 다 필수, Ruby는 없는 것을 부르지 않는다 |

Lua 이름 97개(모듈 49, 클래스 48)는 VM의 엔진 C 함수(전역 18과 `print`, 표 일곱의 78)와 정확히 같다.
Ruby는 VM의 모듈 메서드 53개(`Kernel` 제외), 클래스 메서드 60개(`new` 셋은 `Class#new`라 빠진다), 상수 82개와 같다.

## 6. README와 바인딩이 다른 곳 (명세는 바인딩을 따랐다)

README는 고치지 않았다. 저자가 정할 일이라 목록으로 남긴다.

1. **README 「Font」 절의 예제 `Font("나눔고딕", 72)`는 동작하지 않는다.** `FontEx.Create`는 인자 넷
   (이름, 크기, 텍스처 가로, 세로)을 요구하고, `scripts/lua/Font.lua`는 빠진 둘을 nil로 넘겨
   `bad argument #3` 오류가 난다. 인자가 셋 이하면 0을 돌려준다. (README 「Lua 대응표」와 「스크립트 예제」의
   `Font("나눔고딕", 32, 400, 440)`은 맞다. `lua_font.cpp`의 주석도 인자 둘로 적혀 있다.)
2. **README 「Utils」의 `MessageBox(title, caption)`**: 바인딩은 첫 인자가 본문, 둘째가 제목이다
   (대응표의 `MessageBox(text, caption)`이 맞다).
3. **README 「Lua 대응표」의 `Sprite.load(path, id, x, y, w, h, frames = 1)`**: 프렐류드는 `x`, `y`,
   `width`, `height`도 기본값 0을 가진다 (`mrb_sprite.cpp`의 머리 주석도 README와 같다).
4. **`System.script`가 대응표에 없다.** Ruby 전용이고 언제나 `"mruby"`를 돌려준다.
5. **`DrawText`는 그린 픽셀 폭을 돌려준다** (Lua는 수, Ruby는 Integer, 폰트가 없으면 0). README는 반환을 말하지 않는다.
   R2 지시서의 예시는 `"returns": "nil"`이었으나 바인딩을 따랐다.
6. **Lua의 `draw_set_color`는 인자 넷이 다 필요하고** (셋이면 아무것도 하지 않는다) `draw_point`와 함께
   0을 돌려준다. Ruby의 `set_color`는 `a = 255`이고 둘 다 nil을 돌려준다.
7. **Lua의 `Audio.PlayMusic`, `PlaySound`, `InsertNextMusic`은 `loop`까지 셋 다 필요하다** (둘이면 조용히
   아무것도 하지 않는다). Ruby는 `loop`에 기본값이 있고(음악 true, 효과음 false) 읽기 성공 여부를 돌려준다.
8. **엔진의 `print`는 표준 print와 다르다.** 인자를 구분자 없이 잇고, 문자열과 숫자만 찍으며(불리언과
   nil은 빈 문자열), 인자 없이 부르면 `bad argument #0` 오류다.
9. **README 「Utils」의 `GetCurrentDirectory()`는 "윈도우즈 스타일"이라고 하지만** SDL2 빌드에서는
   인자와 상관없이 운영 체제의 구분자다 (macOS는 언제나 `/`). 인자는 `\`를 `/`로 바꿀 뿐이다.
10. **Lua의 Sprite getter는 모두 실수를 돌려준다** (`GetWidth`가 `16.0`이고 불투명도와 프레임 번호도 실수다).
    Ruby는 폭, 높이, 불투명도, 프레임 번호를 Integer로 돌려준다. 명세는 Lua `number`, Ruby `integer`로 적었다.
11. R2 지시서의 예시는 `Sprite.Create`의 짝을 `Sprite.load`로, `SetPosition`의 짝을 `position=`으로
    적었으나, 바인딩의 짝은 `Sprite.new`(같은 인자)와 `set_position(x, y)`다. `Sprite.load`는 텍스처까지
    읽는 프렐류드(Lua의 `scripts/lua/image.lua`에 해당)이고 `position=`은 `[x, y]` 하나를 받는 프렐류드 setter라
    Ruby 전용 항목으로 따로 적었다.

소스 주석이 바인딩과 다른 곳도 셋 있다. `lua_font.cpp`의 `FontEx.Create(FontFace, FontSize)`(실제는 인자 넷),
`mrb_sprite.cpp` 머리의 `Sprite.load` 인자(3번과 같음), `mrb_prot.cpp`의 `System.resource_files`
"./resources 바로 아래의 파일 이름 배열"(실제는 하위 폴더까지 훑은 `./resources/maps/sample.json` 꼴의 경로이며
Lua의 `GetResourcesFiles`도 같다). C++은 이 단계에서 고치지 않았다.

기존 명시적 목록의 빈 곳도 보였다. Lua 쪽 `GLOBALS`에 `GetPlatform`이, `Audio`에 `InsertNextMusic`이 없고
`Sprite`는 31개 중 16개만 있다. 목록은 지시대로 그대로 두었고, 명세 대조가 전부를 덮는다.

## 7. 작업 항목

- [x] `resources/api/initial2d-api.json`: 모듈 7(함수 58), 클래스 3(생성자 5, 메서드 58), `Keys` 상수 82, 씬 계약 4.
      바인딩 파일(`src/lua_*.cpp`, `src/mrb_*.cpp`)과 프렐류드를 한 줄씩 읽고 적었다
- [x] `tools/gen_api_stubs.py`: 표준 라이브러리만, 결정적. 명세 규칙 검사, Lua 스텁(LuaLS 주석,
      `---@meta`, 핸들 별칭, `---@overload`), Ruby 스텁(YARD, 예약어 상수 `self::END`), `--check`
- [x] `resources/api/initial2d.lua`, `resources/api/initial2d.rb` 생성 (`luac -p`, `ruby -c`, `mrbc` 구문 통과)
- [x] `tests/lua/cases/api_surface_test.lua`: 명세 대조 30건 (명시적 목록은 그대로)
- [x] `tests/ruby/cases/api_surface_test.rb`: 케이스 `api_surface_spec` 37건 (명시적 목록은 그대로)
- [x] `tests/run_all.sh` 3단계에 `python3 tools/gen_api_stubs.py --check`
- [x] 일부러 틀려 보기 (4.3절)
- [x] 문서: README 「스크립트 API 명세 (에디터 자동완성)」, 이 문서, index.md

## 8. 완료 기준

- [x] 명세가 두 언어의 바인딩 표면 전부를 적는다 (VM → 명세 방향이 빈 곳 없이 통과)
- [x] 바인딩을 더하고 명세를 안 고치면 테스트가 깨진다 (4.3절에서 확인)
- [x] 명세를 고치고 스텁을 안 만들면 `run_all.sh`가 멈춘다
- [x] 기존 검사는 그대로 통과하고 명세 대조가 더해졌다: Lua 단위 1673건에서 1703건, mruby 단위 1643건에서
      1680건. 전체 검수(`tests/run_all.sh`, 헤드리스) 통과 (C++ 단위 18, 엔진 씬 394 PASS / 0 FAIL, 브리지 25,
      RTP 1923). C++ diff 0

## 9. 남은 것

- **에디터 쪽(E1)은 InitialEditor 저장소의 일이다.** 명세는 브리지의 `GET /api/files/resources/api/initial2d-api.json`으로
  읽으면 되고 새 엔드포인트는 필요 없다 (`resources/`는 이미 허용 목록 안이다).
- **인자 타입은 대조하지 못한다.** 이 mruby에서 C 메서드의 `arity`는 모두 -1이고 Lua C 함수는 인자 수를
  알려 주지 않는다. 인자는 사람이 적은 그대로이며, 반환 타입도 인자 없는 getter만 불러 본다.
- **Ruby 쪽은 명세에 없는 새 최상위 모듈을 스스로 찾지 않는다.** mruby 내장 상수(Socket, Task 등)와 엔진
  모듈을 가를 기준이 없어서다. 바인딩은 두 언어가 짝으로 늘어나므로 Lua 쪽 발견이 대신 잡는다.
- 스크립트 레이어의 편의 함수(`scripts/lua/image.lua`의 `Image`, `scripts/lua/Font.lua`의 `Font`,
  `scripts/lua/rpg/` 전부)는 엔진 표면이 아니라 명세에 넣지 않았다. 필요해지면 같은 모양의 두 번째 명세로 둔다.
- 6절의 README 어긋남을 고칠지는 저자가 정한다.
