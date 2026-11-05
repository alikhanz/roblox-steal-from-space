--!strict
-- Playtest switches. They only take effect in Studio (DevService does nothing in live servers;
-- the client checks RunService:IsStudio()), so a value left on here can never reach players.
-- Keep the gameplay ones off in commits by default; debug displays may stay on.

return table.freeze({
	-- Oxygen never runs out for players in Studio playtests.
	STUDIO_INFINITE_OXYGEN = false,
	-- Player attribute DevService sets for players with infinite oxygen (read by the simulation).
	INFINITE_OXYGEN_ATTRIBUTE = "DevInfiniteOxygen",
	-- Debug only, Studio only: the guardian's speed stat and its recommended one under its name.
	-- Players never see numbers there (decision 057's sign: the name's colour says it all).
	STUDIO_GUARDIAN_SPEED = true,
})
