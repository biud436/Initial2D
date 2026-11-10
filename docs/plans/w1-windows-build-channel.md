# W1. Windows 빌드 채널

> 작성일: 2026-11-09. 권장 모델: Opus 5 (단계가 작고 확인 방법이 분명하다).

## 1. 목표

「맥에서 명령 한 줄을 치면 Windows PC가 빌드하고, 로그와 결과물이 맥으로 돌아온다. Windows가 켜져 있을 때만 된다」.

## 2. 구조

- 맥이 서버, Windows가 클라이언트다. Windows 클라이언트가 맥의 포트로 먼저 접속하고, 그 연결로 일을 받는다. Windows는 들어오는 포트를 열지 않는다.
- 맥의 포트는 `build` 나 `status` 가 도는 동안만 열린다. Windows 클라이언트는 몇 초(기본 3초)마다 접속을 시도하다가, 열려 있으면 붙어서 일을 하나 하고 끊는다.
- **Windows가 켜져 있을 때만 된다.** `build` 는 클라이언트를 정해진 시간(기본 15초)만 기다리고, 오지 않으면 "Windows가 꺼져 있거나 클라이언트가 돌지 않는다"고 알리고 종료 코드 3으로 끝난다. 줄을 세우거나 Windows를 깨우지 않는다. 클라이언트는 로그온 작업이라 Windows가 켜지면 같이 돈다.
- 명령은 Windows 쪽 `recipes.json` 에 적힌 이름만 받는다. 서버는 이름을 고를 뿐 명령줄을 보내지 않는다.
- 작은 것부터 쌓는다. 에코가 되는 것을 확인한 뒤 그 위에 인증, 빌드, 설치를 차례로 얹는다.

## 3. 확인된 환경 (2026-11-09)

| 항목 | 값 |
|---|---|
| 맥 | Windows PC 와 같은 LAN, 방화벽 꺼짐 |
| Windows | x64, 20코어, 로케일 ko-KR, 콘솔 코드 페이지 65001 (UTF-8), C: 여유 495 GB |
| 네트워크 | 같은 LAN. Windows에서 맥의 포트로 접속된다 |
| Visual Studio | Community 2022 (17.14, 툴셋 v143, MSVC 14.44, MSBuild 17.14)와 Community 2026 (18.1, 툴셋 v145, MSVC 14.50, MSBuild 18.0). v142(VS 2019)는 없다. clang-cl 없음 |
| 도구 | MSBuild, CMake(2022 번들 3.31.6, 2026 번들 4.1.1), Ninja 1.12.1은 VS 번들에만 있고 PATH에 없다 (`vswhere` 로 찾는다). git 2.43.0. **Python 없음** (Store 실행 별칭뿐). PowerShell 5.1.26100 |
| Windows SDK | 10.0.22621.0, 10.0.26100.0 |
| Windows 프로젝트 | `Initial2D.vcxproj`, 툴셋 v142 (VS 2019). Release, Win32 구성의 출력은 `lib\Initial2D.exe`. 링크하는 `luaLib.lib`, `Json.lib` 는 `lib/` 에 커밋되어 있다. 솔루션의 Release, x86 구성은 `Initial2D` 프로젝트를 빌드 대상으로 표시하지 않으므로(`Build.0` 없음) 솔루션이 아니라 vcxproj를 빌드한다 |

**정한 것 (2026-11-09)**

