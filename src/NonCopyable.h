#ifndef _NONCOPYABLE_H_
#define _NONCOPYABLE_H_

class UnCopyable {
public:
	UnCopyable() {}
	~UnCopyable() {}
private:
	UnCopyable(const UnCopyable&);
	UnCopyable& operator=(UnCopyable&);
};

#endif