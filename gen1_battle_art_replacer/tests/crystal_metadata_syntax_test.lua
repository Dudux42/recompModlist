local metadata = assert(loadfile("gen1_battle_art_replacer/crystal_animation_metadata.lua"))()
assert(type(metadata) == "table" and type(metadata[1]) == "table"
  and type(metadata[151]) == "table")
for dex = 1, 151 do
  local entry = metadata[dex]
  assert(type(entry.frames) == "number" and entry.frames > 1)
  assert(type(entry.durations) == "table" and #entry.durations == entry.frames)
  if entry.shiny then
    assert(#entry.shiny.durations == entry.shiny.frames)
  end
end
print("crystal_animation_metadata: ok")
