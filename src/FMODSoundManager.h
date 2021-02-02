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
	* �ν��Ͻ��� �����ϰų� ������ �ν��Ͻ��� �����ɴϴ�.
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
	* ����� ���Ͽ��� BGM �� ȿ������ ������ ���� �ʿ� �����մϴ�.
	*
	* @param fileName ���ϸ�
	* @param id ID ��
	* @param type ����. ȿ���� �Ǵ� BGM�� �����մϴ�.
	*
	* @return ����� ������ �����ϰ� �ε忡 �����ߴٸ� true, �ƴϸ� false.
	*
	*/
	bool load(std::string fileName, std::string id, sound_type type);

	/**
	* ȿ������ ����մϴ�.
	*/
	void playSound(std::string id, int loop);

	/**
	* BGM�� ����մϴ�.
	*/
	void playMusic(std::string id, int loop);

	/**
	* ������ ����� BGM�� �߰��մϴ�.
	*/
	void insertNextMusic(std::string id, int loop);

	/**
	* ���� BGM�� ����մϴ�.
	*/
	void playNextMusic();

	/**
	* BGM�� �Ͻ� �ߴ��մϴ�.
	*/
	void pauseMusic();

	/**
	* BGM ����� �簳�մϴ�.
	*/
	void resumeMusic();

	/**
	* BGM ����� ������ �ߴ��մϴ�.
	*/
	void stopMusic();

	/**
	* BGM�� ���̵� �ƿ��մϴ�.
	*/
	void fadeOutMusic(int ms);

	/**
	* BGM ��� ��ġ�� �����մϴ�.
	*/
	void setMusicPosition(double position);

	/**
	* BGM�� ������ �����մϴ�.
	*
	* @param volume 0 ~ 255. 0�� ���� ����. 255�� �ִ� ���� (������ 0���� 128������ �����մϴ�)
	*/
	void setVolume(int volume);

	/**
	* BGM�� ���� ���� �����ɴϴ�.
	* @return 0 ~ 255. 0�� ���� ����. 255�� �ִ� ����.
	*/
	int getVolume();

	/**
	* ���� ��� ���� BGM ID�� �����մϴ�.
	*/
	void resetCurrentMusicID();

	/**
	* ���� ��� ���� BGM�� ID�� �����ɴϴ�.
	*/
	std::string getCurrentMusicID();

	/**
	* BGM�� ����ǰ� �ִ� �� Ȯ���մϴ�.
	* @return BGM ��� ���� ��ȯ
	*/
	bool isPlaying();

	/**
	* Ư�� BGM�� �޸𸮸� �����մϴ�.
	*/
	void releaseMusic(std::string id);

	/**
	* Ư�� ȿ������ �޸𸮸� �����մϴ�.
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

	std::string m_previousMusicID; // ���� BGM ID
	std::string m_currentMusicID; // ���� BGM ID
	std::string m_nextMusicID; // ���� BGM ID
	int         m_nextMusicLoop; // ���� BGM �ݺ� ��� ���� 
};

#endif