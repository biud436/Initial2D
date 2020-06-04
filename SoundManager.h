/**
 * @file SoundManager.h
 * @date 2018/03/26 11:13
 *
 * @author biud436
 * Contact: biud436@gmail.com
 *
 * @brief 
 *
 * @note
*/

#ifndef SOUNDMANAGER_H
#define SOUNDMANAGER_H

#include <string>
#include <map>
#include <SDL_mixer.h>
#include "NonCopyable.h"

/**
 * @addtogroup SoundModule
 * ���� ���
 * @{
 */

/**
* @enum sound_type
*/
enum sound_type
{
	SOUND_MUSIC = 0,	/**		BGM	*/
	SOUND_SFX			/**		SE	*/
	//SOUND_BGS			/**		BGS	*/
};

using BGM = std::map<std::string, Mix_Music*>;
using SE = std::map<std::string, Mix_Chunk*>; 

/**
 * @class SoundManager
 * @brief ���� ���
 * @details https://www.libsdl.org/projects/SDL_mixer/docs/SDL_mixer_toc.html#SEC_Contents
 */
class SoundManager : private noncopyable
{
private:
	SoundManager();
	virtual ~SoundManager();
public:
	
	/**
	* �ν��Ͻ��� �����ϰų� ������ �ν��Ͻ��� �����ɴϴ�.
	*/
	static SoundManager* Instance()
	{
		if (s_pInstance == NULL)
		{
			s_pInstance = new SoundManager();
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

private:

	static SoundManager* s_pInstance;

	SoundManager(const SoundManager&);
	SoundManager& operator=(const SoundManager&);

	BGM         m_music;	// BGM
	SE          m_sfxs;	// SE

	std::string m_previousMusicID; // ���� BGM ID
	std::string m_currentMusicID; // ���� BGM ID
	std::string m_nextMusicID; // ���� BGM ID
	int         m_nextMusicLoop; // ���� BGM �ݺ� ��� ���� 
		
};

/**
* @def Audio
* �̱��Ͽ� �����ϴ� ��������, ��ü ����ó�� ����ϱ� ���� Ʈ��.
*/
#define Audio SoundManager::Instance()

/**
 * @}
 */

#endif