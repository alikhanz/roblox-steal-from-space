--!strict
-- Playtest switches. They only take effect in Studio (DevService does nothing in live servers;
-- the client checks RunService:IsStudio()), so a value left on here can never reach players. The
-- one exception, the pet bench, is held to the Dev game and its creator (BENCH_GAME_IDS).
-- Keep the gameplay ones off in commits by default; debug displays may stay on.

return table.freeze({
	-- Oxygen never runs out for players in Studio playtests.
	STUDIO_INFINITE_OXYGEN = false,
	-- Player attribute DevService sets for players with infinite oxygen (read by the simulation).
	INFINITE_OXYGEN_ATTRIBUTE = "DevInfiniteOxygen",
	-- Debug only, Studio only: the guardian's speed stat and its recommended one under its name.
	-- Players never see numbers there (decision 057's sign: the name's colour says it all).
	STUDIO_GUARDIAN_SPEED = true,
	-- The pet bench (BenchService, decision 082): the one dev tool that also works in a live
	-- server, only in these games (the Dev game, never the real one) and only for the game's
	-- creator. The player attribute that shows the client its buttons.
	BENCH_GAME_IDS = table.freeze({ 10774871729 }),
	BENCH_ATTRIBUTE = "BenchAllowed",
	-- The pet gallery's page on the bench ("crab 1/2", Domain/PetGallery.label), shown on its
	-- button; absent while no gallery stands.
	GALLERY_ATTRIBUTE = "BenchGallery",
})
