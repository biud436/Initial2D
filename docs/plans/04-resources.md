# 4단계: 리소스 파이프라인 — R2K3 리소스 어댑터

**권장 모델**: Claude Opus 5 — 규격이 이미 조사로 확정된 변환 스크립트와 데이터 작성 위주라, 로드맵의 최소 기준선인 Opus 5로 진행한다.

> 목표: `resources/RTP.zip`(RPG Maker 2003 RTP, 2023년 재배포판)을 엔진이 바로 쓸 수 있는 형태로 변환하는 도구를 만들고, 리소스 규격을 Lua 데이터로 기술한다.
> 원칙: R2K3 규격은 엔진의 규격이 아니다. 엔진(C++)은 PNG와 OGG만 알고, "CharSet은 288x256이고 한 캐릭터는 3x4 프레임"이라는 지식은 전부 Lua 쪽 데이터에 둔다.

## 라이선스 (가장 먼저 확인할 것)

- RPG Maker의 개정 EULA에 따라 RTP 소재는 **해당 RPG Maker 제품(여기서는 RPG Maker 2003)의 정품 보유자에 한해** 다른 엔진의 게임에도 사용할 수 있다. 배포 전에 최신 약관 원문을 다시 확인한다.
- 소재 자체의 재배포는 금지다. **RTP.zip과 변환 결과물은 git에 커밋하지 않는다** (`resources/.gitignore`가 이미 `RTP.zip`을 제외하고 있음을 2026-08-15 확인. 변환 결과 폴더도 제외 목록에 추가할 것).
- 저장소에 포함할 데모용 소재가 필요하면 공개 라이선스 타일셋(InitialEditor가 이미 쓰는 FSM, Tuxemon 계열)을 쓴다. RTP는 "정품 보유자의 로컬 개발용" 경로로 취급한다.

## 조사로 확인된 RTP 규격 (2026-08-15)

| 리소스 | 파일 수 | 규격 | 비고 |
|---|---|---|---|
| CharSet | 16 | 288x256, 8비트 팔레트 PNG | 시트당 8명 (4열 2행), 1명 72x128 = 3프레임 x 4방향, 프레임 24x32 |
| ChipSet | 5 | 480x256 | 16x16 타일 30열, 왼쪽 일부는 오토타일 영역 |
| FaceSet | 5 | 192x192 | 48x48 얼굴 16개 (4x4) |
| System | 4 + System2 3개 | 160x80 | 대화창 스킨: 배경, 프레임, 커서, 화살표, 글자색 팔레트 |
| Title | 4 | 320x240 | 원본 게임 해상도가 320x240 기준 |
| Backdrop | 35 | 320x240 | 전투 배경 |
| Panorama | 14 | 다양 | 원경 스크롤용 |
| Monster | 116 | 다양 | |
| Music | 152 | **MIDI** | 그대로는 재생 불가, 변환 필요 |
| Sound | 207 | WAV | SDL2_mixer로 바로 재생 가능 |

주의할 함정 두 가지:

1. **투명색.** 이 PNG들은 8비트 팔레트인데 tRNS(투명) 청크가 파일마다 들쭉날쭉이다 (ChipSet에는 있고 CharSet과 System에는 없음). R2K3 관례는 "팔레트 0번 = 투명"이므로, **변환 단계에서 tRNS 유무와 무관하게 팔레트 0번을 알파 0으로 강제 변환**해야 한다. 엔진 로더를 고치는 것보다 사전 변환이 깔끔하다.
2. **해상도.** 원본이 320x240 기준이므로 그대로 그리면 요즘 화면에서 아주 작다. RPG 데모는 논리 해상도 320x240에 창 배율 2배나 3배(정수배)로 표시하는 것을 기본으로 한다 (1단계의 해상도 설정 기능 사용).

## 작업 항목

- [ ] 변환 도구 `tools/rtp_import.py` 작성:
  - RTP.zip 압축 해제 → `resources/rtp/` (gitignore 대상)
  - 모든 팔레트 PNG에 대해 팔레트 0번을 알파 0으로 변환해 32비트 PNG로 저장 (Pillow 사용)
  - WAV는 복사, 필요시 OGG 변환 옵션
  - 파일명의 공백 처리 (예: `Mountain Road.png`) — 엔진 경로에서 문제없는지 확인하고 필요하면 언더스코어로 정규화
- [ ] MIDI 처리 방침 결정과 구현:
  - 1안 (권장): fluidsynth와 사운드폰트로 오프라인 OGG 변환하는 옵션을 `rtp_import.py`에 추가. 엔진에 MIDI 재생기를 넣지 않는다.
  - 2안: RTP 음악을 쓰지 않고 자작곡을 쓴다. 이미 OGG 자작곡이 있고(`resources/audio/bless.ogg`, `docs/music/`의 분석 문서들) 장기적으로는 이쪽이 저작권도 깔끔하다. **데모(8단계)는 2안으로 가도 충분하다.**
- [ ] 규격 데이터 `scripts/rpg/specs.lua` 작성 — 엔진이 아니라 Lua가 아는 지식:
  ```lua
  return {
    charset = { sheetW = 288, sheetH = 256, perSheet = 8, blockW = 72, blockH = 128,
                frameW = 24, frameH = 32, frames = 3,
                dirRows = { up = 0, right = 1, down = 2, left = 3 } },  -- 구현 시 실물로 검증할 것
    faceset = { size = 48, cols = 4, rows = 4 },
    chipset = { tile = 16, columns = 30 },
    window  = { skinW = 160, skinH = 80 },  -- 세부 분할은 7단계에서 확정
  }
  ```
  방향 행 순서와 System 분할 좌표는 문서 기억에 의존하지 말고 **실제 이미지를 열어 확인한 뒤 확정**한다 (EasyRPG Player 소스가 좋은 교차 검증 자료다).
- [ ] 사용법을 README.md에 추가 (도구 실행법, 라이선스 주의 문구).

## 완료 기준

- [ ] `python3 tools/rtp_import.py` 한 번으로 `resources/rtp/`에 즉시 사용 가능한 PNG들이 생성된다.
- [ ] 변환된 CharSet 한 장을 화면에 그렸을 때 배경이 투명하게 나온다 (팔레트 0번 처리 검증).
- [ ] 변환 결과물이 git 상태에 나타나지 않는다 (gitignore 검증).

## 의존 관계

- 선행: 없음 (즉시 시작 가능, 1단계와 병행 가능)
- 후행: 5단계(CharSet), 7단계(System, FaceSet)
