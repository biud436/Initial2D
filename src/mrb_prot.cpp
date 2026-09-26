/**
 * @file mrb_prot.cpp
 * @brief mruby VM 의 수명과 전역 모듈 (S1, docs/plans/s1-mruby-binding.md).
 *
 * lua_prot.cpp 에 대응한다. 진입 파일은 ./scripts/ruby/main.rb 이고 (Lua 는 scripts/lua/,
 * Ruby 는 scripts/ruby/ 로 폴더를 나눈다), 씬 계약은
 * 최상위 메서드 넷이다.
 *
 *   def init; end            # Lua 의 Initialize
 *   def update(elapsed); end # 고정 스텝, elapsed 는 ms
 *   def render; end
 *   def destroy; end
 *
 * 없는 메서드는 부르지 않는다 (테스트 러너처럼 init 만 있어도 된다).
 * 예외가 새어 나오면 메시지와 역추적을 stderr 에 찍고 게임을 끝낸다.
 * Lua 쪽의 lua_call 이 오류에 그대로 멈추는 것과 같은 정책이며, 종료 코드는
 * 1 이 되어 검수 러너가 실패를 잡는다.
 *
 * 이 파일이 정의하는 것:
 *   Graphics  창 크기, 렌더 배율, 비트맵 폰트 글자 그리기와 폭 재기, 점 찍기
 *   System    플랫폼 이름, 종료, 현재 디렉터리, 리소스 목록, 메시지 상자, 환경 변수
 *   Keys      가상 키 상수 (Input 이 Symbol 을 받을 때 여기서 찾는다)
 *   Kernel#load, Kernel#require   (mruby 에는 파일 읽기가 없다)
 *   프렐류드  Ruby 로 쓰는 편의 메서드 (Sprite.load 등)
 */
#include "Constants.h"

#ifdef INITIAL2D_HAS_MRUBY

#include "mrb_prot.h"

#include "App.h"
#include "Encrypt.h"
#include "Font.h"
#include "TextureManager.h"

#ifdef RS_WINDOWS
#include <Windows.h>
#else
#include <SDL.h>
#include "platform/Utf8.h"
#endif

#include <algorithm>
#include <cctype>
#include <cstdio>
#include <cstdlib>
#include <filesystem>
#include <set>
#include <string>
#include <vector>

mrb_state* g_pMrbState = nullptr;

namespace
{
	bool s_failed = false;   // 예외로 게임을 끝냈다
	bool s_halted = false;   // 그 뒤로는 훅을 부르지 않는다
	std::set<std::string> s_required;

	mrb_sym s_symInit = 0;
	mrb_sym s_symUpdate = 0;
	mrb_sym s_symRender = 0;
	mrb_sym s_symDestroy = 0;

	// 스크립트 예외를 보고하고 게임을 끝낸다. mrb->exc 는 비운다.
	void ReportError(mrb_state* mrb, const char* where)
	{
		if (mrb->exc == nullptr)
		{
			return;
		}
		std::fprintf(stderr, "mruby: uncaught exception in %s\n", where);
		std::fflush(stdout);
		mrb_print_error(mrb);
		std::fflush(stderr);
		mrb->exc = nullptr;
		s_failed = true;
		s_halted = true;
		App::GetInstance().Quit();
	}

	// 파일을 읽어 실행한다. 실패하면 Ruby 예외를 일으킨다 (호출자가 Ruby 안이면
	// rescue 로 잡히고, C++ 이면 mrb->exc 에 남는다).
	mrb_value LoadFileOrRaise(mrb_state* mrb, const std::string& path)
	{
		FILE* fp = std::fopen(path.c_str(), "rb");
		if (fp == nullptr)
		{
			mrb_raisef(mrb, E_RUNTIME_ERROR, "cannot open script: %s", path.c_str());
		}

		mrb_ccontext* cxt = mrb_ccontext_new(mrb);
		mrb_ccontext_filename(mrb, cxt, path.c_str());
		const mrb_value result = mrb_load_file_cxt(mrb, fp, cxt);
		mrb_ccontext_free(mrb, cxt);
		std::fclose(fp);

		if (mrb->exc != nullptr)
		{
			// 중첩 실행에서 새어 나온 예외를 호출자 쪽으로 다시 던진다
			mrb_value exc = mrb_obj_value(mrb->exc);
			mrb->exc = nullptr;
			mrb_exc_raise(mrb, exc);
		}
		return result;
	}

