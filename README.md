# ����
API ���۷����� ���� ������ ���� �Ͻñ� �ٶ��ϴ�.

<a href="https://biud436.github.io/Initial2D/docs/" target="_blank">https://biud436.github.io/Initial2D/docs/</a>

# ��ũ��Ʈ


```lua
 function Initialize()
	
	-- ��� �̹��� ����
	background = Image("./resources/background.png", 0, 0, 640, 480, 1, "background")
	
	-- ĳ���� ����
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

# ���� ��

���� �� ���� ���̺귯�� ���ϰ� DLL ������ �ʿ��մϴ�.

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
