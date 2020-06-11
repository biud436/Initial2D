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

		void open(std::string filename, const FileMode& mode);
		void close();
		size_t write(const void* ptr, size_t size, size_t count);
		size_t write(const std::string& str);
		void newLine();
		size_t read(void* ptr, size_t size, size_t count);
		size_t read(const std::string& str, size_t size);
		int seek(long int offset, int origin);
		long tell();
		bool setPosition(const fpos_t* pos);

		bool isOpen() const;

	private:
		FILE* m_pFilePointer;
		bool m_bIsOpen;
		std::unique_ptr<FileInterface::FileSystem> fs;

		File(const File&); // ���� ������ ����
		File& operator=(const File&); // ���� ������ ����
	};

}

#endif
