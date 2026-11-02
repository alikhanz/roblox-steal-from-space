--!strict
-- Where a position is in the world. Pure: works only with the vectors it is given.

local Zones = {}

export type Dome = {
	read center: Vector3,
	read radius: number,
}

-- Under the station dome: normal gravity and walking. Outside: open space, jetpack flight.
function Zones.isInsideDome(position: Vector3, dome: Dome): boolean
	return (position - dome.center).Magnitude <= dome.radius
end

return table.freeze(Zones)
