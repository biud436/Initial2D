# Initial2D

Lua 스크립트로 게임을 만드는 범용 2D 엔진. Windows(GDI), macOS(SDL2), Android(SDL2)를 지원한다.

## 로드맵과 진행 상황 (필독)

- **작업을 시작하기 전에 반드시 `docs/plans/index.md`를 읽는다.** 전체 계획, 단계별 문서, 그리고 현재 어디까지 진행되었는지가 그 문서의 진행 상황 표에 있다.
- 작업이 끝나면 해당 단계 문서의 체크리스트와 `docs/plans/index.md`의 진행 상황 표를 갱신한다.
- **구현은 자율 검증 루프로 진행한다** (`docs/plans/09-testing.md` 10절): 스스로 빌드하고 테스트를 돌려 통과할 때까지 반복한다. 테스트를 약화시켜 통과시키는 것은 금지이며, 같은 실패가 세 번 반복되면 멈추고 사용자에게 보고한다. 게임 실행 확인은 반드시 `INITIAL2D_EXIT_AFTER`와 조합해 유한 실행으로 한다.

## 설계 원칙

- **범용 엔진이다.** RPG Maker급 게임도, 플래피버드도 만들 수 있어야 한다. RPG 전용 개념(캐릭터, 이벤트, 대화창)은 C++ 코어에 넣지 않고 `scripts/rpg/` Lua 레이어에 둔다. 판단 기준: "이 기능이 플래피버드에도 말이 되는가?"
- **게임 로직과 콘텐츠는 Lua**(`scripts/`), C++은 엔진과 플랫폼 어댑터만.
- Windows GDI 코드(`archive/windows-gdi` 브랜치와 `RS_WINDOWS` 경로)는 수정하지 않는다.
- `resources/RTP.zip`과 그 변환 결과물은 라이선스상 git에 커밋 금지 (gitignore 유지).

## 문서와 커밋

- 문서는 한국어로 작성하고, 가운뎃점(·)을 쓰지 않는다 (쉼표나 풀어쓰기).
- 새 도구나 워크플로우를 만들면 사용법을 docs/뿐 아니라 README.md에도 반드시 정리한다.
- 커밋 메시지는 **영어**로 작성한다 (타입 접두사 feat:, fix:, docs:, test: 유지). 커밋 끝에 `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>` 푸터를 표시한다. push된 이력은 재작성하지 않는다.
