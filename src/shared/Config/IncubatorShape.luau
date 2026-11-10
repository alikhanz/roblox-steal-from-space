--!strict
-- The island incubator in numbers (docs/design/screens/incubator.md): a dais with a heater in its
-- middle and a ring of slots, each an open capsule (bought) or a closed bud. Measured in studs; the
-- dais from the incubator's centre on the floor, a slot from its own frame on the dais's top (-Z
-- out of the ring, Y up). Plain numbers, so tests load it in Lune; BayLooks has the colours,
-- Domain/Incubator the slots' places and the chip's height, World/BayModel builds it. The kit of
-- meshes (assets/blender/bay/incubator_kit.py) is modelled to the same numbers: keep them in step
-- (a test compares them).

return table.freeze({
	-- Slots in the ring, and the ring's radius (to the slots' centres).
	POSITIONS = 12,
	RING_RADIUS = 9,
	-- The dais under them, and the heater in its middle (its pipes run to every slot).
	DAIS_RADIUS = 11.4,
	DAIS_HEIGHT = 0.6,
	CORE_RADIUS = 2.6,
	CORE_HEIGHT = 2,
	-- A slot's socket (its widest), and how high above the dais an egg's bottom hovers in an open
	-- capsule (every size: EggLooks.liftOf).
	SOCKET_RADIUS = 2,
	EGG_FLOOR = 1.45,
	-- The tips of an open capsule's petals, and the top of a closed bud.
	POD_HEIGHT = 4.6,
	BUD_HEIGHT = 3.4,
})
