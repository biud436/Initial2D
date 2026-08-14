#include "Constants.h"

#ifdef __ANDROID__

#include "AndroidBootstrap.h"

#include <SDL.h>

#include <cerrno>
#include <cstdio>
#include <cstring>
#include <string>
#include <vector>

#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>

namespace {

	// assets의 파일을 통째로 읽는다. 상대 경로 SDL_RWFromFile은 AAssetManager를 경유한다.
	bool ReadAssetFile(const char* path, std::vector<char>& out)
	{
		SDL_RWops* rw = SDL_RWFromFile(path, "rb");
		if (rw == nullptr) {
			return false;
		}

		const Sint64 size = SDL_RWsize(rw);
		if (size < 0) {
			SDL_RWclose(rw);
			return false;
		}

		out.resize(static_cast<size_t>(size));
		const size_t read = out.empty() ? 0 : SDL_RWread(rw, out.data(), 1, out.size());
		SDL_RWclose(rw);
		return read == out.size();
	}

	bool ReadLocalFile(const std::string& path, std::vector<char>& out)
	{
		FILE* fp = std::fopen(path.c_str(), "rb");
		if (fp == nullptr) {
			return false;
		}

		std::fseek(fp, 0, SEEK_END);
		const long size = std::ftell(fp);
		std::fseek(fp, 0, SEEK_SET);
		if (size < 0) {
			std::fclose(fp);
			return false;
		}

		out.resize(static_cast<size_t>(size));
		const size_t read = out.empty() ? 0 : std::fread(out.data(), 1, out.size(), fp);
		std::fclose(fp);
		return read == out.size();
	}

	bool WriteLocalFile(const std::string& path, const std::vector<char>& data)
	{
		FILE* fp = std::fopen(path.c_str(), "wb");
		if (fp == nullptr) {
			return false;
		}

		const size_t written = data.empty() ? 0 : std::fwrite(data.data(), 1, data.size(), fp);
		std::fclose(fp);
		return written == data.size();
	}

	// dst의 부모 디렉터리들을 mkdir -p 방식으로 만든다.
	void MakeParentDirs(const std::string& dst)
	{
		for (size_t i = 1; i < dst.size(); ++i) {
			if (dst[i] == '/') {
				mkdir(dst.substr(0, i).c_str(), 0770);
			}
		}
	}

} // namespace

namespace Initial2D {
namespace Platform {

	bool AndroidBootstrap()
	{
		const char* internal = SDL_AndroidGetInternalStoragePath();
		if (internal == nullptr) {
			SDL_Log("AndroidBootstrap: internal storage unavailable (%s)", SDL_GetError());
			return false;
		}

		// 파일 목록은 prepare_assets.sh가 생성한 매니페스트로 얻는다.
		// (AAssetManager는 디렉터리 열거에 JNI가 필요하므로 목록을 빌드 시점에 만든다)
		std::vector<char> manifest;
		if (!ReadAssetFile("assets_manifest.txt", manifest)) {
			SDL_Log("AndroidBootstrap: assets_manifest.txt missing — run android/prepare_assets.sh and rebuild");
			return false;
		}

		const std::string root = std::string(internal) + "/";
		const std::string manifestPath = root + "assets_manifest.txt";

		// 이전 추출본과 매니페스트가 같으면 추출을 생략한다.
		std::vector<char> previous;
		const bool upToDate = ReadLocalFile(manifestPath, previous) && previous == manifest;

		if (!upToDate) {
			int copied = 0;
			const char* p = manifest.data();
			const char* end = manifest.data() + manifest.size();

			while (p < end) {
				const char* lineEnd = static_cast<const char*>(std::memchr(p, '\n', end - p));
				if (lineEnd == nullptr) {
					lineEnd = end;
				}

				std::string line(p, lineEnd);
				p = lineEnd + 1;

				while (!line.empty() && (line.back() == '\r' || line.back() == ' ')) {
					line.pop_back();
				}
				if (line.empty()) {
					continue;
				}

				std::vector<char> data;
				if (!ReadAssetFile(line.c_str(), data)) {
					SDL_Log("AndroidBootstrap: asset not found in APK: %s", line.c_str());
					return false;
				}

				const std::string dst = root + line;
				MakeParentDirs(dst);
				if (!WriteLocalFile(dst, data)) {
					SDL_Log("AndroidBootstrap: cannot write %s: %s", dst.c_str(), std::strerror(errno));
					return false;
				}
				copied++;
			}

			// 매니페스트는 모든 파일이 성공한 뒤에 기록한다 (중단 시 다음 실행에서 재추출).
			WriteLocalFile(manifestPath, manifest);
			SDL_Log("AndroidBootstrap: extracted %d assets to %s", copied, internal);
		}
		else {
			SDL_Log("AndroidBootstrap: assets up to date at %s", internal);
		}

		if (chdir(internal) != 0) {
			SDL_Log("AndroidBootstrap: chdir(%s) failed: %s", internal, std::strerror(errno));
			return false;
		}

		return true;
	}

} // namespace Platform
} // namespace Initial2D

#endif // __ANDROID__
