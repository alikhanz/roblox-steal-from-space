--!strict
-- The island incubator (docs/design/screens/incubator.md): where each slot stands in its ring, and
-- how high the chip over an egg in a capsule hangs. Pure Luau; the numbers are
-- Config/IncubatorShape's.

local Incubator = {}

export type Shape = {
	read POSITIONS: number,
	read EGG_FLOOR: number,
	read POD_HEIGHT: number,
}

-- Slot `index`'s angle about the incubator's centre (1-based), in the island's frame: 0 toward
-- its back (+Z), pi toward the entrance (-Z). The first slot faces the entrance, the next ones
-- alternate to either side of it: the slots a new player has stand in front, and every bought one
-- joins them.
function Incubator.slotAngle(index: number, shape: Shape): number
	assert(index >= 1 and index <= shape.POSITIONS and index % 1 == 0, `no incubator slot {index}`)
	local step = math.pi * 2 / shape.POSITIONS
	local offset = math.ceil((index - 1) / 2) * (if index % 2 == 0 then 1 else -1)
	return math.pi + offset * step
end

-- How far above the centre of an egg `eggHeight` tall, hovering in an open capsule, its chip
-- hangs: `overPod` over the petals' tips, so the chips of the ring stand in one even row; an egg
-- taller than the petals (with the room it wears) puts its chip `overEgg` over its own top.
function Incubator.chipAbove(eggHeight: number, shape: Shape, overPod: number, overEgg: number): number
	local overTips = shape.POD_HEIGHT + overPod - shape.EGG_FLOOR - eggHeight / 2
	return math.max(overTips, eggHeight / 2 + overEgg)
end

return table.freeze(Incubator)
