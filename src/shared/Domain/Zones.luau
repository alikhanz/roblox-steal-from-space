--!strict
-- Where a position is in the world. Pure: works only with the vectors it is given.
--
-- The station zone is the part of the dome above the bottom of the platform: walking with
-- gravity there, jetpack flight everywhere else (including right under the platform).

local Zones = {}

export type Station = {
	read domeCenter: Vector3,
	read domeRadius: number,
	-- World height of the platform's underside; below it is open space.
	read floorY: number,
}

-- How deep inside the station zone a position is, in studs (negative when outside).
local function depthInside(position: Vector3, station: Station): number
	local fromDome = station.domeRadius - (position - station.domeCenter).Magnitude
	local aboveFloor = position.Y - station.floorY
	return math.min(fromDome, aboveFloor)
end

function Zones.isInStation(position: Vector3, station: Station): boolean
	return depthInside(position, station) >= 0
end

-- Decides the next mode with hysteresis, so a character hovering on the boundary does not flip
-- between flying and walking every step: switching to walking needs `margin` studs inside,
-- switching to flying needs `margin` studs outside.
function Zones.nextInSpace(wasInSpace: boolean, position: Vector3, station: Station, margin: number): boolean
	local depth = depthInside(position, station)
	if wasInSpace then
		return depth < margin
	end
	return depth < -margin
end

return table.freeze(Zones)
