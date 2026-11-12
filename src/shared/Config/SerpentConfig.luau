--!strict
-- The star serpent (EventConfig.EVENTS.Serpent has its clock; decision 055). For the 3 minutes
-- of its hunt it comes out in one zone past the first, picked as the hunt is announced, and is
-- that zone's serpent to the end, wherever it is chased: the speed stat of the zone's middle
-- guardian, an egg of that guardian's grade. Carrying the star egg it winds through the whole
-- guardians' band, from past the station border to the map's edge (Domain/SerpentRoute), and
-- flees whoever comes near, circling the station and swerving, as fast as a player with its
-- stat would fly (a little slower): whoever is strong enough for the zone catches it. HITS_TO_DROP hits on its
-- head (strike, harpoon, bomb; the whole server together) knock the egg out (Domain/StarEgg:
-- rare or better, extra luck). Then it guards the egg like a guardian: hovers over it lying loose and chases whoever
-- carries it, with that same stat (Speed.chaseSpeed), throwing them and knocking it out. Pure
-- Luau: the balance calculator and tests load it. Looks live in SerpentLooks.

local BigNum = require("../Domain/BigNum")
local EggConfig = require("./EggConfig")
local GuardianBrain = require("../Domain/GuardianBrain")
local GuardianConfig = require("./GuardianConfig")
local SerpentRoute = require("../Domain/SerpentRoute")
local Speed = require("../Domain/Speed")
local SpeedConfig = require("./SpeedConfig")
local StationSize = require("./StationSize")
local ZoneConfig = require("./ZoneConfig")

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
	-- It never comes closer to the station than this, a little past the station border: every
	-- dome is well inside it. Like a guardian, it chases a thief carrying its egg until they
	-- are inside the border.
	INNER_RADIUS = StationSize.BORDER_RADIUS + 40,
	-- Nor farther than the edge of the last zone.
	OUTER_RADIUS = EVENT_HORIZON.ringMax,
	-- Its route keeps within this height above or below the station's level, studs.
	ROUTE_HEIGHT = 150,
	-- How its route winds (Domain/SerpentRoute).
	ROUTE = table.freeze({
		turnRadius = 100,
		minArc = 200,
		maxArc = 450,
		maxRadialStep = 450,
		turnBackChance = 0.05,
		swerveRadial = 150,
		swerveSeconds = 1.6,
		swerveClimb = 0.25,
	} :: SerpentRoute.Tuning),
	-- The zones it comes out in (one per hunt, at random), from the station outwards.
	ZONES = table.freeze(ZONES),
	POWER_POST = POWER_POST,
	FLEE_SPEED_SHARE = FLEE_SPEED_SHARE,
	powerIn = powerIn,
	fleeSpeedIn = fleeSpeedIn,
	-- Flees from the nearest player in space within this distance of its head, studs.
	FLEE_RADIUS = 150,
	-- With nobody near it winds along its route at this speed, studs per second.
	ROAM_SPEED = 60,

	-- Hits on its head that knock the egg out, the whole server together.
	HITS_TO_DROP = 3,
	-- Attacks land on its head (only: its body does not count) within this distance of the
	-- head's middle, studs (PvpService): the drawn head with its fins and horns reaches about 8,
	-- and a little more, so a hit that looks like it touched the head counts.
	HIT_RADIUS = 12,
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
	-- Near its spot over the egg it slows to close the gap in this many seconds
	-- (Pursuit.settleVelocity), as guardians do: an arrive radius in studs made fast movers shake.
	SETTLE_SECONDS = GuardianConfig.SETTLE_SECONDS,
	-- Aims this far ahead of a thief at most, seconds (Pursuit.interceptPoint).
	MAX_LEAD_SECONDS = 1,
	-- After a catch it waits this long before it can catch again, seconds.
	CATCH_COOLDOWN_SECONDS = GuardianConfig.CATCH_COOLDOWN_SECONDS,
	-- The catch throws the thief away at this speed; they tumble and cannot steer for the stun.
	KNOCKBACK_SPEED = 80,
	STUN_SECONDS = 1.5,

	-- Logic rate, like the guardians'.
	TICK_SECONDS = 1 / 15,
	-- How quickly its velocity follows each tick's aim, per second (Pursuit.ease): about a
	-- sixth of a second to turn, so its long body bends instead of jerking.
	STEER_RESPONSE = 6,
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
