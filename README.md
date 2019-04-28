# 도움말
API 래퍼런스는 다음 문서를 참고 하시기 바랍니다.

<a href="https://biud436.github.io/Initial2D/docs/" target="_blank">https://biud436.github.io/Initial2D/docs/</a>

# 스크립트


```lua
 function Initialize()
	
	-- 배경 이미지 생성
	background = Image("./resources/background.png", 0, 0, 640, 480, 1, "background")
	
	-- 캐릭터 생성
	character = Image("./resources/my_character.png", 0, 0, 32, 48, 4, "my_character")
	character.setPosition(10, 50)
	character.setAngle(10.0)
	character.setScale(4.0)
	character.setLoop(true)
	character.setFrameDelay(0.5)
	
	Audio.PlayMusic("./resources/test.ogg", "mainBGM", true)
	
end

function Update(elapsed)
	background.update(elapsed)
	character.update(elapsed)
end

function Render()
	background.draw()
	character.draw()
end

function Destroy()
	background.dispose()
	character.dispose()
	Audio.ReleaseMusic("mainBGM")
end
```

# 빌드 시

빌드 시 다음 라이브러리 파일과 DLL 파일이 필요합니다.

- zlib
    - libzlib.lib
    - zlib1.dll
    - libpng16.lib

- Msimg32.lib

- SDL2 (zlib license)
    - SDL2.dll
    - SDL2.lib

- SDL2 Mixer (zlib license)
    - SDL2_mixer.dll
    - SDL2_mixer.lib
    - native_midi.lib
    - playmus.lib
    - playwave.lib
    - timidity.lib
    - libFLAC-8.dll
    - libmodplug-1.dll
    - libmpg123-0.dll
    - libogg-0.dll
    - libvorbis-0.dll
    - libvorbisfile-3.dll

- TinyXML (zlib license)
    - tinyxml.lib
    - OpenAL32.lib

- Initial2D
    - Initial2D.lib
