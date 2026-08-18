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
