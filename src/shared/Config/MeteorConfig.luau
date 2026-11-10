--!strict
-- The meteor shower (EventConfig.EVENTS.Meteor has its clock): meteors fall along a strip from
-- the station outwards, through every zone. Each leaves a crater (a nest of its own) with one
-- meteor egg and a guardian; the crater takes the grade and guardian post of the nearest nest of
-- its zone, the egg its zone's loot. Meteor eggs hatch into meteor aliens
-- (AlienConfig.VARIANTS.Meteor). Looks in MeteorLooks and EggLooks.METEOR.

return table.freeze({
	-- A falling meteor's tag and the point it lands on (a Vector3 attribute): clients sound its
	-- fall there.
	METEOR_TAG = "Meteor",
	METEOR_TARGET_ATTRIBUTE = "Target",
	-- Eggs in one shower: this many per active player on the server (ActivityService: players
	-- away from the keyboard do not count), within the bounds; shared out among the zones, from
	-- the station outwards.
	EGGS_PER_PLAYER = 2,
	MIN_EGGS = 4,
	MAX_EGGS = 16,
	-- One meteor falls this often, seconds: a full shower is down in under a minute, and the rest
	-- of it is for grabbing the eggs (a config test keeps half the shower for that).
	FALL_STEP_SECONDS = 3,
	-- How far a crater lands to either side of the strip's middle line, studs.
	STRIP_HALF_WIDTH = 150,
	-- Craters keep at least this far from every nest and other crater, so each guardian has its
	-- own ground; a meteor that finds no such spot in a few tries does not fall.
	MIN_SPACING = 60,
	PLACE_ATTEMPTS = 12,
})
