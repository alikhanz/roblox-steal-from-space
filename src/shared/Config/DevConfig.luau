--!strict
-- Playtest switches. They only take effect in Studio (DevService does nothing in live servers),
-- so a value left on here can never reach players. Keep them off in commits by default.

return table.freeze({
	-- Oxygen never runs out for players in Studio playtests.
	STUDIO_INFINITE_OXYGEN = false,
	-- Player attribute DevService sets for players with infinite oxygen (read by the simulation).
	INFINITE_OXYGEN_ATTRIBUTE = "DevInfiniteOxygen",
})
