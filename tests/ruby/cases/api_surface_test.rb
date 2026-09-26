# api_surface_test.rb : 엔진이 mruby 에 노출하는 API 표면의 계약 검증.
# 바인딩이 실수로 빠지거나 이름이 바뀌면 여기서 잡힌다.
# Lua 쪽 api_surface_test.lua 에 대응하며, 새 바인딩을 추가하면 이 목록도 갱신할 것.

MODULES = {
  Graphics: %i[width height render_scale render_scale= frame_count prepare_font
               draw_text text_width set_color draw_point],
  System: %i[platform exit current_directory resource_files message_box app_icon= env script],
  Input: %i[key_down? key_up? key_press? any_key_down? trigger? press? release?
            mouse_x mouse_y mouse_down? mouse_up? mouse_press? any_mouse_down?
            mouse_z mouse_z= touch_count touch touches],
  Audio: %i[play_music play_sound insert_next_music volume volume= pause_music stop_music
            resume_music playing_music? fade_out_music music_position= release_music],
  TextureManager: %i[load remove valid?],
  Json: %i[load parse],
}

CLASSES = {
  Sprite: %i[update draw x y position set_position x= y= position= scale scale= width height
             angle angle= radians radians= visible? visible= opacity opacity=
             frame_delay frame_delay= set_frames start_frame end_frame current_frame
             current_frame= loop= anim_complete? anim_complete= set_sheet_grid
             rect set_rect dispose disposed?],
  Tilemap: %i[draw width height tile_width tile_height layer_count size tile_id
              set_tile_id passable? dispose disposed?],
  FontEx: %i[update draw text= set_position set_text_color opacity= angle= text_width
             dispose disposed?],
}

T.run_case("api_surface") do |t|
  MODULES.each do |name, methods|
    mod = Object.const_get(name)
    t.check_type(mod, Module, "모듈 #{name}")
    methods.each do |m|
      t.check(mod.respond_to?(m), "#{name}.#{m}")
    end
  end

  CLASSES.each do |name, methods|
    klass = Object.const_get(name)
    t.check_type(klass, Class, "클래스 #{name}")
    methods.each do |m|
      t.check(klass.method_defined?(m), "#{name}##{m}")
    end
  end

  t.check(Sprite.respond_to?(:load), "Sprite.load (프렐류드)")
  t.check(Tilemap.respond_to?(:load), "Tilemap.load (프렐류드)")
  # 최상위 def 와 같은 자리에 있는 비공개 메서드라 respond_to? 의 둘째 인자로 본다
  t.check(Object.new.respond_to?(:load, true), "Kernel#load")
  t.check(Object.new.respond_to?(:require, true), "Kernel#require")

  t.check_type(Keys, Module, "Keys 모듈")
  t.check_eq(Keys::ESCAPE, 27, "Keys::ESCAPE")
  t.check_eq(Keys::SPACE, 32, "Keys::SPACE")
  t.check_eq(Keys::Z, 90, "Keys::Z")
  t.check_eq(Keys::DIGIT0, 48, "Keys::DIGIT0")
  t.check_eq(Keys::F12, 123, "Keys::F12")
  t.check_eq(System.script, "mruby", "System.script")
end
