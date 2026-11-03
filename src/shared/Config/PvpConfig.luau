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

-- The strike: a wind-up, then a lunge; whoever stands in the corridor ahead is hit.
local STRIKE: Abilities.Strike = {
	windupSeconds = 0.3,
	lungeStuds = 8,
	-- The corridor: this far ahead of the attacker, within this half-angle of their facing.
	reachStuds = 9,
	halfAngleRadians = math.rad(35),
	cooldownSeconds = 1.5,
	-- A miss leaves the attacker without thrust for this long.
	missStallSeconds = 0.5,
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

local SHIELD: Abilities.Shield = {
	seconds = 6,
	cooldownSeconds = 30,
}

local DASH: Abilities.Dash = {
	seconds = 0.8,
	multiplier = 2.2,
	cooldownSeconds = 8,
}

return table.freeze({
	RULES = table.freeze(RULES),
	STRIKE = table.freeze(STRIKE),
	HARPOON = table.freeze(HARPOON),
	BOMB = table.freeze(BOMB),
	SHIELD = table.freeze(SHIELD),
	DASH = table.freeze(DASH),

	-- Character attributes the abilities write and the simulation and clients read.
	SHIELD_UNTIL_ATTRIBUTE = "ShieldUntil",
	DASH_UNTIL_ATTRIBUTE = "DashUntil",
	-- Player attribute: true while the newbie protection holds (for the sign over the player).
	NEWBIE_ATTRIBUTE = "Newbie",

	-- Greybox effects, seconds on screen.
	HARPOON_BEAM_SECONDS = 0.35,
	BOMB_FLASH_SECONDS = 0.4,
	-- Names of the effect instances (the client could dress them up later).
	HARPOON_BEAM_NAME = "HarpoonBeam",
	BOMB_NAME = "GravityBomb",
})
