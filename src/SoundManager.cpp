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
#include <atomic>
#include <cstdio>
#include "SoundManager.h"

SoundManager* SoundManager::s_pInstance;

namespace
{
	// SDL_mixer가 곡이 멈출 때(끝까지 재생, Mix_HaltMusic, 페이드 아웃 끝) 오디오 스레드에서 부른다.
	// 여기서는 표시만 하고, 처리는 메인 스레드의 SoundManager::update()가 한다.
	std::atomic<bool> s_musicStopped(false);

	void SDLCALL OnMusicStopped()
	{
		s_musicStopped.store(true);
	}
}

SoundManager::SoundManager() : 
	m_previousMusicID("null"),
	m_currentMusicID("null"),
	m_switchMusicID(""),
	m_switchMusicLoop(-1),
	m_nextMusicID(""),
	m_nextMusicLoop(-1),
	m_volume(255)
{
	// 오디오 버퍼의 크기 (2048 bytes)
	Mix_OpenAudio(22050, AUDIO_S16, 2, 4096 / 2);
	Mix_HookMusicFinished(OnMusicStopped);
}

SoundManager::~SoundManager()
{
	Mix_HookMusicFinished(NULL);
	Mix_CloseAudio();
}

bool SoundManager::load(std::string fileName, std::string id, sound_type type)
{
	// 같은 id가 이미 로드되어 있으면 다시 읽지 않는다.
	// (PlaySound가 호출마다 load를 부르므로, 이 캐시가 없으면 재생할 때마다
	//  디스크 I/O가 발생하고 이전 청크가 누수되어 간헐적인 프레임 히치를 만든다)
	if (type == SOUND_MUSIC && m_music.find(id) != m_music.end()) {
		return true;
	}
	if (type == SOUND_SFX && m_sfxs.find(id) != m_sfxs.end()) {
		return true;
	}

	if (type == SOUND_MUSIC) {
		Mix_Music* pMusic = Mix_LoadMUS(fileName.c_str());

		if (pMusic == 0)
		{
			reportLoadError(fileName);
			return false;
		}

		m_music[id] = pMusic;
		m_failedPaths.erase(fileName);
		return true;
	}
	else if (type == SOUND_SFX)
	{
		Mix_Chunk* pChunk = Mix_LoadWAV(fileName.c_str());
		
		if (pChunk == 0)
		{
			reportLoadError(fileName);
			return false;
		}

		m_sfxs[id] = pChunk;
		m_failedPaths.erase(fileName);
		return true;
	}

	return false;

}

void SoundManager::reportLoadError(const std::string& fileName)
{
	// 같은 경로를 틱마다 재생하려는 스크립트가 같은 줄을 반복해 찍지 않게 한다
	if (m_failedPaths.insert(fileName).second)
	{
		std::fprintf(stderr, "Audio: cannot load %s (%s)\n", fileName.c_str(), Mix_GetError());
	}
}

// number of times to play through the music.
// 0 plays the music zero times...
// -1 plays the music forever (or as close as it can get to that)
void SoundManager::playMusic(std::string id, int loop)
{
	BGM::iterator music = m_music.find(id);
	if (music == m_music.end())
	{
		return;
	}

	// 다른 곡이 재생 중이면 그 곡을 1초 동안 페이드 아웃한다. 새 곡은 페이드 아웃이 끝난 뒤
	// update()가 이 함수를 다시 불러 시작한다 (Mix_FadeInMusic은 페이드 아웃이 끝날 때까지 기다리기 때문이다).
	if (isPlaying() && (getCurrentMusicID() != id || !m_switchMusicID.empty()))
	{
		if (m_switchMusicID.empty())
		{
			m_previousMusicID = getCurrentMusicID();
		}
		m_switchMusicID = id;
		m_switchMusicLoop = loop;
		Mix_FadeOutMusic(1000);
		return;
	}

	m_switchMusicID.clear();
	Mix_FadeInMusic(music->second, loop, 1000);
	m_currentMusicID = id;
	releasePreviousMusic();
}

void SoundManager::insertNextMusic(std::string id, int loop)
{
	if (m_music.find(id) == m_music.end())
	{
		return;
	}

	m_nextMusicID = id;
	m_nextMusicLoop = loop;

	if (!isPlaying() && m_switchMusicID.empty())
	{
		startNextMusic();
	}
}

void SoundManager::startNextMusic()
{
	const std::string id = m_nextMusicID;
	m_nextMusicID.clear();

	BGM::iterator music = m_music.find(id);
	if (music == m_music.end())
	{
		return;
	}

	Mix_PlayMusic(music->second, m_nextMusicLoop);
	m_currentMusicID = id;
}

void SoundManager::update()
{
	// 표시가 남아 있어도 지금 곡이 재생 중이면 그 표시는 이미 지나간 곡의 것이다
	if (!s_musicStopped.exchange(false) || isPlaying())
	{
		return;
	}

	if (!m_switchMusicID.empty())
	{
		playMusic(m_switchMusicID, m_switchMusicLoop);
		return;
	}

	if (!m_nextMusicID.empty())
	{
		startNextMusic();
	}
}

void SoundManager::releasePreviousMusic()
{
	const std::string id = m_previousMusicID;
	m_previousMusicID = "null";

	if (id != "null" && id != m_currentMusicID && id != m_nextMusicID)
	{
		releaseMusic(id);
	}
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
	m_switchMusicID.clear();
	m_nextMusicID.clear();
	m_previousMusicID = "null";
	Mix_HaltMusic();
}

void SoundManager::setVolume(int volume)
{
	if (volume < 0) 
		volume = 0;
	if (volume > 255)
		volume = 255;

	m_volume = volume;

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
	m_switchMusicID.clear();
	m_nextMusicID.clear();
	m_previousMusicID = "null";
	Mix_FadeOutMusic(ms);
}

void SoundManager::setMusicPosition(double position)
{
	Mix_SetMusicPosition(position);
}

int SoundManager::getVolume()
{
	return m_volume;
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
	BGM::iterator music = m_music.find(id);
	if (music == m_music.end())
	{
		return;
	}

	if (m_switchMusicID == id)
	{
		m_switchMusicID.clear();
	}
	if (m_nextMusicID == id)
	{
		m_nextMusicID.clear();
	}
	if (m_currentMusicID == id)
	{
		m_currentMusicID = "null";
	}
	if (m_previousMusicID == id)
	{
		m_previousMusicID = "null";
	}

	// 재생 중인 곡이면 Mix_FreeMusic이 멈춘다 (곡 종료 콜백은 부르지 않는다)
	Mix_FreeMusic(music->second);
	m_music.erase(music);
}

void SoundManager::releaseSound(std::string id)
{
	SE::iterator sound = m_sfxs.find(id);
	if (sound == m_sfxs.end())
	{
		return;
	}

	Mix_FreeChunk(sound->second);
	m_sfxs.erase(sound);
}

void SoundManager::playSound(std::string id, int loop)
{
	SE::iterator sound = m_sfxs.find(id);
	if (sound == m_sfxs.end())
	{
		return;
	}

	// -1, 임의의 채널 할당
	// loop : 효과음의 반복 횟수.
	Mix_PlayChannel(-1, sound->second, loop);
}
