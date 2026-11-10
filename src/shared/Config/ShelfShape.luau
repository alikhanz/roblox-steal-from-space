--!strict
-- The island's shelf in numbers (docs/design/screens/storage-shelf.md): an arc of niches where the
-- aliens with no place stand small. Measured in the shelf's own frame: its origin on the floor in
-- the middle of the arc, halfway into the niches; -Z out of the niches (toward the player), X along
-- it, Y up. The arc bends toward -Z, round the path in front of it. Plain numbers, so tests load
-- it in Lune; BayLooks has its colours and where it stands on the island, Domain/Shelf the niches,
-- World/BayModel builds it. The kit of meshes (assets/blender/bay/storage_kit.py) is modelled to
-- the same numbers: keep them in step (a test compares them).

return table.freeze({
	COLUMNS = 8,
	TIERS = 3,
	-- One niche: its arc length at the niche's middle, its height (floor of one shelf to the
	-- next) and depth.
	CELL_WIDTH = 2.5,
	CELL_HEIGHT = 2.4,
	DEPTH = 2.3,
	-- The arc's radius at the niches' middle line.
	RADIUS = 22,
	-- The plinth under the bottom niches, each shelf board, the crown over the top ones, the
	-- uprights between niches and the back wall, studs.
	BASE_HEIGHT = 0.5,
	BOARD_THICKNESS = 0.18,
	CROWN_HEIGHT = 0.5,
	UPRIGHT_WIDTH = 0.3,
	BACK_THICKNESS = 0.15,
})