	std::string NormalizeScriptPath(std::string path)
	{
		std::replace(path.begin(), path.end(), '\\', '/');
		return path;
	}

	// ------------------------------------------------------------------
	// Kernel#load(path) / Kernel#require(path)
	// ------------------------------------------------------------------

	/** load("scripts/lua/foo.rb"). 매번 다시 읽는다. Lua 의 LoadScript 에 해당. */
	mrb_value kernel_load(mrb_state* mrb, mrb_value self)
	{
		const char* path = nullptr;
		mrb_get_args(mrb, "z", &path);
		LoadFileOrRaise(mrb, NormalizeScriptPath(path));
		return mrb_true_value();
	}

	/**
	 * require("scripts/lua/games/flappy"). 한 번만 읽는다. ".rb" 가 없으면 붙인다.
	 * 경로는 작업 디렉터리 기준이며 (Lua 의 require("scripts/...") 와 같은 관례),
	 * 절대 경로로 정규화해 같은 파일을 두 번 읽지 않는다. 새로 읽었으면 true.
	 */
	mrb_value kernel_require(mrb_state* mrb, mrb_value self)
	{
		const char* raw = nullptr;
		mrb_get_args(mrb, "z", &raw);

		std::string path = NormalizeScriptPath(raw);
		if (path.size() < 3 || path.compare(path.size() - 3, 3, ".rb") != 0)
		{
			path += ".rb";
		}

		std::error_code ec;
		std::filesystem::path abs = std::filesystem::absolute(path, ec);
		const std::string key = ec ? path : abs.lexically_normal().string();
		if (s_required.count(key) != 0)
		{
			return mrb_false_value();
		}

		LoadFileOrRaise(mrb, path);
		s_required.insert(key);
		return mrb_true_value();
	}

	// ------------------------------------------------------------------
	// Graphics
	// ------------------------------------------------------------------

	mrb_value gfx_width(mrb_state* mrb, mrb_value)
	{
		return mrb_int_value(mrb, App::GetInstance().GetWindowWidth());
	}

	mrb_value gfx_height(mrb_state* mrb, mrb_value)
	{
		return mrb_int_value(mrb, App::GetInstance().GetWindowHeight());
	}

	mrb_value gfx_render_scale(mrb_state* mrb, mrb_value)
	{
		return mrb_int_value(mrb, App::GetInstance().GetRenderScale());
	}

	/** Graphics.render_scale = n. 창은 그대로, 논리 해상도만 1/n (Lua 의 SetRenderScale). */
	mrb_value gfx_set_render_scale(mrb_state* mrb, mrb_value)
	{
		mrb_int scale = 1;
		mrb_get_args(mrb, "i", &scale);
		App::GetInstance().SetRenderScale(static_cast<int>(scale));
		return mrb_int_value(mrb, App::GetInstance().GetRenderScale());
	}

	mrb_value gfx_frame_count(mrb_state* mrb, mrb_value)
	{
		return mrb_int_value(mrb, App::GetInstance().GetFrameCount());
	}

	/** Graphics.prepare_font("./resources/fonts/hangul.fnt") -> true/false */
	mrb_value gfx_prepare_font(mrb_state* mrb, mrb_value)
	{
		const char* path = nullptr;
		mrb_get_args(mrb, "z", &path);
		return mrb_bool_value(App::GetInstance().LoadFont(path));
	}

	std::wstring ToWide(const std::string& utf8)
	{
#ifdef RS_WINDOWS
		const int length = MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(), -1, NULL, 0);
		std::wstring wide(length > 0 ? length - 1 : 0, L'\0');
		if (length > 1)
		{
			MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(), -1, &wide[0], length);
		}
		return wide;
#else
		return Initial2D::Platform::Utf8ToWide(utf8);
