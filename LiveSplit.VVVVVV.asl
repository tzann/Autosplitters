// This code is ugly and doesn't use features such as MemoryWatchers, so please don't use this as an example ;)
// TODO: implement MemoryWatchers to clean up code
// TODO: implement "v2.0 non-Steam" version compatibility

state("VVVVVV", "v2.2") {
	int doneLoading : "VVVVVV.exe", 0x3F8024;
	string255 saveDirectory : "VVVVVV.exe", 0x3F7DD8;
	string255 firstTextLine : "VVVVVV.exe", 0x3F8068, 0x0, 0x0;
	// string255 secondTextLine : "VVVVVV.exe", 0x3F8068, 0x1c, 0x0;
	// string255 thirdTextLine : "VVVVVV.exe", 0x3F8068, 0x38, 0x0;
	// string255 fourthTextLine : "VVVVVV.exe", 0x3F8068, 0x54, 0x0;
}

state("VVVVVV", "v2.0 Steam") {
	int doneLoading : "VVVVVV.exe", 0x637054;
	string255 firstTextLine : "VVVVVV.exe", 0x637098, 0x0, 0x0;
}

startup {
	refreshRate = 2;

	vars.violet = "Split on Violet's teleporter (SS1)";
	vars.vitellary = "Split on rescuing Vitellary (SS2)";
	vars.vermilion = "Split on rescuing Vermilion (Tower)";
	vars.verdigris = "Split on rescuing Verdigris (Warp Zone)";
	vars.victoria = "Split on rescuing Victoria (Lab)";
	vars.int1 = "Split on completing Intermission 1";
	vars.int2 = "Split on completing Intermission 2";
	vars.gameComplete = "Split on game completion";
	vars.trinkets = "Split on collecting trinkets";
	vars.dis = "Split on talking to Victoria (for DIS)";
	vars.hello = "Split on \"Hello!\" (for glitched Any%)";
	vars.menuReset = "Reset on exiting to menu";

	settings.Add(vars.violet, true);
	settings.Add(vars.vitellary, true);
	settings.Add(vars.vermilion, true);
	settings.Add(vars.verdigris, true);
	settings.Add(vars.victoria, true);
	settings.Add(vars.int1, true);
	settings.Add(vars.int2, true);
	settings.Add(vars.gameComplete, true);
	settings.Add(vars.trinkets, false);
	settings.Add(vars.dis, false);
	settings.Add(vars.hello, false);
	settings.Add(vars.menuReset, true);
}

init {
	if (modules.First().ModuleMemorySize == 0x667000) {
    version = "v2.0 non-Steam";
	} else if (modules.First().ModuleMemorySize == 0x6D9000) {
    version = "v2.0 Steam";
	} else if (modules.First().ModuleMemorySize == 0x456000) {
		version = "v2.2";
	}
	vars.hookAttempts = 0;
	vars.hooked = false;
	vars.gamestate = -1;
	vars.menuID = -1;
	vars.trinketCount = -1;
}

start {
	if (vars.hooked) {
		// Start if main menu closes and IGT resets
		if (vars.menuIDOld == 1 && vars.menuID == 0 && vars.gameTime.TotalSeconds < 1) {
			return true;
		}
	}
	return false;
}

split {
	if (vars.hooked) {
		// split on crewmate rescue and intermissions
		if (vars.gamestateOld == 3005) {
			if (vars.gamestate == 3006) {
				// Verdigris
				return settings[vars.verdigris];
			} else if (vars.gamestate == 3020) {
				// Vitellary
				return settings[vars.vitellary];
			} else if (vars.gamestate == 3040) {
				// Victoria
				return settings[vars.victoria];
			} else if (vars.gamestate == 3060) {
				// Vermilion
				return settings[vars.vermilion];
			} else if (vars.gamestate == 3080) {
				// Intermission 2
				return settings[vars.int2];
			} else if (vars.gamestate == 3085) {
				// Intermission 1
				return settings[vars.int1];
			}
		} else if (vars.gamestateOld == 4091 && vars.gamestate != vars.gamestateOld) {
			// split on Violet's teleporter
			return settings[vars.violet];
		} else if (vars.gamestateOld == 3502 && vars.gamestate == 3503) {
			// split on game completion (When "All crew members rescued!" appears on screen)
			return settings[vars.gameComplete];
		} else if (vars.gamestate == 33 && vars.gamestateOld != 33) {
			// split on talking to Victoria
			return settings[vars.dis];
		} else if (current.firstTextLine == "Hello!" && old.firstTextLine != current.firstTextLine) {
			// split on "Hello!" appearing on screen
			return settings[vars.hello];
		} else if (vars.trinketCount == vars.trinketCountOld + 1) {
			// split when collecting trinkets
			return settings[vars.trinkets];
		}
	}
	return false;
}

