#ifndef __FILE_H
#define __FILE_H
#define _CRT_SECURE_NO_WARNINGS

#include <cstdio>
#include <string>
#include <fstream>
#include <memory>

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

		void Open(std::string filename, const FileMode& mode);
		void Close();
		size_t Write(const void* ptr, size_t size, size_t count);
		size_t Write(const std::string& str);
		size_t Read(void* ptr, size_t size, size_t count);
		size_t Read(const std::string& str, size_t size);
		int Seek(long int offset, int origin);
		long Tell();
		bool SetPosition(const fpos_t* pos);

		bool isInValid();

	private:
		FILE* m_pFilePointer;
		bool m_bIsOpen;
		std::unique_ptr<FileInterface::FileSystem> fs;

		File(const File&); // 복사 생성자 방지
		File& operator=(const File&); // 대입 연산자 방지
	};

}

#endif
