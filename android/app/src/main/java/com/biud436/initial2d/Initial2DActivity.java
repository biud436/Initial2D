package com.biud436.initial2d;

import org.libsdl.app.SDLActivity;

/**
 * SDL2 엔트리 액티비티.
 * 네이티브 라이브러리(libmain.so)는 android/app/jni/CMakeLists.txt 에서 빌드된다.
 * SDL_main 은 src/platform/sdl2/sdl2Main.cpp 의 main 이 매핑된 것이다.
 */
public class Initial2DActivity extends SDLActivity {
    @Override
    protected String[] getLibraries() {
        return new String[] {
            "SDL2",
            "SDL2_image",
            "SDL2_mixer",
            "main"
        };
    }
}
