---@meta
-- Initial2D 스크립트 API 스텁 (Lua, EmmyLua / LuaLS 주석)
-- tools/gen_api_stubs.py 가 resources/api/initial2d-api.json 에서 만든다. 손으로 고치지 않는다.
-- 에디터 자동완성용이며 엔진이 읽지 않는다 (같은 이름은 엔진이 C++ 로 등록한다).
-- 명세 version 1
--
-- 씬 계약: 엔진이 부르는 전역 함수 (Lua 는 넷 다 정의해야 한다)
--   function Initialize() end          처음 한 번 부른다
--   function Update(elapsed_ms) end    고정 스텝마다 부른다 (경과 시간은 ms)
--   function Render() end              매 프레임 그릴 때 부른다
--   function Destroy() end             끝날 때 한 번 부른다

---Sprite 의 숫자 핸들 (Sprite 표의 함수에 첫 인자로 넘긴다)
---@alias SpriteHandle number

---Tilemap 의 숫자 핸들 (Tilemap 표의 함수에 첫 인자로 넘긴다)
---@alias TilemapHandle number

---FontEx 의 숫자 핸들 (FontEx 표의 함수에 첫 인자로 넘긴다)
---@alias FontExHandle number

-- Graphics: 화면 크기, 렌더 배율, 비트맵 폰트 글자, 점 찍기 (Lua 는 전역 함수)

---논리 해상도의 가로 픽셀 수 (렌더 배율로 나눈 값)
---@return integer
function WindowWidth() end

---논리 해상도의 세로 픽셀 수 (렌더 배율로 나눈 값)
---@return integer
function WindowHeight() end

---지금의 픽셀 확대 배율
---@return integer
function GetRenderScale() end

---픽셀 확대 배율을 정하고 적용된 값을 돌려준다 (1 에서 16 사이로 자른다)
---@param scale integer
---@return integer
function SetRenderScale(scale) end

---최근의 초당 프레임 수 (SDL2 백엔드는 보통 60)
---@return integer
function GetFrameCount() end

---비트맵 폰트를 읽어 글자 그리기에 쓴다. 실패하면 false
---@param path string BMFont .fnt 파일 경로
---@return boolean
function PreparaFont(path) end

---준비한 비트맵 폰트로 글자를 그리고 그린 픽셀 폭을 돌려준다 (폰트가 없으면 0)
---@param x number
---@param y number
---@param text string
---@return number
function DrawText(x, y, text) end

---DrawText 의 별명
---@param x number
---@param y number
---@param text string
---@return number
function draw_text(x, y, text) end

---그리지 않고 글자의 픽셀 폭만 잰다 (폰트가 없으면 0)
---@param text string
---@return number
function GetTextWidth(text) end

---draw_point 가 찍을 색을 정한다 (Lua 는 넷 다 줘야 하고 0 을 돌려준다)
---@param r integer
---@param g integer
---@param b integer
---@param a integer
---@return number
function draw_set_color(r, g, b, a) end

---정해 둔 색(Lua 는 draw_set_color, Ruby 는 set_color)으로 점 하나를 찍는다 (Lua 는 0 을 돌려준다)
---@param x integer
---@param y integer
---@return number
function draw_point(x, y) end

-- System: 플랫폼, 종료, 경로, 리소스 목록, 메시지 상자, 환경 변수 (Lua 는 전역 함수)

---실행 중인 플랫폼 이름 (windows, macos, linux, android, ios 또는 SDL 이 보고하는 소문자 이름)
---@return string
function GetPlatform() end

---이번 프레임을 마치고 게임을 끝낸다
function GameExit() end

---작업 디렉터리 경로 (Ruby 는 언제나 / 구분자, Lua 는 인자를 주면 \ 를 / 로 바꾼다)
---@param slash? any 주면 경로 구분자를 / 로 바꾼다
---@return string
function GetCurrentDirectory(slash) end

