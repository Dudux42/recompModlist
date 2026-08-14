-- Trade remains valid; level-up is an additional evolution path.
return {
  KADABRA = { evolutions = {
    { method = "TRADE", species = "ALAKAZAM" },
    { method = "LEVEL", level = 42, species = "ALAKAZAM" },
  } },
  MACHOKE = { evolutions = {
    { method = "TRADE", species = "MACHAMP" },
    { method = "LEVEL", level = 38, species = "MACHAMP" },
  } },
  GRAVELER = { evolutions = {
    { method = "TRADE", species = "GOLEM" },
    { method = "LEVEL", level = 38, species = "GOLEM" },
  } },
  HAUNTER = { evolutions = {
    { method = "TRADE", species = "GENGAR" },
    { method = "LEVEL", level = 42, species = "GENGAR" },
  } },
}
