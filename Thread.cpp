#include "Thread.h"



Thread::Thread() :
	m_hMutex(NULL),
	m_bWait(false)
{
	OutputDebugString("new Thread();\n");
	initWithLocker();
}

Thread::~Thread()
{
	OutputDebugString("~Thread();\n");
}

void Thread::initWithLocker() 
{
	m_hMutex = CreateMutex(NULL, FALSE, NULL);
}

UINT WINAPI Thread::Callback(LPVOID p)
{
	OutputDebugString("콜백이 실행되었습니다.\n");
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
	m_bWait = true;
	m_hThread = reinterpret_cast<void*>(_beginthreadex(nullptr, 0, Callback, static_cast<void*>(this), NULL, &m_nThreadId));
}
	
void Thread::lock()
{
	WaitForSingleObject(m_hMutex, INFINITE);
}

void Thread::run()
{
}

void Thread::unlock()
{
	ReleaseMutex(m_hMutex);
	m_bWait = false;
}

void Thread::join() {
	while (isWaiting()) {
		Sleep(1);
	}
}

bool Thread::isWaiting() const {
	return m_bWait;
}