#endif
	}

	/** Graphics.draw_text(x, y, text) -> 그린 픽셀 폭. 폰트가 없으면 0. */
	mrb_value gfx_draw_text(mrb_state* mrb, mrb_value)
	{
		mrb_float x = 0, y = 0;
		mrb_value text;
		mrb_get_args(mrb, "ffS", &x, &y, &text);

		GameFont* pFont = App::GetInstance().GetFont();
		if (pFont == nullptr || pFont->get() == nullptr || !pFont->get()->isValid())
		{
			return mrb_int_value(mrb, 0);
		}
		const std::wstring wide = ToWide(MRuby_ToStdString(mrb, text));
		const int width = pFont->get()->drawText(static_cast<int>(x), static_cast<int>(y), wide);
		return mrb_int_value(mrb, width);
	}

	/** Graphics.text_width(text) -> 그리지 않고 잰 픽셀 폭. */
	mrb_value gfx_text_width(mrb_state* mrb, mrb_value)
	{
		mrb_value text;
		mrb_get_args(mrb, "S", &text);

		GameFont* pFont = App::GetInstance().GetFont();
		if (pFont == nullptr || pFont->get() == nullptr || !pFont->get()->isValid())
		{
			return mrb_int_value(mrb, 0);
		}
		const std::wstring wide = ToWide(MRuby_ToStdString(mrb, text));
		return mrb_int_value(mrb, pFont->get()->getTextWidth(0, 0, wide));
	}

	/** Graphics.set_color(r, g, b, a = 255). draw_point 의 색. */
	mrb_value gfx_set_color(mrb_state* mrb, mrb_value)
	{
		mrb_int r = 0, g = 0, b = 0, a = 255;
		mrb_get_args(mrb, "iii|i", &r, &g, &b, &a);
		App::GetInstance().GetTextureManager().SetBitmapColor(
			static_cast<BYTE>(r), static_cast<BYTE>(g), static_cast<BYTE>(b), static_cast<BYTE>(a));
		return mrb_nil_value();
	}

	/** Graphics.draw_point(x, y) */
	mrb_value gfx_draw_point(mrb_state* mrb, mrb_value)
	{
		mrb_int x = 0, y = 0;
		mrb_get_args(mrb, "ii", &x, &y);
		App::GetInstance().GetTextureManager().DrawPoint(static_cast<int>(x), static_cast<int>(y));
		return mrb_nil_value();
	}

	// ------------------------------------------------------------------
	// System
	// ------------------------------------------------------------------

	/** System.platform -> "macos" | "windows" | "linux" | "android" | "ios" | 그 밖의 소문자 */
	mrb_value sys_platform(mrb_state* mrb, mrb_value)
	{
#ifdef RS_WINDOWS
		return mrb_str_new_cstr(mrb, "windows");
#else
		std::string name = SDL_GetPlatform();
		if (name == "Mac OS X") name = "macos";
		else if (name == "Windows") name = "windows";
		else if (name == "Linux") name = "linux";
		else if (name == "Android") name = "android";
		else if (name == "iOS") name = "ios";
		else std::transform(name.begin(), name.end(), name.begin(), ::tolower);
		return mrb_str_new_cstr(mrb, name.c_str());
#endif
	}

	/** System.exit. 이번 프레임을 마치고 게임을 끝낸다 (Lua 의 GameExit). */
	mrb_value sys_exit(mrb_state* mrb, mrb_value)
	{
		App::GetInstance().Quit();
		return mrb_nil_value();
	}

	/** System.current_directory -> 구분자를 '/' 로 맞춘 작업 디렉터리 */
	mrb_value sys_current_directory(mrb_state* mrb, mrb_value)
	{
		std::error_code ec;
		std::string s = std::filesystem::current_path(ec).string();
		std::replace(s.begin(), s.end(), '\\', '/');
		return mrb_str_new_cstr(mrb, s.c_str());
	}

	/** System.resource_files -> ./resources 바로 아래의 파일 이름 배열 */
	mrb_value sys_resource_files(mrb_state* mrb, mrb_value)
	{
		std::vector<std::string> dirs;
		Initial2D::ReadDirectory(dirs, std::string(".\\resources\\*.*"));

		mrb_value array = mrb_ary_new(mrb);
		for (const std::string& name : dirs)
		{
			mrb_ary_push(mrb, array, mrb_str_new_cstr(mrb, name.c_str()));
		}
		return array;
	}

	/** System.message_box(text, caption = "") */
	mrb_value sys_message_box(mrb_state* mrb, mrb_value)
	{
		const char* text = "";
		const char* caption = "";
		mrb_get_args(mrb, "z|z", &text, &caption);
#ifdef RS_WINDOWS
		MessageBoxW(nullptr, ToWide(text).c_str(), ToWide(caption).c_str(), MB_OK);
#else
		SDL_ShowSimpleMessageBox(SDL_MESSAGEBOX_INFORMATION, caption, text,
			App::GetInstance().GetWindowHandle());
#endif
		return mrb_nil_value();
	}

	/** System.app_icon = "./resources/icons/icon.png" */
	mrb_value sys_set_app_icon(mrb_state* mrb, mrb_value)
	{
		const char* path = nullptr;
		mrb_get_args(mrb, "z", &path);
		App::GetInstance().SetAppIcon(path);
		return mrb_nil_value();
	}

	/** System.env("INITIAL2D_SCENE") -> String | nil (mruby 에는 ENV 가 없다) */
	mrb_value sys_env(mrb_state* mrb, mrb_value)
	{
		const char* name = nullptr;
		mrb_get_args(mrb, "z", &name);
		const char* value = std::getenv(name);
		if (value == nullptr)
		{
			return mrb_nil_value();
		}
		return mrb_str_new_cstr(mrb, value);
	}

	/** System.script -> "mruby" (Lua 에서 같은 이름은 없다. 문서와 테스트가 쓴다) */
	mrb_value sys_script(mrb_state* mrb, mrb_value)
	{
		return mrb_str_new_cstr(mrb, "mruby");
	}

	// ------------------------------------------------------------------
	// Keys. Windows 가상 키 값. SDL 스캔코드도 이 값으로 변환된다 (ScancodeMap).
	// ------------------------------------------------------------------

	void DefineKeys(mrb_state* mrb)
	{
		struct RClass* keys = mrb_define_module(mrb, "Keys");
		struct Entry { const char* name; int code; };
		static const Entry entries[] = {
			{ "BACK", 8 }, { "BACKSPACE", 8 }, { "TAB", 9 },
			{ "RETURN", 13 }, { "ENTER", 13 },
			{ "SHIFT", 16 }, { "CONTROL", 17 }, { "CTRL", 17 }, { "MENU", 18 }, { "ALT", 18 },
			{ "PAUSE", 19 }, { "ESCAPE", 27 }, { "ESC", 27 }, { "SPACE", 32 },
			{ "PAGE_UP", 33 }, { "PAGE_DOWN", 34 }, { "END", 35 }, { "HOME", 36 },
			{ "LEFT", 37 }, { "UP", 38 }, { "RIGHT", 39 }, { "DOWN", 40 },
			{ "INSERT", 45 }, { "DELETE", 46 },
		};
		for (const Entry& e : entries)
		{
			mrb_define_const(mrb, keys, e.name, mrb_int_value(mrb, e.code));
		}

		char name[16];
		for (int i = 0; i < 10; ++i)
		{
			std::snprintf(name, sizeof(name), "DIGIT%d", i);
			mrb_define_const(mrb, keys, name, mrb_int_value(mrb, 48 + i));
			std::snprintf(name, sizeof(name), "NUMPAD%d", i);
			mrb_define_const(mrb, keys, name, mrb_int_value(mrb, 96 + i));
		}
		for (int i = 0; i < 26; ++i)
		{
			std::snprintf(name, sizeof(name), "%c", 'A' + i);
			mrb_define_const(mrb, keys, name, mrb_int_value(mrb, 65 + i));
		}
		for (int i = 1; i <= 12; ++i)
		{
			std::snprintf(name, sizeof(name), "F%d", i);
			mrb_define_const(mrb, keys, name, mrb_int_value(mrb, 111 + i));
		}
	}

	// ------------------------------------------------------------------
	// 프렐류드. C 로 만들 이유가 없는 편의 메서드는 Ruby 로 둔다
	// ------------------------------------------------------------------

	const char* const PRELUDE = R"RUBY(
