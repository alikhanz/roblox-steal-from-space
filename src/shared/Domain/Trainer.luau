--!strict
-- The trainer pad: whether a position (in the bay's own frame, Y up from the floor) counts as
-- standing on it. The pad is a disc; a little slack around its edge keeps a player who stands
-- half on it training. Pure Luau.

local Trainer = {}

export type Pad = {
	-- Center of the pad in the bay's frame.
	read x: number,
	read z: number,
	read radius: number,
	-- A player higher than this above the floor (jumping, flying over) is not on the pad.
	read height: number,
}

function Trainer.isOnPad(localX: number, localY: number, localZ: number, pad: Pad, tolerance: number): boolean
	assert(tolerance >= 0, "pad tolerance must not be negative")
	if localY < 0 or localY > pad.height then
		return false
	end
	local dx = localX - pad.x
	local dz = localZ - pad.z
	local reach = pad.radius + tolerance
	return dx * dx + dz * dz <= reach * reach
end

return table.freeze(Trainer)
