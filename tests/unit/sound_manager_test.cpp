/**
 * @file sound_manager_test.cpp
 * @brief SoundManager의 볼륨, 읽기 실패 알림, 곡 예약과 전환 (src/SoundManager.cpp).
 *
 * SDL 더미 오디오 장치로 연다. 더미 장치도 실제 시간에 맞춰 버퍼를 소비하므로 짧은 WAV 곡은
 * 수십 ms 뒤에 저절로 끝난다. 곡이 멈춘 뒤의 처리는 게임 루프처럼 update()를 불러 진행한다.
 */
#include "test_framework.h"

#include "SoundManager.h"

#include <SDL.h>

#include <cstdint>
#include <cstdio>
#include <filesystem>
#include <fstream>
#include <functional>
#include <string>

#ifndef _WIN32
#include <unistd.h>
#endif

namespace {

void PutU32(std::ofstream& out, uint32_t v)
{
	const char b[4] = { char(v & 0xff), char((v >> 8) & 0xff), char((v >> 16) & 0xff), char((v >> 24) & 0xff) };
	out.write(b, 4);
}

void PutU16(std::ofstream& out, uint16_t v)
{
	const char b[2] = { char(v & 0xff), char((v >> 8) & 0xff) };
	out.write(b, 2);
}

/** 임시 폴더에 무음 16비트 모노 22050Hz WAV 파일을 쓰고 경로를 돌려준다. */
std::string WriteSilentWav(const char* name, int milliseconds)
{
	const uint32_t rate = 22050;
	const uint32_t dataBytes = rate * static_cast<uint32_t>(milliseconds) / 1000 * 2;
	const std::string path = (std::filesystem::temp_directory_path() / name).string();

	std::ofstream out(path, std::ios::binary);
	out.write("RIFF", 4);
	PutU32(out, 36 + dataBytes);
	out.write("WAVEfmt ", 8);
	PutU32(out, 16);
	PutU16(out, 1);         // PCM
	PutU16(out, 1);         // 모노
	PutU32(out, rate);
	PutU32(out, rate * 2);  // 초당 바이트
	PutU16(out, 2);         // 블록 정렬
	PutU16(out, 16);        // 샘플 비트
	out.write("data", 4);
	PutU32(out, dataBytes);
	const std::string silence(dataBytes, '\0');
	out.write(silence.data(), silence.size());
	return path;
}

SoundManager* OpenAudio()
{
	SDL_setenv("SDL_AUDIODRIVER", "dummy", 1);
	return SoundManager::Instance();
}

/** 게임 루프처럼 10ms마다 update()를 부르며 cond가 참이 되기를 기다린다. */
bool WaitUntil(const std::function<bool()>& cond, int timeoutMs)
{
	for (int waited = 0; waited <= timeoutMs; waited += 10) {
		Audio->update();
		if (cond()) {
			return true;
		}
		SDL_Delay(10);
	}
	return false;
}

void StopAndSettle()
{
	Audio->stopMusic();
	WaitUntil([] { return !Audio->isPlaying(); }, 500);
	Audio->update();
}

} // namespace

TEST(sound_volume_round_trip)
{
	SoundManager* audio = OpenAudio();

	audio->setVolume(200);
	CHECK_EQ(audio->getVolume(), 200);
	CHECK_EQ(Mix_VolumeMusic(-1), 128 * 200 / 255);

	audio->setVolume(300);
	CHECK_EQ(audio->getVolume(), 255);
	CHECK_EQ(Mix_VolumeMusic(-1), 128);

	audio->setVolume(-5);
	CHECK_EQ(audio->getVolume(), 0);
	CHECK_EQ(Mix_VolumeMusic(-1), 0);

	audio->setVolume(255);
}

