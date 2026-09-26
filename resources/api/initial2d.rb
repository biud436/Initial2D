# Initial2D 스크립트 API 스텁 (Ruby, YARD 주석)
# tools/gen_api_stubs.py 가 resources/api/initial2d-api.json 에서 만든다. 손으로 고치지 않는다.
# 에디터 자동완성용이며 엔진이 읽지 않는다 (같은 이름은 엔진이 C++ 와 프렐류드로 정의한다).
# 명세 version 1
#
# 씬 계약: 엔진이 부르는 최상위 메서드 (없는 것은 부르지 않는다)
#   def init; end                  처음 한 번 부른다
#   def update(elapsed_ms); end    고정 스텝마다 부른다 (경과 시간은 ms)
#   def render; end                매 프레임 그릴 때 부른다
#   def destroy; end               끝날 때 한 번 부른다

# 화면 크기, 렌더 배율, 비트맵 폰트 글자, 점 찍기 (Lua 는 전역 함수)
module Graphics
  # 논리 해상도의 가로 픽셀 수 (렌더 배율로 나눈 값)
  # @return [Integer]
  def self.width; end

  # 논리 해상도의 세로 픽셀 수 (렌더 배율로 나눈 값)
  # @return [Integer]
  def self.height; end

  # 지금의 픽셀 확대 배율
  # @return [Integer]
  def self.render_scale; end

  # 픽셀 확대 배율을 정하고 적용된 값을 돌려준다 (1 에서 16 사이로 자른다)
  # @param [Integer] scale
  # @return [Integer]
  def self.render_scale=(scale); end

  # 최근의 초당 프레임 수 (SDL2 백엔드는 보통 60)
  # @return [Integer]
  def self.frame_count; end

  # 비트맵 폰트를 읽어 글자 그리기에 쓴다. 실패하면 false
  # @param [String] path BMFont .fnt 파일 경로
  # @return [Boolean]
  def self.prepare_font(path); end

  # 준비한 비트맵 폰트로 글자를 그리고 그린 픽셀 폭을 돌려준다 (폰트가 없으면 0)
  # @param [Numeric] x
  # @param [Numeric] y
  # @param [String] text
  # @return [Integer]
  def self.draw_text(x, y, text); end

  # 그리지 않고 글자의 픽셀 폭만 잰다 (폰트가 없으면 0)
  # @param [String] text
  # @return [Integer]
  def self.text_width(text); end

  # draw_point 가 찍을 색을 정한다 (Lua 는 넷 다 줘야 하고 0 을 돌려준다)
  # @param [Integer] r
  # @param [Integer] g
  # @param [Integer] b
  # @param [Integer] a 기본값 255
  # @return [void]
  def self.set_color(r, g, b, a = 255); end

  # 정해 둔 색(Lua 는 draw_set_color, Ruby 는 set_color)으로 점 하나를 찍는다 (Lua 는 0 을 돌려준다)
  # @param [Integer] x
  # @param [Integer] y
  # @return [void]
  def self.draw_point(x, y); end
end

# 플랫폼, 종료, 경로, 리소스 목록, 메시지 상자, 환경 변수 (Lua 는 전역 함수)
module System
  # 실행 중인 플랫폼 이름 (windows, macos, linux, android, ios 또는 SDL 이 보고하는 소문자 이름)
  # @return [String]
  def self.platform; end

  # 이번 프레임을 마치고 게임을 끝낸다
  # @return [void]
  def self.exit; end

  # 작업 디렉터리 경로 (Ruby 는 언제나 / 구분자, Lua 는 인자를 주면 \ 를 / 로 바꾼다)
  # @return [String]
  def self.current_directory; end

  # ./resources 아래 파일의 경로 목록 (하위 폴더까지, 예: ./resources/maps/sample.json)
  # @return [Array<String>]
  def self.resource_files; end

  # 메시지 상자를 띄운다 (첫 인자가 본문, 둘째가 제목)
  # @param [String] text 본문
  # @param [String] caption 제목, 기본값 ""
  # @return [void]
  def self.message_box(text, caption = ""); end

  # 창 아이콘을 이미지 파일로 바꾼다
  # @param [String] path
  # @return [void]
  def self.app_icon=(path); end

  # 환경 변수 값, 없으면 nil (mruby 에는 ENV 가 없다. Lua 는 os.getenv)
  # @param [String] name
  # @return [String, nil]
  def self.env(name); end

  # 지금 도는 스크립트 백엔드 이름 (언제나 "mruby")
  # @return [String]
  def self.script; end