---./resources 아래 파일의 경로 목록 (하위 폴더까지, 예: ./resources/maps/sample.json)
---@return string[]
function GetResourcesFiles() end

---메시지 상자를 띄운다 (첫 인자가 본문, 둘째가 제목)
---@param text string 본문
---@param caption? string 제목, 기본값 ""
function MessageBox(text, caption) end

---창 아이콘을 이미지 파일로 바꾼다
---@param path string
function SetAppIcon(path) end

-- Kernel: 스크립트 파일 읽기와 출력 (Lua 는 전역 함수, Ruby 는 받는 쪽 없이 부르는 Kernel 메서드)

---Lua 파일을 읽어 실행한다. 실패해도 알리지 않는다 (Ruby 의 load 에 해당)
---@param path string
function LoadScript(path) end

---표준 print 를 대신한다. 인자를 구분자 없이 이어 찍고 줄을 바꾼다 (문자열과 숫자만 찍히고, 인자가 하나 이상 필요)
---@param ... any
function print(...) end

---키보드, 마우스, 멀티터치 입력 (고정 스텝마다 상태를 읽는다)
---@class Input
Input = {}

---이번 틱에 눌렸는가
---@param key integer 가상 키 코드 (Ruby 는 Keys 상수 이름 Symbol 도 된다)
---@return boolean
function Input.IsKeyDown(key) end

---이번 틱에 떼었는가
---@param key integer 가상 키 코드 (Ruby 는 Keys 상수 이름 Symbol 도 된다)
---@return boolean
function Input.IsKeyUp(key) end

---눌린 채로 있는가
---@param key integer 가상 키 코드 (Ruby 는 Keys 상수 이름 Symbol 도 된다)
---@return boolean
function Input.IsKeyPress(key) end

---이번 틱에 아무 키나 눌렸는가
---@return boolean
function Input.IsAnyKeyDown() end

---마우스 x (논리 좌표)
---@return number
function Input.GetMouseX() end

---마우스 y (논리 좌표)
---@return number
function Input.GetMouseY() end

---이번 틱에 마우스 버튼이 눌렸는가
---@param button integer 0 왼쪽, 1 오른쪽, 2 가운데 (Ruby 는 :left, :right, :middle 도 된다)
---@return boolean
function Input.IsMouseDown(button) end

---이번 틱에 마우스 버튼을 떼었는가
---@param button integer 0 왼쪽, 1 오른쪽, 2 가운데 (Ruby 는 :left, :right, :middle 도 된다)
---@return boolean
function Input.IsMouseUp(button) end

---마우스 버튼이 눌린 채로 있는가
---@param button integer 0 왼쪽, 1 오른쪽, 2 가운데 (Ruby 는 :left, :right, :middle 도 된다)
---@return boolean
function Input.IsMousePress(button) end

---이번 틱에 아무 마우스 버튼이나 눌렸는가
---@return boolean
function Input.IsAnyMouseDown() end

---마우스 휠 값 (올림과 내림을 -1 과 1 로)
---@return integer
function Input.GetMouseZ() end

---마우스 휠 값을 정한다
---@param wheel integer
function Input.SetMouseZ(wheel) end

---이번 틱에 보이는 손가락 수 (뗀 손가락도 한 틱 보인다, GDI 는 언제나 0)
---@return integer
function Input.GetTouchCount() end

---손가락 하나의 id, x, y, 단계(down, press, up). 범위 밖이면 nil
---@param index integer Lua 는 1 부터, Ruby 는 0 부터
---@return integer|nil
---@return number
---@return number
---@return string
function Input.GetTouch(index) end

---배경 음악과 효과음 (SDL_mixer, 파일은 재생할 때 읽고 id 로 찾는다)
---@class Audio
Audio = {}