reset {
	if (!vars.hooked) {
		return false;
	}
	return vars.menuID == 1 && settings[vars.menuReset];
}

gameTime {
	return vars.gameTime;
}

update {
	if (vars.hookAttempts > 5) {
		// print("VVVVVV Autosplitter ----- Could not hook into VVVVVV.exe");
		return false;
	} else if (!vars.hooked) {
		if (version == "v2.2") {
			if (current.doneLoading == 50) {
				// print("VVVVVV Autosplitter ----- Starting scan...");
				int addr = 0x0;

				for (int i = 0x00000000; i < 0x02000000; i += 0x10000) {
					// The base address of the game's variables will always be between ????CD00 and ????D600
					for (int j = 0xCD00; j < 0xD600; j += 0x4) {
						addr = i+j;
						int val = game.ReadValue<int>(new IntPtr(addr));
						if (game.ReadString(new IntPtr(val), 255) == current.saveDirectory) {
							if (game.ReadValue<int>(new IntPtr(addr+0x74)) == 1 && game.ReadValue<int>(new IntPtr(addr+0x84)) == 1) {
								vars.hooked = true;
								break;
							}
						}
					}
				}

				if (vars.hooked) {
					addr += 0x74;
					vars.gamestateAddr = addr;
					vars.menuIDAddr = addr+0x10;
					vars.trinketCountAddr = addr+0x3D0;
					vars.gameTimeHourAddr = addr+0x54;
					vars.gameTimeMinAddr = addr+0x50;
					vars.gameTimeSecAddr = addr+0x4c;
					vars.gameTimeFrameAddr = addr+0x48;

					// print("VVVVVV Autosplitter ----- Successfully hooked!");
				} else {
					vars.hookAttempts += 1;
					return false;
				}
			} else {
				return false;
			}
		} else if (version == "v2.0 Steam") {
			if (current.doneLoading == 50) {
				var ptr = IntPtr.Add(modules.First().BaseAddress, 0x0167658);
				int addr = game.ReadValue<int>(ptr) + 0x4B8;

				vars.gamestateAddr = addr;
				vars.menuIDAddr = addr+0x8;
				vars.trinketCountAddr = addr+0x250;
				vars.gameTimeHourAddr = addr+0x48;
				vars.gameTimeMinAddr = addr+0x44;
				vars.gameTimeSecAddr = addr+0x40;
				vars.gameTimeFrameAddr = addr+0x3c;
				vars.hooked = true;

				// print("VVVVVV Autosplitter ----- Successfully hooked!");
			} else {
				return false;
			}
		}
	}
	if (vars.hooked) {
		// Game is hooked succesfully, update variables
		vars.gamestateOld = vars.gamestate;
		vars.menuIDOld = vars.menuID;
		vars.trinketCountOld = vars.trinketCount;

		vars.gamestate = game.ReadValue<int>(new IntPtr(vars.gamestateAddr));
		vars.menuID = game.ReadValue<int>(new IntPtr(vars.menuIDAddr));
		vars.trinketCount = game.ReadValue<int>(new IntPtr(vars.trinketCountAddr));

		int gameTimeHours = game.ReadValue<int>(new IntPtr(vars.gameTimeHourAddr));
		int gameTimeMinutes = game.ReadValue<int>(new IntPtr(vars.gameTimeMinAddr));
		int gameTimeSeconds = game.ReadValue<int>(new IntPtr(vars.gameTimeSecAddr));
		int gameTimeFrames = game.ReadValue<int>(new IntPtr(vars.gameTimeFrameAddr));

		vars.gameTime = new TimeSpan(0, gameTimeHours, gameTimeMinutes, gameTimeSeconds, 100*gameTimeFrames/3);

		/*if (vars.gamestateOld != vars.gamestate) {
			print("VVVVVV Autosplitter ----- Gamestate " + vars.gamestateOld + " -> " + vars.gamestate);
		}*/

		return true;
	}
	return false;
}
