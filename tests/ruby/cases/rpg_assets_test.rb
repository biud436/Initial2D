# rpg_assets_test.rb : 리소스 고르기(scripts/ruby/rpg/assets.rb) 검증 (8단계).
# rpg_assets_test.lua 의 Ruby 판.
# RTP는 재배포할 수 없어 CI에도 개발자 기계에도 없을 수 있다. 그래서 "있으면
# RTP, 없으면 플레이스홀더"가 두 경우 모두에서 옳아야 한다.

require "scripts/ruby/rpg/assets"

T.run_case("rpg_assets") do |t|
  assets = Rpg::Assets

  # [1] exists?: 커밋된 파일과 없는 파일
  t.check(assets.exists?("./resources/charsets/placeholder.png"),
          "커밋된 플레이스홀더 CharSet은 있다")
  t.check(!assets.exists?("./resources/charsets/이런_파일은_없다.png"),
          "없는 파일은 없다고 한다")
  t.check(!assets.exists?(nil), "nil은 없는 것으로 친다")
  t.check(!assets.exists?(42), "문자열이 아니면 없는 것으로 친다")

  # [2] pick: 앞에서부터 처음 있는 것
  t.check_eq(assets.pick(["./없다.png", "./resources/ui/window.png"]),
             "./resources/ui/window.png", "없는 후보를 건너뛴다")
  t.check_eq(assets.pick(["./resources/ui/window.png", "./resources/ui/fade.png"]),
             "./resources/ui/window.png", "앞의 후보가 있으면 그것을 쓴다")
  t.check_eq(assets.pick(["./없다1.png", "./없다2.png"]), "./없다2.png",
             "전부 없으면 마지막 후보를 돌려준다 (nil이 아니라)")
  # Ruby 판에서 더한 검사: 후보가 없으면 오류 (Lua 판의 assert)
  empty_fails = begin
    assets.pick([])
    false
  rescue ArgumentError
    true
  end
  t.check(empty_fails, "빈 후보 목록은 오류")
  nil_fails = begin
    assets.pick(nil)
    false
  rescue ArgumentError
    true
  end
  t.check(nil_fails, "후보 목록이 nil이면 오류")

  # [3] 이름 붙은 접근자는 언제나 실재하는 파일을 준다 (RTP 유무와 무관)
  {
    player_charset: assets.player_charset,
    npc_charset: assets.npc_charset,
    faceset: assets.faceset,
    windowskin: assets.windowskin,
  }.each do |name, path|
    t.check(assets.exists?(path), "#{name} 는 실재하는 파일: #{path}")
  end

  # [4] 후보 목록의 순서: RTP가 먼저, 커밋된 플레이스홀더가 나중
  [assets::PLAYER_CHARSET, assets::NPC_CHARSET,
   assets::FACESET, assets::WINDOWSKIN].each do |list|
    t.check(list[0].include?("/rtp/"), "첫 후보는 RTP: #{list[0]}")
    t.check(!list[-1].include?("/rtp/"), "마지막 후보는 저장소 자산: #{list[-1]}")
  end

  # [5] 맵 경로: 칩셋이 없으면 기본 판
  has_exterior = assets.exists?("./resources/rtp/ChipSet/Exterior.png") && assets.rtp_enabled?
  village = assets.map_path("village", "Exterior")
  if has_exterior
    t.check_eq(village, "./resources/maps/village_rtp.json", "칩셋이 있으면 RTP 판")
  else
    t.check_eq(village, "./resources/maps/village.json", "칩셋이 없으면 기본 판")
  end
  t.check(assets.exists?(village), "고른 맵 파일은 실재한다: #{village}")

  # [5b] INITIAL2D_NO_RTP 가 걸린 실행에서는 RTP를 아예 보지 않는다
  unless assets.rtp_enabled?
    t.check_eq(village, "./resources/maps/village.json",
               "RTP를 끄면 칩셋이 있어도 기본 판")
    [assets.player_charset, assets.npc_charset,
     assets.faceset, assets.windowskin].each do |path|
      t.check(!path.include?("/rtp/"), "RTP를 끄면 저장소 자산만: #{path}")
    end
  end

  # Ruby 판에서 더한 검사: rtp_enabled? 는 환경 변수를 그대로 따른다
  t.check_eq(assets.rtp_enabled?, System.env("INITIAL2D_NO_RTP").nil?,
             "rtp_enabled?는 INITIAL2D_NO_RTP를 따른다")

  t.check_eq(assets.map_path("room", nil), "./resources/maps/room.json",
             "칩셋 이름이 없으면 기본 판")
  t.check_eq(assets.map_path("room"), "./resources/maps/room.json",
             "칩셋 인자를 생략해도 기본 판")
  t.check(assets.exists?(assets.map_path("room", "Interior")), "오두막 맵도 실재한다")
end
