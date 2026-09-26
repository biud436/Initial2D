#!/usr/bin/env bash
# 배포용 엔진 실행 파일을 검사한다 (R4, docs/plans/r4-dist-build.md).
#
#   tools/check_dist.sh [실행 파일]      기본 dist/Initial2D-<이 컴퓨터의 타깃 트리플>
#
# 보는 것:
#   - 동적 의존이 허용 목록 안이다. macOS 는 /usr/lib/ 와 /System/Library/ 만,
#     Linux 는 glibc 계열(libc, libm, libdl, libpthread, librt, ld-linux)과 libstdc++, libgcc_s 만
#     (X11, Wayland, ALSA, PulseAudio 는 SDL 이 실행 중에 dlopen 하므로 목록에 없어야 한다)
#   - macOS 는 minos 가 11.0, 아키텍처가 arm64, 서명이 유효하다
#   - --features 에 lua 와 mruby, --version 의 커밋이 저장소 HEAD, --bogus 가 종료 코드 2.
#     셋 다 작업 폴더에 아무것도 쓰지 않는다 (게임을 띄우기 전에 끝난다)
#   - Lua 와 Ruby 스크립트를 헤드리스로 유한 실행해 PNG, WAV, OGG 를 읽고 종료 코드 0
# 실행은 모두 mktemp -d 의 작업 폴더에서 시간 제한을 두고 한다. 기대 커밋은 INITIAL2D_EXPECT_COMMIT 로 바꿀 수 있다.
# 종료 코드: 0 전부 통과, 1 실패가 있다
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OS="$(uname -s)"
case "$OS-$(uname -m)" in
    Darwin-arm64) TRIPLE=aarch64-apple-darwin ;;
    Linux-x86_64) TRIPLE=x86_64-unknown-linux-gnu ;;
    *) TRIPLE="" ;;
esac
EXE="${1:-$ROOT/dist/Initial2D-$TRIPLE}"
if [ ! -x "$EXE" ]; then
    echo "실행 파일이 없다: $EXE (tools/build_dist.sh 로 만든다)" >&2
    exit 1
fi
EXE="$(cd "$(dirname "$EXE")" && pwd)/$(basename "$EXE")"

FAILS=0
pass() { echo "  PASS  $1"; }
fail() { echo "  FAIL  $1${2:+  ($2)}"; FAILS=$((FAILS + 1)); }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# run <초> <작업 폴더> <인자...>: 시간 제한을 두고 실행한다. 결과는 $OUT_TXT, $ERR_TXT, $RC
run() {
    local secs=$1 dir=$2
    shift 2
    OUT_TXT="$dir.out"
    ERR_TXT="$dir.err"
    (cd "$dir" && SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy \
        perl -e 'alarm shift; exec @ARGV or die "exec: $!\n"' "$secs" "$EXE" "$@") \
        > "$OUT_TXT" 2> "$ERR_TXT"
    RC=$?
    if [ "$RC" -eq 142 ]; then
        echo "        시간 제한 ${secs}초를 넘겼다"
    fi
}

# 옵션 실행은 빈 작업 폴더에 아무것도 남기지 않아야 한다 (config.setting 은 게임을 띄울 때 쓴다)
empty_after() {
    if [ -z "$(ls -A "$1")" ]; then
        pass "$2: 작업 폴더에 쓰지 않는다"
    else
        fail "$2: 작업 폴더에 쓰지 않는다" "$(find "$1" -mindepth 1 -maxdepth 1 -exec basename {} \; | tr '\n' ' ')"
    fi
}

echo "검사: $EXE"

