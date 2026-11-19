#include "GameIdentity.h"

#include "json/json.h"

#include <filesystem>
#include <system_error>

namespace Initial2D {
namespace Platform {

	const char* const kDefaultWindowTitle = "Initial2D";
	const char* const kDefaultIconPath = "resources/icons/icon.png";

	namespace {

		bool HasGameJson(const std::filesystem::path& folder)
		{
			std::error_code ec;
			return std::filesystem::is_regular_file(folder / "game.json", ec);
		}

	} // namespace

	std::string FindBundledGameFolder(const std::string& executableDirectory)
	{
		if (executableDirectory.empty()) {
			return std::string();
		}
		const std::filesystem::path exeDir(executableDirectory);

		// 1. macOS 앱 묶음
		const std::filesystem::path contents = exeDir.parent_path();
		if (exeDir.filename() == "MacOS" && contents.filename() == "Contents") {
			const std::filesystem::path bundled = contents / "Resources" / "game";
			if (HasGameJson(bundled)) {
				return bundled.string();
			}
		}

		// 2. 실행 파일 옆의 game 폴더
		const std::filesystem::path beside = exeDir / "game";
		if (HasGameJson(beside)) {
			return beside.string();
		}
		return std::string();
	}

	GameIdentity ReadGameIdentity(const Json::Value& root, std::vector<std::string>& warnings)
	{
		GameIdentity identity;
		if (!root.isObject()) {
			return identity;
		}

		const Json::Value& name = root["name"];
		if (name.isString()) {
			identity.name = name.asString();
		} else if (!name.isNull()) {
			warnings.push_back("game.json name: expected a string");
		}

		const Json::Value& icon = root["icon"];
		if (icon.isString()) {
			identity.icon = icon.asString();
			identity.hasIcon = true;
		} else if (!icon.isNull()) {
			warnings.push_back("game.json icon: expected a string");
		}
		return identity;
	}

	std::string WindowTitle(const GameIdentity& identity, int fps)
	{
		std::string title = identity.name.empty() ? std::string(kDefaultWindowTitle) : identity.name;
		if (fps >= 0) {
			title += " (" + std::to_string(fps) + " FPS)";
		}
		return title;
	}

} // namespace Platform
} // namespace Initial2D
