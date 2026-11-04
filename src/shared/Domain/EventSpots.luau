--!strict
-- An event that happens in many places at once (the meteor shower's craters) is marked zone by
-- zone: one pin per zone, on the spot of it nearest to the player, so the farther zones show up
-- too instead of hiding behind the first one. Pure: the caller measures the distances.

export type Spot<T> = {
	read zone: string,
	read distance: number,
	read item: T,
}

local EventSpots = {}

-- The nearest spot of each zone, nearest first.
function EventSpots.nearestPerZone<T>(spots: { Spot<T> }): { Spot<T> }
	local byZone: { [string]: Spot<T> } = {}
	for _, spot in spots do
		local best = byZone[spot.zone]
		if not best or spot.distance < best.distance then
			byZone[spot.zone] = spot
		end
	end
	local result: { Spot<T> } = {}
	for _, spot in byZone do
		table.insert(result, spot)
	end
	table.sort(result, function(a: Spot<T>, b: Spot<T>)
		return a.distance < b.distance
	end)
	return result
end

return table.freeze(EventSpots)
