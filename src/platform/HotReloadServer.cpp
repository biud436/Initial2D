#include "Constants.h"

#ifndef RS_WINDOWS

#include "HotReloadServer.h"

#include <atomic>
#include <cstring>
#include <mutex>
#include <thread>

#include <arpa/inet.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <unistd.h>

namespace {

	// 폭주 방지 상한 — 개발용 스크립트 번들 기준으로 넉넉한 값
	const uint32_t kMaxFiles = 4096;
	const uint32_t kMaxPathLen = 4096;
	const uint32_t kMaxFileSize = 32u * 1024u * 1024u;

	std::thread g_thread;
	std::atomic<bool> g_running{ false };
	int g_listenFd = -1;

	std::mutex g_bundleMutex;
	std::vector<Initial2D::Platform::HotReloadFile> g_pendingBundle;
	bool g_hasPending = false;

	bool RecvAll(int fd, void* buffer, size_t size)
	{
		char* p = static_cast<char*>(buffer);
		while (size > 0) {
			const ssize_t n = recv(fd, p, size, 0);
			if (n <= 0) {
				return false;
			}
			p += n;
			size -= static_cast<size_t>(n);
		}
		return true;
	}

	bool RecvU32(int fd, uint32_t& out)
	{
		uint32_t raw = 0;
		if (!RecvAll(fd, &raw, sizeof(raw))) {
			return false;
		}
		// 프로토콜은 리틀 엔디언 — 대상 플랫폼(arm64/x86_64) 모두 리틀 엔디언
		out = raw;
		return true;
	}

	// cwd 밖으로 나가는 경로를 거부한다.
	bool IsSafeRelativePath(const std::string& path)
	{
		if (path.empty() || path[0] == '/' || path.find('\\') != std::string::npos) {
			return false;
		}
		if (path == ".." || path.find("../") == 0) {
			return false;
		}
		if (path.find("/../") != std::string::npos ||
			(path.size() >= 3 && path.compare(path.size() - 3, 3, "/..") == 0)) {
			return false;
		}
		return true;
	}

	// 한 연결에서 번들 하나를 수신한다. 성공 시 대기 번들을 교체한다.
	bool ReceiveBundle(int fd)
	{
		char magic[4] = { 0 };
		if (!RecvAll(fd, magic, sizeof(magic)) || std::memcmp(magic, "I2DH", 4) != 0) {
			return false;
		}

		uint32_t fileCount = 0;
		if (!RecvU32(fd, fileCount) || fileCount == 0 || fileCount > kMaxFiles) {
			return false;
		}

		std::vector<Initial2D::Platform::HotReloadFile> bundle;
		bundle.reserve(fileCount);

		for (uint32_t i = 0; i < fileCount; ++i) {
			uint32_t pathLen = 0;
			if (!RecvU32(fd, pathLen) || pathLen == 0 || pathLen > kMaxPathLen) {
				return false;
			}

			std::string path(pathLen, '\0');
			if (!RecvAll(fd, &path[0], pathLen) || !IsSafeRelativePath(path)) {
				return false;
			}

			uint32_t dataLen = 0;
			if (!RecvU32(fd, dataLen) || dataLen > kMaxFileSize) {
				return false;
			}

			std::vector<char> data(dataLen);
			if (dataLen > 0 && !RecvAll(fd, data.data(), dataLen)) {
				return false;
			}

			Initial2D::Platform::HotReloadFile file;
			file.path = path;
			file.data.swap(data);
			bundle.push_back(std::move(file));
		}

		{
			std::lock_guard<std::mutex> lock(g_bundleMutex);
			g_pendingBundle.swap(bundle);
			g_hasPending = true;
		}
		return true;
	}

	void ServerLoop()
	{
		while (g_running.load()) {
			const int client = accept(g_listenFd, nullptr, nullptr);
			if (client < 0) {
				// Stop()이 리슨 소켓을 닫으면 accept가 실패하며 루프가 끝난다.
				if (!g_running.load()) {
					break;
				}
				continue;
			}

			const bool ok = ReceiveBundle(client);
			const char* reply = ok ? "OK\n" : "ER\n";
			send(client, reply, 3, 0);
			close(client);
		}
	}

} // namespace

namespace Initial2D {
namespace Platform {
namespace HotReloadServer {

	bool Start(int port)
	{
		if (g_running.load()) {
			return true;
		}

		g_listenFd = socket(AF_INET, SOCK_STREAM, 0);
		if (g_listenFd < 0) {
			return false;
		}

		const int enable = 1;
		setsockopt(g_listenFd, SOL_SOCKET, SO_REUSEADDR, &enable, sizeof(enable));

		sockaddr_in addr;
		std::memset(&addr, 0, sizeof(addr));
		addr.sin_family = AF_INET;
		// 루프백 전용 — adb forward로만 접근, 같은 네트워크의 타 기기는 차단
		addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
		addr.sin_port = htons(static_cast<uint16_t>(port));

		if (bind(g_listenFd, reinterpret_cast<sockaddr*>(&addr), sizeof(addr)) < 0 ||
			listen(g_listenFd, 1) < 0) {
			close(g_listenFd);
			g_listenFd = -1;
			return false;
		}

		g_running.store(true);
		g_thread = std::thread(ServerLoop);
		return true;
	}

	bool TakeBundle(std::vector<HotReloadFile>& out)
	{
		std::lock_guard<std::mutex> lock(g_bundleMutex);
		if (!g_hasPending) {
			return false;
		}
		out.swap(g_pendingBundle);
		g_pendingBundle.clear();
		g_hasPending = false;
		return true;
	}

	void Stop()
	{
		if (!g_running.load()) {
			return;
		}
		g_running.store(false);
		if (g_listenFd >= 0) {
			close(g_listenFd);
			g_listenFd = -1;
		}
		if (g_thread.joinable()) {
			g_thread.join();
		}
	}

} // namespace HotReloadServer
} // namespace Platform
} // namespace Initial2D

#endif // !RS_WINDOWS