echo "[의존]"
if [ "$OS" = "Darwin" ]; then
    bad=""
    while read -r lib; do
        case "$lib" in
            /usr/lib/*|/System/Library/*) ;;
            *) bad="$bad $lib" ;;
        esac
    done < <(otool -L "$EXE" | tail -n +2 | awk '{print $1}')
    if [ -z "$bad" ]; then pass "동적 의존이 /usr/lib/ 와 /System/Library/ 뿐이다"; else fail "허용 목록 밖의 동적 의존" "$bad"; fi

    minos="$(otool -l "$EXE" | awk '/LC_BUILD_VERSION/ {f = 1} f && $1 == "minos" {print $2; exit}')"
    if [ "$minos" = "11.0" ]; then pass "minos 11.0"; else fail "minos 11.0" "minos=${minos:-없음}"; fi

    archs="$(lipo -archs "$EXE" 2>/dev/null)"
    if [ "$archs" = "arm64" ]; then pass "아키텍처 arm64"; else fail "아키텍처 arm64" "$archs"; fi

    if codesign --verify "$EXE" 2>/dev/null; then pass "서명이 유효하다 (ad-hoc)"; else fail "서명이 유효하다"; fi
elif [ "$OS" = "Linux" ]; then
    bad=""
    while read -r name rest; do
        case "$name" in
            linux-vdso.so.*|libc.so.*|libm.so.*|libdl.so.*|libpthread.so.*|librt.so.*|libstdc++.so.*|libgcc_s.so.*) ;;
            ld-linux*|/lib*/ld-linux*|/usr/lib*/ld-linux*) ;;
            *) bad="$bad $name" ;;
        esac
        case "$rest" in
            *"not found"*) bad="$bad $name(없음)" ;;
        esac
    done < <(ldd "$EXE")
    if [ -z "$bad" ]; then pass "동적 의존이 glibc 계열과 libstdc++, libgcc_s 뿐이다"; else fail "허용 목록 밖의 동적 의존" "$bad"; fi

    if file "$EXE" | grep -q "x86-64"; then pass "아키텍처 x86-64"; else fail "아키텍처 x86-64" "$(file -b "$EXE")"; fi
    glibc="$(objdump -T "$EXE" 2>/dev/null | grep -o 'GLIBC_[0-9.]*' | sort -uV | tail -1)"
    echo "  INFO  요구하는 glibc: ${glibc:-알 수 없음}"
else
    fail "지원하지 않는 OS: $OS"
fi

echo "[인자]"
d="$WORK/features"; mkdir "$d"
run 20 "$d" --features
features="$(cat "$OUT_TXT")"
if [ "$RC" -eq 0 ]; then pass "--features 종료 코드 0"; else fail "--features 종료 코드 0" "rc=$RC"; fi
for want in lua mruby; do
    case " $features " in
        *" $want "*) pass "--features 에 $want" ;;
        *) fail "--features 에 $want" "'$features'" ;;
    esac
done
empty_after "$d" "--features"

d="$WORK/version"; mkdir "$d"
run 20 "$d" --version
version="$(cat "$OUT_TXT")"
expect="${INITIAL2D_EXPECT_COMMIT:-$(git -C "$ROOT" rev-parse HEAD 2>/dev/null)}"
if [ "$RC" -eq 0 ]; then pass "--version 종료 코드 0"; else fail "--version 종료 코드 0" "rc=$RC"; fi
if [[ "$version" =~ ^Initial2D\ ([^ ]+)\ ([0-9a-f]{40})$ ]]; then
    pass "--version 모양 (Initial2D <describe> <커밋 40자>)"
    describe="${BASH_REMATCH[1]}"
    commit="${BASH_REMATCH[2]}"
    if [ "$commit" = "$expect" ]; then pass "--version 의 커밋이 HEAD ($commit)"; else fail "--version 의 커밋이 HEAD" "$commit, HEAD $expect"; fi
    case "$describe" in
        *-dirty) echo "  WARN  describe 가 $describe 다 (커밋하지 않은 변경이 있는 채로 빌드했다)" ;;
    esac
else
    fail "--version 모양 (Initial2D <describe> <커밋 40자>)" "'$version'"
fi
empty_after "$d" "--version"

d="$WORK/bogus"; mkdir "$d"
run 20 "$d" --bogus
if [ "$RC" -eq 2 ]; then pass "--bogus 종료 코드 2"; else fail "--bogus 종료 코드 2" "rc=$RC"; fi
if [ -s "$ERR_TXT" ] && [ ! -s "$OUT_TXT" ]; then pass "--bogus 는 사용법을 stderr 에만"; else fail "--bogus 는 사용법을 stderr 에만"; fi
empty_after "$d" "--bogus"

