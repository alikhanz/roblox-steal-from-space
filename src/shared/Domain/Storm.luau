--!strict
-- The solar storm's rules (StormService runs them). Pure Luau.

local Bounds = require("./Bounds")

local Storm = {}

-- Whether the storm brings a player back to their spawn as it starts: only one out in space past
-- the station border, the storm's edge. Anyone within it (under a dome, or flying between the
-- islands and the central station) stays where they are, egg and all: the storm's edge only
-- keeps them in.
function Storm.bringsHome(inSpace: boolean, position: Vector3, center: Vector3, borderRadius: number): boolean
	return inSpace and Bounds.isOutside(position, center, borderRadius)
end

return table.freeze(Storm)
