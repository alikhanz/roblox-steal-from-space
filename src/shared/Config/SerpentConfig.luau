--!strict
-- The star serpent (EventConfig.EVENTS.Serpent has its clock). For the 3 minutes of its hunt it
-- comes out of the Event Horizon and goes after everyone past the first zone. It chases the way
-- a guardian does (Speed.chaseSpeed), with the speed stat of the middle guardian of the zone
-- its prey is in: a player strong enough for the middle of their zone gets away even with a
-- light egg, a weaker one loses it. A catch is a guardian's: the prey is thrown and the egg
-- knocked out. Eggs delivered during the hunt hatch luckier. Pure Luau: the balance calculator
-- and tests load it. Looks live in SerpentLooks.

local BigNum = require("../Domain/BigNum")
local GuardianConfig = require("./GuardianConfig")
local ZoneConfig = require("./ZoneConfig")

local DEBRIS_BELT = ZoneConfig.ZONES.DebrisBelt
local EVENT_HORIZON = ZoneConfig.ZONES.EventHorizon

-- In each zone the serpent is as strong as the zone's guardian at this post (of the six, from
-- the station outwards).
local POWER_POST = 3

-- The serpent's speed stat when it chases a player `distance` studs from the station: that of
-- the POWER_POST guardian of the zone there (the nearest zone between rings).
local function powerAt(distance: number): BigNum.BigNum
	local zone = ZoneConfig.zoneAtDistance(distance) or ZoneConfig.ZONE_ORDER[1]
	return GuardianConfig.POSTS[ZoneConfig.postIndex(zone, POWER_POST)].speed
end

return table.freeze({
	-- Hunts players farther than this from the station: everyone past the Debris Belt. The
	-- serpent itself never comes closer.
	HUNT_RADIUS = DEBRIS_BELT.ringMax,
	-- Comes out in the middle of the Event Horizon's ring.
	SPAWN_RADIUS = (EVENT_HORIZON.ringMin + EVENT_HORIZON.ringMax) / 2,
	POWER_POST = POWER_POST,
	powerAt = powerAt,
	-- With nobody to hunt it roams its grounds at this speed, studs per second.
	ROAM_SPEED = 60,
	-- Aims this far ahead of its prey at most, seconds (Pursuit.interceptPoint).
	MAX_LEAD_SECONDS = 1,
	-- Catches within this distance of its head, studs.
	CATCH_RADIUS = 12,
	-- A caught player is left alone this long, seconds: one catch, not a stun lock.
	SPARE_SECONDS = 20,
	-- The catch throws the prey away at this speed; it tumbles and cannot steer for the stun.
	KNOCKBACK_SPEED = 80,
	STUN_SECONDS = 1.5,
	-- Luck on top of an egg's own for eggs delivered during the hunt (EggConfig.luckOf): about
	-- a rare egg's edge over an uncommon one.
	EGG_LUCK = 0.35,
	-- Logic rate, like the guardians'.
	TICK_SECONDS = 1 / 15,
	-- Its pin follows it this often, seconds.
	PIN_SECONDS = 0.25,
	-- Force budget of the movers.
	MAX_FORCE = 1e7,
	ALIGN_RESPONSIVENESS = 15,

	-- The serpent's model in workspace.World, for the clients to draw its body behind the head.
	MODEL_NAME = "StarSerpent",
	HEAD_NAME = "Head",
	VELOCITY_NAME = "SerpentVelocity",
	ALIGN_NAME = "SerpentAlign",
	-- Who dealt a hit (GuardianConfig.HIT_BY_ATTRIBUTE).
	HIT_BY = "Serpent",
})
