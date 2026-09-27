# Initial2D — Android 포트 (SDL2)

macOS 포팅에서 만든 SDL2 어댑터(`src/platform/sdl2/`)를 그대로 재사용하는 Android 빌드입니다.
실기(Galaxy S24 / Android 16)에서 게임 구동, 터치 입력, 오디오 재생이 확인되었습니다.
남은 포팅 작업은 `docs/porting/android-plan.md`를 참조하십시오.

## 요구 사항

- JDK 17
- Android SDK (API 34) + NDK r27 이상 + CMake 3.22 이상 (Android Studio SDK Manager로 설치)

## 빌드

```bash
# 저장소 루트에서:

# 1. SDL2/SDL2_image/SDL2_mixer 소스 다운로드 (최초 1회, gitignore 대상)
./android/download_sdl.sh

# 2. 게임 에셋을 assets로 스테이징 (다른 프로젝트는 아래 "에셋 스테이징")
./android/prepare_assets.sh

# 3-a. Android Studio로 android/ 디렉터리를 열고 빌드하거나,
# 3-b. CLI로:
cd android
gradle wrapper --gradle-version 8.6   # 최초 1회 (wrapper는 커밋하지 않음)
./gradlew :app:assembleDebug
```

APK는 `android/app/build/outputs/apk/debug/`에 생성됩니다.

## 에셋 스테이징

인자 없이 부르면 이 저장소 자신을 예전 그대로 올립니다. `scripts/`, `resources/`, `game.json`, `config.setting`,
`db.sqlite`를 복사하고 `resources/RTP.zip`과 점 파일만 뺍니다. RTP 변환물(`resources/rtp/`)도 들어가므로 알데바란을
RTP 그림으로 기기에서 볼 수 있습니다.

다른 프로젝트(에디터로 만든 게임 등)는 `--project`로 줍니다. 규칙은 `tools/stage_rules.json` 한 장이고 목록은
`tools/stage_list.py`가 만듭니다 (`python3` 필요).

```bash
./android/prepare_assets.sh --project ~/games/flappy             # 규칙대로 스테이징
./android/prepare_assets.sh --project ~/games/flappy --dry-run   # 복사 없이 파일 수와 크기만
./android/prepare_assets.sh --project . --with-rtp               # 이 저장소를 새 규칙으로, RTP 변환물 포함
```

- `game.json`, `db.sqlite`, `scripts/`, `resources/`만 올립니다. `config.setting`, 점으로 시작하는 이름, `.zip`, `.psd`,
  `resources/aldebaran/src/`는 넣지 않습니다. AAPT가 버리는 이름(`_`로 시작하는 폴더, `~`로 끝나는 파일 등)은 빼고 경고합니다.
- `resources/rtp/`는 `--with-rtp`일 때만 넣고 `WARN rtp:` 줄을 찍습니다. 재배포할 수 없는 소재이므로 이 APK는 개인 기기
  시험에만 쓰십시오.
- 스탬프 파일(`assets_stamp/<해시>.txt`)이 목록에 들어갑니다. 파일 목록이 같고 내용만 바뀌어도 `assets_manifest.txt`가
  달라져 기기가 에셋을 다시 풉니다.
- 마지막 줄은 `STAGED files=<n> bytes=<b> stamp=<12자> rtp=<yes|no> dest=<경로>`이고, `--dry-run`은
  `DRYRUN files=<n> bytes=<b> rtp=<yes|no>`입니다. 종료 코드는 0 성공, 1 입출력 오류, 2 인자나 프로젝트 오류입니다.
- `--dest <폴더>`로 대상을 바꿀 수 있습니다 (시험용. 대상 폴더는 통째로 지워집니다).

InitialEditor의 "실행 > 안드로이드로 스테이징"이 열린 프로젝트로 `--project`를 붙여 이 스크립트를 부릅니다. 검사는
`tests/tools/prepare_assets_test.sh`이고 `tests/run_all.sh`에서 돕니다.

## 릴리즈 빌드

릴리즈 APK는 서명이 필요합니다. 키스토어와 접속 정보 파일을 `android/`에 만들면
`assembleRelease`가 서명까지 합니다. **두 파일 모두 gitignore 대상이며 절대
커밋하지 않습니다.** 키스토어를 잃으면 같은 기기에 업데이트 설치가 불가능해지므로
(서명 불일치) 정식 배포용 키는 따로 백업하십시오.

```bash
cd android

# 1. 키스토어 생성 (최초 1회. 비밀번호는 예시이니 바꿔서 사용)
keytool -genkeypair -v -keystore release.keystore -alias initial2d \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -dname "CN=biud436, OU=Initial2D, O=biud436, C=KR"

# 2. 접속 정보 (android/keystore.properties)
cat > keystore.properties <<'PROPS'
storeFile=release.keystore
storePassword=<비밀번호>
keyAlias=initial2d
keyPassword=<비밀번호>
PROPS
chmod 600 keystore.properties release.keystore

# 3. 빌드와 서명 확인
./gradlew :app:assembleRelease
apksigner verify --print-certs app/build/outputs/apk/release/app-release.apk
```

APK는 `android/app/build/outputs/apk/release/`에 생성됩니다.
`keystore.properties`가 없으면 릴리즈는 서명 없이 빌드되어 설치할 수 없습니다.

디버그 빌드와 릴리즈 빌드는 서명이 다르므로 서로 덮어 설치할 수 없습니다.
바꿔 설치할 때는 먼저 제거하십시오 (`adb uninstall com.biud436.initial2d`).

릴리즈 빌드(NDEBUG)에서는 아래의 핫 리로드 서버가 열리지 않습니다.

## 핫 리로드 (HMR)

디버그 빌드는 HMR 서버가 내장되어 있어, APK 재설치 없이 Lua 스크립트를 바로 반영할 수 있습니다.

```bash
adb forward tcp:5959 tcp:5959      # 최초 1회
python3 tools/hmr_push.py --watch  # 저장할 때마다 자동 push
```

자세한 사용법은 저장소 루트 `README.md`의 "핫 리로드 (HMR)" 섹션을 참조하십시오.

## 구조

| 경로 | 역할 |
|---|---|
| `app/jni/CMakeLists.txt` | 네이티브 빌드 진입점 — SDL 계열 + 엔진 소스를 `libmain.so`로 빌드 |
| `app/src/main/java/.../Initial2DActivity.java` | `SDLActivity` 상속 엔트리 액티비티 |
| `app/jni/SDL2*` | `download_sdl.sh`가 받는 SDL 소스 (gitignore) |
| `app/src/main/assets/` | `prepare_assets.sh`가 스테이징하는 게임 에셋 (gitignore) |

엔진 소스 목록은 저장소 루트 `CMakeLists.txt`(macOS 빌드)와 동일하게 유지해야 합니다.
루트에서 소스가 추가/제거되면 `app/jni/CMakeLists.txt`에도 반영하십시오.