end

# 스크립트 파일 읽기와 출력 (Lua 는 전역 함수, Ruby 는 받는 쪽 없이 부르는 Kernel 메서드)
module Kernel
  # Ruby 파일을 매번 다시 읽어 실행한다. 실패하면 예외 (Lua 의 LoadScript 에 해당)
  # @param [String] path
  # @return [Boolean]
  def load(path); end

  # Ruby 파일을 한 번만 읽는다. 새로 읽었으면 true
  # @param [String] path 작업 디렉터리 기준, .rb 는 붙여 준다
  # @return [Boolean]
  def require(path); end
end

# 키보드, 마우스, 멀티터치 입력 (고정 스텝마다 상태를 읽는다)
module Input
  # 이번 틱에 눌렸는가
  # @param [Integer, Symbol] key 가상 키 코드 (Ruby 는 Keys 상수 이름 Symbol 도 된다)
  # @return [Boolean]
  def self.key_down?(key); end

  # 이번 틱에 떼었는가
  # @param [Integer, Symbol] key 가상 키 코드 (Ruby 는 Keys 상수 이름 Symbol 도 된다)
  # @return [Boolean]
  def self.key_up?(key); end

  # 눌린 채로 있는가
  # @param [Integer, Symbol] key 가상 키 코드 (Ruby 는 Keys 상수 이름 Symbol 도 된다)
  # @return [Boolean]
  def self.key_press?(key); end

  # 이번 틱에 아무 키나 눌렸는가
  # @return [Boolean]
  def self.any_key_down?; end

  # key_down? 의 RGSS 식 별명 (눌린 순간)
  # @param [Integer, Symbol] key 가상 키 코드 (Ruby 는 Keys 상수 이름 Symbol 도 된다)
  # @return [Boolean]
  # @see key_down?
  def self.trigger?(key); end

  # key_press? 의 RGSS 식 별명 (눌린 채)
  # @param [Integer, Symbol] key 가상 키 코드 (Ruby 는 Keys 상수 이름 Symbol 도 된다)
  # @return [Boolean]
  # @see key_press?
  def self.press?(key); end

  # key_up? 의 RGSS 식 별명 (뗀 순간)
  # @param [Integer, Symbol] key 가상 키 코드 (Ruby 는 Keys 상수 이름 Symbol 도 된다)
  # @return [Boolean]
  # @see key_up?
  def self.release?(key); end

  # 마우스 x (논리 좌표)
  # @return [Numeric]
  def self.mouse_x; end

  # 마우스 y (논리 좌표)
  # @return [Numeric]
  def self.mouse_y; end

  # 이번 틱에 마우스 버튼이 눌렸는가
  # @param [Integer, Symbol] button 0 왼쪽, 1 오른쪽, 2 가운데 (Ruby 는 :left, :right, :middle 도 된다)
  # @return [Boolean]
  def self.mouse_down?(button); end

  # 이번 틱에 마우스 버튼을 떼었는가
  # @param [Integer, Symbol] button 0 왼쪽, 1 오른쪽, 2 가운데 (Ruby 는 :left, :right, :middle 도 된다)
  # @return [Boolean]
  def self.mouse_up?(button); end

  # 마우스 버튼이 눌린 채로 있는가
  # @param [Integer, Symbol] button 0 왼쪽, 1 오른쪽, 2 가운데 (Ruby 는 :left, :right, :middle 도 된다)
  # @return [Boolean]
  def self.mouse_press?(button); end

  # 이번 틱에 아무 마우스 버튼이나 눌렸는가
  # @return [Boolean]
  def self.any_mouse_down?; end

  # 마우스 휠 값 (올림과 내림을 -1 과 1 로)
  # @return [Integer]
  def self.mouse_z; end

  # 마우스 휠 값을 정한다
  # @param [Integer] wheel
  # @return [void]
  def self.mouse_z=(wheel); end

  # 이번 틱에 보이는 손가락 수 (뗀 손가락도 한 틱 보인다, GDI 는 언제나 0)
  # @return [Integer]
  def self.touch_count; end

  # 손가락 하나의 id, x, y, 단계(down, press, up). 범위 밖이면 nil
  # @param [Integer] index Lua 는 1 부터, Ruby 는 0 부터
  # @return [Array, nil]
  def self.touch(index); end

  # 이번 틱의 손가락 전부 ([id, x, y, 단계] 의 배열)
  # @return [Array<Array>]
  def self.touches; end