echo "[유한 실행]"
# 커밋된 파일만 쓴다: 타일셋 PNG, 효과음 WAV, 배경 음악 OGG
stage() {
    mkdir -p "$1/resources"
    cp "$ROOT/resources/tiles/tileset16-8x13.png" "$1/resources/smoke.png"
    cp "$ROOT/resources/audio/flap.wav" "$1/resources/smoke.wav"
    cp "$ROOT/resources/audio/bless.ogg" "$1/resources/smoke.ogg"
}

d="$WORK/lua"; stage "$d"; mkdir -p "$d/scripts/lua"
cat > "$d/scripts/lua/main.lua" <<'LUA'
function Initialize()
	print("dist-smoke png " .. tostring(TextureManager.Load("./resources/smoke.png", "smoke")))
end
function Update(elapsed) end
function Render() end
function Destroy() print("dist-smoke destroy") end
LUA
INITIAL2D_EXIT_AFTER=30 run 60 "$d"
if [ "$RC" -eq 0 ]; then pass "Lua 유한 실행 종료 코드 0"; else fail "Lua 유한 실행 종료 코드 0" "rc=$RC $(tail -c 300 "$ERR_TXT")"; fi
if grep -q "dist-smoke png true" "$OUT_TXT"; then pass "Lua: PNG 를 읽는다"; else fail "Lua: PNG 를 읽는다" "$(tail -c 300 "$OUT_TXT")"; fi
if grep -q "dist-smoke destroy" "$OUT_TXT"; then pass "Lua: 끝까지 돌고 Destroy"; else fail "Lua: 끝까지 돌고 Destroy"; fi

d="$WORK/ruby"; stage "$d"; mkdir -p "$d/scripts/ruby"
cat > "$d/scripts/ruby/main.rb" <<'RUBY'
def init
  puts "dist-smoke png #{TextureManager.load('./resources/smoke.png', 'smoke')}"
  puts "dist-smoke wav #{Audio.play_sound('./resources/smoke.wav', 'se', false)}"
  puts "dist-smoke ogg #{Audio.play_music('./resources/smoke.ogg', 'bgm', false)}"
end

def update(elapsed)
end

def render
end

def destroy
  puts "dist-smoke destroy"
end
RUBY
INITIAL2D_EXIT_AFTER=30 run 60 "$d"
if [ "$RC" -eq 0 ]; then pass "Ruby 유한 실행 종료 코드 0"; else fail "Ruby 유한 실행 종료 코드 0" "rc=$RC $(tail -c 300 "$ERR_TXT")"; fi
for kind in png wav ogg; do
    if grep -q "dist-smoke $kind true" "$OUT_TXT"; then pass "Ruby: ${kind} 를 읽는다"; else fail "Ruby: ${kind} 를 읽는다" "$(tail -c 300 "$OUT_TXT")"; fi
done
if grep -q "dist-smoke destroy" "$OUT_TXT"; then pass "Ruby: 끝까지 돌고 destroy"; else fail "Ruby: 끝까지 돌고 destroy"; fi

echo "[고지]"
# THIRD-PARTY.md 의 표가 실행 파일에 든 판을 적고 있는가 (판을 올리고 고지를 안 고치면 여기서 멈춘다)
# shellcheck source=tools/sdl_versions.sh
. "$ROOT/tools/sdl_versions.sh"
MRUBY_VER="$(sed -n 's/^MRUBY_VER=//p' "$ROOT/tools/build_mruby.sh")"
notice="$ROOT/THIRD-PARTY.md"
for row in "SDL2|$SDL2_VER" "SDL2_image|$IMG_VER" "SDL2_mixer|$MIX_VER" "mruby (와 함께 든 gem)|$MRUBY_VER"; do
    name="${row%%|*}"
    ver="${row#*|}"
    if grep -qF "| $name | $ver" "$notice"; then pass "THIRD-PARTY.md 에 $name $ver"; else fail "THIRD-PARTY.md 에 $name $ver"; fi
done

echo ""
if [ "$FAILS" -eq 0 ]; then
    echo "check_dist: 전부 통과"
    exit 0
fi
echo "check_dist: $FAILS FAIL"
exit 1
