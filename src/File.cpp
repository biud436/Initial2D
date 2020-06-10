#include "File.h"

namespace Initial2D {

	namespace FileInterface {

		void FileSystem::Initialize() {
			Open = fopen;
			Close = fclose;
			Write = fwrite;
			Read = fread;
			Tell = ftell;
			Seek = fseek;
			SetPosition = fsetpos;
		}

		void FileSystem::Remove() {
			Open = nullptr;
			Close = nullptr;
			Write = nullptr;
			Read = nullptr;
			Tell = nullptr;
			Seek = nullptr;
			SetPosition = nullptr;
		}

	}

	File::File() : 
		m_pFilePointer(nullptr),
		fs(std::make_unique<FileInterface::FileSystem>())
	{
		fs->Initialize();
	}

	File::~File() 
	{
		fs->Remove();
		fs.reset();
	}

	void File::Open(std::string filename, const FileMode& mode)
	{
		std::string filemode = "rb";

		// 파일 모드를 설정합니다.
		switch (mode) {
		case FileMode::BinaryWrite:
			filemode = "wb";
			break;
		case FileMode::BinrayRead:
			filemode = "rb";
			break;
		case FileMode::TextWrite:
			filemode = "wt";
			break;
		case FileMode::TextRead:
			filemode = "rt";
			break;
		}

		// 파일을 오픈합니다.
		m_pFilePointer = fs->Open(filename.c_str(), filemode.c_str());
		m_bIsOpen = true;
	}

	void File::Close() 
	{
		fs->Close(m_pFilePointer);
		m_pFilePointer = nullptr;
		m_bIsOpen = false;
	}

	bool File::isInValid()
	{
		return !m_bIsOpen || m_pFilePointer == nullptr;
	}

	size_t File::Write(const void* ptr, size_t size, size_t count) 
	{
		size_t ret = 0;
		if (isInValid()) {
			Close();
			return ret;
		}

		ret = fs->Write(ptr, size, count, m_pFilePointer);

		return ret;
	}

	size_t File::Write(const std::string& str)
	{
		size_t ret = 0;
		if (isInValid()) {
			Close();
			return ret;
		}

		ret = fs->Write(&str[0], str.size(), 1, m_pFilePointer);

		return ret;
	}

	size_t File::Read(void* ptr, size_t size, size_t count)
	{
		size_t ret = 0;
		if (isInValid()) {
			Close();
			return ret;
		}

		ret = fs->Read(ptr, size, count, m_pFilePointer);

		return ret;
	}

	size_t File::Read(const std::string& str, size_t size)
	{
		size_t ret = 0;
		if (isInValid()) {
			Close();
			return ret;
		}

		const char* ptr = str.c_str();
		void* voidp = reinterpret_cast<void*>(const_cast<char*>(ptr));
		ret = fs->Read(voidp, size, 1, m_pFilePointer);
	}

	int File::Seek(long int offset, int origin)
	{
		int ret = 0;
		if (isInValid()) {
			Close();
			return ret;
		}

		ret = fs->Seek(m_pFilePointer, offset, origin);

		return ret;
	}

	long File::Tell()
	{
		long ret = 0;
		if (isInValid()) {
			Close();
			return ret;
		}

		ret = fs->Tell(m_pFilePointer);

		return ret;
	}

	bool File::SetPosition(const fpos_t* pos)
	{
		bool ret = false;
		if (isInValid()) {
			Close();
			return false;
		}

		ret = fs->SetPosition(m_pFilePointer, pos) != 0;

		return ret;
	
	}

}