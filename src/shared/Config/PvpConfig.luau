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

local HARPOON: Abilities.Harpoon = {
	rangeStuds = 50,
	-- Half-angle of the aim cone a carrier must be in.
	halfAngleRadians = math.rad(8),
	cooldownSeconds = 20,
	-- A shot that finds nobody costs less.
	missCooldownSeconds = 5,
}

local BOMB: Abilities.Bomb = {
	throwSpeed = 40,
	fuseSeconds = 1,
	contactStuds = 6,
	radiusStuds = 25,
	cooldownSeconds = 45,
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
	-- Test targets (playtests) carry this tag so the client's aim sees them like carriers.
	DUMMY_TAG = "PvpDummy",

	-- Greybox effects, seconds on screen. The harpoon's hook flies out to the target and back
	-- along the beam over its whole time.
	HARPOON_BEAM_SECONDS = 0.8,
	BOMB_FLASH_SECONDS = 0.4,
	-- The strike's impact: a burst at the touch point, its size and time on screen.
	STRIKE_IMPACT_RADIUS = 3,
	STRIKE_IMPACT_SECONDS = 0.25,
	-- Names of the effect instances (the client could dress them up later).
	HARPOON_BEAM_NAME = "HarpoonBeam",
	BOMB_NAME = "GravityBomb",
})
