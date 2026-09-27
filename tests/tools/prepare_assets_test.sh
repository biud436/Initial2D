#!/usr/bin/env bash
# 안드로이드 에셋 스테이징 검사 (InitialEditor 의 docs/plans/e6-packaging.md 6절).
#
# android/prepare_assets.sh 와 tools/stage_list.py, tools/stage_rules.json 이 규칙대로인가:
#   - --project: 임시 프로젝트 둘의 목록이 규칙 표와 같다. 점 이름, zip, psd, config.setting, RTP 변환물,
#     resources/aldebaran/src/ 가 빠지고, AAPT 가 버리는 이름은 빠지며 경고가 남는다
#   - --with-rtp 일 때만 RTP 변환물이 들고 경고 줄이 나온다
#   - 마지막 줄이 STAGED (파일 수, 크기, 스탬프, rtp, 대상), --dry-run 은 복사 없이 DRYRUN 한 줄
#   - 스탬프가 내용 변경에 바뀌고 무변경이면 같다. 스탬프 파일이 assets_manifest.txt 에 있다
#   - 인자와 프로젝트 오류는 종료 코드 2 (대상이 프로젝트 자신이면 지우지 않는다), python3 이 없으면 이유와 2
#   - 규칙 파일의 예시(examples, keepExamples)가 그 규칙대로 빠지고 남는다
#   - 인자 없는 실행은 지금과 같다: 가짜 저장소에서 scripts/, resources/(RTP.zip 과 점 파일만 빼고),
#     game.json, config.setting, db.sqlite 를 그대로 올리고 스탬프가 없다
#   - tools/web_stage.py 의 출력 목록이 이 작업 전과 같다
#
# 사용법: tests/tools/prepare_assets_test.sh      종료 코드: 0 전부 통과, 1 실패가 있다
set -u

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$REPO/android/prepare_assets.sh"
PY="${PYTHON:-python3}"
WORK="$(cd "$(mktemp -d "${TMPDIR:-/tmp}/prepare_assets_test.XXXXXX")" && pwd)"
trap 'rm -rf "$WORK"' EXIT

PASS=0
FAIL=0
check() {
  # check <이름> <참이면 0 인 명령...>
  local name="$1"
  shift
  if "$@"; then
    PASS=$((PASS + 1))
    echo "  PASS  $name"
  else
    FAIL=$((FAIL + 1))
    echo "  FAIL  $name"
  fi
}

same_text() {
  # same_text <기대> <실제>
  if [ "$1" = "$2" ]; then
    return 0
  fi
  echo "    기대:" >&2
  printf '%s\n' "$1" | sed 's/^/      /' >&2
  echo "    실제:" >&2
  printf '%s\n' "$2" | sed 's/^/      /' >&2
  return 1
}

contains() {
  case "$1" in
    *"$2"*) return 0 ;;
  esac
  echo "    '$2' 가 없다" >&2
  return 1
}

lacks() {
  case "$1" in
    *"$2"*) echo "    '$2' 가 있다" >&2; return 1 ;;
  esac
  return 0
}

put() {
  # put <폴더> <상대 경로> [내용]
  mkdir -p "$(dirname "$1/$2")"
  printf '%s' "${3:-$2}" > "$1/$2"
}

sorted() {
  printf '%s\n' "$@" | LC_ALL=C sort
}

last_line() {
  printf '%s\n' "$1" | tail -n 1
}

field() {
  printf '%s\n' "$1" | tr ' ' '\n' | sed -n "s/^$2=//p"
}

sum_bytes() {
  local dir="$1" total=0 f
  shift
  for f in "$@"; do
    total=$((total + $(wc -c < "$dir/$f")))
  done
  echo "$total"
}

