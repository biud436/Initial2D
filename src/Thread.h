#ifndef __THREAD_H_
#define __THREAD_H_

// C++ 표준 라이브러리 기반 스레드 (macOS 포팅 Phase 1에서 공통화).
// 원본 Win32 구현(_beginthreadex/CreateMutex)은 src/platform/win32/legacy/ 와
// archive/windows-gdi 브랜치에 보존되어 있다. 공개 인터페이스는 원본과 동일하다.

#include <thread>
#include <mutex>

class Thread
{
public:
	Thread();
	virtual ~Thread();

	void initWithLocker();
	virtual void start();
	static unsigned int Callback(void* p);
	void lock();
	virtual void run();
	void unlock();
	void join();

	bool isWaiting() const;
private:
	std::mutex m_mutex;
	std::thread m_thread;
	bool m_bWait;
};

#endif
