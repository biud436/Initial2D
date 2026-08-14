# Initial2D — Android 포트 (SDL2)

macOS 포팅에서 만든 SDL2 어댑터(`src/platform/sdl2/`)를 그대로 재사용하는 Android 빌드입니다.
실기(Galaxy S24 / Android 16)에서 게임 구동·터치 입력·오디오 재생이 확인되었습니다.
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

## 구조

| 경로 | 역할 |
|---|---|
| `app/jni/CMakeLists.txt` | 네이티브 빌드 진입점 — SDL 계열 + 엔진 소스를 `libmain.so`로 빌드 |
| `app/src/main/java/.../Initial2DActivity.java` | `SDLActivity` 상속 엔트리 액티비티 |
| `app/jni/SDL2*` | `download_sdl.sh`가 받는 SDL 소스 (gitignore) |
| `app/src/main/assets/` | `prepare_assets.sh`가 스테이징하는 게임 에셋 (gitignore) |

엔진 소스 목록은 저장소 루트 `CMakeLists.txt`(macOS 빌드)와 동일하게 유지해야 합니다.
루트에서 소스가 추가/제거되면 `app/jni/CMakeLists.txt`에도 반영하십시오.
