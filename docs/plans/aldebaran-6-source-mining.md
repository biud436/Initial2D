# A6 (P0). 알데바란: 원안 완전 채굴 — "쓰지 않은 데이터를 전부 꺼낸다"

> 상위 계획: [docs/prompts/aldebaran-game-meta-prompt.md](../prompts/aldebaran-game-meta-prompt.md) P0.
> 마일스톤 M1(근거)의 첫 Phase. 권장 모델 Opus 5.
> 작성일 2026-08-23.

## 1. 목표 (한 문장)

`docs/design/Spica_v0.9.docx`에 있는 것 중 **게임에 반영된 것과 남은 것을 한 표로 답할 수 있게**
하고, 남은 것이 들어갈 그릇(`data/monsters.lua`)을 원안 규격서 모양으로 미리 판다.

이 Phase는 사용자 판정 다섯 중 **5번(기획서의 지도 데이터를 쓰지 않았다)**을 정면으로 겨냥하되,
그 답을 내는 것은 P6이다. 여기서는 **무엇이 안 쓰였는지를 셀 수 있게** 만든다. 1번(데모다),
3번(게임성이 낮다)의 재료도 여기서 나온다.

## 2. 시작 시점의 사실 (2026-08-23 코드로 확인)

- 원안 docx: 표 58개, 최상위 문단 237개(빈 문단 포함), 이미지 17장
  (png 7, jpeg 6, emf 4). `docs/design/.gitignore`가 docx를 이미 막고 있다.
- 채굴 산출물 없음. `docs/design/spica-source/`도 `tools/spica_extract.py`도 없다.
- 몬스터 데이터는 `scripts/games/aldebaran/stage.lua`의 `M.species` 표 하나이고
  종별 4종, 칸은 전투 8칸 + 스프라이트 7칸이다. `data/` 디렉터리는 아직 없다.
- `M.species`를 읽는 곳은 `game.lua` 다섯 군데뿐이다
  (`game.lua:200,203,411,504,972`). 테스트는 표시 이름(`def.name`)으로만 본다.

## 3. 작업 항목

- [x] 1. **추출기** `tools/spica_extract.py`. 표준 라이브러리(`zipfile` + `xml.etree`)만 쓴다.
      다시 돌릴 수 있어야 하고, 문서의 순서(문단과 표가 섞인 순서)를 보존한다.
      절 번호를 문단에서 뽑아 각 표에 **가장 가까운 앞 절 번호**를 붙인다.
- [x] 2. **`docs/design/spica-source/tables.md`**: 표 58개 전부. 표마다 번호, 절, 캡션, 크기.
- [x] 3. **`docs/design/spica-source/text.md`**: 문단 전부. 절 제목 위계를 살린다.
- [x] 4. **`docs/design/spica-source/media.md`**: 이미지 17장을 절 번호와 짝짓는다.
      `.emf` 4장은 macOS에서 바로 못 보므로 변환을 시도하고, 실패하면 그 사실을 적는다.
- [x] 5. **`docs/design/spica-unused.md`**: 미채택 데이터 목록.
      항목마다 `원안 절 / 내용 요약 / 게임성 가치(상중하) / 갈 Phase / 기각이면 이유`.
      **반드시 들어갈 항목**: 12 스테이지 구조, 적의 4가지 공격 방식, 몬스터 규격서의
      미사용 칸 전부, 상태 이상(마비와 독), 스킬 시스템, 상점 3화폐, 세계 지도.
- [x] 6. **`scripts/games/aldebaran/data/monsters.lua`**: 원안 표 39와 40의 칸을 전부 가진
      스키마. 값이 없으면 `nil`. `stage.lua`의 종별 표를 그리로 옮기고 `stage.lua`는
      다시 내보내기만 한다(`game.lua`는 고치지 않는다).
- [x] 7. **스키마 단위 테스트**: 모든 종이 필수 칸을 갖는지, 원안 칸 이름과 어긋나지 않는지.
- [x] 8. 라이선스 확인: 채굴 산출물에 **원안 이미지를 넣을지는 저자 자산이므로 사용자에게 묻는다.**
      묻기 전까지 이미지 바이너리는 커밋하지 않는다(`spica-source/media/`를 gitignore).