end

# 배경 음악과 효과음 (SDL_mixer, 파일은 재생할 때 읽고 id 로 찾는다)
module Audio
  # 음악 파일을 읽어 배경 음악으로 튼다 (Lua 는 loop 까지 셋 다 줘야 한다)
  # @param [String] path
  # @param [String] id
  # @param [Boolean, Integer] loop true 무한 반복, false 한 번, 숫자는 SDL_mixer 루프 값 그대로, 기본값 true
  # @return [Boolean]
  def self.play_music(path, id, loop = true); end

  # 효과음 파일을 읽어 튼다 (Lua 는 loop 까지 셋 다 줘야 한다)
  # @param [String] path
  # @param [String] id
  # @param [Boolean, Integer] loop true 무한 반복, false 한 번, 숫자는 SDL_mixer 루프 값 그대로, 기본값 false
  # @return [Boolean]
  def self.play_sound(path, id, loop = false); end

  # 배경 음악 볼륨을 정한다 (0..255 를 SDL_mixer 의 0..128 로 바꾼다)
  # @param [Integer] volume 0 에서 255
  # @return [void]
  def self.volume=(volume); end

  # 배경 음악 볼륨 (SDL_mixer 의 0..128)
  # @return [Integer]
  def self.volume; end

  # 지금 곡이 끝나면 이어서 틀 음악을 예약한다 (Lua 는 loop 까지 셋 다 줘야 한다)
  # @param [String] path
  # @param [String] id
  # @param [Boolean, Integer] loop true 무한 반복, false 한 번, 숫자는 SDL_mixer 루프 값 그대로, 기본값 true
  # @return [Boolean]
  def self.insert_next_music(path, id, loop = true); end

  # 배경 음악을 잠시 멈춘다
  # @return [void]
  def self.pause_music; end

  # 배경 음악을 멈춘다
  # @return [void]
  def self.stop_music; end

  # 잠시 멈춘 배경 음악을 잇는다
  # @return [void]
  def self.resume_music; end

  # 배경 음악이 나오고 있는가
  # @return [Boolean]
  def self.playing_music?; end

  # 배경 음악을 ms 동안 줄이며 끈다
  # @param [Integer] ms
  # @return [void]
  def self.fade_out_music(ms); end

  # 배경 음악의 재생 위치(초)를 옮긴다
  # @param [Numeric] seconds
  # @return [void]
  def self.music_position=(seconds); end

  # 읽어 둔 음악을 메모리에서 놓는다
  # @param [String] id
  # @return [void]
  def self.release_music(id); end
end

# JSON 읽기 (객체는 표나 Hash, 배열은 배열, null 은 nil)
module Json
  # JSON 파일을 읽는다. 실패하면 Lua 는 nil 과 메시지, Ruby 는 RuntimeError
  # @param [String] path
  # @return [Object]
  def self.load(path); end

  # JSON 문자열을 바로 읽는다. 실패하면 RuntimeError
  # @param [String] text
  # @return [Object]
  def self.parse(text); end
end

