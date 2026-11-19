/**
 * @file GameIdentity.h
 * @brief 내보낸 게임의 게임 폴더 찾기와 game.json 의 이름과 아이콘 (엔진 3, docs/plans/engine3-exported-game.md).
 * @details SDL2 판(데스크톱, 안드로이드, 웹)이 쓴다. Windows GDI 판은 쓰지 않는다.
 */
#pragma once

#include <string>
#include <vector>

namespace Json {
	class Value;
}

namespace Initial2D {
namespace Platform {

	/** 이름이 없을 때의 창 제목 */
	extern const char* const kDefaultWindowTitle;

	/** game.json 에 icon 이 없을 때 있으면 쓰는 아이콘 (게임 폴더 기준) */
	extern const char* const kDefaultIconPath;

	/**
	 * 실행 파일 위치 기준의 게임 폴더. 후보는 순서대로
	 *   1. <이름>.app/Contents/Resources/game   (실행 파일이 <이름>.app/Contents/MacOS/ 에 있을 때)
	 *   2. <실행 파일 폴더>/game
	 * 이고, game.json 이 파일로 있는 첫 후보의 경로를 돌려준다. 없으면 빈 문자열 (작업 폴더를 쓴다).
	 */
	std::string FindBundledGameFolder(const std::string& executableDirectory);

	/** game.json 의 name 과 icon */
	struct GameIdentity {
		std::string name;      ///< 빈 문자열이면 kDefaultWindowTitle
		std::string icon;      ///< hasIcon 일 때의 경로
		bool hasIcon = false;  ///< game.json 에 문자열 icon 이 있다
	};

	/** game.json 의 최상위 값에서 읽는다. 타입이 틀린 키는 무시하고 그 문장을 warnings 에 더한다. */
	GameIdentity ReadGameIdentity(const Json::Value& root, std::vector<std::string>& warnings);

	/** 창 제목. fps 가 0 이상이면 "<이름> (<fps> FPS)" */
	std::string WindowTitle(const GameIdentity& identity, int fps);

} // namespace Platform
} // namespace Initial2D
