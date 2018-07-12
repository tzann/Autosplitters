// This code is ugly and doesn't use built-in features such as MemoryWatchers, so please don't use this as an example ;)
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
	refreshRate = 60;

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
	vars.finalStretch = "Split on Final Level terminal";
	vars.hello = "Split on \"Hello!\" (for glitched Any%)";
	vars.menuReset = "Reset on exiting to menu";
	vars.ils = "Start/Split/Reset on Time Trials";

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
	settings.Add(vars.finalStretch, false);
	settings.Add(vars.hello, false);
	settings.Add(vars.menuReset, true);
	settings.Add(vars.ils, false);
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
	vars.trinketCount = 0;
	vars.finalMode = 0;
	vars.gameTime = new TimeSpan(0, 0, 0, 0);

	vars.timeTrial = -1;
}

start {
	if (vars.hooked) {
		// Start if main menu closes and IGT resets
		if (vars.menuIDOld == 1 && vars.menuID == 0 && vars.gameTime.TotalMilliseconds < 100) {
			if (vars.timeTrial == 0) {
				// BUG: starts on selecting intermissions and secret lab from main menu
				return true;
			}
		}
		if (vars.gameTimeOld.TotalMilliseconds > vars.gameTime.TotalMilliseconds) {
			if (vars.timeTrial != 0 && vars.timeTrialOld == vars.timeTrial) {
				if (vars.gameTimeOld.TotalMilliseconds >= 4000 && vars.gameTimeOld.TotalMilliseconds <= 4066)
				// Start the timer if: game time resets between 4.000 or 4.066 seconds, the player is in a time trial and the time trial ID didn't change last frame
				return settings[vars.ils];
			}
		}
	}
	return false;
}

split {
	// BUG: sometimes randomly won't split... is the autosplitter "missing" the
	// frames where the gamestate is changed to the right value?
	if (vars.hooked) {
		// split on crewmate rescue and intermissions
		if (vars.gamestateOld == 3005 || vars.gamestateOld == 3004) {
			if (vars.gamestate == 3006 || vars.gamestate == 3007) {
				// Verdigris
				return settings[vars.verdigris];
			} else if (vars.gamestate == 3020 || vars.gamestate == 3021) {
				// Vitellary
				return settings[vars.vitellary];
			} else if (vars.gamestate == 3040 || vars.gamestate == 3041) {
				// Victoria
				return settings[vars.victoria];
			} else if (vars.gamestate == 3060 || vars.gamestate == 3061) {
				// Vermilion
				return settings[vars.vermilion];
			} else if (vars.gamestate == 3080 || vars.gamestate == 3081) {
				// Intermission 2
				return settings[vars.int2];
			} else if (vars.gamestate == 3085 || vars.gamestate == 3086) {
				// Intermission 1
				return settings[vars.int1];
			}
		} else if (vars.gamestateOld == 4091 && vars.gamestate != vars.gamestateOld) {
			// split on Violet's teleporter
			return settings[vars.violet];
		} else if (vars.gamestateOld == 3502 && vars.gamestate == 3503) {
			// split on game completion (When "All crew members rescued!" appears on screen)
			// This is when IGT stops counting, which is why we don't split on "Game complete!" appearing, which is one gamestate increment earlier
			return settings[vars.gameComplete];
		} else if (vars.finalMode == 1 && vars.finalModeOld == 0) {
			// split on activating final mode
			return settings[vars.finalStretch];
		} else if (vars.gamestate == 33 && vars.gamestateOld != 33) {
			// split on talking to Victoria
			return settings[vars.dis];
		} else if (current.firstTextLine == "Hello!" && old.firstTextLine != current.firstTextLine) {
			// split on "Hello!" appearing on screen
			return settings[vars.hello];
		} else if (vars.trinketCount == vars.trinketCountOld + 1) {
			// split when collecting trinkets
			return settings[vars.trinkets];
		} else if (vars.gamestate == 83 && vars.gamestateOld != 83 && vars.timeTrial != 0) {
			// split when ending time trial
			return settings[vars.ils];
		}
	}
	return false;
}

reset {
	if (!vars.hooked) {
		return false;
	}
	if (vars.gameTimeOld.TotalMilliseconds > vars.gameTime.TotalMilliseconds && vars.gameTime.TotalMilliseconds < 67) {
		// reset if game time resets (on exit to menu)
		// BUG: There are glitches that reset IGT, but they would invalidate
		// the run anyway (except Any%, which uses RTA, but then IGT is
		// irrelevant anyway)
		// BUG: sometimes the timer randomly resets during runs
		// Tried to fix by not resetting if gameTime is > 66
		if (vars.timeTrial == 0) {
			// print("VVVVVV Autosplitter ----- Reset @" + vars.gameTimeOld.TotalMilliseconds + " -> " + vars.gameTime.TotalMilliseconds + " timeTrial " + vars.timeTrialOld + " -> " + vars.timeTrial);
			return settings[vars.menuReset] || settings[vars.ils];
		}
	}
	// reset if in main menu (shouldn't ever really happen, but you never know)
	return vars.menuID == 1 && settings[vars.menuReset];
}

