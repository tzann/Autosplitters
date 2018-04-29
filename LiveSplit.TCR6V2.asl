state("R6Vegas2_Game") {
  int loading: "R6Vegas2_Game.exe", 0x1A6A0C8;
}

isLoading {
  return current.loading != 0;
}