# ---------------------------------------------------------------- 프로젝트 A
A="$WORK/project a"
A_FILES_KEEP=(
  "db.sqlite"
  "game.json"
  "resources/aldebaran/title.png"
  "resources/fonts/한글 글꼴.fnt"
  "resources/images/hero.png"
  "scripts/lua/main.lua"
  "scripts/ruby/main.rb"
)
A_FILES_DROP=(
  "config.setting"
  "README.md"
  "tests/t.lua"
  ".initial-editor/layout.json"
  ".git/HEAD"
  "scripts/lua/.cache/a.lua"
  "resources/.DS_Store"
  "resources/RTP.zip"
  "resources/audio/pack.zip"
  "resources/images/hero.psd"
  "resources/images/logo.PSD"
  "resources/aldebaran/src/gpt/sheet.png"
  "resources/config.setting"
  "resources/_old/a.png"
  "resources/images/a.png~"
)
RTP_FILE="resources/rtp/CharSet/hero.png"
for f in "${A_FILES_KEEP[@]}" "${A_FILES_DROP[@]}" "$RTP_FILE"; do put "$A" "$f"; done

echo "== --project (프로젝트 A) =="
D1="$WORK/dest one"
OUT="$(bash "$SCRIPT" --project "$A" --dest "$D1" 2>"$WORK/err")"
CODE=$?
ERR="$(cat "$WORK/err")"
LAST="$(last_line "$OUT")"
check "종료 코드 0" [ "$CODE" -eq 0 ]
MANIFEST="$(cat "$D1/assets_manifest.txt" 2>/dev/null)"
STAMP="$(field "$LAST" stamp)"
check "마지막 줄이 STAGED" contains "$LAST" "STAGED "
check "STAGED 의 파일 수 7, 크기, rtp=no, 대상" same_text \
  "STAGED files=7 bytes=$(sum_bytes "$A" "${A_FILES_KEEP[@]}") stamp=$STAMP rtp=no dest=$(cd "$D1" && pwd)" "$LAST"
check "스탬프는 12자 16진수" bash -c "printf '%s' '$STAMP' | grep -Eq '^[0-9a-f]{12}$'"
check "목록이 규칙 표와 같다 (스탬프 포함)" same_text "$(sorted "${A_FILES_KEEP[@]}" "assets_stamp/$STAMP.txt")" "$MANIFEST"
check "복사한 파일이 목록과 같다" same_text "$MANIFEST" "$(cd "$D1" && find . -type f ! -name assets_manifest.txt | sed 's|^\./||' | LC_ALL=C sort)"
check "내용이 원본과 같다" cmp -s "$A/resources/fonts/한글 글꼴.fnt" "$D1/resources/fonts/한글 글꼴.fnt"
check "config.setting 이 빠진다" [ ! -e "$D1/config.setting" -a ! -e "$D1/resources/config.setting" ]
check "RTP 경고가 없다" lacks "$OUT" "WARN rtp"
check "AAPT 가 버리는 이름은 경고한다 (_old)" contains "$ERR" "WARN aapt-ignored: resources/_old/a.png"
check "AAPT 가 버리는 이름은 경고한다 (~)" contains "$ERR" "WARN aapt-ignored: resources/images/a.png~"
check "다른 빠지는 파일은 경고하지 않는다" same_text "2" "$(printf '%s\n' "$ERR" | grep -c '^WARN')"

echo "== --with-rtp =="
OUT="$(bash "$SCRIPT" --project "$A" --dest "$D1" --with-rtp 2>/dev/null)"
CODE=$?
LAST="$(last_line "$OUT")"
check "종료 코드 0" [ "$CODE" -eq 0 ]
check "RTP 변환물이 들어간다" [ -f "$D1/$RTP_FILE" ]
check "목록에 RTP 변환물" same_text "$(sorted "${A_FILES_KEEP[@]}" "$RTP_FILE" "assets_stamp/$(field "$LAST" stamp).txt")" "$(cat "$D1/assets_manifest.txt")"
check "경고 줄" contains "$OUT" "WARN rtp: RTP 변환물이 들어간다. 이 APK 는 배포하지 않는다"
check "STAGED rtp=yes, 파일 8" same_text "files=8 rtp=yes" "files=$(field "$LAST" files) rtp=$(field "$LAST" rtp)"
check "RTP.zip 은 --with-rtp 에도 빠진다" [ ! -e "$D1/resources/RTP.zip" ]