module Input
  # 이번 틱의 손가락 전부. 각 원소는 [id, x, y, phase] (phase 는 :down, :press, :up)
  def self.touches
    (0...touch_count).map { |i| touch(i) }
  end
end

class Sprite
  # 텍스처를 읽고 스프라이트를 만든다. Lua 의 scripts/lua/image.lua 에 해당한다.
  # 텍스처는 TextureManager 가 갖고 있으므로 다 쓴 뒤 TextureManager.remove(id) 로 놓는다.
  def self.load(path, id, x = 0, y = 0, width = 0, height = 0, frames = 1)
    raise "TextureManager.load failed: #{path}" unless TextureManager.load(path, id)
    new(x, y, width, height, frames, id)
  end

  def x=(value)
    set_position(value, y)
  end

  def y=(value)
    set_position(x, value)
  end

  def position=(pair)
    set_position(pair[0], pair[1])
  end
end

class Tilemap
  # 실패하면 예외 대신 nil
  def self.load(path)
    new(path)
  rescue RuntimeError
    nil
  end
end
)RUBY";

	// ------------------------------------------------------------------
	// 훅 호출
	// ------------------------------------------------------------------

	bool HasTopLevelMethod(mrb_state* mrb, mrb_sym sym)
	{
		return mrb_obj_respond_to(mrb, mrb->object_class, sym);
	}

	void CallHook(mrb_state* mrb, mrb_sym sym, const char* name, mrb_int argc, const mrb_value* argv)
	{
		if (s_halted || !HasTopLevelMethod(mrb, sym))
		{
			return;
		}
		const int arena = mrb_gc_arena_save(mrb);
		mrb_funcall_argv(mrb, mrb_top_self(mrb), sym, argc, argv);
		if (mrb->exc != nullptr)
		{
			ReportError(mrb, name);
		}
		mrb_gc_arena_restore(mrb, arena);
	}
}