- [x] 9. `tests/run_all.sh` 통과. 인수 시나리오 무변경 통과. `git diff --stat src/` 0.
- [x] 10. 이 문서 체크리스트, `docs/plans/index.md` 진행 표(A5 행 누락도 함께 고친다),
      메타 프롬프트 4절 마일스톤 표를 갱신한다.

## 4. 완료 기준

1. 미채택 목록이 존재하고, **항목마다 Phase 배정이 있거나 기각 이유가 있다.**
2. `data/monsters.lua`로 바뀐 상태에서 **기존 인수 시나리오가 그대로 통과한다.**
3. 추출기를 다시 돌리면 같은 산출물이 나온다(결정적).
4. 원안 이미지의 저장소 반입 여부에 대한 사용자 결정이 문서에 남는다.
   **(2026-08-23 결정: 세계 지도 `image6.png` 한 장만 넣는다. 나머지 16장은 로컬에 둔다.)**

## 5. 검증 방법

| 무엇 | 어떻게 |
|---|---|
| 추출의 완전성 | 표 58개, 이미지 17장이 산출물에 전부 있는가를 스크립트가 세어 보고한다 |
| 추출의 재현성 | 두 번 돌려 `git diff`가 비는지 확인 |
| 스키마 | Lua 단위 테스트. 필수 칸, 종별 개수, 원안 칸 이름 대조 |
| 회귀 | `tests/run_all.sh` 전체. 특히 `aldebaran_scene`(무변경) |
| 눈 | 산출물 마크다운을 직접 읽는다. 표가 깨졌으면 셀 병합 처리를 고친다 |

## 6. 하지 않는 것

- 게임플레이 변경. 이 Phase는 **데이터와 문서만** 만진다. 밸런스 수치를 고치지 않는다.
- 새 몬스터 추가. 그릇만 만들고 채우는 것은 P5다.
- 지도 화면. P6이다.
- docx 자체의 커밋.

## 7. 한 일 (2026-08-23)

| 무엇 | 어디 |
|---|---|
| 채굴기 | `tools/spica_extract.py` (표준 라이브러리만, 결정적, `--media`와 `--check`) |
| 표 58개 | `docs/design/spica-source/tables.md` (82KB, 찾아보기 포함) |
| 문단 | `docs/design/spica-source/text.md` (제목 77, 글자 있는 문단 53) |
| 이미지 17장 | `docs/design/spica-source/media.md`. `.emf` 넷은 감싼 DIB를 꺼내 PNG로 변환 |
| 미채택 목록 | `docs/design/spica-unused.md` |
| 몬스터 규격서 | `scripts/games/aldebaran/data/monsters.lua` (평평한 칸 + `spec` 두 층, 검사기) |
| 단위 테스트 | `tests/lua/cases/aldebaran_monsters_data_test.lua` (64건) |
| 문서 | README에 채굴 도구 절 추가 |

### 계획과 달라진 것

1. **EMF 변환.** 계획은 libreoffice를 쓰는 것이었으나 이 기기에 없다. 원안의 EMF 넷은 전부
   `EMR_STRETCHDIBITS` 한 장으로 비트맵을 감싸고만 있어, 그 DIB를 꺼내 BMP로 쓰고 `sips`로
   PNG를 만들었다. 표준 라이브러리로 넷 다 변환됐다. libreoffice가 있으면 그쪽을 먼저 쓴다.
2. **표의 병합 칸.** 처음에는 병합된 칸에 같은 값을 채웠더니 표 39가 같은 문장을 여섯 번
   반복해 읽을 수 없었다. 연속 칸은 비우는 쪽으로 바꿨다.
3. **문단 수.** 메타 프롬프트의 "문단 216개"는 최상위 `<w:p>` 237개(빈 문단과 목차 포함) 중
   일부를 센 것으로 보인다. 글자가 있는 본문 문단은 53개다.
4. **세계 지도를 눈으로 읽었다.** 계획에는 없던 일이지만 P6의 근거가 되므로 확대해서 읽고
   `spica-unused.md` 6절에 남겼다. 붉은 X 다섯은 스테이지가 아니라 **밀림거미굴 1~5**였다.