echo "== --dry-run =="
D2="$WORK/dest dry"
OUT="$(bash "$SCRIPT" --project "$A" --dest "$D2" --dry-run 2>/dev/null)"
CODE=$?
check "종료 코드 0" [ "$CODE" -eq 0 ]
check "DRYRUN 한 줄 (STAGED 와 같은 수)" same_text "DRYRUN files=7 bytes=$(sum_bytes "$A" "${A_FILES_KEEP[@]}") rtp=no" "$OUT"
check "대상 폴더를 만들지 않는다" [ ! -e "$D2" ]
BEFORE="$(cat "$D1/assets_manifest.txt")"
OUT="$(bash "$SCRIPT" --project "$A" --dest "$D1" --dry-run --with-rtp 2>/dev/null)"
check "DRYRUN --with-rtp" same_text "DRYRUN files=8 bytes=$(sum_bytes "$A" "${A_FILES_KEEP[@]}" "$RTP_FILE") rtp=yes" "$OUT"
check "있는 대상 폴더를 건드리지 않는다" same_text "$BEFORE" "$(cat "$D1/assets_manifest.txt")"

echo "== 스탬프 =="
S1="$(field "$(last_line "$(bash "$SCRIPT" --project "$A" --dest "$D1" 2>/dev/null)")" stamp)"
M1="$(cat "$D1/assets_manifest.txt")"
S2="$(field "$(last_line "$(bash "$SCRIPT" --project "$A" --dest "$D1" 2>/dev/null)")" stamp)"
check "무변경이면 같다" same_text "$S1" "$S2"
check "처음 스테이징의 스탬프와 같다" same_text "$STAMP" "$S1"
printf '%s' "scripts/lua/main.LUA" > "$A/scripts/lua/main.lua"   # 크기는 같고 내용만 다르다
S3="$(field "$(last_line "$(bash "$SCRIPT" --project "$A" --dest "$D1" 2>/dev/null)")" stamp)"
M3="$(cat "$D1/assets_manifest.txt")"
check "내용만 바꿔도 바뀐다" [ -n "$S3" -a "$S3" != "$S1" ]
check "그래서 assets_manifest.txt 의 바이트가 바뀐다" [ "$M1" != "$M3" ]
check "옛 스탬프 파일이 남지 않는다" same_text "1" "$(ls "$D1/assets_stamp" | wc -l | tr -d ' ')"
printf '%s' "scripts/lua/main.lua" > "$A/scripts/lua/main.lua"
S4="$(field "$(last_line "$(bash "$SCRIPT" --project "$A" --dest "$D1" 2>/dev/null)")" stamp)"
check "되돌리면 처음 스탬프" same_text "$S1" "$S4"

# ---------------------------------------------------------------- 프로젝트 B
echo "== --project (프로젝트 B: Ruby 만, db.sqlite 없음, 32 MB 넘는 파일) =="
B="$WORK/project-b"
B_FILES=("game.json" "resources/scenes/main.json" "scripts/ruby/main.rb" "scripts/ruby/scene_types/tilemap.rb")
for f in "${B_FILES[@]}"; do put "$B" "$f"; done
"$PY" -c "import sys; f = open(sys.argv[1], 'wb'); f.seek(33 * 1024 * 1024); f.write(b'x'); f.close()" "$B/resources/big.bin"
D3="$WORK/dest-b"
OUT="$(bash "$SCRIPT" --project "$B" --dest "$D3" 2>/dev/null)"
CODE=$?
LAST="$(last_line "$OUT")"
check "종료 코드 0" [ "$CODE" -eq 0 ]
check "목록이 규칙 표와 같다 (큰 파일도 넣는다)" same_text "$(sorted "${B_FILES[@]}" "resources/big.bin" "assets_stamp/$(field "$LAST" stamp).txt")" "$(cat "$D3/assets_manifest.txt")"
check "크기에 큰 파일이 들어간다" same_text "$(sum_bytes "$B" "${B_FILES[@]}" resources/big.bin)" "$(field "$LAST" bytes)"
check "stage_list.py 의 목록 (한 줄에 하나)" same_text "$(sorted "${B_FILES[@]}" "resources/big.bin")" "$("$PY" "$REPO/tools/stage_list.py" --project "$B")"

