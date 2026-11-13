--!strict
-- The jetpack stand, the trainer on a player's island (docs/design/screens/jetpack-stand.md):
-- the owner who walks into its zone is pulled onto it and held there, the jetpack burning, until
-- they jump or step away. Where it stands and its zone are BayConfig.TRAINER_PAD; the logic is
-- Domain/Stand. Plain values, so the simulation and Lune load it.

return table.freeze({
	-- On the Player: the island (StationConfig.ISLANDS) their bay stands on; set by BayService.
	ISLAND_ATTRIBUTE = "Island",
	-- On the Player: their trainer's level, for the stand's flame (TrainingService).
	TRAINER_LEVEL_ATTRIBUTE = "TrainerLevel",
	-- On the character: where they are with the stand (Domain/Stand.State); written by the
	-- simulation.
	STATE_ATTRIBUTE = "Stand",

	-- The stand's platform: the owner stands on it, this high above the island floor, facing the
	-- island's center.
	PLATFORM_HEIGHT = 0.6,
	-- The stand holds its rider this far over the platform, feet off it, as if the jetpack held
	-- them up: standing on it in the shaking pose read as twitching on the floor (user,
	-- 2026-11-13). Within the pad's zone height (BayConfig.TRAINER_PAD.height).
	HOVER_HEIGHT = 1.2,
	-- The pull onto the stand: about this long, never faster than this, studs per second.
	PULL_SECONDS = 0.3,
	PULL_MAX_SPEED = 30,
	-- Move input past this share of a full step takes the player off the stand.
	LEAVE_MOVE_THRESHOLD = 0.1,

	-- The jetpack's flame on the stand grows with the trainer's level, up to this many times its
	-- size at this level (logarithmically: big steps early, then slower).
	FLAME_MAX_SCALE = 3,
	FLAME_FULL_LEVEL = 20,

	-- The training pose (Character/StandPose), uploaded from ServerStorage.StandTraining (see
	-- StandPose; re-upload over the same asset keeps the id). Empty: the player stands in the
	-- default pose and training still works.
	ANIMATION_ID = "rbxassetid://76900933840927",
	ANIMATION_INSTANCE_NAME = "StandTraining",
	ANIMATION_FADE_SECONDS = 0.2,
})
