-- manifest.lua : 실행할 Lua 테스트 케이스 목록.
-- 경로는 워크 디렉터리 기준 require 이름이다 (scripts/luatests/cases/ 아래로 복사됨).
-- 새 케이스를 추가하면 여기 명시한다 (자동 스캔하지 않는 이유는
-- C++ 쪽과 동일: 명시적 목록이 스테일과 누락을 눈에 보이게 한다).

return {
    "scripts/luatests/cases/framework_selftest",
    "scripts/luatests/cases/api_surface_test",
    "scripts/luatests/cases/input_replay_test",
    "scripts/luatests/cases/font_text_test",
    "scripts/luatests/cases/json_load_test",
    "scripts/luatests/cases/sprite_sheet_test",
    "scripts/luatests/cases/tilemap_test",
    "scripts/luatests/cases/vpad_test",
    "scripts/luatests/cases/bgm_test",
    "scripts/luatests/cases/rpg_specs_test",
    "scripts/luatests/cases/rpg_rng_test",
    "scripts/luatests/cases/rpg_camera_test",
    "scripts/luatests/cases/rpg_character_test",
    "scripts/luatests/cases/rpg_map_scene_test",
    "scripts/luatests/cases/rpg_interpreter_test",
    "scripts/luatests/cases/rpg_event_test",
    "scripts/luatests/cases/rpg_commands_test",
    "scripts/luatests/cases/rpg_mapdata_test",
    "scripts/luatests/cases/rpg_text_test",
    "scripts/luatests/cases/rpg_window_test",
    "scripts/luatests/cases/rpg_choice_test",
    "scripts/luatests/cases/rpg_inventory_test",
    "scripts/luatests/cases/rpg_menu_test",
    "scripts/luatests/cases/rpg_message_test",
    "scripts/luatests/cases/rpg_assets_test",
    "scripts/luatests/cases/aldebaran_player_test",
    "scripts/luatests/cases/aldebaran_combat_test",
    "scripts/luatests/cases/aldebaran_monster_test",
    "scripts/luatests/cases/aldebaran_monsters_data_test",
    "scripts/luatests/cases/aldebaran_climate_test",
}
