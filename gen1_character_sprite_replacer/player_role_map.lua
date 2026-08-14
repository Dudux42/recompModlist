return {
  walk = { supported = true, romRole = "walk" },
  bike = { supported = true, romRole = "bike" },
  surf = { supported = true, romRole = "surf", composition = "player_and_mount" },
  fishing = {
    supported = false,
    romRole = "fishing",
    reason = "The engine composes an 8px Gen 1 hand tile with a separate rod effect; the supplied FRLG frames contain an inseparable full rod.",
  },
  surfPikachu = {
    supported = false,
    romRole = "surfPikachu",
    reason = "Pokemon follower/mount presentation remains ROM-owned.",
  },
  fly = {
    supported = false,
    romRole = "fly",
    reason = "The Fly bird is a nonhuman effect and remains ROM-owned.",
  },
  front = { supported = true, consumers = { "intro", "trainer_card", "hall_of_fame" } },
  back = { supported = true, consumers = {
    "battle", "battle_sendout_throw_5_frame", "hall_of_fame_back_sweep"
  } },
  main_menu = {
    supported = true,
    providerOnly = true,
    reason = "Requires the Widescreen presenter consumer requested in GEN1_WIDESCREEN_UI_CHARACTER_PRESENTATION_REQUEST.md.",
  },
}
