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
 * 사운드 모듈
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
 * @brief 사운드 모듈
 * @details https://www.libsdl.org/projects/SDL_mixer/docs/SDL_mixer_toc.html#SEC_Contents
 */
class SoundManager : private noncopyable
{
private:
	SoundManager();
	virtual ~SoundManager();
public:
	
	/**
	* 인스턴스를 생성하거나 생성된 인스턴스를 가져옵니다.
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

private:

	static SoundManager* s_pInstance;

	SoundManager(const SoundManager&);
	SoundManager& operator=(const SoundManager&);

	BGM         m_music;	// BGM
	SE          m_sfxs;	// SE

	std::string m_previousMusicID; // 이전 BGM ID
	std::string m_currentMusicID; // 현재 BGM ID
	std::string m_nextMusicID; // 다음 BGM ID
	int         m_nextMusicLoop; // 다음 BGM 반복 재생 여부 
		
};

/**
* @def Audio
* 싱글턴에 접근하는 것이지만, 객체 변수처럼 사용하기 위한 트릭.
*/
#define Audio SoundManager::Instance()

/**
 * @}
 */

#endif