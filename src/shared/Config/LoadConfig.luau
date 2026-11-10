--!strict
-- The order the client loads its assets in (Domain/LoadOrder, client Loading/AssetQueue): the
-- player's own jetpack at once, everything else queued behind it by PRIORITY, one preload at a time.

return table.freeze({
	-- The queue waits at most this long for the player's own jetpack, seconds since the client started
	-- (a rig with no jetpack, a profile slow to load).
	JETPACK_WAIT_SECONDS = 20,
	-- One queued preload holds up the next at most this long, seconds; it goes on loading anyway.
	JOB_SECONDS = 8,
	-- Higher first. Things that show up in front of the player go before things in hidden windows.
	PRIORITY = table.freeze({
		-- Other players' jetpacks.
		JETPACK = 7,
		-- One job at the join, and the clicks and the engine are needed in the first seconds
		-- (Studio, 2026-11-11: after the guardians it waited 3 s behind the six near the island).
		SOUNDS = 6,
		-- The star serpent, a guardian near the camera: they are in front of the player right now.
		SERPENT = 5,
		GUARDIAN = 5,
		-- Pets on the player's own island, then everyone else's.
		OWN_PETS = 3,
		PETS = 2,
		-- The alien icon sheets: windows open later.
		ICONS = 1,
	}),
})