- Windows 클라이언트는 **PowerShell 5.1** 로 만든다 (`tools/winbuild/client.ps1`). Python이 깔려 있지 않고, PowerShell은 설치 없이 있다. PowerShell 5.1은 BOM 없는 스크립트를 시스템 코드 페이지로 읽으므로 `.ps1` 은 ASCII로만 쓴다.
- v142가 없으므로 vcxproj를 고치지 않고 `/p:PlatformToolset=v143` 으로 VS 2022 툴셋을 쓴다. MSBuild 경로는 `vswhere -version [17.0,18.0)` 으로 찾는다.
- **인증은 토큰 대신 양쪽 인증서 고정(mTLS)이다.** 처음 계획의 토큰은 비밀이라 Windows로 보낼 길(Remote Control 메시지)에 기록이 남는다. 인증서 방식은 공개 인증서와 지문만 오간다. 서버 키는 맥의 `~/.config/initial2d-winbuild/` 에, 클라이언트 키는 Windows의 `Cert:\CurrentUser\My` 에 내보내기 불가로 있다. 클라이언트 인증서에는 clientAuth 용도가 있어야 한다 (없으면 서버가 "unsupported certificate purpose" 로 거부한다. 테스트로 확인). 그리고 **SHA-256으로 서명해야 한다**: `New-SelfSignedCertificate` 는 옛 CSP를 쓰면 기본이 SHA-1인데, TLS 1.2 클라이언트는 서버가 요청한 서명 알고리즘으로 서명된 인증서만 보낼 수 있고 맥의 OpenSSL 3은 `RSA+SHA1` 을 요청하지 않는다. 그래서 Windows의 Schannel이 인증서를 보내지 않았고 서버 로그에는 `PEER_DID_NOT_RETURN_A_CERTIFICATE` 가 남았다 (2026-11-09 22:09, 첫 Windows 실행). `-Init` 은 이제 `-HashAlgorithm SHA256` 으로 만들고, 예전 SHA-1 인증서가 있으면 지우고 새로 만든다. 맥의 OpenSSL 클라이언트는 이 규칙을 따지지 않아 맥 테스트로는 잡히지 않는다.
- Windows 쪽 시험은 저자가 연 Remote Control 세션(T세션)에 맥 세션이 보내고, 결과는 맥 서버 로그로 확인한다 (2026-11-09 21:44, T세션의 에코가 Windows PC에서 도착).

## 4. 프로토콜

TLS 위의 줄 단위 JSON이다. 머리에 `size` 가 있으면 그 줄 바로 뒤에 그만큼의 바이트가 붙는다.

| 방향 | 종류 | 내용 |
|---|---|---|
| Windows → 맥 | `hello` | `agent`(판), `host`, `user`, `have`(클라이언트 저장소의 마지막 스냅숏과 그 부모), `recipes`(이름 목록) |
| 맥 → Windows | `job` | `id`, `recipe`, `snapshot`(커밋 해시), `clean`, `size` 와 git 묶음. 클라이언트가 그 스냅숏을 이미 가졌으면 `size` 0 |
| 맥 → Windows | `bye` | 일이 없다 (`status`, 없는 레시피, 이미 다른 클라이언트가 붙음) |
| Windows → 맥 | `log` | 출력 한 줄 |
| Windows → 맥 | `tick` | 15초 동안 출력이 없을 때. 맥이 사라졌으면 여기서 쓰기가 실패해 빌드를 멈춘다 |
| Windows → 맥 | `artifact` | `path`(저장소 기준), `size`, `sha256` 과 파일 내용. 빌드가 성공했을 때만 |
| Windows → 맥 | `result` | `exit`, `seconds`, `snapshot`, `error` |

**스냅숏**: 맥의 `build` 는 색인의 사본에 `git add -A` 를 해서 HEAD 위에 작업 트리를 얹은 커밋을 만든다. 커밋하지 않은 변경, 추적하지 않는 파일, 지운 파일이 들어가고 `.gitignore` 대상은 빠진다. 원본 저장소의 색인과 상태는 그대로이고, 묶음을 만드는 동안만 `refs/winbuild/snapshot` 을 썼다가 지운다. 날짜를 HEAD 의 것으로 고정해서 같은 상태는 같은 해시가 된다. 묶음은 클라이언트의 `have` 를 뺀 것만 담는다.

