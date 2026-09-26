/**
 * @file mrb_prot.h
 * @brief mruby 바인딩의 공용 선언 (S1, docs/plans/s1-mruby-binding.md).
 *
 * lua_prot.h 에 대응한다. 모듈과 클래스는 파일 하나에 하나씩이다.
 *   mrb_prot.cpp     VM 수명, 프렐류드, Graphics / System / Keys, Kernel#load, #require
 *   mrb_input.cpp    Input
 *   mrb_audio.cpp    Audio
 *   mrb_json.cpp     Json
 *   mrb_sprite.cpp   Sprite (클래스)
 *   mrb_texture.cpp  TextureManager
 *   mrb_tilemap.cpp  Tilemap (클래스)
 *   mrb_font.cpp     FontEx (클래스)
 *
 * 이 헤더는 INITIAL2D_HAS_MRUBY 가 정의된 빌드에서만 의미가 있다.
 */
#ifndef _MRB_PROT_H__
#define _MRB_PROT_H__

#ifdef INITIAL2D_HAS_MRUBY

#include <mruby.h>
#include <mruby/array.h>
#include <mruby/class.h>
#include <mruby/compile.h>
#include <mruby/data.h>
#include <mruby/error.h>
#include <mruby/hash.h>
#include <mruby/string.h>
#include <mruby/variable.h>

#include <string>

#include "ExceptionText.h"

extern mrb_state* g_pMrbState;

/**
 * 바인딩 함수에서 나온 C++ 예외를 Ruby 의 RuntimeError("타입: 메시지")로 바꾼다.
 * 그래서 rescue 로 잡히고, C++ 예외가 VM 의 C 프레임을 지나가지 않는다.
 * 바인딩을 등록하는 mrb_define_* 는 전부 함수 대신 MRUBY_GUARD(함수) 를 넘긴다
 * (tests/run_engine_tests.py 의 test_mruby_binding_guard 가 확인한다).
 */
template <mrb_func_t F>
mrb_value MRuby_Guarded(mrb_state* mrb, mrb_value self)
{
	char message[512];
	try
	{
		return F(mrb, self);
	}
	catch (...)
	{
		Initial2D::DescribeCurrentException(message, sizeof(message));
	}
	// raise(longjmp)는 catch 블록을 벗어난 뒤에 한다. C++ 예외 객체는 이미 정리되었다
	mrb_raise(mrb, E_RUNTIME_ERROR, message);
	return mrb_nil_value();
}

#define MRUBY_GUARD(fn) (&MRuby_Guarded<fn>)

int MRuby_Init();
int MRuby_Update(double elapsed);
int MRuby_Render();
int MRuby_Destroy();

/** 스크립트 예외로 VM 이 멈췄는가 (ScriptRuntime 이 게임 종료와 종료 코드로 옮긴다). */
bool MRuby_Failed();

// 하위 바인딩. 각 mrb_*.cpp 가 자기 모듈이나 클래스를 정의한다
void MRuby_DefineInput(mrb_state* mrb);
void MRuby_DefineAudio(mrb_state* mrb);
void MRuby_DefineJson(mrb_state* mrb);
void MRuby_DefineSprite(mrb_state* mrb);
void MRuby_DefineTextureManager(mrb_state* mrb);
void MRuby_DefineTilemap(mrb_state* mrb);
void MRuby_DefineFontEx(mrb_state* mrb);

// 공용 도우미
/** String 이나 Symbol 을 UTF-8 std::string 으로. 그 밖의 값은 to_s 한다. */
std::string MRuby_ToStdString(mrb_state* mrb, mrb_value value);

/**
 * loop 인자를 SDL_mixer 루프 값으로 (lua_audio.cpp 의 ResolveLoopArg 와 같은 계약).
 * true = 무한(-1), false 나 nil = 한 번(onceValue), Integer = 그대로.
 */
int MRuby_ResolveLoop(mrb_state* mrb, mrb_value value, int onceValue);

/** Ruby 값을 정수로 (Integer 나 Float). 그 밖에는 TypeError. */
mrb_int MRuby_ToInt(mrb_state* mrb, mrb_value value);

#endif // INITIAL2D_HAS_MRUBY

#endif
