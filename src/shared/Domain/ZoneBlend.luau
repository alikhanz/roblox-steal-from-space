--!strict
-- How much of which zone a spot `distance` studs from the station belongs to, for the zones'
-- looks (docs/plans/ZONES.md): inside a zone's ring it is that zone; across the gap between two
-- rings one zone gives way to the next, evenly; this side of the first ring it is the first zone,
-- past the last ring the last. The field's rocks and the zone's tint on screen both follow it, so
-- a zone has no line where it starts.

local ZoneConfig = require("../Config/ZoneConfig")

export type Blend = {
	-- The zone on the station's side and the next one out (the same inside a ring).
	inner: ZoneConfig.ZoneId,
	outer: ZoneConfig.ZoneId,
	-- How far into the outer zone, 0..1.
	t: number,
}

local ZoneBlend = {}

function ZoneBlend.at(distance: number): Blend
	local order = ZoneConfig.ZONE_ORDER
	for index, id in order do
		local ring = ZoneConfig.ZONES[id]
		if distance <= ring.ringMax then
			if index == 1 or distance >= ring.ringMin then
				return { inner = id, outer = id, t = 0 }
			end
			local previous = order[index - 1]
			local from = ZoneConfig.ZONES[previous].ringMax
			return { inner = previous, outer = id, t = (distance - from) / (ring.ringMin - from) }
		end
	end
	local last = order[#order]
	return { inner = last, outer = last, t = 0 }
end

-- The zone whose looks a thing at `distance` takes: across a gap, the outer one with a chance
-- of how far in it is. `roll` is 0..1.
function ZoneBlend.pick(distance: number, roll: number): ZoneConfig.ZoneId
	local blend = ZoneBlend.at(distance)
	return if roll < blend.t then blend.outer else blend.inner
end

return ZoneBlend
