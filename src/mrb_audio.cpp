/**
 * @file mrb_audio.cpp
 * @brief Audio 모듈 (mruby). lua_audio.cpp 에 대응한다.
 *
 *   Audio.play_music(path, id, loop = true)
 *   Audio.play_sound(path, id, loop = false)
 *   Audio.insert_next_music(path, id, loop = true)
 *   Audio.volume, Audio.volume = n
 *   Audio.pause_music, stop_music, resume_music, playing_music?
 *   Audio.fade_out_music(ms), Audio.music_position = seconds, Audio.release_music(id)
 *
 * loop 는 Lua 와 같은 계약이다. true = 무한 반복, false = 한 번, 숫자 = SDL_mixer 의
 * 루프 값 그대로 (음악은 재생 횟수, 효과음은 추가 반복 횟수).
 */
#include "Constants.h"

#ifdef INITIAL2D_HAS_MRUBY

#include "mrb_prot.h"
#include "SoundManager.h"

#include <string>

namespace
{
	mrb_value audio_play_music(mrb_state* mrb, mrb_value)
	{
		const char* path = nullptr;
		const char* id = nullptr;
		mrb_value loop = mrb_true_value();
		mrb_get_args(mrb, "zz|o", &path, &id, &loop);

		const int loops = MRuby_ResolveLoop(mrb, loop, 1);
		if (Audio->load(path, id, SOUND_MUSIC))
		{
			Audio->playMusic(id, loops);
			return mrb_true_value();
		}
		return mrb_false_value();
	}

	mrb_value audio_insert_next_music(mrb_state* mrb, mrb_value)
	{
		const char* path = nullptr;
		const char* id = nullptr;
		mrb_value loop = mrb_true_value();
		mrb_get_args(mrb, "zz|o", &path, &id, &loop);

		const int loops = MRuby_ResolveLoop(mrb, loop, 1);
		if (Audio->load(path, id, SOUND_MUSIC))
		{
			Audio->insertNextMusic(id, loops);
			return mrb_true_value();
		}
		return mrb_false_value();
	}

	mrb_value audio_play_sound(mrb_state* mrb, mrb_value)
	{
		const char* path = nullptr;
		const char* id = nullptr;
		mrb_value loop = mrb_false_value();
		mrb_get_args(mrb, "zz|o", &path, &id, &loop);

		const int loops = MRuby_ResolveLoop(mrb, loop, 0);
		if (Audio->load(path, id, SOUND_SFX))
		{
			Audio->playSound(id, loops);
			return mrb_true_value();
		}
		return mrb_false_value();
	}

	mrb_value audio_volume(mrb_state* mrb, mrb_value)
	{
		return mrb_int_value(mrb, Audio->getVolume());
	}

	mrb_value audio_set_volume(mrb_state* mrb, mrb_value)
	{
		mrb_int volume = 0;
		mrb_get_args(mrb, "i", &volume);
		Audio->setVolume(static_cast<int>(volume));
		return mrb_int_value(mrb, volume);
	}

	mrb_value audio_pause_music(mrb_state* mrb, mrb_value)
	{
		Audio->pauseMusic();
		return mrb_nil_value();
	}

	mrb_value audio_stop_music(mrb_state* mrb, mrb_value)
	{
		Audio->stopMusic();
		return mrb_nil_value();
	}

	mrb_value audio_resume_music(mrb_state* mrb, mrb_value)
	{
		Audio->resumeMusic();
		return mrb_nil_value();
	}

	mrb_value audio_playing_music(mrb_state* mrb, mrb_value)
	{
		return mrb_bool_value(Audio->isPlaying());
	}

	mrb_value audio_fade_out_music(mrb_state* mrb, mrb_value)
	{
		mrb_int ms = 0;
		mrb_get_args(mrb, "i", &ms);
		Audio->fadeOutMusic(static_cast<int>(ms));
		return mrb_nil_value();
	}

	mrb_value audio_set_music_position(mrb_state* mrb, mrb_value)
	{
		mrb_float position = 0;
		mrb_get_args(mrb, "f", &position);
		Audio->setMusicPosition(position);
		return mrb_float_value(mrb, position);
	}

	mrb_value audio_release_music(mrb_state* mrb, mrb_value)
	{
		const char* id = nullptr;
		mrb_get_args(mrb, "z", &id);
		Audio->releaseMusic(id);
		return mrb_nil_value();
	}
}

void MRuby_DefineAudio(mrb_state* mrb)
{
	struct RClass* audio = mrb_define_module(mrb, "Audio");
	mrb_define_module_function(mrb, audio, "play_music", MRUBY_GUARD(audio_play_music), MRB_ARGS_ARG(2, 1));
	mrb_define_module_function(mrb, audio, "play_sound", MRUBY_GUARD(audio_play_sound), MRB_ARGS_ARG(2, 1));
	mrb_define_module_function(mrb, audio, "insert_next_music", MRUBY_GUARD(audio_insert_next_music), MRB_ARGS_ARG(2, 1));
	mrb_define_module_function(mrb, audio, "volume", MRUBY_GUARD(audio_volume), MRB_ARGS_NONE());
	mrb_define_module_function(mrb, audio, "volume=", MRUBY_GUARD(audio_set_volume), MRB_ARGS_REQ(1));
	mrb_define_module_function(mrb, audio, "pause_music", MRUBY_GUARD(audio_pause_music), MRB_ARGS_NONE());
	mrb_define_module_function(mrb, audio, "stop_music", MRUBY_GUARD(audio_stop_music), MRB_ARGS_NONE());
	mrb_define_module_function(mrb, audio, "resume_music", MRUBY_GUARD(audio_resume_music), MRB_ARGS_NONE());
	mrb_define_module_function(mrb, audio, "playing_music?", MRUBY_GUARD(audio_playing_music), MRB_ARGS_NONE());
	mrb_define_module_function(mrb, audio, "fade_out_music", MRUBY_GUARD(audio_fade_out_music), MRB_ARGS_REQ(1));
	mrb_define_module_function(mrb, audio, "music_position=", MRUBY_GUARD(audio_set_music_position), MRB_ARGS_REQ(1));
	mrb_define_module_function(mrb, audio, "release_music", MRUBY_GUARD(audio_release_music), MRB_ARGS_REQ(1));
}

#endif // INITIAL2D_HAS_MRUBY