---음악 파일을 읽어 배경 음악으로 튼다 (Lua 는 loop 까지 셋 다 줘야 한다)
---@param path string
---@param id string
---@param loop boolean|integer true 무한 반복, false 한 번, 숫자는 SDL_mixer 루프 값 그대로
function Audio.PlayMusic(path, id, loop) end

---효과음 파일을 읽어 튼다 (Lua 는 loop 까지 셋 다 줘야 한다)
---@param path string
---@param id string
---@param loop boolean|integer true 무한 반복, false 한 번, 숫자는 SDL_mixer 루프 값 그대로
function Audio.PlaySound(path, id, loop) end

---배경 음악 볼륨을 정한다 (0..255 를 SDL_mixer 의 0..128 로 바꾼다)
---@param volume integer 0 에서 255
function Audio.SetVolume(volume) end

---배경 음악 볼륨 (SDL_mixer 의 0..128)
---@return integer
function Audio.GetVolume() end

---지금 곡이 끝나면 이어서 틀 음악을 예약한다 (Lua 는 loop 까지 셋 다 줘야 한다)
---@param path string
---@param id string
---@param loop boolean|integer true 무한 반복, false 한 번, 숫자는 SDL_mixer 루프 값 그대로
function Audio.InsertNextMusic(path, id, loop) end

---배경 음악을 잠시 멈춘다
function Audio.PauseMusic() end

---배경 음악을 멈춘다
function Audio.StopMusic() end

---잠시 멈춘 배경 음악을 잇는다
function Audio.ResumeMusic() end

---배경 음악이 나오고 있는가
---@return boolean
function Audio.IsPlayingMusic() end

---배경 음악을 ms 동안 줄이며 끈다
---@param ms integer
function Audio.FadeOutMusic(ms) end

---배경 음악의 재생 위치(초)를 옮긴다
---@param seconds number
function Audio.SetMusicPosition(seconds) end

---읽어 둔 음악을 메모리에서 놓는다
---@param id string
function Audio.ReleaseMusic(id) end

---JSON 읽기 (객체는 표나 Hash, 배열은 배열, null 은 nil)
---@class Json
Json = {}

---JSON 파일을 읽는다. 실패하면 Lua 는 nil 과 메시지, Ruby 는 RuntimeError
---@param path string
---@return any
---@return string|nil
function Json.Load(path) end

---텍스처 캐시 (이미지를 id 로 등록하고 스프라이트가 id 로 찾는다)
---@class TextureManager
TextureManager = {}

---이미지 파일을 읽어 id 로 등록한다
---@param path string
---@param id string
---@return boolean
function TextureManager.Load(path, id) end

---id 의 텍스처를 놓는다
---@param id string
---@return boolean
function TextureManager.Remove(id) end

---id 로 등록된 텍스처가 있는가
---@param id string
---@return boolean
function TextureManager.IsValid(id) end

---텍스처 한 장을 그리는 스프라이트 (시트 애니메이션, 회전, 확대, 투명도)
---@class Sprite
Sprite = {}

---스프라이트를 만든다. 텍스처는 TextureManager 에 먼저 올려 둔다 (Lua 는 인자가 모자라면 0)
---@param x number
---@param y number
---@param width integer
---@param height integer
---@param max_frames integer
---@param texture_id string TextureManager 에 올린 id
---@return SpriteHandle
function Sprite.Create(x, y, width, height, max_frames, texture_id) end

---애니메이션을 경과 시간만큼 넘기고 변환을 확정한다
---@param handle SpriteHandle
---@param elapsed number ms
function Sprite.Update(handle, elapsed) end

---화면에 그린다
---@param handle SpriteHandle
function Sprite.Draw(handle) end

---위치 (x, y)
---@param handle SpriteHandle
---@return number
---@return number
function Sprite.GetPosition(handle) end

---위치를 옮긴다
---@param handle SpriteHandle
---@param x number
---@param y number
function Sprite.SetPosition(handle, x, y) end

---확대 배율
---@param handle SpriteHandle
---@return number
function Sprite.GetScale(handle) end

