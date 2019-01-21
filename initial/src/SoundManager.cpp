/**
 * @file SoundManager.cpp
 * @date 2018/03/26 11:13
 *
 * @author biud436
 * Contact: biud436@gmail.com
 *
 * @brief 
 *
 * @note
*/

#include <SDL.h>
#include "SoundManager.h"

SoundManager* SoundManager::s_pInstance;

void musicFinished()
{
	SoundManager::Instance()->releaseMusic("null");
	SoundManager::Instance()->playNextMusic();
	Mix_HookMusicFinished(NULL);
}

SoundManager::SoundManager() : 
	m_previousMusicID("null"),
	m_currentMusicID("null"),
	m_nextMusicID(""),
	m_nextMusicLoop(-1)
{
	// 오디오 버퍼의 크기 (2048 bytes)
	Mix_OpenAudio(22050, AUDIO_S16, 2, 4096 / 2);
}

SoundManager::~SoundManager()
{
	Mix_CloseAudio();
}

bool SoundManager::load(std::string fileName, std::string id, sound_type type)
{
	if (type == SOUND_MUSIC) {
		Mix_Music* pMusic = Mix_LoadMUS(fileName.c_str());

		if (pMusic == 0)
		{
			return false;
		}

		m_music[id] = pMusic;
		return true;
	}
	else if (type == SOUND_SFX)
	{
		Mix_Chunk* pChunk = Mix_LoadWAV(fileName.c_str());
		
		if (pChunk == 0)
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
void SoundManager::playMusic(std::string id, int loop)
{
	// 음악이 재생 중이고, 재생하려는 음악이 현재 음악과 다르면
	if (isPlaying() && getCurrentMusicID() != id)
	{
		m_previousMusicID = getCurrentMusicID();
		insertNextMusic(id, loop);
		fadeOutMusic(1000);
		Mix_HookMusicFinished(musicFinished);
		return;
	}

	// 음악이 재생 중이고, 재생하려는 음악이 현재 음악과 같으면
	//if (isPlaying() && getCurrentMusicID() == id)
	//	return;

	Mix_FadeInMusic(m_music[id], loop, 1000);
	
	m_currentMusicID = id;

}

void SoundManager::insertNextMusic(std::string id, int loop)
{
	m_nextMusicID = id;
	m_nextMusicLoop = loop;
}

void SoundManager::playNextMusic()
{
	playMusic(m_nextMusicID, m_nextMusicLoop);
}

void SoundManager::pauseMusic()
{
	Mix_PauseMusic();
}

void SoundManager::resumeMusic()
{
	Mix_ResumeMusic();
}

void SoundManager::stopMusic()
{
	Mix_HaltMusic();
}

void SoundManager::setVolume(int volume)
{
	if (volume < 0) 
		volume = 0;

	// 연립 방정식으로 구한 변환 식이다.
	int n = 255;
	int f = 0;
	float a = 128.0f / (n - f);
	float b = 128.0f - ((128.0f * n) / (n - f));
	int c = static_cast<int>(a * (volume)+ b );
	
	Mix_VolumeMusic(c);
	Mix_Volume(-1, c);
}

void SoundManager::fadeOutMusic(int ms)
{
	Mix_FadeOutMusic(ms);
}

void SoundManager::setMusicPosition(double position)
{
	Mix_SetMusicPosition(position);
}

int SoundManager::getVolume()
{
	return Mix_VolumeMusic(-1);
}

void SoundManager::resetCurrentMusicID()
{
	m_currentMusicID = "null";
	m_previousMusicID = "null";
}

std::string SoundManager::getCurrentMusicID()
{
	return m_currentMusicID;
}

bool SoundManager::isPlaying()
{
	return Mix_PlayingMusic() == 1;
}

void SoundManager::releaseMusic(std::string id)
{
	if (id == "null") 
	{
		id = m_previousMusicID;
	}

	Mix_FreeMusic(m_music[id]);
	m_music.erase(id);
	resetCurrentMusicID();
}

void SoundManager::releaseSound(std::string id)
{
	Mix_FreeChunk(m_sfxs[id]);
	m_sfxs.erase(id);
}

void SoundManager::playSound(std::string id, int loop)
{
	// -1, 임의의 채널 할당
	// loop : 효과음의 반복 횟수.
	Mix_PlayChannel(-1, m_sfxs[id], loop);
}
