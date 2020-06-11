#include "File.h"
#include "Constants.h"

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

	void File::open(std::string filename, const FileMode& mode)
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

	void File::close() 
	{
		fs->Close(m_pFilePointer);
		m_pFilePointer = nullptr;
		m_bIsOpen = false;
	}

	bool File::isOpen() const
	{
		return !m_bIsOpen || m_pFilePointer == nullptr;
	}

	size_t File::write(const void* ptr, size_t size, size_t count) 
	{
		size_t ret = 0;
		if (!isOpen()) {
			close();
			return ret;
		}

		ret = fs->Write(ptr, size, count, m_pFilePointer);

		return ret;
	}

	size_t File::write(const std::string& str)
	{
		size_t ret = 0;
		if (!isOpen()) {
			close();
			return ret;
		}

		ret = fs->Write(&str[0], str.size(), 1, m_pFilePointer);

		return ret;
	}

	void File::newLine()
	{
		write(LINE_BREAK);
	}

	size_t File::read(void* ptr, size_t size, size_t count)
	{
		size_t ret = 0;
		if (!isOpen()) {
			close();
			return ret;
		}

		ret = fs->Read(ptr, size, count, m_pFilePointer);

		return ret;
	}

	size_t File::read(const std::string& str, size_t size)
	{
		size_t ret = 0;
		if (!isOpen()) {
			close();
			return ret;
		}

		const char* ptr = str.c_str();
		void* voidp = reinterpret_cast<void*>(const_cast<char*>(ptr));
		ret = fs->Read(voidp, size, 1, m_pFilePointer);

		return ret;
	}

	int File::seek(long int offset, int origin)
	{
		int ret = 0;
		if (!isOpen()) {
			close();
			return ret;
		}

		ret = fs->Seek(m_pFilePointer, offset, origin);

		return ret;
	}

	long File::tell()
	{
		long ret = 0;
		if (!isOpen()) {
			close();
			return ret;
		}

		ret = fs->Tell(m_pFilePointer);

		return ret;
	}

	bool File::setPosition(const fpos_t* pos)
	{
		bool ret = false;
		if (!isOpen()) {
			close();
			return false;
		}

		ret = fs->SetPosition(m_pFilePointer, pos) != 0;

		return ret;
	
	}

}