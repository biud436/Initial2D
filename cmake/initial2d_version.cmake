# 판 헤더를 만든다 (sdl2Main.cpp 의 --version). CMakeLists.txt 의 initial2d_version 대상이 빌드마다 부른다.
#   cmake -DSOURCE_DIR=<저장소> -DOUTPUT=<헤더> [-DGIT_EXECUTABLE=<git>] -P cmake/initial2d_version.cmake
# 내용이 같으면 파일을 다시 쓰지 않아 sdl2Main.cpp 가 다시 컴파일되지 않는다.
# describe 는 v2 이상의 태그만 본다 (v1.x 태그는 Windows GDI 판이다). 그런 태그가 없으면 짧은 커밋이다.

set(describe "unknown")
set(commit "unknown")
if(NOT GIT_EXECUTABLE)
  find_program(GIT_EXECUTABLE git)
endif()
if(GIT_EXECUTABLE)
  execute_process(
    COMMAND "${GIT_EXECUTABLE}" -C "${SOURCE_DIR}" describe --tags --always --dirty --match "v[2-9]*"
    OUTPUT_VARIABLE _describe OUTPUT_STRIP_TRAILING_WHITESPACE ERROR_QUIET RESULT_VARIABLE _describe_rc)
  execute_process(
    COMMAND "${GIT_EXECUTABLE}" -C "${SOURCE_DIR}" rev-parse HEAD
    OUTPUT_VARIABLE _commit OUTPUT_STRIP_TRAILING_WHITESPACE ERROR_QUIET RESULT_VARIABLE _commit_rc)
  if(_describe_rc EQUAL 0 AND _describe)
    set(describe "${_describe}")
  endif()
  if(_commit_rc EQUAL 0 AND _commit MATCHES "^[0-9a-f]+$")
    set(commit "${_commit}")
  endif()
endif()

set(_content "// cmake/initial2d_version.cmake 가 만든다. 손으로 고치지 않는다.
#pragma once
#define INITIAL2D_VERSION_DESCRIBE \"${describe}\"
#define INITIAL2D_VERSION_COMMIT \"${commit}\"
")
set(_old "")
if(EXISTS "${OUTPUT}")
  file(READ "${OUTPUT}" _old)
endif()
if(NOT _old STREQUAL _content)
  file(WRITE "${OUTPUT}" "${_content}")
endif()