# ---------------------------------------------------------------- 오류
echo "== 오류 =="
E="$WORK/no-game"
put "$E" "scripts/lua/main.lua"
bash "$SCRIPT" --project "$E" --dest "$WORK/dest-e" >/dev/null 2>"$WORK/err"
check "game.json 이 없으면 2" [ $? -eq 2 ]
check "  그 이유" contains "$(cat "$WORK/err")" "game.json 이 없다"
bash "$SCRIPT" --project "$WORK/nope" >/dev/null 2>&1
check "없는 프로젝트 폴더면 2" [ $? -eq 2 ]
bash "$SCRIPT" --project "$A" --bogus >/dev/null 2>&1
check "모르는 인자면 2" [ $? -eq 2 ]
bash "$SCRIPT" --project >/dev/null 2>&1
check "--project 뒤에 폴더가 없으면 2" [ $? -eq 2 ]
bash "$SCRIPT" --dry-run >/dev/null 2>&1
check "--project 없이 다른 인자만 주면 2" [ $? -eq 2 ]
bash "$SCRIPT" --project "$A" --dest "$A" >/dev/null 2>&1
check "대상이 프로젝트 자신이면 2" [ $? -eq 2 ]
check "  프로젝트는 그대로다" [ -f "$A/game.json" -a -f "$A/scripts/lua/main.lua" ]
bash "$SCRIPT" --project "$A" --dest "$WORK" >/dev/null 2>&1
check "대상이 프로젝트의 위 폴더면 2" [ $? -eq 2 ]
check "  프로젝트는 그대로다" [ -f "$A/game.json" ]
bash "$SCRIPT" --project "$A" --dest "$A/resources/staged" >/dev/null 2>&1
check "대상이 프로젝트의 resources/ 안이면 2" [ $? -eq 2 ]
INITIAL2D_PYTHON="$WORK/no-python" bash "$SCRIPT" --project "$A" --dest "$WORK/dest-p" >/dev/null 2>"$WORK/err"
check "python3 이 없으면 2" [ $? -eq 2 ]
check "  그 이유" contains "$(cat "$WORK/err")" "python3 이 필요하다"
check "  대상 폴더를 만들지 않는다" [ ! -e "$WORK/dest-p" ]

# ---------------------------------------------------------------- 규칙 파일의 예시
echo "== 규칙 파일의 예시 =="
C="$WORK/examples"
EXAMPLES="$("$PY" - "$REPO/tools/stage_rules.json" <<'PYEOF'
import json, sys
rules = json.load(open(sys.argv[1], encoding="utf-8"))
for p in rules["keepExamples"]:
    print("keep\t" + p)
for rule in rules["exclude"]:
    for p in rule["examples"]:
        print(("rtp" if rule.get("withRtp") else "drop") + "\t" + p)
PYEOF
)"
KEEP=()
RTP=()
while IFS="$(printf '\t')" read -r kind path; do
  put "$C" "$path"
  case "$kind" in
    keep) KEEP+=("$path") ;;
    rtp) RTP+=("$path") ;;
  esac
