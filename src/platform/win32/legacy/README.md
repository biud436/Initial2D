# platform/win32/legacy

macOS 포팅 과정에서 C++ 표준 라이브러리로 공통화되어 더 이상 빌드에 포함되지 않는
**원본 Win32 구현의 보존본**입니다. 어떤 빌드 타깃에도 포함되지 않습니다.

| 파일 | 원위치 | 공통화 시점 | 대체 구현 |
|---|---|---|---|
| `Thread.h`, `Thread.cpp` | `src/` | Phase 1 | `std::thread`/`std::mutex` (동일 경로, 동일 인터페이스) |

전체 원본 스냅샷은 `archive/windows-gdi` 브랜치와 `v1.1.0` 태그에 보존되어 있습니다.
