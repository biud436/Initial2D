#ifndef __THREAD_H_
#define __THREAD_H_

#define WIN32_LEAN_AND_MEAN
#include <Windows.h>
#include <process.h>

class Thread
{
public:
	Thread();
	virtual ~Thread();

	void initWithLocker();
	virtual void start();
	static UINT WINAPI Callback(LPVOID p);
	void lock();
	virtual void run();
	void unlock();
	void join();

	bool isWaiting() const;
private:
	HANDLE m_hMutex;
	HANDLE m_hThread;
	unsigned int m_nThreadId;
	bool m_bWait;
};

#endif