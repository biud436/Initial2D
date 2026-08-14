#include "../SystemPath.h"

#include <filesystem>

#if defined(__APPLE__)
#include <mach-o/dyld.h>
#include <vector>
#elif defined(__linux__)
#include <unistd.h>
#include <limits.h>
#endif

namespace Initial2D {
namespace Platform {

	std::string GetExecutablePath()
	{
#if defined(__APPLE__)
		uint32_t size = 0;
		_NSGetExecutablePath(nullptr, &size);
		std::vector<char> buffer(size + 1, '\0');
		if (_NSGetExecutablePath(buffer.data(), &size) != 0) {
			return std::string();
		}
		// 심볼릭 링크·상대 경로를 정규화한다.
		std::error_code ec;
		auto canonical = std::filesystem::canonical(buffer.data(), ec);
		return ec ? std::string(buffer.data()) : canonical.string();
#elif defined(__linux__)
		char buffer[PATH_MAX] = { 0 };
		const ssize_t len = readlink("/proc/self/exe", buffer, sizeof(buffer) - 1);
		if (len <= 0) {
			return std::string();
		}
		return std::string(buffer, static_cast<size_t>(len));
#else
		return std::string();
#endif
	}

	std::string GetExecutableDirectory()
	{
		const std::string path = GetExecutablePath();
		if (path.empty()) {
			return std::string();
		}
		return std::filesystem::path(path).parent_path().string();
	}

} // namespace Platform
} // namespace Initial2D
