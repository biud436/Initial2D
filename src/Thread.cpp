#include "Thread.h"
#include <cstdio>

// 원본 구현의 OutputDebugString 트레이스에 대응. 디버거 대신 stderr로 출력한다.
#ifndef NDEBUG
#define THREAD_TRACE(MSG) std::fputs(MSG, stderr)
#else
#define THREAD_TRACE(MSG)
#endif

Thread::Thread() :
	m_bWait(false)
{
	THREAD_TRACE("new Thread();\n");
	initWithLocker();
}

Thread::~Thread()
{
	THREAD_TRACE("~Thread();\n");
	// 원본 구현은 스레드 핸들을 회수하지 않고 방치했다.
	// std::thread는 joinable 상태로 소멸하면 terminate되므로 동등한 동작인 detach를 수행한다.
	if (m_thread.joinable()) {
		m_thread.detach();
	}
}

void Thread::initWithLocker()
{
	// std::mutex는 별도의 초기화가 필요 없다. 원본 인터페이스 유지를 위해 남겨둔다.
}

unsigned int Thread::Callback(void* p)
{
	THREAD_TRACE("Callback();\n");
	Thread* thread = reinterpret_cast<Thread*>(p);
	if (thread == nullptr)
	{
		return 0;
	}

	thread->lock();

	thread->run();

	thread->unlock();
	return 0;
}

void Thread::start()
{
	// 원본은 재시작 시 이전 핸들을 덮어썼다. joinable 상태에서의 대입은 terminate이므로 먼저 분리한다.
	if (m_thread.joinable()) {
		m_thread.detach();
	}
	m_bWait = true;
	m_thread = std::thread(&Thread::Callback, static_cast<void*>(this));
}

void Thread::lock()
{
	m_mutex.lock();
}

void Thread::run()
{
}

void Thread::unlock()
{
	m_mutex.unlock();
	m_bWait = false;
}

void Thread::join() {
	if (m_thread.joinable()) {
		m_thread.join();
	}
	m_bWait = false;
}

bool Thread::isWaiting() const {
	return m_bWait;
}
