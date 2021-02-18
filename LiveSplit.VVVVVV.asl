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
	
	vars.gamestate = -1;
	vars.menuID = -1;
	vars.trinketCount = 0;
	vars.finalMode = 0;
	vars.gameTime = new TimeSpan(0, 0, 0, 0);

	vars.timeTrial = -1;
	
	if (version == "v2.2") {
		// print("------- VVVVVV TESTING -------");
		
		var baseAddress = new IntPtr(0);
		var regionSize = 0;
		
		var gameObjectAddr = -1;
		
		// Find the memory page containing the stack
		foreach (MemoryBasicInformation mbi in game.MemoryPages()) {
			// Scan for the music class on the stack
			var scanner = new SignatureScanner(game, mbi.BaseAddress, (int) mbi.RegionSize.ToUInt64());
			
			// Note: Masks always mask the entire byte, so 0? and ?0 are the same as ??
			IntPtr musicClassPtr = scanner.Scan(new SigScanTarget(0,
				"?? ?? ?? ??",	// int currentsong;
				"CC CC CC CC",	// int musicfade;
				"CC CC CC CC",	// int musicfadein;
				"CC CC CC CC",	// int resumesong;
				"?? ?? ?? ??",	// std::vector<SoundTrack> soundTracks (*begin);
				"?? ?? ?? ??",	// (*end)
				"?? ?? ?? ??",	// (*end_capacity)
				"CC CC CC CC",	// 4 unused bytes
				"?? ?? ?? ??",	// std::vector<MusicTrack> musicTracks (*begin);
				"?? ?? ?? ??",	// (*end)
				"?? ?? ?? ??",	// (*end_capacity)
				"CC CC CC CC",	// 4 unused bytes
				"?? ?? ?? ??",	// SoundSystem soundSystem; bool safeToProcessMusic; 2 unused bytes
				"?? ?? ?? ??",	// int nicechange;
				"?? ?? ?? ??",	// int nicefade;
				"0? CC CC CC",	// bool m_doFadeInVol; 3 unused bytes
				"?? ?0 00 00",	// int FadeVolAmountPerFrame; invariant <= 128;
				"?? ?0 00 00",	// int musicvolume; invariant <= 128;
				"?? ?? ?? ??",	// float volume;
				"00 0? 0? CC"	// bool custompd; bool mmmmmm; bool usingmmmmmm; 1 unused byte
			), 4); // 4 byte aligned
			
			// First value of game object is a pointer to the save location
			// Use that to verify we have successfully found the right address
			var tempGameObjectAddr = musicClassPtr.ToInt32() + 0x418 - 0x28E8;
			var saveDirAddr = game.ReadValue<int>(new IntPtr(tempGameObjectAddr));
			if (game.ReadString(new IntPtr(saveDirAddr), 255) == current.saveDirectory) {
				gameObjectAddr = tempGameObjectAddr;
				break;
			}
		}
		
		// Workaround copied from A Hat In Time autosplitter :)
		if (gameObjectAddr == -1) {
			// Waiting for the game to have booted up. This is a pretty ugly work
			// around, but we don't really know when the game is booted or where the
			// struct will be, so to reduce the amount of searching we are doing, we
			// sleep a bit between every attempt.
			Thread.Sleep(1000);
			throw new Exception("Could not find music class!");
		}
		
		// Found the right address, we can find the variables we need
		vars.finalModeAddr		= gameObjectAddr - 0x53c;
		vars.gamestateAddr		= gameObjectAddr + 0x74	;
		vars.menuIDAddr			= gameObjectAddr + 0x84	;
		vars.gameTimeFrameAddr	= gameObjectAddr + 0xBC	;
		vars.gameTimeSecAddr	= gameObjectAddr + 0xC0	;
		vars.gameTimeMinAddr	= gameObjectAddr + 0xC4	;
		vars.gameTimeHourAddr	= gameObjectAddr + 0xC8	;
		vars.timeTrialAddr		= gameObjectAddr + 0x27C;
		vars.trinketCountAddr	= gameObjectAddr + 0x444;
		
		// print("VVVVVV Autosplitter ----- Successfully hooked!");
	} else if (version == "v2.0 Steam") {
		var ptr = IntPtr.Add(modules.First().BaseAddress, 0x0167658);
		int addr = game.ReadValue<int>(ptr) + 0x4B8;

		vars.finalModeAddr = addr-0x470;
		vars.gamestateAddr = addr;
		vars.menuIDAddr = addr+0x8;
		vars.gameTimeFrameAddr = addr+0x3c;
		vars.gameTimeSecAddr = addr+0x40;
		vars.gameTimeMinAddr = addr+0x44;
		vars.gameTimeHourAddr = addr+0x48;
		vars.timeTrialAddr = addr+0x138;
		vars.trinketCountAddr = addr+0x250;

		// print("VVVVVV Autosplitter ----- Successfully hooked!");
	}
}

start {
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
	
	return false;
}

split {
	// BUG: sometimes randomly won't split... is the autosplitter "missing" the
	// frames where the gamestate is changed to the right value?
	
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
	
	return false;
}

reset {
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
	// Update variables
	vars.gameTimeOld = vars.gameTime;

	int gameTimeHours = game.ReadValue<int>(new IntPtr(vars.gameTimeHourAddr));
	int gameTimeMinutes = game.ReadValue<int>(new IntPtr(vars.gameTimeMinAddr));
	int gameTimeSeconds = game.ReadValue<int>(new IntPtr(vars.gameTimeSecAddr));
	int gameTimeFrames = game.ReadValue<int>(new IntPtr(vars.gameTimeFrameAddr));

	// Subtract one frame from the timer because the autosplitter splits a frame late
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

	// Debug stuff
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
}