# 텍스처 캐시 (이미지를 id 로 등록하고 스프라이트가 id 로 찾는다)
module TextureManager
  # 이미지 파일을 읽어 id 로 등록한다
  # @param [String] path
  # @param [String] id
  # @return [Boolean]
  def self.load(path, id); end

  # id 의 텍스처를 놓는다
  # @param [String] id
  # @return [Boolean]
  def self.remove(id); end

  # id 로 등록된 텍스처가 있는가
  # @param [String] id
  # @return [Boolean]
  def self.valid?(id); end
end

# 가상 키 상수 (Windows 가상 키 값, Input 이 Symbol 을 받을 때 여기서 찾는다)
module Keys
  BACK = 8
  BACKSPACE = 8
  TAB = 9
  RETURN = 13
  ENTER = 13
  SHIFT = 16
  CONTROL = 17
  CTRL = 17
  MENU = 18
  ALT = 18
  PAUSE = 19
  ESCAPE = 27
  ESC = 27
  SPACE = 32
  PAGE_UP = 33
  PAGE_DOWN = 34
  self::END = 35
  HOME = 36
  LEFT = 37
  UP = 38
  RIGHT = 39
  DOWN = 40
  INSERT = 45
  DELETE = 46
  DIGIT0 = 48
  NUMPAD0 = 96
  DIGIT1 = 49
  NUMPAD1 = 97
  DIGIT2 = 50
  NUMPAD2 = 98
  DIGIT3 = 51
  NUMPAD3 = 99
  DIGIT4 = 52
  NUMPAD4 = 100
  DIGIT5 = 53
  NUMPAD5 = 101
  DIGIT6 = 54
  NUMPAD6 = 102
  DIGIT7 = 55
  NUMPAD7 = 103
  DIGIT8 = 56
  NUMPAD8 = 104
  DIGIT9 = 57
  NUMPAD9 = 105
  A = 65
  B = 66
  C = 67
  D = 68
  E = 69
  F = 70
  G = 71
  H = 72
  I = 73
  J = 74
  K = 75
  L = 76
  M = 77
  N = 78
  O = 79
  P = 80
  Q = 81
  R = 82
  S = 83
  T = 84
  U = 85
  V = 86
  W = 87
  X = 88
  Y = 89
  Z = 90
  F1 = 112
  F2 = 113
  F3 = 114
  F4 = 115
  F5 = 116
  F6 = 117
  F7 = 118
  F8 = 119
  F9 = 120
  F10 = 121
  F11 = 122
  F12 = 123
end

