#!/bin/sh
# Initial2D 통합 검수 실행 — 로컬 한 줄 실행 (docs/plans/09-testing.md)
#
# 사용법:
#   tests/run_all.sh                  # 빌드 + C++ 단위 + Lua 단위 + 픽셀 검증 + 브리지 + RTP
#   tests/run_all.sh --update-golden  # 골든 스크린샷 갱신 (변경을 눈으로 확인 후 커밋)
#   SDL_VIDEODRIVER= tests/run_all.sh # 실제 창을 띄워 실행 (기본은 헤드리스)
#
# 기본은 헤드리스(SDL_VIDEODRIVER=dummy)다 — 테스트가 개발자 화면에 창을 껐다 켰다
# 하지 않게 하고, CI와 같은 경로(소프트웨어 렌더러)로 돌린다. 골든 허용 오차는
# 이 차이를 반영해 정해져 있다 (tests/run_engine_tests.py).
#
# exit code: 0 = 전부 통과, 그 외 = 실패
set -e
cd "$(dirname "$0")/.."

if [ -z "${SDL_VIDEODRIVER+x}" ]; then
  export SDL_VIDEODRIVER=dummy
fi

echo "== [1/5] 빌드 =="
cmake -B build -S . > /dev/null
cmake --build build

echo ""
echo "== [2/5] C++ 단위 테스트 =="
./build/engine_unit_tests

echo ""
echo "== [3/5] 엔진 씬 테스트 (Lua 단위 + 픽셀 검증 + 골든) =="
python3 tests/run_engine_tests.py "$@"

echo ""
echo "== [4/5] 에디터 브리지 서버 (Node) =="
# 브리지(tools/bridge)는 Node 20 이상이 필요하다. Node가 없는 환경에서는 건너뛰되
# 눈에 띄게 알린다 (CI의 macOS 러너에는 Node가 있으므로 거기서는 항상 실행된다).
if command -v node >/dev/null 2>&1; then
  node --test tools/bridge/test/*.test.js
else
  echo "SKIP: node 가 없어 브리지 서버 테스트를 건너뜁니다 (Node 20 이상 설치 필요)"
fi

echo ""
echo "== [5/5] RTP 변환 결과 검증 =="
# 변환 결과(resources/rtp/)는 정품 보유자의 로컬 자산이라 커밋되지 않는다.
# 없으면 verify_rtp.py 가 스스로 SKIP을 알리고 통과시킨다 (gitignore 검사만 항상 돈다).
python3 tests/verify_rtp.py

echo ""
echo "전체 검수 통과"
