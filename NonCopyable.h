#ifndef _NONCOPYABLE_H_
#define _NONCOPYABLE_H_

class noncopyable {
public:
	noncopyable() {}
	~noncopyable() {}
private:
	noncopyable(const noncopyable&);
	noncopyable& operator=(noncopyable&);
};

#endif