# 텍스처 한 장을 그리는 스프라이트 (시트 애니메이션, 회전, 확대, 투명도)
class Sprite
  # 스프라이트를 만든다. 텍스처는 TextureManager 에 먼저 올려 둔다 (Lua 는 인자가 모자라면 0)
  # @param [Numeric] x
  # @param [Numeric] y
  # @param [Integer] width
  # @param [Integer] height
  # @param [Integer] max_frames
  # @param [String] texture_id TextureManager 에 올린 id
  def initialize(x, y, width, height, max_frames, texture_id); end

  # 텍스처를 읽고 스프라이트를 만든다 (Lua 의 scripts/lua/image.lua 에 해당). 실패하면 RuntimeError
  # @param [String] path
  # @param [String] id
  # @param [Numeric] x 기본값 0
  # @param [Numeric] y 기본값 0
  # @param [Integer] width 기본값 0
  # @param [Integer] height 기본값 0
  # @param [Integer] frames 기본값 1
  # @return [Sprite]
  def self.load(path, id, x = 0, y = 0, width = 0, height = 0, frames = 1); end

  # 애니메이션을 경과 시간만큼 넘기고 변환을 확정한다
  # @param [Numeric] elapsed ms
  # @return [Sprite]
  def update(elapsed); end

  # 화면에 그린다
  # @return [Sprite]
  def draw; end

  # 위치 (x, y)
  # @return [Array<Numeric>]
  def position; end

  # x 좌표
  # @return [Numeric]
  def x; end

  # y 좌표
  # @return [Numeric]
  def y; end

  # 위치를 옮긴다
  # @param [Numeric] x
  # @param [Numeric] y
  # @return [Sprite]
  def set_position(x, y); end

  # x 만 옮긴다
  # @param [Numeric] x
  # @return [void]
  def x=(x); end

  # y 만 옮긴다
  # @param [Numeric] y
  # @return [void]
  def y=(y); end

  # [x, y] 로 옮긴다
  # @param [Array<Numeric>] pair [x, y]
  # @return [void]
  def position=(pair); end

  # 확대 배율
  # @return [Numeric]
  def scale; end

  # 확대 배율을 정한다
  # @param [Numeric] scale
  # @return [void]
  def scale=(scale); end

  # 한 프레임의 가로 픽셀
  # @return [Integer]
  def width; end

  # 한 프레임의 세로 픽셀
  # @return [Integer]
  def height; end

  # 회전 각도(도)
  # @return [Numeric]
  def angle; end

  # 회전 각도(도)를 정한다
  # @param [Numeric] degrees
  # @return [void]
  def angle=(degrees); end

  # 회전 각도(라디안)
  # @return [Numeric]
  def radians; end

  # 회전 각도(라디안)를 정한다
  # @param [Numeric] radians
  # @return [void]
  def radians=(radians); end

  # 보이는가
  # @return [Boolean]
  def visible?; end

  # 보일지 정한다
  # @param [Boolean] visible
  # @return [void]
  def visible=(visible); end

  # 불투명도 (0..255)
  # @return [Integer]
  def opacity; end

  # 불투명도를 정한다
  # @param [Integer] opacity 0 에서 255
  # @return [void]
  def opacity=(opacity); end

  # 프레임 사이 시간(ms)
  # @return [Numeric]
  def frame_delay; end

  # 프레임 사이 시간을 정한다
  # @param [Numeric] delay ms
  # @return [void]
  def frame_delay=(delay); end

  # 애니메이션 프레임 범위를 정한다 (둘째 인자는 끝의 다음)
  # @param [Integer] first
  # @param [Integer] last 끝의 다음 프레임 번호
  # @return [Sprite]
  def set_frames(first, last); end

  # 애니메이션 첫 프레임
  # @return [Integer]
  def start_frame; end

  # 애니메이션 마지막 프레임
  # @return [Integer]
  def end_frame; end

  # 지금 프레임
  # @return [Integer]
  def current_frame; end

  # 지금 프레임을 정한다
  # @param [Integer] frame
  # @return [void]
  def current_frame=(frame); end

  # 애니메이션을 되풀이할지 정한다
  # @param [Boolean] loop
  # @return [void]
  def loop=(loop); end

  # 애니메이션이 끝났는가
  # @return [Boolean]
  def anim_complete?; end

  # 애니메이션 끝 표시를 정한다
  # @param [Boolean] complete
  # @return [void]
  def anim_complete=(complete); end

  # 시트 분할을 정한다 (기본 4x4, R2K3 CharSet 은 3x4)
  # @param [Integer] cols
  # @param [Integer] rows
  # @return [Sprite]
  def set_sheet_grid(cols, rows); end

  # 소스 사각형. Lua 는 width, height 칸에 오른쪽, 아래 좌표를 담고, Ruby 는 x, y, right, bottom, width, height 를 이름대로 준다
  # @return [Hash]
  def rect; end

  # 텍스처에서 잘라 그릴 소스 사각형을 정한다 (x, y, width, height 를 가진 표 하나로도 된다)
  # @param [Integer] x
  # @param [Integer] y
  # @param [Integer] width
  # @param [Integer] height
  # @overload set_rect(rect)
  #   @param [Hash] rect x, y, width, height
  # @return [Sprite]
  def set_rect(x, y, width, height); end

  # 스프라이트를 놓는다. 텍스처는 함께 놓지 않는다
  # @return [void]
  def dispose; end

  # 이미 놓았는가 (놓은 뒤에 쓰면 RuntimeError)
  # @return [Boolean]
  def disposed?; end
end

