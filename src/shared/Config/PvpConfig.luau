--!strict
-- Player versus player: who may attack whom and what each ability does. Pure Luau: tests load
-- it in Lune. Looks live in PvpLooks.

local Abilities = require("../Domain/Abilities")
local Pvp = require("../Domain/Pvp")

local RULES: Pvp.Rules = {
	-- A player is a newbie, safe from attacks and unable to attack, for this much play time.
	newbieSeconds = 20 * 60,
	-- Nobody can be attacked this soon after their character spawned.
	spawnGraceSeconds = 10,
	-- An attacker whose speed stat is this many times the victim's (or more) is held back.
	maxSpeedRatio = 10,
}

-- The strike: a lunge along the aim (about 10 studs ahead of where the attacker would be);
-- whoever the attacker touches on the way is hit. Not while carrying an egg: the hands are full.
local STRIKE: Abilities.Strike = {
	lungeSeconds = 0.25,
	lungeExtraSpeed = 40,
	-- Measured between character centers, so it allows for bodies.
	contactStuds = 6,
	contactHalfAngleRadians = math.rad(70),
	cooldownSeconds = 1.5,
}

-- Aim assist (decision 103): of the egg carriers within the range and the cone, the one nearest
-- the crosshair is hit (Abilities.bestInCone). The cone is wide enough for a thumb on a phone and
-- for what a client sees lagging behind the server at flight speeds.
local HARPOON: Abilities.Harpoon = {
	rangeStuds = 70,
	halfAngleRadians = math.rad(18),
	cooldownSeconds = 20,
	-- A shot that finds nobody costs less.
	missCooldownSeconds = 5,
}

-- The bomb leaves with the thrower's velocity plus `throwSpeed` along the aim, so it flies ahead
-- at any flight speed, and homes on the target nearest the crosshair (decision 103). It steers
-- far more weakly than a player turns (FlightConfig.TUNING.response): whoever flies straight is
-- caught, a sharp turn dodges it.
local BOMB: Abilities.Bomb = {
	throwSpeed = 60,
	fuseSeconds = 1.5,
	contactStuds = 8,
	radiusStuds = 25,
	cooldownSeconds = 45,
	homingRangeStuds = 120,
	homingHalfAngleRadians = math.rad(30),
	steerAcceleration = 180,
}

-- No shield (decision 060): it made every attack pointless.
return table.freeze({
	RULES = table.freeze(RULES),
	STRIKE = table.freeze(STRIKE),
	HARPOON = table.freeze(HARPOON),
	BOMB = table.freeze(BOMB),

	-- The strike lives in the simulation (predicted, so the attacker's lunge has no lag) and
	-- keeps its state on the character: seconds of lunge left, seconds of cooldown left and the
	-- lunge's direction. The server watches the lunge for a touch.
	STRIKE_LUNGE_ATTRIBUTE = "StrikeLunge",
	STRIKE_COOLDOWN_ATTRIBUTE = "StrikeCooldown",
	STRIKE_AIM_ATTRIBUTE = "StrikeAim",
	-- The punch animation, uploaded from ServerStorage.Strike (see StrikePose; re-upload over the
	-- same asset after changing the pose). Empty: no animation, the lunge works without it.
	STRIKE_ANIMATION_ID = "rbxassetid://82493247842000",
	STRIKE_ANIMATION_INSTANCE_NAME = "StrikeAnimation",
	STRIKE_ANIMATION_FADE_SECONDS = 0.05,
	-- Player attribute: seconds of newbie protection left, 0 once it is over (for the sign over
	-- the player and the newbie's own HUD).
	NEWBIE_ATTRIBUTE = "NewbieSecondsLeft",
	-- The bomb leaves this far ahead of the thrower, along the aim.
	BOMB_START_STUDS = 3,
	-- Test targets (playtests) carry this tag so the client's aim sees them like carriers.
	DUMMY_TAG = "PvpDummy",

	-- The strike's greybox impact: a burst at the touch point, its size and time on screen. The
	-- harpoon's and the bomb's looks are PvpLooks.
	STRIKE_IMPACT_RADIUS = 3,
	STRIKE_IMPACT_SECONDS = 0.25,
	-- The impact part's tag: clients play the hit's sound where it appears.
	STRIKE_IMPACT_TAG = "StrikeImpact",
})
