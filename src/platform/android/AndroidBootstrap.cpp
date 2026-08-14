#include "Constants.h"

#ifdef __ANDROID__

#include "AndroidBootstrap.h"

#include <SDL.h>

#include <jni.h>
#include <android/asset_manager.h>
#include <android/asset_manager_jni.h>

#include <cerrno>
#include <cstdio>
#include <cstring>
#include <string>
#include <vector>

#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>

namespace {

	// APK assets 접근자. 주의: SDL_RWFromFile은 상대 경로일 때 내부 저장소를
	// 먼저 찾기 때문에, 한 번 추출된 뒤에는 APK가 갱신되어도 옛 사본을 읽는다.
	// 반드시 AAssetManager로 직접 읽어야 항상 진짜 APK 내용을 본다.
	struct ApkAssets {
		JNIEnv* env = nullptr;
		jobject assetManagerRef = nullptr;   // GC 방지용 전역 참조
		AAssetManager* am = nullptr;

		bool open()
		{
			env = static_cast<JNIEnv*>(SDL_AndroidGetJNIEnv());
			jobject activity = static_cast<jobject>(SDL_AndroidGetActivity());
			if (env == nullptr || activity == nullptr) {
				return false;
			}

			jclass activityClass = env->GetObjectClass(activity);
			jmethodID getAssets = env->GetMethodID(
				activityClass, "getAssets", "()Landroid/content/res/AssetManager;");
			jobject localRef = env->CallObjectMethod(activity, getAssets);

			env->DeleteLocalRef(activityClass);
			env->DeleteLocalRef(activity);

			if (localRef == nullptr) {
				return false;
			}

			assetManagerRef = env->NewGlobalRef(localRef);
			env->DeleteLocalRef(localRef);
			am = AAssetManager_fromJava(env, assetManagerRef);
			return am != nullptr;
		}

		void close()
		{
			if (env != nullptr && assetManagerRef != nullptr) {
				env->DeleteGlobalRef(assetManagerRef);
				assetManagerRef = nullptr;
			}
			am = nullptr;
		}
	};

	// APK assets의 파일을 통째로 읽는다.
	bool ReadAssetFile(AAssetManager* am, const char* path, std::vector<char>& out)
	{
		AAsset* asset = AAssetManager_open(am, path, AASSET_MODE_STREAMING);
		if (asset == nullptr) {
			return false;
		}

		const off_t size = AAsset_getLength(asset);
		out.resize(static_cast<size_t>(size));

		size_t total = 0;
		while (total < out.size()) {
			const int read = AAsset_read(asset, out.data() + total, out.size() - total);
			if (read <= 0) {
				break;
			}
			total += static_cast<size_t>(read);
		}

		AAsset_close(asset);
		return total == out.size();
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

		ApkAssets apk;
		if (!apk.open()) {
			SDL_Log("AndroidBootstrap: cannot access APK asset manager");
			return false;
		}

		// 파일 목록은 prepare_assets.sh가 생성한 매니페스트로 얻는다.
		// (AAssetManager는 디렉터리 열거가 서브디렉터리를 못 봐서 목록을 빌드 시점에 만든다)
		std::vector<char> manifest;
		if (!ReadAssetFile(apk.am, "assets_manifest.txt", manifest)) {
			SDL_Log("AndroidBootstrap: assets_manifest.txt missing — run android/prepare_assets.sh and rebuild");
			apk.close();
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
				if (!ReadAssetFile(apk.am, line.c_str(), data)) {
					SDL_Log("AndroidBootstrap: asset not found in APK: %s", line.c_str());
					apk.close();
					return false;
				}

				const std::string dst = root + line;
				MakeParentDirs(dst);
				if (!WriteLocalFile(dst, data)) {
					SDL_Log("AndroidBootstrap: cannot write %s: %s", dst.c_str(), std::strerror(errno));
					apk.close();
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

		apk.close();

		if (chdir(internal) != 0) {
			SDL_Log("AndroidBootstrap: chdir(%s) failed: %s", internal, std::strerror(errno));
			return false;
		}

		return true;
	}

} // namespace Platform
} // namespace Initial2D

#endif // __ANDROID__
