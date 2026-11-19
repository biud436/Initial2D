/**
 * @file game_folder_test.cpp
 * @brief 내보낸 게임의 게임 폴더 찾기와 game.json 의 이름과 아이콘 (엔진 3, docs/plans/engine3-exported-game.md).
 */
#include "test_framework.h"

#include "platform/GameIdentity.h"

#include "json/json.h"

#include <filesystem>
#include <fstream>
#include <random>
#include <sstream>

namespace fs = std::filesystem;

using Initial2D::Platform::FindBundledGameFolder;
using Initial2D::Platform::GameIdentity;
using Initial2D::Platform::ReadGameIdentity;
using Initial2D::Platform::WindowTitle;

namespace {

	/** 테스트마다 비어 있는 임시 폴더. 소멸할 때 지운다 */
	struct TempDir {
		fs::path path;
		TempDir()
		{
			std::random_device rd;
			path = fs::temp_directory_path() / ("initial2d_game_folder_" + std::to_string(rd()));
			fs::create_directories(path);
		}
		~TempDir()
		{
			std::error_code ec;
			fs::remove_all(path, ec);
		}
	};

	void Touch(const fs::path& file)
	{
		fs::create_directories(file.parent_path());
		std::ofstream(file) << "{}\n";
	}

	Json::Value Parse(const std::string& text)
	{
		Json::Value root;
		std::istringstream(text) >> root;
		return root;
	}

} // namespace

TEST(game_folder_app_bundle)
{
	TempDir t;
	const fs::path macos = t.path / "Bird.app" / "Contents" / "MacOS";
	fs::create_directories(macos);
	Touch(t.path / "Bird.app" / "Contents" / "Resources" / "game" / "game.json");
	CHECK_EQ(FindBundledGameFolder(macos.string()), (t.path / "Bird.app" / "Contents" / "Resources" / "game").string());
}

TEST(game_folder_bundle_before_beside)
{
	// 묶음의 Resources/game 과 MacOS/game 이 둘 다 있으면 묶음이 먼저다
	TempDir t;
	const fs::path macos = t.path / "Bird.app" / "Contents" / "MacOS";
	Touch(macos / "game" / "game.json");
	Touch(t.path / "Bird.app" / "Contents" / "Resources" / "game" / "game.json");
	CHECK_EQ(FindBundledGameFolder(macos.string()), (t.path / "Bird.app" / "Contents" / "Resources" / "game").string());
}

TEST(game_folder_beside_executable)
{
	TempDir t;
	Touch(t.path / "game" / "game.json");
	CHECK_EQ(FindBundledGameFolder(t.path.string()), (t.path / "game").string());
}

TEST(game_folder_bundle_without_game_json_falls_back)
{
	// Resources/game 에 game.json 이 없으면 후보가 아니다. MacOS/game 도 없으면 빈 문자열 (작업 폴더)
	TempDir t;
	const fs::path macos = t.path / "Bird.app" / "Contents" / "MacOS";
	fs::create_directories(macos);
	fs::create_directories(t.path / "Bird.app" / "Contents" / "Resources" / "game" / "scripts");
	CHECK_EQ(FindBundledGameFolder(macos.string()), std::string());

	Touch(macos / "game" / "game.json");
	CHECK_EQ(FindBundledGameFolder(macos.string()), (macos / "game").string());
}

TEST(game_folder_game_json_directory_is_not_a_game)
{
	TempDir t;
	fs::create_directories(t.path / "game" / "game.json");
	CHECK_EQ(FindBundledGameFolder(t.path.string()), std::string());
}

TEST(game_folder_macos_outside_contents_is_not_a_bundle)
{
	// MacOS 폴더라도 부모가 Contents 가 아니면 묶음으로 보지 않는다
	TempDir t;
	const fs::path macos = t.path / "Bird" / "MacOS";
	fs::create_directories(macos);
	Touch(t.path / "Bird" / "Resources" / "game" / "game.json");
	CHECK_EQ(FindBundledGameFolder(macos.string()), std::string());
}

TEST(game_folder_nothing_and_empty_path)
{
	TempDir t;
	CHECK_EQ(FindBundledGameFolder(t.path.string()), std::string());
	CHECK_EQ(FindBundledGameFolder(""), std::string());
	CHECK_EQ(FindBundledGameFolder((t.path / "missing").string()), std::string());
}

TEST(game_identity_name_and_icon)
{
	std::vector<std::string> warnings;
	const GameIdentity id = ReadGameIdentity(Parse(R"({"name": "날아라 새", "icon": "resources/icons/bird.png"})"), warnings);
	CHECK_EQ(id.name, std::string("날아라 새"));
	CHECK_EQ(id.icon, std::string("resources/icons/bird.png"));
	CHECK(id.hasIcon);
	CHECK_EQ(warnings.size(), static_cast<size_t>(0));
}

TEST(game_identity_missing_keys)
{
	std::vector<std::string> warnings;
	const GameIdentity id = ReadGameIdentity(Parse(R"({"windowWidth": 320, "name": null})"), warnings);
	CHECK_EQ(id.name, std::string());
	CHECK(!id.hasIcon);
	CHECK_EQ(warnings.size(), static_cast<size_t>(0));
}

TEST(game_identity_wrong_types_warn)
{
	std::vector<std::string> warnings;
	const GameIdentity id = ReadGameIdentity(Parse(R"({"name": 3, "icon": ["a.png"]})"), warnings);
	CHECK_EQ(id.name, std::string());
	CHECK(!id.hasIcon);
	CHECK_EQ(warnings.size(), static_cast<size_t>(2));
	if (warnings.size() == 2) {
		CHECK_EQ(warnings[0], std::string("game.json name: expected a string"));
		CHECK_EQ(warnings[1], std::string("game.json icon: expected a string"));
	}
}

TEST(game_identity_not_an_object)
{
	std::vector<std::string> warnings;
	const GameIdentity id = ReadGameIdentity(Parse("[1, 2]"), warnings);
	CHECK_EQ(id.name, std::string());
	CHECK(!id.hasIcon);
	CHECK_EQ(warnings.size(), static_cast<size_t>(0));
}

TEST(game_identity_empty_icon_is_set)
{
	// 빈 문자열 icon 도 적은 것이다. 엔진이 읽지 못한다고 알린다
	std::vector<std::string> warnings;
	const GameIdentity id = ReadGameIdentity(Parse(R"({"icon": ""})"), warnings);
	CHECK(id.hasIcon);
	CHECK_EQ(id.icon, std::string());
}

TEST(window_title_text)
{
	GameIdentity id;
	CHECK_EQ(WindowTitle(id, -1), std::string("Initial2D"));
	CHECK_EQ(WindowTitle(id, 60), std::string("Initial2D (60 FPS)"));
	id.name = "날아라 새";
	CHECK_EQ(WindowTitle(id, -1), std::string("날아라 새"));
	CHECK_EQ(WindowTitle(id, 0), std::string("날아라 새 (0 FPS)"));
}
