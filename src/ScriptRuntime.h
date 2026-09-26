/**
 * @file ScriptRuntime.h
 * @brief 스크립트 백엔드(Lua, mruby) 선택과 공용 진입점 (S1, docs/plans/s1-mruby-binding.md).
 *
 * 엔진 루프(main.cpp, AppSDL2.cpp)는 Lua_* 대신 여기의 Script_* 를 부른다.
 * 어느 언어로 게임을 쓸지는 다음 순서로 정한다.
 *   1. INITIAL2D_SCRIPT 환경 변수 ("lua" | "mruby")
 *   2. 프로젝트 루트 game.json 의 "script" 키
 *   3. scripts/ruby/main.rb 만 있고 scripts/lua/main.lua 가 없으면 mruby, 그 밖에는 lua
 *
 * Lua 스크립트는 scripts/lua/ 에, Ruby 스크립트는 scripts/ruby/ 에 둔다.
 *
 * mruby 는 빌드에 들어 있을 때만 쓸 수 있다 (CMake 가 libmruby 를 찾으면
 * INITIAL2D_HAS_MRUBY 를 정의한다). 없는데 고르면 오류를 내고 종료 코드 1로 끝난다.
 */
#ifndef _SCRIPT_RUNTIME_H__
#define _SCRIPT_RUNTIME_H__

#include <string>

enum class ScriptBackend
{
	Lua,
	MRuby
};

/** 선택된 백엔드. 처음 부를 때 결정하고 그 뒤로는 같은 값을 돌려준다 (핫 리로드 포함). */
ScriptBackend Script_Backend();
const char* Script_BackendName();

/**
 * 이 빌드가 실행할 수 있는 언어 목록 ("lua" 또는 "lua mruby"). `--features` 가 찍는다.
 * Emscripten 빌드는 끝에 " wasm" 이 붙는다 ("lua mruby wasm", mruby 없이 빌드하면 "lua wasm").
 * 에디터가 이것으로 브라우저 빌드와 쓸 수 있는 언어를 알아본다 (R3).
 */
std::string Script_Features();
bool Script_HasMRuby();

int Script_Init();
int Script_Update(double elapsed);
int Script_Render();
int Script_Destroy();

/**
 * 스크립트 VM 을 내리고 다시 올린다 (Destroy 뒤 Init). 핫 리로드 서버가 번들을 받은 뒤와
 * 브라우저의 initial2d_reload() 가 같은 길을 쓴다. 게임 진행 상태는 초기화된다 (풀 리스타트).
 *
 * 새 VM 이 오류 없이 올라오면(진입 파일 읽기와 init 훅) true. 스크립트 오류면 false 이고, 메시지는
 * 시작 때와 같은 형식("Lua error in ...")으로 이미 stderr 에 나갔다. 이때 게임은 끝나지 않고
 * 스크립트만 멈춘다 (Update 와 Render 를 건너뛴다). 다음 재시작이 성공하면 다시 돈다.
 * 시작 때의 오류와 Update, Render 의 오류는 전처럼 게임을 끝낸다 (종료 코드 1).
 */
bool Script_Restart();

/**
 * 스크립트가 오류로 멈춰 있는가 (예외, 없는 언어). 프로세스 종료 코드에 쓴다.
 * 재시작이 성공하면 false 로 돌아간다.
 */
bool Script_Failed();

#endif
