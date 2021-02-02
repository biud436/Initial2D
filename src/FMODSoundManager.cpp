#include "FMODSoundManager.h"
#include "App.h"

FMODSoundManager* FMODSoundManager::s_pInstance;

void musicFinished()
{
	SoundManager::Instance()->releaseMusic("null");
	SoundManager::Instance()->playNextMusic();
	Mix_HookMusicFinished(NULL);
}

FMODSoundManager::FMODSoundManager() :
	m_previousMusicID("null"),
	m_currentMusicID("null"),
	m_nextMusicID(""),
	m_nextMusicLoop(-1)
{
	// FMOD 초기화
	FMOD_RESULT result;
	unsigned int version;
	void* extradriverdata = 0;

	result = FMOD::System_Create(&m_pSystem);
	if (result != FMOD_OK) 
	{
		throw new std::exception("FMOD System 초기화 실패");
	}

	result = m_pSystem->getVersion(&version);
	if (result != FMOD_OK)
	{
		throw new std::exception("Can't get the version of FMOD System.");
	}

	if (version < FMOD_VERSION)
	{
		std::string message = "FMOD lib version %08x doesn't match header version %08x";
		message.resize(255);

		sprintf(&message[0], &std::to_string(version)[0], FMOD_VERSION);
		throw new std::exception(&message[0]);
	}

	result = m_pSystem->init(32, FMOD_INIT_NORMAL, extradriverdata);
}

FMODSoundManager::~FMODSoundManager()
{
	FMOD_RESULT result;

	result = m_pSystem->close();
	if (result != FMOD_OK)
	{
		throw new std::exception("m_pSystem->close() has failed");
	}

	result = m_pSystem->release();
	if (result != FMOD_OK)
	{
		throw new std::exception("m_pSystem->release() has failed");
	}
}

bool FMODSoundManager::load(std::string fileName, std::string id, sound_type type)
{
	FMOD_RESULT result;

	if (type == SOUND_MUSIC) {
		
		FMOD::Sound* pMusic = nullptr;

		result = m_pSystem->createStream(fileName.data(), FMOD_LOOP_NORMAL | FMOD_2D, 0, &pMusic);
		if (result != FMOD_OK)
		{
			throw new std::exception("FMODSoundManager::load() has failed");
		}

		if (pMusic == nullptr)
		{
			return false;
		}

		m_music[id] = pMusic;
		return true;
	}
	else if (type == SOUND_SFX)
	{
		// Mix_Chunk* pChunk = Mix_LoadWAV(fileName.c_str());
		FMOD::Sound* pChunk = nullptr;
		result = m_pSystem->createSound(fileName.data(), FMOD_DEFAULT, 0, &pChunk);
		if (result != FMOD_OK)
		{
			throw new std::exception("FMODSoundManager::load() has failed");
		}
		
		if (pChunk == nullptr)
		{
			return false;
		}

		m_sfxs[id] = pChunk;
		return true;
	}

	return false;

}

// number of times to play through the music.
// 0 plays the music zero times...
// -1 plays the music forever (or as close as it can get to that)
void FMODSoundManager::playMusic(std::string id, int loop)
{
	FMOD::Channel* channel = 0;

	// 음악이 재생 중이고, 재생하려는 음악이 현재 음악과 다르면
	if (isPlaying() && getCurrentMusicID() != id)
	{
		m_previousMusicID = getCurrentMusicID();
		insertNextMusic(id, loop);
		fadeOutMusic(1000);
		
		// Mix_HookMusicFinished(musicFinished);
		m_pSystem->playSound(m_music[id], 0, false, &channel);
		m_channel[id] = channel;

		return;
	}

	// 음악이 재생 중이고, 재생하려는 음악이 현재 음악과 같으면
	//if (isPlaying() && getCurrentMusicID() == id)
	//	return;

	// Mix_FadeInMusic(m_music[id], loop, 1000);

	m_currentMusicID = id;

}

void FMODSoundManager::insertNextMusic(std::string id, int loop)
{
	m_nextMusicID = id;
	m_nextMusicLoop = loop;
}

void FMODSoundManager::playNextMusic()
{
	playMusic(m_nextMusicID, m_nextMusicLoop);
}

void FMODSoundManager::pauseMusic()
{
	FMOD_RESULT result;

	if (isPlaying()) {
		std::string id = getCurrentMusicID();
		
		if (m_channel[id] != nullptr) {

			// pause 상태인가?
			bool paused = false;
			result = m_channel[id]->getPaused(&paused);

			// pause 토글
			m_channel[id]->setPaused(!paused);
		}
	}
}

void FMODSoundManager::resumeMusic()
{
	// Mix_ResumeMusic();

}

void FMODSoundManager::stopMusic()
{
	Mix_HaltMusic();
}

void FMODSoundManager::setVolume(int volume)
{
	if (volume < 0)
		volume = 0;

	// 연립 방정식으로 구한 변환 식이다.
	int n = 255;
	int f = 0;
	float a = 128.0f / (n - f);
	float b = 128.0f - ((128.0f * n) / (n - f));
	int c = static_cast<int>(a * (volume)+b);

	Mix_VolumeMusic(c);
	Mix_Volume(-1, c);
}

void FMODSoundManager::fadeOutMusic(int ms)
{
	Mix_FadeOutMusic(ms);
}

void FMODSoundManager::setMusicPosition(double position)
{
	Mix_SetMusicPosition(position);
}

int FMODSoundManager::getVolume()
{
	return Mix_VolumeMusic(-1);
}

void FMODSoundManager::resetCurrentMusicID()
{
	m_currentMusicID = "null";
	m_previousMusicID = "null";
}

std::string FMODSoundManager::getCurrentMusicID()
{
	return m_currentMusicID;
}

bool FMODSoundManager::isPlaying()
{
	bool isPlaying = false;
	std::string id = getCurrentMusicID();

	FMOD::Channel* channel = m_channel[id];
	
	if (channel != nullptr) {
		channel->isPlaying(&isPlaying);
	}

	return isPlaying;
}

void FMODSoundManager::releaseMusic(std::string id)
{
	if (id == "null")
	{
		id = m_previousMusicID;
	}
	
	FMOD_RESULT result;

	FMOD::Sound* sound = m_music[id];

	m_music.erase(id);

	result = sound->release();
	resetCurrentMusicID();
}

void FMODSoundManager::releaseSound(std::string id)
{
	FMOD_RESULT result;
	
	FMOD::Sound* sound = m_sfxs[id];

	result = sound->release();

	m_sfxs.erase(id);
}

void FMODSoundManager::playSound(std::string id, int loop)
{
	// -1, 임의의 채널 할당
	// loop : 효과음의 반복 횟수.
	// Mix_PlayChannel(-1, m_sfxs[id], loop);

	FMOD::Sound* sound = m_sfxs[id];
	FMOD::Channel* channel = 0;

	if (sound != nullptr) {
		m_pSystem->playSound(sound, 0, false, &channel);
	}
}

void FMODSoundManager::update()
{
	FMOD_RESULT  result;
	unsigned int ms = 0;
	unsigned int lenms = 0;
	bool         playing = 0;
	bool         paused = 0;
	int          channelsplaying = 0;

	result = m_pSystem->update();

	if ( isPlaying() ) {
		
	}
}
