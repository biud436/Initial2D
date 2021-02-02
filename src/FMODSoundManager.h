#ifndef __FMOD_SOUND_MANAGER_H__
#define __FMOD_SOUND_MANAGER_H__

#include "SoundManager.h"
#include "NonCopyable.h"
#include <fmod.hpp>

/**
* @enum sound_type
*/
enum sound_type
{
	SOUND_MUSIC = 0,	/**		BGM	*/
	SOUND_SFX			/**		SE	*/
};

using BGM = std::map<std::string, FMOD::Sound*>;
using SE = std::map<std::string, FMOD::Sound*>;
using BGMChannel = std::map<std::string, FMOD::Channel*>;

class FMODSoundManager : private UnCopyable
{
private:
	FMODSoundManager();
	~FMODSoundManager();

public:

	/**
	* 인스턴스를 생성하거나 생성된 인스턴스를 가져옵니다.
	*/
	static FMODSoundManager* Instance()
	{
		if (s_pInstance == NULL)
		{
			s_pInstance = new FMODSoundManager();
			return s_pInstance;
		}

		return s_pInstance;

	}

	/**
	*
	* 오디오 파일에서 BGM 및 효과음을 가져와 사운드 맵에 저장합니다.
	*
	* @param fileName 파일명
	* @param id ID 값
	* @param type 유형. 효과음 또는 BGM을 지정합니다.
	*
	* @return 오디오 파일이 존재하고 로드에 성공했다면 true, 아니면 false.
	*
	*/
	bool load(std::string fileName, std::string id, sound_type type);

	/**
	* 효과음을 재생합니다.
	*/
	void playSound(std::string id, int loop);

	/**
	* BGM을 재생합니다.
	*/
	void playMusic(std::string id, int loop);

	/**
	* 다음에 재생될 BGM을 추가합니다.
	*/
	void insertNextMusic(std::string id, int loop);

	/**
	* 다음 BGM을 재생합니다.
	*/
	void playNextMusic();

	/**
	* BGM을 일시 중단합니다.
	*/
	void pauseMusic();

	/**
	* BGM 재생을 재개합니다.
	*/
	void resumeMusic();

	/**
	* BGM 재생을 완전히 중단합니다.
	*/
	void stopMusic();

	/**
	* BGM을 페이드 아웃합니다.
	*/
	void fadeOutMusic(int ms);

	/**
	* BGM 재생 위치를 설정합니다.
	*/
	void setMusicPosition(double position);

	/**
	* BGM의 볼륨을 설정합니다.
	*
	* @param volume 0 ~ 255. 0은 볼륨 없음. 255은 최대 볼륨 (범위를 0에서 128까지로 보간합니다)
	*/
	void setVolume(int volume);

	/**
	* BGM의 볼륨 값을 가져옵니다.
	* @return 0 ~ 255. 0은 볼륨 없음. 255는 최대 볼륨.
	*/
	int getVolume();

	/**
	* 현재 재생 중인 BGM ID를 리셋합니다.
	*/
	void resetCurrentMusicID();

	/**
	* 현재 재생 중인 BGM의 ID를 가져옵니다.
	*/
	std::string getCurrentMusicID();

	/**
	* BGM이 재생되고 있는 지 확인합니다.
	* @return BGM 재생 여부 반환
	*/
	bool isPlaying();

	/**
	* 특정 BGM의 메모리를 해제합니다.
	*/
	void releaseMusic(std::string id);

	/**
	* 특정 효과음의 메모리를 해제합니다.
	*/
	void releaseSound(std::string id);


	void update();

private:
	static FMODSoundManager* s_pInstance;

	FMODSoundManager(const FMODSoundManager&);
	FMODSoundManager& operator=(const FMODSoundManager&);

	FMOD::System* m_pSystem;

	BGM         m_music;	// BGM
	SE          m_sfxs;		// SE
	BGMChannel  m_channel;

	std::string m_previousMusicID; // 이전 BGM ID
	std::string m_currentMusicID; // 현재 BGM ID
	std::string m_nextMusicID; // 다음 BGM ID
	int         m_nextMusicLoop; // 다음 BGM 반복 재생 여부 
};

#endif