# 맵 포맷 v1, v2 JSON 을 읽어 그리는 다층 타일맵 (x, y 는 0 기준 타일 좌표)
class Tilemap
  # 맵 파일을 읽는다. 실패하면 nil (Lua 는 오류 메시지도 함께)
  # @param [String] path
  # @return [Tilemap, nil]
  def self.load(path); end

  # 맵 파일을 읽는다. 실패하면 RuntimeError (메시지는 로더의 오류)
  # @param [String] path
  def initialize(path); end

  # 레이어 범위를 카메라 오프셋과 함께 그린다 (보이는 타일만)
  # @param [Integer] layer_from Lua 는 1 부터, Ruby 는 0 부터
  # @param [Integer] layer_to 양 끝 포함
  # @param [Integer] cam_x 월드 픽셀, 기본값 0
  # @param [Integer] cam_y 월드 픽셀, 기본값 0
  # @return [Tilemap]
  def draw(layer_from, layer_to, cam_x = 0, cam_y = 0); end

  # 가로 타일 수, 세로 타일 수, 타일 가로 픽셀, 타일 세로 픽셀, 레이어 수
  # @return [Array<Integer>]
  def size; end

  # 가로 타일 수
  # @return [Integer]
  def width; end

  # 세로 타일 수
  # @return [Integer]
  def height; end

  # 타일 한 칸의 가로 픽셀
  # @return [Integer]
  def tile_width; end

  # 타일 한 칸의 세로 픽셀
  # @return [Integer]
  def tile_height; end

  # 레이어 수
  # @return [Integer]
  def layer_count; end

  # 타일 gid (빈 칸과 범위 밖은 0)
  # @param [Integer] x
  # @param [Integer] y
  # @param [Integer] layer Lua 는 1 부터, Ruby 는 0 부터
  # @return [Integer]
  def tile_id(x, y, layer); end

  # 타일 gid 를 바꾼다. 범위 밖이면 false
  # @param [Integer] x
  # @param [Integer] y
  # @param [Integer] layer Lua 는 1 부터, Ruby 는 0 부터
  # @param [Integer] gid
  # @return [Boolean]
  def set_tile_id(x, y, layer, gid); end

  # 지나갈 수 있는 칸인가 (범위 밖은 false)
  # @param [Integer] x
  # @param [Integer] y
  # @return [Boolean]
  def passable?(x, y); end

  # 맵을 놓는다. 타일셋 텍스처는 TextureManager 에 남는다
  # @return [void]
  def dispose; end

  # 이미 놓았는가 (놓은 뒤에 쓰면 RuntimeError)
  # @return [Boolean]
  def disposed?; end
end

# 시스템 폰트로 글자 텍스처를 만드는 동적 폰트 (Windows 전용, macOS 와 Android 는 무동작 스텁)
class FontEx
  # 폰트 이름과 크기, 텍스처 크기로 만든다 (Lua 는 인자가 모자라면 0)
  # @param [String] face 폰트 이름
  # @param [Integer] size
  # @param [Integer] width
  # @param [Integer] height
  def initialize(face, size, width, height); end

  # 갱신한다 (지금은 하는 일이 없다)
  # @param [Numeric] elapsed ms
  # @return [FontEx]
  def update(elapsed); end

  # 화면에 그린다
  # @return [FontEx]
  def draw; end

  # 그릴 글자를 정한다
  # @param [String] text
  # @return [void]
  def text=(text); end

  # 위치를 정한다
  # @param [Integer] x
  # @param [Integer] y
  # @return [FontEx]
  def set_position(x, y); end

  # 글자 색을 정한다
  # @param [Integer] r
  # @param [Integer] g
  # @param [Integer] b
  # @return [FontEx]
  def set_text_color(r, g, b); end

  # 불투명도를 정한다
  # @param [Integer] opacity 0 에서 255
  # @return [void]
  def opacity=(opacity); end

  # 회전 각도(도)를 정한다
  # @param [Numeric] degrees
  # @return [void]
  def angle=(degrees); end

  # 글자의 픽셀 폭을 잰다
  # @param [String] text
  # @return [Integer]
  def text_width(text); end

  # 폰트를 놓는다
  # @return [void]
  def dispose; end

  # 이미 놓았는가 (놓은 뒤에 쓰면 RuntimeError)
  # @return [Boolean]
  def disposed?; end
end
