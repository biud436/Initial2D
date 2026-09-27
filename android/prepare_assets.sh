#!/usr/bin/env bash
# 게임 에셋을 android/app/src/main/assets/ 로 스테이징한다. (gitignore 대상)
#
# APK 안의 assets 는 파일 시스템이 아니므로, 런타임에는 최초 실행 시
# 내부 저장소로 추출한 뒤 chdir 하는 방식을 사용한다.
# 상세: docs/porting/android-plan.md (Phase A1)
#
# 사용법:
#   android/prepare_assets.sh
#       이 저장소 자신(scripts/, resources/, game.json, config.setting, db.sqlite)을 예전 규칙 그대로.
#       resources/RTP.zip 과 점 파일만 빼므로 RTP 변환물(resources/rtp/)도 들어간다
#   android/prepare_assets.sh --project <폴더> [--with-rtp] [--dry-run] [--dest <폴더>]
#       프로젝트 하나(에디터로 만든 게임)를 tools/stage_rules.json 의 규칙으로. config.setting 은 넣지 않고
#       resources/rtp/ 는 --with-rtp 일 때만 넣는다. 파일 목록은 tools/stage_list.py 가 낸다 (python3 필요)
#       --dry-run  복사하지 않고 DRYRUN files=<n> bytes=<b> rtp=<yes|no> 한 줄
#       --dest     대상 폴더 (기본 android/app/src/main/assets, 통째로 바뀐다). 시험용
#       마지막 줄: STAGED files=<n> bytes=<b> stamp=<12자> rtp=<yes|no> dest=<경로>
#       스탬프 파일 assets_stamp/<스탬프>.txt 가 목록에 들어가 내용만 바뀐 프로젝트도 기기가 다시 푼다.
#       python3 대신 쓸 실행 파일은 INITIAL2D_PYTHON 으로 준다
#   종료 코드: 0 성공, 1 입출력 오류, 2 인자나 프로젝트 오류
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ASSETS="$ROOT/android/app/src/main/assets"

# ---- 인자 없는 실행: 이 저장소를 예전 규칙 그대로 (알데바란 기기 시험) ----
if [ "$#" -eq 0 ]; then
  rm -rf "$ASSETS"
  mkdir -p "$ASSETS"

  cp -R "$ROOT/scripts"   "$ASSETS/scripts"
  cp -R "$ROOT/resources" "$ASSETS/resources"

  # RTP.zip은 런타임에 쓰이지 않는 변환용 원본이며 라이선스상 재배포 불가라
  # APK에 넣지 않는다 (13MB 절감). 변환 결과물(resources/rtp/)은 이 실행에서 그대로 들어간다.
  rm -f "$ASSETS/resources/RTP.zip"
  [ -f "$ROOT/config.setting" ] && cp "$ROOT/config.setting" "$ASSETS/"
  [ -f "$ROOT/game.json" ] && cp "$ROOT/game.json" "$ASSETS/"
  [ -f "$ROOT/db.sqlite" ]      && cp "$ROOT/db.sqlite"      "$ASSETS/"

  # AAPT는 닷파일(.gitignore 등)을 APK assets에 넣지 않으므로 스테이징에서도
  # 지운다. 매니페스트에 남으면 런타임 추출이 실패해 게임이 즉시 종료된다.
  find "$ASSETS" -type f -name '.*' -delete

  # 런타임 추출용 파일 목록. AndroidBootstrap이 읽는다 (AAssetManager는 디렉터리 열거 불가)
  (cd "$ASSETS" && find . -type f ! -name assets_manifest.txt | sed 's|^\./||' | LC_ALL=C sort > assets_manifest.txt)

  echo "완료: $ASSETS ($(wc -l < "$ASSETS/assets_manifest.txt" | tr -d ' ')개 파일)"
  echo "주의: resources/ 의 일부 이미지 에셋은 저장소에 없음 —"   # 출력은 예전 그대로 둔다
  echo "      python3 tools/generate_placeholder_assets.py 로 생성 가능"
  exit 0
fi

# ---- --project: 규칙 표(tools/stage_rules.json)로 ----
usage() {
  sed -n '8,20p' "$0" | sed 's/^# \{0,1\}//'
}

fail() {
  local code="$1"
  shift
  echo "prepare_assets: $*" >&2
  exit "$code"
}

