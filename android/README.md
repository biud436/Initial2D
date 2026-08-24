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

# 2. 게임 에셋을 assets로 스테이징
./android/prepare_assets.sh

# 3-a. Android Studio로 android/ 디렉터리를 열고 빌드하거나,
# 3-b. CLI로:
cd android
gradle wrapper --gradle-version 8.6   # 최초 1회 (wrapper는 커밋하지 않음)
./gradlew :app:assembleDebug
```

APK는 `android/app/build/outputs/apk/debug/`에 생성됩니다.

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