---확대 배율을 정한다
---@param handle SpriteHandle
---@param scale number
function Sprite.SetScale(handle, scale) end

---한 프레임의 가로 픽셀
---@param handle SpriteHandle
---@return number
function Sprite.GetWidth(handle) end

---한 프레임의 세로 픽셀
---@param handle SpriteHandle
---@return number
function Sprite.GetHeight(handle) end

---회전 각도(도)
---@param handle SpriteHandle
---@return number
function Sprite.GetAngle(handle) end

---회전 각도(도)를 정한다
---@param handle SpriteHandle
---@param degrees number
function Sprite.SetAngle(handle, degrees) end

---회전 각도(라디안)
---@param handle SpriteHandle
---@return number
function Sprite.GetRadians(handle) end

---회전 각도(라디안)를 정한다
---@param handle SpriteHandle
---@param radians number
function Sprite.SetRadians(handle, radians) end

---보이는가
---@param handle SpriteHandle
---@return boolean
function Sprite.GetVisible(handle) end

---보일지 정한다
---@param handle SpriteHandle
---@param visible boolean
function Sprite.SetVisible(handle, visible) end

---불투명도 (0..255)
---@param handle SpriteHandle
---@return number
function Sprite.GetOpacity(handle) end

---불투명도를 정한다
---@param handle SpriteHandle
---@param opacity integer 0 에서 255
function Sprite.SetOpacity(handle, opacity) end

---프레임 사이 시간(ms)
---@param handle SpriteHandle
---@return number
function Sprite.GetFrameDelay(handle) end

---프레임 사이 시간을 정한다
---@param handle SpriteHandle
---@param delay number ms
function Sprite.SetFrameDelay(handle, delay) end

---애니메이션 프레임 범위를 정한다 (둘째 인자는 끝의 다음)
---@param handle SpriteHandle
---@param first integer
---@param last integer 끝의 다음 프레임 번호
function Sprite.SetFrames(handle, first, last) end

---애니메이션 첫 프레임
---@param handle SpriteHandle
---@return number
function Sprite.GetStartFrame(handle) end

---애니메이션 마지막 프레임
---@param handle SpriteHandle
---@return number
function Sprite.GetEndFrame(handle) end

---지금 프레임
---@param handle SpriteHandle
---@return number
function Sprite.GetCurrentFrame(handle) end

---지금 프레임을 정한다
---@param handle SpriteHandle
---@param frame integer
function Sprite.SetCurrentFrame(handle, frame) end

---애니메이션을 되풀이할지 정한다
---@param handle SpriteHandle
---@param loop boolean
function Sprite.SetLoop(handle, loop) end

---애니메이션이 끝났는가
---@param handle SpriteHandle
---@return boolean
function Sprite.GetAnimComplete(handle) end

---애니메이션 끝 표시를 정한다
---@param handle SpriteHandle
---@param complete boolean
function Sprite.SetAnimComplete(handle, complete) end

---시트 분할을 정한다 (기본 4x4, R2K3 CharSet 은 3x4)
---@param handle SpriteHandle
---@param cols integer
---@param rows integer
function Sprite.SetSheetGrid(handle, cols, rows) end

---소스 사각형. Lua 는 width, height 칸에 오른쪽, 아래 좌표를 담고, Ruby 는 x, y, right, bottom, width, height 를 이름대로 준다
---@param handle SpriteHandle
---@return table
function Sprite.GetRect(handle) end

---텍스처에서 잘라 그릴 소스 사각형을 정한다 (x, y, width, height 를 가진 표 하나로도 된다)
---@param handle SpriteHandle
---@param x integer
---@param y integer
---@param width integer
---@param height integer
---@overload fun(handle: SpriteHandle, rect: table)
function Sprite.SetRect(handle, x, y, width, height) end