**Windows 쪽**: `%LOCALAPPDATA%\Initial2DBuildAgent\repo` 에 받아 `checkout --force --detach` 하고 `clean -fd` 한다 (`--clean` 이면 `-fdx`. 무시 대상인 중간 산출물을 남겨 다음 빌드가 빠르다). `core.autocrlf false` 로 맥과 같은 바이트를 쓴다. 레시피의 결과물은 빌드 전에 지운다 (`lib\Initial2D.exe` 는 커밋된 파일이라, 빌드가 실패했을 때 옛 파일을 보내지 않기 위해).

## 5. 단계

- [x] **1. 에코 서버.** 한 줄에 명령 하나(`PING`, `ECHO <글>`, `QUIT`)를 받는 TCP 서버. 확인: 맥에서 `nc` 로 PING, 한글 ECHO, 모르는 명령, QUIT. Windows Chrome에서 `GET /echo` 로 한글을 포함한 왕복, 서버 로그에 접속 주소 Windows PC (브라우저 확인용 HTTP 경로는 3단계에서 뺐다).
- [x] **2. Windows 소켓 클라이언트의 에코.** PowerShell 5.1의 `TcpClient` 가 ECHO 줄을 보내고 답을 받는다. 확인 (2026-11-09 21:39): 서버 로그에 Windows PC에서 `'ECHO 안녕 from windows' -> '안녕 from windows'`, `'QUIT' -> 'BYE'`. Windows가 소켓에 쓴 UTF-8 한글과 CRLF 줄 끝을 서버가 그대로 읽었다. T세션에서도 같은 결과 (21:44).
- [x] **3. 인증서 고정 TLS.** Windows 확인 (2026-11-09 22:15): 저자가 `client.ps1` 을 받아 `-Init` 을 실행하고(T세션은 이 PC에 인증서와 에이전트를 두는 일이라 사용자의 직접 허락을 요구하며 보류), 맥이 그 PEM 을 `trust --name U` 로 등록했다. 첫 시도는 SHA-1 인증서라 거부됐고(3절), SHA-256 으로 다시 만든 뒤 `connected: Initial2D winbuild client U ... TLSv1.2`. `server.py init`, `trust`, `serve` 와 `client.ps1 -Init`, `-Echo`. 아무것도 보내지 않는 연결은 `--idle` 초 뒤에 닫는다 (2단계에서 Chrome이 미리 열어 둔 연결 하나가 서버를 끌 때까지 남았던 것). 맥 테스트 통과 (`tests/tools/winbuild_test.py`: 등록 안 된 인증서, 인증서 없음, clientAuth 없는 인증서, 평문 거부, 말 없는 연결 닫기). Windows 확인 남음.
- [x] **4. 빌드.** Windows 확인 (2026-11-09): `selftest` 22:15 는 스냅숏 46.4 MB를 보내 Windows 저장소에 체크아웃하고 `git rev-parse HEAD` 가 스냅숏 해시를 찍고, 돌려받은 README.md가 맥 작업 트리와 바이트까지 같고 6.1초에 종료 코드 0. `gdi-release` 22:17 과 22:18 은 스냅숏이 같아 묶음 없이 체크아웃하고 VS 2022 MSBuild(v143)로 `Initial2D.vcxproj` 를 시작했으나, 프로젝트가 참조하는 NuGet 패키지(`packages.config` 의 `v8-v140-x64`, `v8.redist-v140-x64` 7.4.288.11)가 복원되지 않아 종료 코드 1 (`EnsureNuGetPackageBuildImports`. 한국어 오류 문장은 vcxproj 안에 적힌 것이다). 이전 기록: `server.py build <레시피>`, `status` 와 `client.ps1 -Once`. 맥 테스트 통과 (가짜 에이전트로 스냅숏 내용, 원본 저장소 무변경, 같은 상태는 묶음 없음, 바뀐 뒤 작은 묶음, 빌드 실패 코드, 없는 레시피 2, 클라이언트 없음 3, 결과 전 끊김 4, 위험한 결과물 경로 거부, TLS 1.2 접속과 거부). 이 저장소 전체로 돌린 루프백 시험(2026-11-09): 첫 묶음 46.4 MB를 3.2초에 보내고, 받은 README.md가 작업 트리와 같고, 작업 트리의 파일이 체크아웃에 빠짐없이 있고, 같은 상태 재빌드는 묶음 0바이트. Windows에서 `selftest`, `gdi-release` 확인 남음.
- [x] **5. 설치.** `install.ps1` 이 `client.ps1 -Agent` 를 로그온 작업으로 등록한다 (관리자 권한 없이, 사용자 계정, 실패하면 1분 뒤 다시). 클라이언트는 몇 초마다 접속을 시도하고, 같은 오류는 10분에 한 번만 로그에 남긴다. Windows 확인 (2026-11-09 22:18): 저자가 설치한 뒤 Windows 에서 아무것도 하지 않고 맥의 `status` 에 1초 안에 붙었고(`have` 에 지난 스냅숏), 맥에서만 시작한 `gdi-release` 가 Windows 에서 MSBuild 를 돌렸다.
- [x] **6. GDI 빌드 성공.** 저자 지시("GDI 코드를 수정해서 빌드 성공시켜봐", 2026-11-09)로 master 의 Windows 빌드를 고쳤다 (PR #72). 빌드 구성은 다음과 같고, 실행하며 고친 `RS_WINDOWS` 코드는 7단계에 적었다:
  - `Initial2D.vcxproj` 를 CMake 빌드와 같은 구성으로: 빠졌던 `ScriptRuntime.cpp`, `lua_json.cpp`, `lua_tilemap.cpp`, `platform/Utf8.cpp` 를 넣고, Lua(`lua/*.cpp`), jsoncpp, tinyxml 은 미리 빌드한 lib 대신 소스로 컴파일하고, 쓰이지 않는 `FMODSoundManager.cpp` 와 FMOD lib 를 뺐다.
  - 쓰이지 않는 V8 NuGet 의존(import 두 줄, 검사 타깃, `packages.config`)을 뺐다.
  - `node tools\copydir.js` 와 로컬 `bin/` 에 기대던 빌드 앞뒤 이벤트를 뺐다. 실행에 필요한 DLL, `scripts`, `resources` 는 저장소 루트에 있다.
  - 저장소에 없는 `SDL2.lib` 와, 옛 컴파일러의 /GL 이라 VS 2022 가 링크하지 못하는 `libpng16.lib`(C1047) 대신, 루트의 `SDL2.dll`, `libpng16-16.dll` 에서 뽑은 내보내기 목록(`external/SDL2/SDL2.def`, `external/libpng/libpng16-16.def`, `tools/make_import_def.py`)으로 빌드 중에 `lib.exe /def` 가 가져오기 라이브러리를 만든다.
  - `src/Tilemap.cpp` 의 `std::max`, `std::min` 을 `(std::max)` 꼴로 (Windows.h 의 매크로).
  - 확인 (2026-11-09 22:50 무렵): 맥에서만 시작한 `gdi-release` 가 17.4초에 종료 코드 0, `lib/Initial2D.exe`(PE32 GUI x86, `SDL2.dll`, `SDL2_mixer.dll`, `libpng16-16.dll` 을 가져온다)를 맥으로 돌려받았다. `gdi-debug` 도 47.3초에 종료 코드 0 (`lib/Initial2D_d.exe`).
  - 이전 기록 (22:20~22:40, 고치기 전에 알아낸 것):
  - NuGet: `-restore -p:RestorePackagesConfig=true` 로 V8 패키지 둘이 `repo\packages` 에 복원된다 (확인. `client.ps1` 의 기본 레시피에 넣었다. Windows 에 이미 깔린 `recipes.json` 은 저자가 고쳐야 한다).
  - npm: 빌드 앞뒤 이벤트의 `node tools\copydir.js` 가 `fs-extra`, `minimist` 를 쓰므로 `npm ci` 가 먼저 필요하다 (확인. `package-lock.json` 이 옛 판이라 경고가 나지만 설치된다).
  - 빌드 앞 이벤트가 `./bin/*.dll` 을 복사하는데 저장소에 `bin/` 이 없다. 같은 DLL 대부분은 저장소 루트에 있지만 `libpng16.dll` 은 어디에도 없고, `fs-extra` 8 은 없는 원본에서 예외를 던진다. **GDI 프로젝트는 원래 개발 PC의 로컬 `bin/` 에 기대며, 새 PC에서 다시 빌드된 적이 없다** (`archive/windows-gdi` 도 같고, 그 브랜치의 `.github` 에는 Windows 빌드 CI가 없다).
  - master 의 vcxproj 는 `src/*.cpp` 44개 중 34개만 컴파일한다. `main.cpp` 가 부르는 `Script_Init` 의 `ScriptRuntime.cpp`, `lua_json.cpp`, `lua_tilemap.cpp`, `mrb_*.cpp` 가 빠져 있어 `bin/` 을 풀어도 링크가 실패한다. 고치려면 vcxproj 와 코드(mruby 포함)를 손대야 하고, 이는 GDI 무수정 원칙과 하지 않기로 한 R5 에 걸린다.
  - 그래서 시도에 쓴 저장소 쪽 임시 파일(`Directory.Build.rsp` 로 NuGet 복원, `Directory.Build.targets` 로 `npm ci`)은 되돌렸다.
  - `archive/windows-gdi` 를 스크래치 클론으로 빌드해 보니(빌드 앞뒤 이벤트를 끄고 NuGet 복원) 컴파일에서 그 브랜치 코드 자체가 깨져 있었다 (`SoundManager.h` 의 FMOD 이름공간, `FMODSoundManager` 의 타입 충돌). 보존 브랜치는 고치지 않았다.
- [x] **7. 실행과 진단.** 레시피에 `launch` 가 있으면 빌드 뒤 그 실행 파일을 저장소에서 띄운다 (`run-release`, `run-stage`, `play-stage`).
  - 띄우는 쪽: 표준 출력과 오류, 꺼졌을 때 이벤트 로그(1000, 1001: 모듈, 예외 코드, 오프셋, `abort` 하위 코드)를 로그로 보낸다. `shots` 의 시점마다 엔진 창만 `PrintWindow` 로 찍어 보내고, 끝나면 닫는다 (`keep_running` 이면 둔다). `until_exit` 이면 엔진이 스스로 끝나기를 기다렸다가 `collect` 의 파일(엔진이 저장한 BMP)을 PNG 로 보낸다.
  - 갱신: 일이 끝나면 스냅숏의 `client.ps1`, `install.ps1` 이 설치본을 바꾼다. 기본 레시피는 `recipes.json` 에 합쳐지고, 같은 이름은 `"managed": false` 가 아니면 기본값을 따른다. 상주 루프(`-Agent`)는 포트만 보고 열리면 최신 `-Once` 를 띄우며, 디스크의 `client.ps1` 이 바뀌면 스스로 다시 뜬다 (0.2.6). 설치는 저자가 한 번 했다 (23:15).
  - 실행하며 찾고 고친 GDI 문제 (PR #72): libpng DLL 에 실행 파일의 `FILE*` 를 넘겨 "setjmp 실패", 실패한 텍스처의 NULL 역참조, `LoadBMP` 의 해제 뒤 읽기, 렌더 배율이 왼쪽 위만 그리던 것, 미리 곱하지 않은 알파로 글자가 흰 사각형, 갱신마다 프레임 시간을 넘겨 화면을 자주 그릴수록 게임이 느려지던 것(SDL2 판은 예전에 고쳤다), mruby 가 없을 때 아무 표시 없이 꺼지던 것.
  - GDI 판에 SDL2 판과 같은 이름의 시험 기능을 더했다 (틱 단위): `INITIAL2D_SCREENSHOT(_FRAME)`, `INITIAL2D_EXIT_AFTER`, `INITIAL2D_TEST_EVENTS` 의 `틱:keydown:가상키`, `틱:keyup:가상키`.
  - 확인 (23:18~23:29): 타이틀이 창 전체에 글자까지 제대로 그려지고, 스테이지 화면의 디버그 표시가 FPS 62 (고정 16 ms).
  - 겪은 일: 옛 상주 루프의 `Start-Process -Wait` 가 띄운 엔진과 빌드가 남긴 `mspdbsrv.exe`(약 10분 산다)까지 기다려 에이전트가 10분씩 멈췄다 (T세션 진단). 이제 자식만 기다리고, 빌드는 `/nodeReuse:false` 와 전용 PDB 서버 이름을 쓰고 그 작업에서 생긴 `mspdbsrv` 를 끈다. `Start-Process -PassThru` 는 핸들을 열어 두지 않으면 끝난 뒤 `ExitCode` 가 비어 정상 종료를 실패로 보았다 (고침).
- [x] **8. 이동 속도 측정.** `play-stage` 는 60틱에 오른쪽 키를 누르고 360틱에 떼며, 60틱부터 180틱까지 15틱마다 엔진이 화면을 저장하고 400틱에 끝난다. 디버그 표시의 x 로 틱당 이동량을 잰다 (기대 1.44 px, `WALK_SPEED` 90 px/s 와 16 ms).
  - 결과 (2026-11-10 21:47, 클라이언트 0.2.8): 틱 60, 75, 90, 105, 120, 135 의 x 가 57, 79, 100, 122, 143, 165. 75틱에 108 px, **틱당 1.44 px 로 기대와 같다**. 표시는 내림이라 15틱 간격이 21 과 22 를 오가며, 시작 x 를 57.5 로 두면 여섯 값이 모두 맞는다. FPS 표시는 62.
  - 150틱부터는 거미에게 맞아(체력 줄어듦, y 375 공중) 밀려난 거리가 섞인다 (189, 213, 235). 60틱 간격으로 찍은 첫 시도에서 120~180틱 구간이 92 px 로 나온 까닭이다. 그래서 간격을 15틱으로 줄였다. 240틱 뒤로는 돌 턱에 막혀 x 313 에서 멈춘다.
  - 같은 스냅숏을 두 번 돌리면 같은 틱의 화면이 바이트까지 같다 (120틱과 180틱의 PNG 크기로 확인).
  - 고친 것: `until_exit` 실행은 종료 코드가 0 이 아니어도 `collect` 의 파일을 먼저 보낸다 (0.2.7). 실패한 실행이 어디까지 갔는지 보기 위해서다.
  - **남은 문제**: GDI 판은 `INITIAL2D_EXIT_AFTER` 로 끝나면 종료 코드가 1 이라 `play-stage` 가 실패(종료 코드 1)로 보고된다. `App::Run` 이 `WM_QUIT` 을 받지 않고 루프를 나온 뒤 마지막으로 처리한 창 메시지의 `wParam` 을 돌려주기 때문으로 보인다 (`src/App.cpp` 의 `RS_WINDOWS` 경로, 확인은 하지 않았다). GDI 무수정 원칙에 걸려 고치지 않았다. 고치려면 저자 결정이 필요하다.

## 6. 주의

- 맥에서 LAN 주소로 서버를 띄우는 명령은 Claude Code 자동 모드 분류기가 막을 수 있다 (2026-11-09 한 번 막혔고, 저자 지시 뒤 실행됐다).
- 보안 경계는 서로 고정한 인증서다. 레시피는 실수를 막는 목록일 뿐이다: 스냅숏(vcxproj, props)과 클라이언트 갱신은 맥이 정하므로, 서버 키를 가진 쪽은 Windows 에서 코드를 실행할 수 있다.
- 스냅숏에는 추적하지 않는 파일도 들어간다 (`.gitignore` 대상은 빠진다). Windows에 보내고 싶지 않은 파일은 `.gitignore` 에 넣는다.
