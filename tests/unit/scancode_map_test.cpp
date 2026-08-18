/**
 * @file scancode_map_test.cpp
 * @brief SDL 스캔코드 → Win32 VK 상태 변환 검증 (src/platform/sdl2/ScancodeMap.cpp).
 *
 * 회귀 대상: 매핑 표에서 VK_ESCAPE가 두 번 나오는데(ESC, 안드로이드 뒤로가기)
 * 대입으로 채우는 바람에 나중 항목이 앞의 눌림을 지워, 데스크톱에서 ESC가 아예
 * 먹지 않았다 (2026-08-18, 사용자 보고: "ESC를 눌러도 메뉴가 안 뜬다").
 *
 * 진짜 키보드 상태는 테스트에서 만들 수 없으므로 매핑만 순수 함수로 떼어 두고,
 * 여기서 가짜 상태 배열로 부른다.
 */
#include "test_framework.h"

#include "platform/sdl2/ScancodeMap.h"
#include "platform/WinTypes.h"
#include "Input.h"      // RELEASED / PRESSED

#include <SDL.h>

#include <cstring>

namespace {

struct Keyboard
{
	unsigned char keys[SDL_NUM_SCANCODES];
	unsigned char vk[256];

	Keyboard() { std::memset(keys, 0, sizeof(keys)); std::memset(vk, 0, sizeof(vk)); }

	void press(SDL_Scancode sc) { keys[sc] = 1; }

	void apply()
	{
		Initial2D::Platform::ApplyScancodeState(keys, SDL_NUM_SCANCODES, vk);
	}
};

} // namespace

TEST(scancode_escape_survives_the_android_back_entry)
{
	Keyboard kb;
	kb.press(SDL_SCANCODE_ESCAPE);
	kb.apply();
	// 뒤로가기(AC_BACK)가 같은 VK를 가리키지만, 눌리지 않았다고 ESC를 지우면 안 된다
	CHECK_EQ((int)kb.vk[VK_ESCAPE], PRESSED);
}

TEST(scancode_android_back_maps_to_escape)
{
	Keyboard kb;
	kb.press(SDL_SCANCODE_AC_BACK);
	kb.apply();
	CHECK_EQ((int)kb.vk[VK_ESCAPE], PRESSED);
}

TEST(scancode_nothing_pressed_is_all_released)
{
	Keyboard kb;
	kb.press(SDL_SCANCODE_ESCAPE);
	kb.apply();
	CHECK_EQ((int)kb.vk[VK_ESCAPE], PRESSED);

	std::memset(kb.keys, 0, sizeof(kb.keys));
	kb.apply();
	CHECK_EQ((int)kb.vk[VK_ESCAPE], RELEASED);
	CHECK_EQ((int)kb.vk['Z'], RELEASED);
}

TEST(scancode_letters_digits_and_arrows)
{
	Keyboard kb;
	kb.press(SDL_SCANCODE_Z);
	kb.press(SDL_SCANCODE_X);
	kb.press(SDL_SCANCODE_0);
	kb.press(SDL_SCANCODE_7);
	kb.press(SDL_SCANCODE_UP);
	kb.press(SDL_SCANCODE_RETURN);
	kb.press(SDL_SCANCODE_SPACE);
	kb.apply();

	CHECK_EQ((int)kb.vk['Z'], PRESSED);          // 대화 진행키
	CHECK_EQ((int)kb.vk['X'], PRESSED);          // 선택지 취소키
	CHECK_EQ((int)kb.vk['0'], PRESSED);
	CHECK_EQ((int)kb.vk['7'], PRESSED);
	CHECK_EQ((int)kb.vk[VK_UP], PRESSED);
	CHECK_EQ((int)kb.vk[VK_RETURN], PRESSED);
	CHECK_EQ((int)kb.vk[VK_SPACE], PRESSED);
	CHECK_EQ((int)kb.vk[VK_DOWN], RELEASED);
	CHECK_EQ((int)kb.vk['A'], RELEASED);
}