gameTime {
	return vars.gameTime;
}

isLoading {
	// disable game time approximation
	return true;
}

update {
	if (vars.hookAttempts > 3) {
		// If we fail to hook the game after 5 scans, there's no reason to keep scanning
		// print("VVVVVV Autosplitter ----- Could not hook into VVVVVV.exe");
		return false;
	} else if (!vars.hooked) {
		if (version == "v2.2") {
			// Wait for the game to finish loading
			// BUG: If clicked out or in Esc menu, this will not be the correct value, even though the game is loaded.
			// TODO: find another value / combination of values to accurately determine whether the game is loaded.
			if (current.doneLoading == 50) {
				// print("VVVVVV Autosplitter ----- Starting scan...");
				int addr = 0x0;
				// Scan memory for the base address of the game's variables
				for (int i = 0x00000000; !vars.hooked && i < 0x02000000; i += 0x10000) {
					// The base address of the game's variables will always be between ????CD00 and ????D600
					for (int j = 0xCD00; !vars.hooked && j < 0xD600; j += 0x4) {
						// The address we're looking for is a pointer to a pointer to the game's save directory
						addr = i+j;
						int val = game.ReadValue<int>(new IntPtr(addr));
						if (game.ReadString(new IntPtr(val), 255) == current.saveDirectory) {
							vars.hooked = true;
						}
					}
				}

				if (vars.hooked) {
					// We found the address, so we can find the variables we need
					vars.finalModeAddr = addr-0x53c;
					addr += 0x74;
					vars.gamestateAddr = addr;
					vars.menuIDAddr = addr+0x10;
					vars.trinketCountAddr = addr+0x3D0;
					vars.gameTimeHourAddr = addr+0x54;
					vars.gameTimeMinAddr = addr+0x50;
					vars.gameTimeSecAddr = addr+0x4c;
					vars.gameTimeFrameAddr = addr+0x48;
					vars.timeTrialAddr = addr+0x208;

					// print("VVVVVV Autosplitter ----- Gamestate address " + vars.gamestateAddr.ToString("X8"));
				} else {
					vars.hookAttempts += 1;
					return false;
				}
			} else {
				// Game hasn't finished loading yet
				return false;
			}
		} else if (version == "v2.0 Steam") {
			// We don't really need to wait for the game to load on v2.0, but it's probably a good idea to wait anyway
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
				vars.timeTrialAddr = addr+0x138;
				vars.finalModeAddr = addr-0x470;

				vars.hooked = true;


				// print("VVVVVV Autosplitter ----- Successfully hooked!");
			} else {
				// Game hasn't finished loading yet
				return false;
			}
		}
	}
	if (vars.hooked) {
		// Game is hooked succesfully, update variables
		vars.gameTimeOld = vars.gameTime;

		int gameTimeHours = game.ReadValue<int>(new IntPtr(vars.gameTimeHourAddr));
		int gameTimeMinutes = game.ReadValue<int>(new IntPtr(vars.gameTimeMinAddr));
		int gameTimeSeconds = game.ReadValue<int>(new IntPtr(vars.gameTimeSecAddr));
		int gameTimeFrames = game.ReadValue<int>(new IntPtr(vars.gameTimeFrameAddr));

		// subtract one frame from the timer because the autosplitter splits a frame late
		vars.gameTime = new TimeSpan(0, gameTimeHours, gameTimeMinutes, gameTimeSeconds, 100*(gameTimeFrames-1)/3);

		vars.gamestateOld = vars.gamestate;
		vars.menuIDOld = vars.menuID;
		vars.trinketCountOld = vars.trinketCount;
		vars.timeTrialOld = vars.timeTrial;
		vars.finalModeOld = vars.finalMode;

		vars.gamestate = game.ReadValue<int>(new IntPtr(vars.gamestateAddr));
		vars.menuID = game.ReadValue<int>(new IntPtr(vars.menuIDAddr));
		vars.trinketCount = game.ReadValue<int>(new IntPtr(vars.trinketCountAddr));

		vars.timeTrial = game.ReadValue<int>(new IntPtr(vars.timeTrialAddr));
		vars.finalMode = game.ReadValue<int>(new IntPtr(vars.finalModeAddr));

		/*if (vars.gamestateOld != vars.gamestate) {
			print("VVVVVV Autosplitter ----- Gamestate " + vars.gamestateOld + " -> " + vars.gamestate + " timeTrial " + vars.timeTrialOld + " -> " + vars.timeTrial);
		}*/
		/*if (vars.menuIDOld != vars.menuID) {
			print("VVVVVV Autosplitter ----- Menu ID " + vars.menuIDOld + " -> " + vars.menuID);
		}*/
		/*if (vars.gameTimeOld.TotalMilliseconds > vars.gameTime.TotalMilliseconds) {
			print("VVVVVV Autosplitter ----- Reset @" + vars.gameTimeOld.TotalMilliseconds + " -> " + vars.gameTime.TotalMilliseconds + " timeTrial " + vars.timeTrialOld + " -> " + vars.timeTrial);
		}*/
		return true;
	} else {
		// Game isn't hooked yet
		return false;
	}
}