done <<EOF
$EXAMPLES
EOF
check "예시가 있다 (남는 것과 빠지는 것)" [ "${#KEEP[@]}" -ge 3 -a "$(printf '%s\n' "$EXAMPLES" | grep -c '^drop')" -ge 10 ]
check "빠지는 예시는 빠지고 남는 예시만 남는다" same_text "$(sorted "${KEEP[@]}")" "$("$PY" "$REPO/tools/stage_list.py" --project "$C" 2>/dev/null)"
check "--with-rtp 면 RTP 예시도 남는다" same_text "$(sorted "${KEEP[@]}" "${RTP[@]}")" "$("$PY" "$REPO/tools/stage_list.py" --project "$C" --with-rtp 2>/dev/null)"

# ---------------------------------------------------------------- 인자 없는 실행
echo "== 인자 없는 실행 (가짜 저장소, 지금과 같다) =="
R="$WORK/fake repo"
mkdir -p "$R/android" "$R/tools"
cp "$SCRIPT" "$R/android/prepare_assets.sh"
cp "$REPO/tools/stage_list.py" "$REPO/tools/stage_rules.json" "$R/tools/"
LEGACY_KEEP=(
  "config.setting"
  "db.sqlite"
  "game.json"
  "resources/.dotdir/c.png"
  "resources/_old/b.png"
  "resources/a.psd"
  "resources/aldebaran/src/gpt/a.png"
  "resources/other.zip"
  "resources/rtp/CharSet/x.png"
  "scripts/lua/main.lua"
)
LEGACY_DROP=(
  "README.md"
  "tests/x.lua"
  ".initial-editor/layout.json"
  "scripts/.hidden"
  "resources/.DS_Store"
  "resources/RTP.zip"
)
for f in "${LEGACY_KEEP[@]}" "${LEGACY_DROP[@]}"; do put "$R" "$f"; done
ASSETS="$R/android/app/src/main/assets"
put "$ASSETS" "stale.txt"
OUT="$(cd "$WORK" && bash "$R/android/prepare_assets.sh" 2>&1)"
CODE=$?
check "종료 코드 0" [ "$CODE" -eq 0 ]
check "목록이 예전 규칙 그대로 (RTP 변환물, config.setting, 다른 zip, psd 포함, 스탬프 없음)" same_text "$(sorted "${LEGACY_KEEP[@]}")" "$(cat "$ASSETS/assets_manifest.txt" 2>/dev/null)"
check "대상을 먼저 비운다" [ ! -e "$ASSETS/stale.txt" ]
check "출력이 예전과 같다" same_text "완료: $ASSETS (10개 파일)
주의: resources/ 의 일부 이미지 에셋은 저장소에 없음 —
      python3 tools/generate_placeholder_assets.py 로 생성 가능" "$OUT"
mkdir -p "$WORK/fake-bin"
printf '#!/bin/sh\ntouch "%s/python-called"\nexit 1\n' "$WORK" > "$WORK/fake-bin/python3"
chmod +x "$WORK/fake-bin/python3"
(cd "$WORK" && PATH="$WORK/fake-bin:$PATH" bash "$R/android/prepare_assets.sh" >/dev/null 2>&1)
check "python3 을 부르지 않는다" [ $? -eq 0 -a ! -e "$WORK/python-called" ]

# ---------------------------------------------------------------- web_stage.py
echo "== tools/web_stage.py (무변경) =="
W="$WORK/web"
"$PY" "$REPO/tools/web_stage.py" --project "$A" --out "$W" >/dev/null
WEB_LIST="$("$PY" -c "import json, sys; print('\n'.join(json.load(open(sys.argv[1], encoding='utf-8'))['files']))" "$W/project.json")"
check "출력 목록이 이 작업 전과 같다" same_text "game.json
scripts/lua/main.lua
scripts/ruby/main.rb
resources/config.setting
resources/_old/a.png
resources/aldebaran/title.png
resources/audio/pack.zip
resources/fonts/한글 글꼴.fnt
resources/images/a.png~
resources/images/hero.png" "$WEB_LIST"

echo ""
echo "결과: $PASS PASS / $FAIL FAIL"
[ "$FAIL" -eq 0 ]