TEST(scancode_modifiers_merge_left_and_right)
{
	Keyboard kb;
	kb.press(SDL_SCANCODE_RSHIFT);
	kb.press(SDL_SCANCODE_LCTRL);
	kb.apply();
	CHECK_EQ((int)kb.vk[VK_SHIFT], PRESSED);
	CHECK_EQ((int)kb.vk[VK_CONTROL], PRESSED);
	CHECK_EQ((int)kb.vk[VK_MENU], RELEASED);
}

TEST(scancode_latched_key_survives_a_missed_poll)
{
	// 리맵 도구가 만든 키는 down과 up이 같은 틱에 들어와, 상태 배열에는 흔적이
	// 남지 않는다. 이벤트에서 래치해 두면 그 틱에 눌린 것으로 관측된다.
	Keyboard kb;
	unsigned char latch[256];
	std::memset(latch, 0, sizeof(latch));
	latch[VK_ESCAPE] = 1;

	Initial2D::Platform::ApplyScancodeState(kb.keys, SDL_NUM_SCANCODES, kb.vk, latch);
	CHECK_EQ((int)kb.vk[VK_ESCAPE], PRESSED);
	CHECK_EQ((int)latch[VK_ESCAPE], 0);        // 한 틱만 살아 있다

	// 다음 틱에는 눌리지 않은 상태로 돌아간다 (그래야 눌림→뗌 전이가 만들어진다)
	Initial2D::Platform::ApplyScancodeState(kb.keys, SDL_NUM_SCANCODES, kb.vk, latch);
	CHECK_EQ((int)kb.vk[VK_ESCAPE], RELEASED);
}

TEST(scancode_latch_does_not_erase_a_held_key)
{
	Keyboard kb;
	unsigned char latch[256];
	std::memset(latch, 0, sizeof(latch));
	kb.press(SDL_SCANCODE_Z);
	latch[VK_ESCAPE] = 1;

	Initial2D::Platform::ApplyScancodeState(kb.keys, SDL_NUM_SCANCODES, kb.vk, latch);
	CHECK_EQ((int)kb.vk['Z'], PRESSED);
	CHECK_EQ((int)kb.vk[VK_ESCAPE], PRESSED);
}

TEST(scancode_to_virtual_key_lookup)
{
	using Initial2D::Platform::ScancodeToVirtualKey;
	CHECK_EQ(ScancodeToVirtualKey(SDL_SCANCODE_ESCAPE), VK_ESCAPE);
	CHECK_EQ(ScancodeToVirtualKey(SDL_SCANCODE_AC_BACK), VK_ESCAPE);
	CHECK_EQ(ScancodeToVirtualKey(SDL_SCANCODE_Z), 'Z');
	CHECK_EQ(ScancodeToVirtualKey(SDL_SCANCODE_0), '0');
	CHECK_EQ(ScancodeToVirtualKey(SDL_SCANCODE_5), '5');
	CHECK_EQ(ScancodeToVirtualKey(SDL_SCANCODE_F3), VK_F3);
	CHECK_EQ(ScancodeToVirtualKey(SDL_SCANCODE_RIGHT), VK_RIGHT);
	CHECK_EQ(ScancodeToVirtualKey(SDL_SCANCODE_RSHIFT), VK_SHIFT);
	CHECK_EQ(ScancodeToVirtualKey(SDL_SCANCODE_F18), 0);   // 표에 없는 키는 0
}

TEST(scancode_short_state_array_is_safe)
{
	// SDL이 알려 준 길이보다 큰 스캔코드는 읽지 않는다
	unsigned char keys[8] = { 0 };
	unsigned char vk[256];
	std::memset(vk, PRESSED, sizeof(vk));
	Initial2D::Platform::ApplyScancodeState(keys, 8, vk);
	CHECK_EQ((int)vk[VK_ESCAPE], RELEASED);

	std::memset(vk, PRESSED, sizeof(vk));
	Initial2D::Platform::ApplyScancodeState(nullptr, 0, vk);
	CHECK_EQ((int)vk[VK_ESCAPE], RELEASED);
}