PROJECT=""
DEST="$ASSETS"
WITH_RTP=0
DRY_RUN=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --project)
      [ "$#" -ge 2 ] || fail 2 "--project 뒤에 폴더가 없다"
      PROJECT="$2"
      shift 2
      ;;
    --dest)
      [ "$#" -ge 2 ] || fail 2 "--dest 뒤에 폴더가 없다"
      DEST="$2"
      shift 2
      ;;
    --with-rtp) WITH_RTP=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *)
      usage >&2
      fail 2 "모르는 인자: $1"
      ;;
  esac
done

[ -n "$PROJECT" ] || fail 2 "--project 가 없다 (인자 없이 부르면 이 저장소를 예전 규칙으로 스테이징한다)"
[ -d "$PROJECT" ] || fail 2 "프로젝트 폴더가 없다: $PROJECT"
PROJECT="$(cd "$PROJECT" && pwd)"
[ -f "$PROJECT/game.json" ] || fail 2 "game.json 이 없다: $PROJECT"

PYTHON="${INITIAL2D_PYTHON:-python3}"
command -v "$PYTHON" >/dev/null 2>&1 || fail 2 "python3 이 필요하다 (찾지 못했다: $PYTHON)"
"$PYTHON" -c 'import sys; sys.exit(0 if sys.version_info[0] == 3 else 1)' >/dev/null 2>&1 \
  || fail 2 "python3 이 필요하다 ($PYTHON 이 Python 3 이 아니다)"

LIST_ARGS=(--project "$PROJECT")
if [ "$WITH_RTP" -eq 1 ]; then
  LIST_ARGS+=(--with-rtp)
fi

# "files=3 bytes=10 rtp=no" 에서 이름 하나의 값
field() {
  printf '%s\n' "$1" | tr ' ' '\n' | sed -n "s/^$2=//p"
}

if [ "$DRY_RUN" -eq 1 ]; then
  SUMMARY="$("$PYTHON" "$ROOT/tools/stage_list.py" "${LIST_ARGS[@]}" --count)" || exit $?
  echo "DRYRUN files=$(field "$SUMMARY" files) bytes=$(field "$SUMMARY" bytes) rtp=$(field "$SUMMARY" rtp)"
  exit 0
fi

# 대상은 통째로 지우므로 프로젝트 자신이나 그 위 폴더, 프로젝트의 scripts/ 와 resources/ 안은 받지 않는다
mkdir -p "$DEST" || fail 1 "대상 폴더를 만들지 못했다: $DEST"
DEST="$(cd "$DEST" && pwd)"
[ "$DEST" != "/" ] || fail 2 "대상이 / 다"
case "$PROJECT/" in
  "$DEST"/*) fail 2 "대상이 프로젝트이거나 그 위 폴더다: $DEST" ;;
esac
case "$DEST/" in
  "$PROJECT/scripts/"*|"$PROJECT/resources/"*) fail 2 "대상이 프로젝트의 scripts/ 나 resources/ 안이다: $DEST" ;;
esac

echo "스테이징: $PROJECT -> $DEST"
rm -rf "$DEST" || fail 1 "대상 폴더를 비우지 못했다: $DEST"
mkdir -p "$DEST" || fail 1 "대상 폴더를 만들지 못했다: $DEST"

SUMMARY="$("$PYTHON" "$ROOT/tools/stage_list.py" "${LIST_ARGS[@]}" --stage "$DEST")" || exit $?
RTP="$(field "$SUMMARY" rtp)"

# 런타임 추출용 파일 목록 (인자 없는 실행과 같은 모양). AndroidBootstrap 은 이 파일의 바이트가 같으면 다시 풀지 않는다
(cd "$DEST" && find . -type f ! -name assets_manifest.txt | sed 's|^\./||' | LC_ALL=C sort > assets_manifest.txt) \
  || fail 1 "assets_manifest.txt 를 쓰지 못했다"

if [ "$RTP" = "yes" ]; then
  echo "WARN rtp: RTP 변환물이 들어간다. 이 APK 는 배포하지 않는다"
fi
echo "STAGED files=$(field "$SUMMARY" files) bytes=$(field "$SUMMARY" bytes) stamp=$(field "$SUMMARY" stamp) rtp=$RTP dest=$DEST"
