--!strict
-- The hard edge of the map: a sphere around the station nobody flies out of. Applied inside the
-- flight simulation, so it holds on the server and cannot be bypassed. Pure Luau.

local Bounds = {}

function Bounds.isOutside(position: Vector3, center: Vector3, radius: number): boolean
	return (position - center).Magnitude >= radius
end

-- The velocity with its outward component removed once at or past the edge, so the flyer slides
-- along the boundary and can always turn back. Inside the edge the velocity is unchanged.
function Bounds.limitVelocity(position: Vector3, velocity: Vector3, center: Vector3, radius: number): Vector3
	local offset = position - center
	if offset.Magnitude < radius then
		return velocity
	end
	local outward = offset.Unit
	local outwardSpeed = velocity:Dot(outward)
	if outwardSpeed <= 0 then
		return velocity
	end
	return velocity - outward * outwardSpeed
end

return table.freeze(Bounds)
