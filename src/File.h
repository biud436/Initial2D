#ifndef __FILE_H
#define __FILE_H

#include <cstdio>
#include <string>

namespace Initial2D {

	namespace FileInterface {
		typedef FILE* (*FileOpen)(const char* filename, const char* mode);
		typedef int(*FileClose)(FILE* stream);
		typedef size_t(*FileWrite)(const void* ptr, size_t size, size_t count, FILE* stream);
		typedef size_t(*FileRead)(void* ptr, size_t size, size_t count, FILE* stream);
		typedef int(*FileSeek)(FILE* stream, long int offset, int origin);
		typedef long int(*FileTell)(FILE* stream);
		typedef int(*FileSetPosition)(FILE* stream, const fpos_t* pos);

		typedef struct _FS {
			FileOpen Open;
			FileClose Close;
			FileWrite Write;
			FileRead Read;
			FileTell Tell;
			FileSeek Seek;
			FileSetPosition SetPosition;

			void Initialize();
			void Remove();

		} FileSystem;

	}

	FileInterface::FileSystem fs;

	enum FileMode {
		BinaryWrite = 0,
		BinrayRead,
		TextWrite,
		TextRead
	};

	class File
	{
	public:
		File();
		virtual ~File();

		virtual void Open(std::string filename, const FileMode& mode);
		virtual void Close();
		virtual size_t Write(const void* ptr, size_t size, size_t count);
		virtual size_t Read(void* ptr, size_t size, size_t count);
		virtual int Seek(long int offset, int origin);
		virtual long Tell();
		virtual bool SetPosition(const fpos_t* pos);

	private:
		FILE* m_pFilePointer;
		bool m_bIsOpen;

		File(const File&); // 복사 생성자 방지
		File& operator=(const File&); // 대입 연산자 방지
	};

	class TextFile : public File
	{
		TextFile() : File() {};
		virtual ~TextFile();
	};

}

#endif