#ifndef _WIN32
TEST(sound_load_failure_is_reported_once_per_path)
{
	SoundManager* audio = OpenAudio();
	const std::string logPath = (std::filesystem::temp_directory_path() / "initial2d_sound_stderr.txt").string();
	const std::string folder = std::filesystem::temp_directory_path().string() + "/";

	std::fflush(stderr);
	const int saved = dup(fileno(stderr));
	FILE* log = std::fopen(logPath.c_str(), "w");
	dup2(fileno(log), fileno(stderr));

	const bool missing1 = audio->load("./no_such_dir/missing.wav", "missing_se", SOUND_SFX);
	const bool missing2 = audio->load("./no_such_dir/missing.wav", "missing_se", SOUND_SFX);
	const bool dir = audio->load(folder, "folder_se", SOUND_SFX);

	std::fflush(stderr);
	dup2(saved, fileno(stderr));
	close(saved);
	std::fclose(log);

	CHECK(!missing1);
	CHECK(!missing2);
	CHECK(!dir);

	std::ifstream in(logPath);
	std::string line;
	int missingLines = 0;
	int folderLines = 0;
	while (std::getline(in, line)) {
		if (line.find("Audio: cannot load ./no_such_dir/missing.wav") == 0) {
			++missingLines;
		}
		if (line.find("Audio: cannot load " + folder) == 0) {
			++folderLines;
		}
	}
	CHECK_EQ(missingLines, 1);
	CHECK_EQ(folderLines, 1);
	std::remove(logPath.c_str());
}
#endif

TEST(sound_inserted_music_plays_after_the_current_one_ends)
{
	SoundManager* audio = OpenAudio();
	CHECK(audio->load(WriteSilentWav("initial2d_short.wav", 80), "short", SOUND_MUSIC));
	CHECK(audio->load(WriteSilentWav("initial2d_long_a.wav", 3000), "long_a", SOUND_MUSIC));
	StopAndSettle();

	audio->playMusic("short", 1);
	audio->insertNextMusic("long_a", -1);
	CHECK_EQ(audio->getCurrentMusicID(), std::string("short"));

	const bool next = WaitUntil([&] {
		return audio->getCurrentMusicID() == "long_a" && audio->isPlaying();
	}, 2000);
	CHECK(next);

	StopAndSettle();
}

TEST(sound_inserted_music_plays_at_once_when_nothing_plays)
{
	SoundManager* audio = OpenAudio();
	CHECK(audio->load(WriteSilentWav("initial2d_long_a.wav", 3000), "long_a", SOUND_MUSIC));
	StopAndSettle();

	audio->insertNextMusic("long_a", -1);
	CHECK(audio->isPlaying());
	CHECK_EQ(audio->getCurrentMusicID(), std::string("long_a"));

	StopAndSettle();
}

TEST(sound_stop_cancels_the_inserted_music)
{
	SoundManager* audio = OpenAudio();
	CHECK(audio->load(WriteSilentWav("initial2d_short.wav", 80), "short", SOUND_MUSIC));
	CHECK(audio->load(WriteSilentWav("initial2d_long_a.wav", 3000), "long_a", SOUND_MUSIC));
	StopAndSettle();

	audio->playMusic("short", -1);
	audio->insertNextMusic("long_a", -1);
	audio->stopMusic();

	const bool started = WaitUntil([&] { return audio->isPlaying(); }, 300);
	CHECK(!started);
	CHECK(audio->getCurrentMusicID() != "long_a");
}

TEST(sound_play_music_fades_out_then_starts_the_new_one)
{
	SoundManager* audio = OpenAudio();
	CHECK(audio->load(WriteSilentWav("initial2d_long_a.wav", 3000), "long_a", SOUND_MUSIC));
	CHECK(audio->load(WriteSilentWav("initial2d_long_b.wav", 3000), "long_b", SOUND_MUSIC));
	StopAndSettle();

	audio->playMusic("long_a", -1);
	audio->playMusic("long_b", -1);
	CHECK_EQ(audio->getCurrentMusicID(), std::string("long_a"));

	const bool switched = WaitUntil([&] {
		return audio->getCurrentMusicID() == "long_b" && audio->isPlaying();
	}, 2500);
	CHECK(switched);

	// 이전 곡은 해제되었다: 같은 id라도 캐시가 없으므로 없는 경로로는 읽지 못한다
	CHECK(!audio->load("./no_such_dir/long_a.wav", "long_a", SOUND_MUSIC));

	StopAndSettle();
}
