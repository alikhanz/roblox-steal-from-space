--!strict
-- The meteor shower (EventConfig.EVENTS.Meteor has its clock): meteor eggs fall around one
-- guardian's nest while it lasts. That guardian guards them like its own egg; they hatch into
-- the meteor variant of its aliens (AlienConfig.VARIANTS.Meteor), and their rarity and size come
-- from its zone's loot. Looks in EggLooks (METEOR, METEOR_STREAK).

return table.freeze({
	-- Eggs in one shower: this many per player on the server, within the bounds.
	EGGS_PER_PLAYER = 2,
	MIN_EGGS = 4,
	MAX_EGGS = 16,
	-- The eggs fall evenly over this share of the shower, so the last ones still give a chance
	-- to grab them before it ends.
	FALL_SHARE = 0.75,
	-- How far from the nest an egg lands, studs: across, and up or down.
	SCATTER_RADIUS = 40,
	SCATTER_HEIGHT = 12,
})
