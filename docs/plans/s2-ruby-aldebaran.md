# S2. 알데바란을 Ruby 로: 「같은 게임을 두 언어로 돌린다」

> 작성일 2026-09-26. **권장 모델 Fable 5** (모듈 규약과 검증 전략이 판단의 본체이며, 모듈
> 단위의 번역은 Opus 5 에이전트에게 나눈다).
>
> 저자 지시 (2026-09-26): "스크립트 폴더를 더 깔끔히 정리하고, 알데바란도 포팅하세요."
> 선행: [S1 mruby 바인딩](s1-mruby-binding.md). 폴더는 `scripts/lua/` 와 `scripts/ruby/` 로
> 갈랐다 (PR #34).

## 1. 목표 (한 문장)

**Lua 알데바란과 Ruby 알데바란이 같은 화면을 그린다.** 증명은 S1 과 같은 방식이다.
Ruby 로 옮긴 인수 씬이 Lua 인수 씬과 **같은 골든**(`aldebaran_forest`, `aldebaran_title`,
`aldebaran_tomb_stars`)을 통과하고, 같은 봇이 1-1 과 1-2 를 주파한다.

## 2. 무엇을 옮기는가

알데바란 자체(약 3,900 줄)와 그것이 기대는 공용 모듈(약 2,000 줄), 그리고 그 모듈들의
Lua 단위 테스트(약 2,300 줄)다. Lua 쪽은 그대로 남는다. Lua 가 기본이고, Ruby 는 같은
게임의 두 번째 구현이다.

| Lua (`scripts/lua/`) | Ruby (`scripts/ruby/`) | Ruby 이름 | 담당 |
|---|---|---|---|
| `image.lua` | `image.rb` | `Image.create(path, x, y, w, h, frames, id)` → `Sprite` (+ `release`, `texture_id`) | 저자 에이전트(본체) |
| `rpg/rng.lua` | `rpg/rng.rb` | `Rpg::Rng` (클래스) | 본체 |
| `bgm.lua` | `bgm.rb` | `Bgm` (모듈) | E |
| `rpg/assets.lua` | `rpg/assets.rb` | `Rpg::Assets` (모듈) | E |
| `rpg/specs.lua` | `rpg/specs.rb` | `Rpg::Specs` (모듈, 상수 표 + 순수 함수) | E |
| `rpg/text.lua` | `rpg/text.rb` | `Rpg::Text` (모듈) | E |
| `rpg/window.lua` | `rpg/window.rb` | `Rpg::Window` (클래스. 순수 기하는 클래스 메서드) + `Rpg::Skin` (클래스) | E |
| `rpg/choice.lua` | `rpg/choice.rb` | `Rpg::Choice` (클래스) | E |
| `rpg/message.lua` | `rpg/message.rb` | `Rpg::Dialogue` (클래스. Lua 도 Dialogue 라 부른다) | E |
| `ui/touch.lua` | `ui/touch.rb` | `Ui::Touch` (모듈) | D |
| `ui/layout.lua` | `ui/layout.rb` | `Ui::Layout` (모듈) | D |
| `ui/vpad.lua` | `ui/vpad.rb` | `Ui::VirtualPad` (클래스 + `should_show?`) | D |
| `ui/buttons.lua` | `ui/buttons.rb` | `Ui::Buttons` (클래스. 순수 판정은 클래스 메서드) | D |
| `tests/lua/input_replay.lua` | `tests/ruby/input_replay.rb` | `InputReplay` (클래스) | D |
| `games/aldebaran/player.lua` | `games/aldebaran/player.rb` | `Aldebaran::Player` (클래스) | A |
| `games/aldebaran/combat.lua` | `games/aldebaran/combat.rb` | `Aldebaran::Combat` (모듈) | A |
| `games/aldebaran/monster.lua` | `games/aldebaran/monster.rb` | `Aldebaran::Monster` (클래스) | B |
| `games/aldebaran/data/monsters.lua` | `games/aldebaran/data/monsters.rb` | `Aldebaran::Monsters` (모듈, 상수 표) | B |
| `games/aldebaran/climate.lua` | `games/aldebaran/climate.rb` | `Aldebaran::Climate` (모듈 함수 + `Aldebaran::Climate::State`) | C |
| `games/aldebaran/stages/{init,forest,tomb}.lua` | `games/aldebaran/stages/{init,forest,tomb}.rb` | `Aldebaran::Stages`, `Aldebaran::Stages::Forest`, `::Tomb` (모듈) | C |
| `games/aldebaran/hud.lua` | `games/aldebaran/hud.rb` | `Aldebaran::Hud` (클래스) | 본체 |
| `games/aldebaran/title.lua` | `games/aldebaran/title.rb` | `AldebaranTitleScene` (모듈) | 본체 |
| `games/aldebaran/game.lua` | `games/aldebaran/game.rb` | `AldebaranScene` (모듈) | 본체 |
| `tests/engine/scenes/aldebaran_scene.lua` | `tests/engine/scenes/mruby_aldebaran_scene.rb` | 인수 씬 | 본체 |

단위 테스트는 `tests/lua/cases/<이름>.lua` 를 `tests/ruby/cases/<이름>.rb` 로 하나씩 옮긴다.
목록은 `tests/ruby/manifest.rb` 에 미리 적어 두었다 (파일이 없으면 러너가 "케이스 로드
실패"로 알린다).

## 3. 번역 규약 (전원이 따른다)

이름은 Ruby 관례를 따르되 Lua 와 **하나씩 짝**이 있어야 한다. 읽는 사람이 Lua 파일을 옆에
놓고 한 줄씩 대조할 수 있게 **구조와 주석을 그대로 옮긴다** (Lua 주석의 한국어 문장을 살린다).

### 3.1 모듈과 객체

- Lua 의 `local M = {}` + `M.new(...)` 가 있으면 **클래스**다. `M.func(self, ...)` 와
  `obj:func(...)` 는 **인스턴스 메서드** `obj.func(...)`. `self.x` 필드는 `attr_accessor`.
- `M.func(...)` 에 self 가 없고 `new` 도 없으면 **모듈 함수** (`module Foo; def self.func`).
- `M.CONST` → `Foo::CONST`. Lua 의 대문자 표(`M.SKILLS`, `M.EXP_TABLE`)도 상수다.
- Lua 의 기록용 테이블(`{ x = 1, y = 2 }`: 배치, 종별 표, 옵션, 입력, 결과)은 **Symbol 키
  Hash** (`{ x: 1, y: 2 }`). 키는 snake_case (`chargeAtk` → `:charge_atk`).
- Lua 의 문자열 열거값(`"patrol"`, `"crit"`, `"wind"`, `"snow"`, 버튼 id `"jump"`)은
  **Symbol** (`:patrol`). 외부 데이터(JSON 맵)에서 온 문자열은 문자열 그대로.
- 콜백(`measure`, `drawText`, `probe`, 효과음 함수)은 **Proc/lambda** 이고 `.call` 로 부른다.
  기본값이 엔진 전역이면 Ruby 에서는 `Graphics.text_width`, `Graphics.draw_text` 를 감싼 lambda.
- 옵션 테이블 인자 `M.new{ skin = ..., scale = 2 }` 는 **키워드 인자** `new(skin:, scale: 2)`.
  Lua 가 옵션 하나로 받던 자리(`VirtualPad.new(controls.pad)`)는 Hash 하나도 받게 한다.
- **필드 이름 `def` 는 쓰지 않는다** (Ruby 예약어). 종별 표나 기후 표를 가리키는 `m.def`,
  `climate.def` 는 `spec` 으로. 표 안의 방어력 `def` 키는 `:defense`.
- Lua 의 `nil` 을 돌려주는 생성자(`Climate.new(nil) → nil`)는 클래스 `new` 로 만들 수 없다.
  모듈 함수 `Climate.create(def)` 로 두고 나머지 함수는 `nil` 상태를 그대로 받는다.

### 3.2 숫자와 컬렉션 (틀리기 쉬운 곳)

- **Ruby 의 `/` 는 정수끼리면 정수 나눗셈이다.** Lua 의 `/` 는 언제나 실수다. 피연산자가
  정수일 수 있는 나눗셈은 `a.to_f / b` 나 `a.fdiv(b)` 로 쓴다. Lua 의 `//` 만 정수 나눗셈이다.
- `math.floor(x)` → `x.floor` (Integer 가 나온다). `math.min/max` → `[a, b].min/max`.
- `%` 는 두 언어가 같다 (부호는 제수를 따른다).
- 배열은 **0 기준**. `#t` → `size`, `t[#t + 1] = v` → `push`, `ipairs` → `each`,
  `for i = a, b` → `(a..b).each`, 역순 삭제 루프는 `delete_if` 나 인덱스 역순.
- Lua 의 `x or default` 는 `x || default`. 0 과 "" 는 두 언어 모두 참이다.
- 문자열은 UTF-8 이며 mruby 는 `size`, `chars`, `[]` 가 글자 단위다 (`bytesize` 가 바이트).
  `text.lua` 의 바이트 패턴은 `chars` 로 바꾼다. `last:byte(1,3)` 로 코드포인트를 만들던
  자리는 `last.ord`.
- `string.format` → `format`. `tostring` → `to_s`. `table.concat` → `join`.
- `os.getenv` → `System.env`. `io.open` → `File`. `print` → `puts` (Lua 의 print 는 인자를
  구분자 없이 잇는다. 검수 러너가 보는 문자열은 그 형식을 그대로 맞춘다).

### 3.3 엔진 API

S1 의 대응표(README 「mruby 스크립팅」)를 그대로 쓴다. 자주 나오는 것:

| Lua | Ruby |
|---|---|
| `Image(path, x, y, w, h, frames, id)` | `Image.create(path, x, y, w, h, frames, id)` (`scripts/ruby/image.rb`) |
| `img.setPosition(x, y)`, `img.setRect(x, y, w, h)`, `img.setSheetGrid(c, r)` | `set_position`, `set_rect`, `set_sheet_grid` |
| `img.setLoop(b)`, `setScale(s)`, `setOpacity(a)`, `setFrames(a, b)`, `setCurrentFrame(f)` | `loop=`, `scale=`, `opacity=`, `set_frames`, `current_frame=` |
| `img.update(0)`, `img.draw()` | `update(0)`, `draw` |
| `img.dispose()` (텍스처까지 놓는다) | `img.release` (`dispose` + `TextureManager.remove`) |
| `Input.IsKeyDown(VK)` 등 | `Input.key_down?(:z)` (Symbol 이나 정수) |
| `Input.IsMouseDown(0)`, `GetMouseX()` | `Input.mouse_down?(:left)`, `Input.mouse_x` |
| `Input.GetTouchCount()`, `GetTouch(i)` (1부터, 값 넷) | `Input.touch_count`, `Input.touch(i)` (0부터, `[id, x, y, phase]`) |
| `Tilemap.IsPassable(map, x, y)`, `Tilemap.Draw(map, 1, n, cx, 0)` | `map.passable?(x, y)`, `map.draw(0, n - 1, cx, 0)` (레이어 0 기준) |
| `Audio.PlaySound(path, id, 0)` | `Audio.play_sound(path, id, 0)` |
| `GetTextWidth`, `DrawText`, `PreparaFont`, `WindowWidth()` | `Graphics.text_width`, `draw_text`, `prepare_font`, `Graphics.width` |
| `SetRenderScale(n)` | `Graphics.render_scale = n` |
| `GameExit()` | `System.exit` |

가짜 입력(`InputReplay`)과 테스트의 가짜 Input 은 **Ruby 이름의 표면**을 흉내낸다
(`key_down?`, `mouse_down?`, `touch_count`, `touch`). `Ui::Touch.pointers(input)` 도 그 표면을 읽는다.

### 3.4 테스트

- 프레임워크는 `tests/ruby/test.rb` 다. 케이스 파일은 `T.run_case("이름") do |t| ... end`
  하나로 감싸고, `t.check(cond, 라벨, 상세)`, `t.check_eq(실제, 기대, 라벨)`,
  `t.check_type(값, 클래스, 라벨)` 을 쓴다. 오류 기대는 `begin/rescue`.
- 라벨(한국어)은 Lua 케이스와 같게 둔다. 검사 수가 늘어도 줄지는 않는다.
- Lua 케이스가 가짜 Image 나 가짜 Audio 를 주입하면 같은 가짜를 Ruby 로 만든다. 가짜
  Image 는 `Image.create` 가 돌려주는 `Sprite` 의 표면(3.3)을 흉내낸다.
- 돌리는 법 (mruby 단위 테스트만, 10초 안팎):

  ```bash
  cmake --build build > /dev/null && SDL_VIDEODRIVER=dummy python3 tests/run_engine_tests.py --only=mruby_units
  ```

  전체는 `tests/run_all.sh`. 골든과 인수 씬은 본체가 돌린다.

### 3.5 하지 않는 것

- 엔진(C++)은 손대지 않는다. 바인딩이 모자라면 본체에 보고한다.
- Lua 쪽 파일은 읽기만 한다. 고치지 않는다.
- 다른 담당의 파일을 만들거나 고치지 않는다. 의존하는 모듈이 아직 없으면 그 이름과
  표면(이 문서 2절과 3절)만 믿고 쓴다.

## 4. 작업 항목

- [x] 본체: `image.rb`, `rpg/rng.rb`(+테스트), 이 문서, `manifest.rb` 선등록, 러너 `--only`
- [x] A: `player.rb`, `combat.rb` + `aldebaran_player_test.rb`, `aldebaran_combat_test.rb`
      (Lua 와 6000 프레임 비트 단위 일치를 따로 확인했다)
- [x] B: `monster.rb`, `data/monsters.rb` + `aldebaran_monster_test.rb`, `aldebaran_monsters_data_test.rb`
- [x] C: `climate.rb`, `stages/{init,forest,tomb}.rb` + `aldebaran_climate_test.rb` (스테이지 케이스 포함)
- [x] D: `ui/{touch,layout,vpad,buttons}.rb`, `tests/ruby/input_replay.rb` + `touch_test.rb`,
      `layout_test.rb`, `vpad_test.rb`, `buttons_test.rb`, `input_replay_test.rb`
- [x] E1: `bgm.rb`, `rpg/{assets,specs,text}.rb` + 테스트 넷. E2: `rpg/{window,choice,message}.rb` + 테스트 셋
- [x] 본체: `hud.rb`, `title.rb`, `game.rb`, `scripts/ruby/main.rb` (알데바란 타이틀로 부팅),
      `tests/engine/scenes/mruby_aldebaran_scene.rb`, 러너의 Ruby 인수 (같은 골든)
- [x] 문서: README 「mruby 스크립팅」에 Ruby 알데바란 실행법, index.md 의 S2 행

## 5. 완료 기준

- [x] `INITIAL2D_SCRIPT=mruby ./build/Initial2D` 가 알데바란 타이틀로 뜨고, 시작하면 숲이 열린다
      (인수 씬의 titleScene → sceneAfterStart 가 그 길이다)
- [x] Ruby 인수 씬이 Lua 인수 씬의 검사와 **같은 골든 세 장**을 통과한다 (80 PASS / 0 FAIL)
- [x] 옮긴 단위 테스트가 전부 통과한다 (Lua 케이스 수 이상. 검사는 Lua 보다 늘었다)
- [x] 기존 전체 스위트 무변경 통과, C++ diff 0

## 6. 구현 메모 (에이전트 여섯의 보고를 합쳤다)

1. **이 mruby 는 몇몇 실수 리터럴을 1ulp 다르게 읽는다.** `0.3`, `0.35`, `0.6`, `0.7`, `0.95` 가
   그렇다 (`0.3 == 3.0 / 10` 이 거짓). A 가 Lua 와 Ruby 의 Player 를 같은 입력으로 6000 프레임
   돌려 비트 단위로 대조하다가 찾았다. Lua 와 같은 값이 필요한 자리(몬스터 표, 기후 임계값,
   환각 페이드)는 나눗셈 `3.0 / 10`, `35.0 / 100` 으로 적었다. IEEE 나눗셈은 정확히 반올림되므로
   Lua 의 strtod 와 같은 double 이 나온다.
2. **없는 것 둘.** Homebrew mruby 에는 `Regexp` 가 없고(정규식 리터럴이 NameError) `Range#step`
   도 없다. `game.rb` 의 시작 x 파싱은 손으로, 홍수 물 타일링은 while 로 썼다.
3. **선택지 번호는 0 기준.** Lua 는 1 기준이다. 타이틀의 START/HELP/LEAVE, 일시 정지의
   "다시 하기"(1)와 "끝내기"(2), 인수 씬의 `titleItems:3 index:1` 출력(+1)이 그 자리다.
4. **`def` 는 못 쓴다.** 종별 표를 가리키던 `m.def` 는 `m.spec`, 방어력 키 `def` 는 `:defense`.
5. **첫 인수 실행에서 1-1 과 1-2 가 바로 통과했다.** 실패 다섯은 전부 2번 항목(Regexp, step)이었고
   물리와 전투와 상태 기계는 첫 시도에 Lua 와 같은 결과(아포피스 처치, 32회 피격, 1회 사망)를 냈다.
6. **Dialogue 의 `port` 는 Hash 가 아니라 위임 객체**(`Rpg::Dialogue::Port`)다. Ruby 실행기가 생기면
   `port.show_message(...)` 로 부른다.