// ----------------------------------------------------------------------
// 공용 도우미 (mrb_prot.h)
// ----------------------------------------------------------------------

std::string MRuby_ToStdString(mrb_state* mrb, mrb_value value)
{
	if (mrb_symbol_p(value))
	{
		mrb_int length = 0;
		const char* name = mrb_sym_name_len(mrb, mrb_symbol(value), &length);
		return std::string(name, static_cast<size_t>(length));
	}
	if (!mrb_string_p(value))
	{
		value = mrb_obj_as_string(mrb, value);
	}
	return std::string(RSTRING_PTR(value), static_cast<size_t>(RSTRING_LEN(value)));
}

int MRuby_ResolveLoop(mrb_state* mrb, mrb_value value, int onceValue)
{
	if (mrb_true_p(value))
	{
		return -1;
	}
	if (mrb_nil_p(value) || mrb_type(value) == MRB_TT_FALSE)
	{
		return onceValue;
	}
	return static_cast<int>(MRuby_ToInt(mrb, value));
}

mrb_int MRuby_ToInt(mrb_state* mrb, mrb_value value)
{
	if (mrb_integer_p(value))
	{
		return mrb_integer(value);
	}
	if (mrb_float_p(value))
	{
		return static_cast<mrb_int>(mrb_float(value));
	}
	mrb_raise(mrb, E_TYPE_ERROR, "expected an Integer or a Float");
	return 0;
}

bool MRuby_Failed()
{
	return s_failed;
}

// ----------------------------------------------------------------------
// VM 수명
// ----------------------------------------------------------------------