---스프라이트를 놓는다. 텍스처는 함께 놓지 않는다
---@param handle SpriteHandle
function Sprite.Dispose(handle) end

---맵 포맷 v1, v2 JSON 을 읽어 그리는 다층 타일맵 (x, y 는 0 기준 타일 좌표)
---@class Tilemap
Tilemap = {}

---맵 파일을 읽는다. 실패하면 nil (Lua 는 오류 메시지도 함께)
---@param path string
---@return TilemapHandle|nil
---@return string|nil
function Tilemap.Load(path) end

---레이어 범위를 카메라 오프셋과 함께 그린다 (보이는 타일만)
---@param handle TilemapHandle
---@param layer_from integer Lua 는 1 부터, Ruby 는 0 부터
---@param layer_to integer 양 끝 포함
---@param cam_x? integer 월드 픽셀, 기본값 0
---@param cam_y? integer 월드 픽셀, 기본값 0
function Tilemap.Draw(handle, layer_from, layer_to, cam_x, cam_y) end

---가로 타일 수, 세로 타일 수, 타일 가로 픽셀, 타일 세로 픽셀, 레이어 수
---@param handle TilemapHandle
---@return integer
---@return integer
---@return integer
---@return integer
---@return integer
function Tilemap.GetSize(handle) end

---타일 gid (빈 칸과 범위 밖은 0)
---@param handle TilemapHandle
---@param x integer
---@param y integer
---@param layer integer Lua 는 1 부터, Ruby 는 0 부터
---@return integer
function Tilemap.GetTileId(handle, x, y, layer) end

---타일 gid 를 바꾼다. 범위 밖이면 false
---@param handle TilemapHandle
---@param x integer
---@param y integer
---@param layer integer Lua 는 1 부터, Ruby 는 0 부터
---@param gid integer
---@return boolean
function Tilemap.SetTileId(handle, x, y, layer, gid) end

---지나갈 수 있는 칸인가 (범위 밖은 false)
---@param handle TilemapHandle
---@param x integer
---@param y integer
---@return boolean
function Tilemap.IsPassable(handle, x, y) end

---맵을 놓는다. 타일셋 텍스처는 TextureManager 에 남는다
---@param handle TilemapHandle
function Tilemap.Dispose(handle) end

---시스템 폰트로 글자 텍스처를 만드는 동적 폰트 (Windows 전용, macOS 와 Android 는 무동작 스텁)
---@class FontEx
FontEx = {}

---폰트 이름과 크기, 텍스처 크기로 만든다 (Lua 는 인자가 모자라면 0)
---@param face string 폰트 이름
---@param size integer
---@param width integer
---@param height integer
---@return FontExHandle
function FontEx.Create(face, size, width, height) end

---갱신한다 (지금은 하는 일이 없다)
---@param handle FontExHandle
---@param elapsed number ms
function FontEx.Update(handle, elapsed) end

---화면에 그린다
---@param handle FontExHandle
function FontEx.Draw(handle) end

---그릴 글자를 정한다
---@param handle FontExHandle
---@param text string
function FontEx.SetText(handle, text) end

---위치를 정한다
---@param handle FontExHandle
---@param x integer
---@param y integer
function FontEx.SetPosition(handle, x, y) end

---글자 색을 정한다
---@param handle FontExHandle
---@param r integer
---@param g integer
---@param b integer
function FontEx.SetTextColor(handle, r, g, b) end

---불투명도를 정한다
---@param handle FontExHandle
---@param opacity integer 0 에서 255
function FontEx.SetOpacity(handle, opacity) end

---회전 각도(도)를 정한다
---@param handle FontExHandle
---@param degrees number
function FontEx.SetAngle(handle, degrees) end

---글자의 픽셀 폭을 잰다
---@param handle FontExHandle
---@param text string
---@return number
function FontEx.GetTextWidth(handle, text) end

---폰트를 놓는다
---@param handle FontExHandle
function FontEx.Dispose(handle) end
