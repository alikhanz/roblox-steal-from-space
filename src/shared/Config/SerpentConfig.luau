--!strict
-- The star serpent (EventConfig.EVENTS.Serpent has its clock; decision 055). For the 3 minutes
-- of its hunt it comes out in one zone past the first, picked as the hunt is announced, and is
-- that zone's serpent to the end, wherever it is chased: the speed stat of the zone's middle
-- guardian, an egg of that guardian's grade. It roams its zone carrying the star egg and flees
-- whoever comes near, as fast as a player with its stat would fly (a little slower): whoever
-- is strong enough for the zone catches it. HITS_TO_DROP hits on its head (strike, harpoon,
-- bomb; the whole server together) knock the egg out (Domain/StarEgg: rare or better, extra
-- luck). Then it guards the egg like a guardian: hovers over it lying loose and chases whoever
-- carries it, with that same stat (Speed.chaseSpeed), throwing them and knocking it out. Pure
-- Luau: the balance calculator and tests load it. Looks live in SerpentLooks.

local BigNum = require("../Domain/BigNum")
local EggConfig = require("./EggConfig")
local GuardianBrain = require("../Domain/GuardianBrain")
local GuardianConfig = require("./GuardianConfig")
local Speed = require("../Domain/Speed")
local SpeedConfig = require("./SpeedConfig")
local ZoneConfig = require("./ZoneConfig")

local DEBRIS_BELT = ZoneConfig.ZONES.DebrisBelt
local EVENT_HORIZON = ZoneConfig.ZONES.EventHorizon

-- In each zone the serpent is as strong as the zone's guardian at this post (of the six, from
-- the station outwards), and its egg hatches into that guardian's grade.
local POWER_POST = 3
-- It flees at this share of the flight speed of a player with its stat, so that player gains
-- on it.
local FLEE_SPEED_SHARE = 0.9

-- The zones it can come out in: every zone past the first, where it never goes.
local ZONES: { ZoneConfig.ZoneId } = table.clone(ZoneConfig.ZONE_ORDER)
table.remove(ZONES, 1)

-- The serpent of `zone` (the one it came out in, for the whole hunt, wherever it is chased):
-- the speed stat of that zone's POWER_POST guardian.
local function powerIn(zone: ZoneConfig.ZoneId): BigNum.BigNum
	return GuardianConfig.POSTS[ZoneConfig.postIndex(zone, POWER_POST)].speed
end

-- How fast the serpent of `zone` flees, studs per second.
local function fleeSpeedIn(zone: ZoneConfig.ZoneId): number
	return Speed.flightSpeed(powerIn(zone), SpeedConfig.FLIGHT) * FLEE_SPEED_SHARE
end

-- How it guards its egg once it is out: a guardian's brain, a guardian's head start.
local BRAIN: GuardianBrain.Tuning = {
	aggroDelaySeconds = GuardianConfig.BRAIN.aggroDelaySeconds,
	homeRadius = 10,
	-- Its head is big: it catches within this distance of the head's middle, studs.
	catchRadius = 12,
}

return table.freeze({
	-- It never comes closer to the station than this: the Debris Belt is out of its reach, so
	-- a thief who makes it there has got away.
	HUNT_RADIUS = DEBRIS_BELT.ringMax,
	-- Nor farther than the edge of the last zone.
	OUTER_RADIUS = EVENT_HORIZON.ringMax,
	-- The zones it comes out in (one per hunt, at random), from the station outwards.
	ZONES = table.freeze(ZONES),
	POWER_POST = POWER_POST,
	FLEE_SPEED_SHARE = FLEE_SPEED_SHARE,
	powerIn = powerIn,
	fleeSpeedIn = fleeSpeedIn,
	-- Flees from the nearest player in space within this distance of its head, studs.
	FLEE_RADIUS = 150,
	-- With nobody near it roams its zone's ring at this speed, studs per second.
	ROAM_SPEED = 60,

	-- Hits on its head that knock the egg out, the whole server together.
	HITS_TO_DROP = 3,
	-- Attacks land on its head within this distance of the head's middle, studs (PvpService).
	HIT_RADIUS = 7,
	-- The star egg (Domain/StarEgg): of this rarity at least, with this much luck on top of its
	-- own (EggConfig.luckOf): twice the first version's hunt luck.
	STAR_EGG_MIN_RARITY = "Rare" :: EggConfig.RarityId,
	STAR_EGG_LUCK = 0.7,
	-- A star egg lying loose when the hunt's time runs out stays this long, unguarded, for whoever
	-- gets to it first, seconds: a knock-out in the last moment is not wasted.
	STAR_EGG_LINGER_SECONDS = 30,
	-- The egg's home (Domain/EggHomes): carried and loose star eggs name it.
	EGG_HOME_ID = "StarSerpent",

	-- Guarding the egg once it is out.
	BRAIN = table.freeze(BRAIN),
	-- Hovers this far above its egg lying loose, studs.
	HOVER_HEIGHT = 12,
	-- Eases into its spot over the egg within this distance, studs.
	ARRIVE_RADIUS = 10,
	-- Aims this far ahead of a thief at most, seconds (Pursuit.interceptPoint).
	MAX_LEAD_SECONDS = 1,
	-- After a catch it waits this long before it can catch again, seconds.
	CATCH_COOLDOWN_SECONDS = GuardianConfig.CATCH_COOLDOWN_SECONDS,
	-- The catch throws the thief away at this speed; they tumble and cannot steer for the stun.
	KNOCKBACK_SPEED = 80,
	STUN_SECONDS = 1.5,

	-- Logic rate, like the guardians'.
	TICK_SECONDS = 1 / 15,
	-- Its pin follows it (or its egg) this often, seconds.
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
	-- On the event's folder (ReplicatedStorage.Events.Serpent), for the clients: where the star
	-- egg is (SerpentHunt.EggPlace), the hits landed since it was last inside, who knocked it
	-- out or delivered it (display name), and how the hunt ended when its time ran out
	-- (SerpentHunt.Ending).
	EGG_ATTRIBUTE = "StarEgg",
	HITS_ATTRIBUTE = "SerpentHits",
	EGG_BY_ATTRIBUTE = "StarEggBy",
	ENDING_ATTRIBUTE = "SerpentEnding",
	-- On the head: server time of the last hit, for the clients' flash.
	LAST_HIT_ATTRIBUTE = "LastHit",
})
