# 소개
[![Build status](https://ci.appveyor.com/api/projects/status/277ojyc6arrdrcxd/branch/master?svg=true)](https://ci.appveyor.com/project/biud436/initial2d/branch/master)

개인적인 용도로 만든 C++ (GDI) 기반 게임 엔진입니다. 

|구분|내용|
|:--:|:--:|
|Version|Beta|
|Platform|Windows|
|사용된 언어|C++, Lua, C#|
|Engine Type|자체 개발 엔진|
|Graphics Device|Windows GDI 사용|
|이미지 포맷|*.PNG(libpng), *.BMP 지원|
|오디오 재생|*.ogg 포함 대부분 포맷 지원 (SDL Audio 사용)|
|동영상 재생|동영상 재생 불가|
|하드웨어 가속 여부|false|
|Script Engine|Lua v5.0.3|
|Map Editor|개발 중 (C# Winform, QT 5)|
|Data Type|*.json (Game Data), *.sqlite (DB)|
|암호화 지원|false|
|멀티 쓰레딩 지원|false|
|쓰레드 처리 지원|Unstable|
|프로세스 실행|true|
|Bitmap Font 지원|true|
|GetGlyphOutline을 이용한 폰트 묘화 지원|true|
|타일맵 지원|true|

# 맵 에디터
- 웹 PC 버전

C# Winfrom으로 개발된 초안에 비해 상당한 UI 개선과 설계 개선이 있으며 자체 개발되었습니다. 크로스 플랫폼 에디터를 목표로 개발되었습니다. 그러나 보안 상의 문제로 바닐라 웹에서 동작하기에는 한계가 있어 Electron + Typescript 조합을 사용하였습니다.

|구분|내용|
|:--:|:--:|
|버전|개발 중|
|레이어 갯수|4개|
|오브젝트 배치 가능 여부|아직 불가능|
|오브젝트 속성 변경 가능|아직 불가능|
|스크립트 에디터|없음|
|맵 파일 생성|가능|
|테스트 플레이 기능|없음|
|다중 타일셋 처리|가능|

![IMG_NEW_EDITOR](./docs/img/new_editor.png)

---

- C# Winfrom PC 버전 (초안)

1차원 배열로 되어있는 타일맵을 편집하고 테스트 플레이를 하면 자체 개발된 게임 엔진에 그대로 반영되는 간단한 툴로 시작하였습니다만 스크립트 에디터까지 추가하면서 차차 발전을 하였습니다. 그러나 타일맵을 직접 페인트 이벤트로 그리기에는 다양한 문제가 있는데다가 윈폼은 크로스 플랫폼도 아니기 때문에 현재는 중단되었습니다.

|구분|내용|
|:--:|:--:|
|버전|개발 중단|
|레이어 갯수|1개|
|오브젝트 배치 가능 여부|아직 불가능|
|오브젝트 속성 변경 가능|아직 불가능|
|스크립트 에디터|있음|
|맵 파일 생성|가능|
|테스트 플레이 기능|있음|
|다중 타일셋 처리|불가능|

![IMG1](./docs/img/0.png)


# 스크립트 예제
C++ 에선 내부적으로 WinMain을 Entry Point로 삼고 초기화를 거치고, 상태 머신을 통해 순서대로 initialize, update, render 등의 메소드를 자동으로 호출할 수 있습니다. 

Initialize 함수가 유일한 Entry Point 입니다. 다음으로 중요한 함수는 Update 함수와 Render 함수로 매 프레임마다 호출되며 마지막으로 Destroy 함수에서 메모리 해제를 합니다.

```lua
local Font = require("scripts/Font")
local Image = require("scripts/image")
local Tilemap = require("scripts/tilemap")

function Initialize()
	
	-- -- Create background image
	-- background = Image("./resources/titles/title.png", 0, 0, 640, 480, 1, "Title")

	-- -- Create button text
	buttonText = Image("./resources/titles/start_button.png" , 0, 0, 256, 30, 1, "buttonText")
	
	-- -- Create Image
	mx = WindowWidth() / 2 - buttonText.getWidth() / 2
	my = WindowHeight() / 2 - buttonText.getHeight() + WindowHeight() / 4
	buttonText.setPosition(mx, my)
	buttonText.setAngle(0.0)
	buttonText.setScale(1.0)
	buttonText.setLoop(false)
	
	-- Play background music
	Audio.PlayMusic("./resources/audio/bless.ogg", "mainBGM", true)
	
	isValid = PreparaFont("./resources/fonts/hangul.fnt")

	myElapsed = 0.0
	tt = 0

	print("hi...",  "안녕하십니까")

	tilemap = Tilemap(17, 13)
	tilemap.init()

	local res = GetResourcesFiles()
	for k, v in ipairs(res) do
		print(v)
	end
	
end

function Update(elapsed)
	-- background.update(elapsed)
	
	buttonText.setAngle(Input.GetMouseY())
	buttonText.update(elapsed)
	
	tilemap.rotate(tt % 360)
	tilemap.update(elapsed)

	tt = tt + 1
	if tt > WindowWidth() then
		tt = 0
	end

	myElapsed = elapsed
end

function DrawTempText()
	-- Create a text
	local text = "2020년입니다~ 하하"
	myFont = Font("나눔고딕", 32, 400, 440)
	myFont.setText(text)
	
	-- myFont.setPosition(WindowWidth() - myFont.getTextWidth(text), 0)	
	myFont.setTextColor(math.floor(math.random() * 255), math.floor(math.random() * 255), math.floor(math.random() * 255))
	myFont.setOpacity( 200 )
	myFont.setAngle(tt % 360)
	myFont.setPosition(WindowWidth() / 2 - myFont.getTextWidth(text) / 2, WindowHeight() / 4)
		
	myFont.update(myElapsed)

	myFont.draw()
	myFont.dispose()
end

function Render()
	-- background.draw()
	buttonText.draw()

	tilemap.draw()
		
	DrawTempText()
		
	if isValid then 
		DrawText(100, 0, "테스트")
		frameCount = GetFrameCount()
		DrawText(0, 0, tostring(frameCount))
	end
		
end

function Destroy()
	-- background.dispose()
	buttonText.dispose()

	tilemap.dispose()

	Audio.ReleaseMusic("mainBGM")	
end
```

# Image
Image 객체는 Sprite Sheet를 사용하여 Character Animation을 표현하기 위한 객체입니다.
또한 Sprite class의 Wrapper입니다. 
루아의 GC 대상이 아니므로 비트맵 메모리 해제를 명시적으로 호출해줘야 할 필요성이 있습니다.

```lua
	image = Image(path, x, y, width, height, max_frames, id)
	image.update(elapsed) -- 프레임 업데이트
	image.draw() -- 렌더링
	image.dispose() -- 메모리 해제
	image.getPosition() -- 위치 
	image.getScale() -- 스케일
	image.getWidth() -- 가로 크기
	image.getHeight() -- 세로 크기
	image.getRadians() -- 각도를 라디안으로 반환
	image.getAngle() -- 각도 반환
	image.getVisible() -- Visible 값 반환
	image.getOpacity() -- 투명도
	image.getFrameDelay() -- 프레임 딜레이
	image.getStartFrame() -- 시작 프레임
	image.getEndFrame() -- 종료 프레임
	image.getAnimComplete() -- 애니메이션 완료
	image.getRect() -- Rect Table 반환
	image.setPosition(x, y)
	image.setScale(n)
	image.setAngle(degree)
	image.setRadians(rotation)
	image.setVisible(visible)
	image.setOpacity(n)
	image.setFrameDelay(delay)
	image.setFrames(s, e)
	image.setCurrentFrame(currentFrame)
	image.setRect(x, y, width, height)
	image.setLoop(isLooping)
	image.setAnimComplete(isCompletedAnimation)
```

# TextureManager

이미지 파일(*.png, *.bmp)을 로드하여 DIB로 변환합니다. DIB는 GDI 기반으로 렌더링 시 이용됩니다.
PNG 파일의 경우, 내부적으로 libpng를 이용하여 색상 RAW 값을 얻은 후 DIB로 디코딩하였습니다. 

Image 객체에서 내부적으로 호출하므로 굳이 수동으로 사용할 필요는 없습니다.

```lua
	-- id는 문자열이어야 합니다. 
	-- "my_character"와 같은 식으로 지정하십시오.
	TextureManager.Load(filename, id)
	TextureManager.Remove(id)
	local isValid = TextureManager.IsValid(id)
```

# Audio
OGG 파일 또는 WAV 파일, 미디 파일 등 여러가지 포맷의 오디오 파일을 재생할 수 있습니다. 

```lua
	Audio.PlayMusic(path, id, loop) -- BGM 재생
	Audio.PlaySound(path, id, loop) -- SE 재생
	Audio.SetVolume(vol) -- BGM 볼륨 설정
	Audio.GetVolume() -- BGM 볼륨 획득
	Audio.InsertNextMusic(path, id, loop) -- 다음 BGM 추가
	Audio.PauseMusic() -- BGM 일시 정지
	Audio.StopMusic() -- BGM 정지
	Audio.ResumeMusic() -- BGM 재개
	Audio.IsPlayingMusic() -- BGM 재생 여부
	Audio.FadeOutMusic(ms) -- BGM 페이드아웃
	Audio.SetMusicPosition(position) -- BGM 재생 위치 설정
	Audio.ReleaseMusic(id) -- 메모리 해제
```

음악 재생 시 오디오 파일을 자동으로 로드합니다. 하지만 메모리는 반드시 수동으로 해제해야 합니다.

# Input
키보드 및 마우스 입력을 처리합니다. 

```lua

	-- vKey는 가상 키 값입니다. 
	Input.IsKeyDown(vKey)
	Input.IsKeyUp(vKey)
	Input.IsKeyPress(vKey)
	Input.IsAnyKeyDown()
	Input.GetMouseX()
	Input.GetMouseY()

	-- 마우스에서의 가상 키는 다음과 같습니다.
	-- 0 : 마우스 왼쪽
	-- 1 : 마우스 오른쪽
	-- 2 : 마우스 중앙
	Input.IsMouseDown(vKey)
	Input.IsMouseUp(vKey)
	Input.IsMousePress(vKey)
	Input.IsAnyMouseDown()

	-- 마우스 휠 처리는 메시지 콜백 함수에서 수신합니다.
	-- 마우스 휠 올림 내림 판단을 -1과 1로 처리합니다.
	Input.GetMouseZ()
	Input.SetMouseZ(wheel)

	-- Enter 키를 누르고 있는가?
	local vKey = string.byte("\r\n") -- 13
	if Input.IsKeyPress(vKey) then
		-- 처리
	end

	-- A 키를 눌렀는가?
	local vKey = string.byte("A") --65
	if Input.IsKeyDown(vKey) then
		-- 처리
	end	

```

# Bitmap Text

텍스트를 화면에 그립니다. Bitmap Text(비트맵 텍스트)로 되어있으나 \n과 같은 개행 문자(Line Break)도 처리합니다. **한글**과 **영어**를 사용할 수 있습니다. BMFont로 만든 **PNG 파일**과 **XML 규격**으로 된 **FNT 파일**이 리소스 폴더에 있어야 합니다.

동적 할당이 아닌 고정적으로 수 만자에 대한 텍스트 메모리를 한 번에 할당합니다. 이렇게 하는 이유는 동적 할당으로 인한 캐시 문제 때문입니다.

```lua
	-- FNT 파일 준비 (TinyXml을 이용하여 읽습니다)
	PreparaFont(fontFilePath)
	--텍스트 묘화 (Bitmap Text 기반입니다.)
	DrawText(x, y, text)
```

# Font

동적으로 폰트 텍스쳐를 생성하고 화면에 텍스트를 그립니다. 
사용자의 시스템 폰트 폴더에 있는 어떤 폰트도 사용할 수 있습니다.

```lua
	nanumFont = Font("나눔고딕", 72)
	nanumFont.setText("안녕하세요?")
	nanumFont.setPosition(100, 100)
	nanumFont.setTextColor(255, 0, 0)
	nanumFont.setOpacity(128)

	-- 업데이트 함수입니다만 아직 아무 기능도 하지 않습니다.
	nanumFont.update(elapsed)

	-- 렌더링 함수입니다. 반드시 호출해야 합니다.
	nanumFont.draw()
	nanumFont.dispose()

```

다만 폰트가 시스템에 설치되어있는 지 여부는 따로 검색하지 않습니다.

# Utils

```lua
	-- 메시지 박스를 띄웁니다.
	MessageBox(title, caption)

	-- 루아 스크립트 파일을 로드합니다.
	LoadScript(luaFile)
	
	-- 창 가로 크기
	WindowWidth()

	-- 창 세로 크기
	WindowHeight()

	-- 평균 FPS 
	-- 고정 프레임을 사용하지 않으므로
	-- 보통 100 프레임 이상이 나와야 정상입니다.
	GetFrameCount()


	-- 현재 경로를 유닉스/리눅스 스타일로 출력합니다. (경로 구분자 = /)
	GetCurrentDirectory(True)

	-- 현재 경로를 윈도우즈 스타일로 출력합니다. (경로 구분자 = \\)
	GetCurrentDirectory()

	-- 리소스 파일 목록을 반환합니다 (암호화 X)
	GetResourcesFiles()
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


# 코딩 스타일

- 함수는 소문자로 시작되어야 하며, 단어마다 대문자를 사용해야 합니다.

# 리소스 출처

tuxemon-tileset - https://opengameart.org/content/tuxemon-tileset