int MRuby_Init()
{
	s_failed = false;
	s_halted = false;
	s_required.clear();

	g_pMrbState = mrb_open();
	if (g_pMrbState == nullptr)
	{
		std::fprintf(stderr, "mruby: mrb_open failed\n");
		s_failed = true;
		App::GetInstance().Quit();
		return 1;
	}
	mrb_state* mrb = g_pMrbState;

	s_symInit = mrb_intern_lit(mrb, "init");
	s_symUpdate = mrb_intern_lit(mrb, "update");
	s_symRender = mrb_intern_lit(mrb, "render");
	s_symDestroy = mrb_intern_lit(mrb, "destroy");

	// Kernel
	mrb_define_method(mrb, mrb->kernel_module, "load", kernel_load, MRB_ARGS_REQ(1));
	mrb_define_method(mrb, mrb->kernel_module, "require", kernel_require, MRB_ARGS_REQ(1));

	// Graphics
	struct RClass* graphics = mrb_define_module(mrb, "Graphics");
	mrb_define_module_function(mrb, graphics, "width", gfx_width, MRB_ARGS_NONE());
	mrb_define_module_function(mrb, graphics, "height", gfx_height, MRB_ARGS_NONE());
	mrb_define_module_function(mrb, graphics, "render_scale", gfx_render_scale, MRB_ARGS_NONE());
	mrb_define_module_function(mrb, graphics, "render_scale=", gfx_set_render_scale, MRB_ARGS_REQ(1));
	mrb_define_module_function(mrb, graphics, "frame_count", gfx_frame_count, MRB_ARGS_NONE());
	mrb_define_module_function(mrb, graphics, "prepare_font", gfx_prepare_font, MRB_ARGS_REQ(1));
	mrb_define_module_function(mrb, graphics, "draw_text", gfx_draw_text, MRB_ARGS_REQ(3));
	mrb_define_module_function(mrb, graphics, "text_width", gfx_text_width, MRB_ARGS_REQ(1));
	mrb_define_module_function(mrb, graphics, "set_color", gfx_set_color, MRB_ARGS_ARG(3, 1));
	mrb_define_module_function(mrb, graphics, "draw_point", gfx_draw_point, MRB_ARGS_REQ(2));

	// System
	struct RClass* system = mrb_define_module(mrb, "System");
	mrb_define_module_function(mrb, system, "platform", sys_platform, MRB_ARGS_NONE());
	mrb_define_module_function(mrb, system, "exit", sys_exit, MRB_ARGS_NONE());
	mrb_define_module_function(mrb, system, "current_directory", sys_current_directory, MRB_ARGS_NONE());
	mrb_define_module_function(mrb, system, "resource_files", sys_resource_files, MRB_ARGS_NONE());
	mrb_define_module_function(mrb, system, "message_box", sys_message_box, MRB_ARGS_ARG(1, 1));
	mrb_define_module_function(mrb, system, "app_icon=", sys_set_app_icon, MRB_ARGS_REQ(1));
	mrb_define_module_function(mrb, system, "env", sys_env, MRB_ARGS_REQ(1));
	mrb_define_module_function(mrb, system, "script", sys_script, MRB_ARGS_NONE());

	DefineKeys(mrb);
	MRuby_DefineInput(mrb);
	MRuby_DefineAudio(mrb);
	MRuby_DefineJson(mrb);
	MRuby_DefineSprite(mrb);
	MRuby_DefineTextureManager(mrb);
	MRuby_DefineTilemap(mrb);
	MRuby_DefineFontEx(mrb);

	// 프렐류드 (C 정의 뒤에 얹는다)
	{
		mrb_ccontext* cxt = mrb_ccontext_new(mrb);
		mrb_ccontext_filename(mrb, cxt, "<prelude>");
		mrb_load_string_cxt(mrb, PRELUDE, cxt);
		mrb_ccontext_free(mrb, cxt);
		if (mrb->exc != nullptr)
		{
			ReportError(mrb, "prelude");
			return 1;
		}
	}

	// 진입 파일과 init 훅
	{
		const int arena = mrb_gc_arena_save(mrb);
		FILE* fp = std::fopen("./scripts/ruby/main.rb", "rb");
		if (fp == nullptr)
		{
			std::fprintf(stderr, "mruby: cannot open ./scripts/ruby/main.rb\n");
			s_failed = true;
			s_halted = true;
			App::GetInstance().Quit();
			return 1;
		}
		mrb_ccontext* cxt = mrb_ccontext_new(mrb);
		mrb_ccontext_filename(mrb, cxt, "scripts/ruby/main.rb");
		mrb_load_file_cxt(mrb, fp, cxt);
		mrb_ccontext_free(mrb, cxt);
		std::fclose(fp);
		mrb_gc_arena_restore(mrb, arena);
		if (mrb->exc != nullptr)
		{
			ReportError(mrb, "scripts/ruby/main.rb");
			return 1;
		}
	}

	CallHook(mrb, s_symInit, "init", 0, nullptr);
	return s_failed ? 1 : 0;
}

int MRuby_Update(double elapsed)
{
	if (g_pMrbState == nullptr)
	{
		return 0;
	}
	const mrb_value arg = mrb_float_value(g_pMrbState, static_cast<mrb_float>(elapsed));
	CallHook(g_pMrbState, s_symUpdate, "update", 1, &arg);
	return 0;
}

int MRuby_Render()
{
	if (g_pMrbState == nullptr)
	{
		return 0;
	}
	CallHook(g_pMrbState, s_symRender, "render", 0, nullptr);
	return 0;
}

int MRuby_Destroy()
{
	if (g_pMrbState == nullptr)
	{
		return 0;
	}
	CallHook(g_pMrbState, s_symDestroy, "destroy", 0, nullptr);

	// mrb_close 가 살아 있는 Sprite, Tilemap, FontEx 의 dfree 를 부른다.
	// TextureManager 보다 먼저라야 하며 (App::Destroy 의 순서), Lua 의 lua_close 와 같은 자리다.
	mrb_close(g_pMrbState);
	g_pMrbState = nullptr;
	s_required.clear();
	return 0;
}

#endif // INITIAL2D_HAS_MRUBY
