--!strict
-- Which islands' pets a client builds (decision 123). The server stands only a box for each pet
-- (World/AlienModel); a client builds the pets of an island while its camera is near the island,
-- and when it flies off keeps them hidden a while, so coming back shows them at once. Pure Luau:
-- AlienViewController feeds it the distances and the clock.

local PetView = {}

-- Whether an island's pets are shown with the camera `distance` studs from its centre: they come
-- within `reach` and go only past `reach + margin`, so the edge does not flicker.
function PetView.shows(distance: number, shown: boolean, reach: number, margin: number): boolean
	return distance <= reach + (if shown then margin else 0)
end

-- The island (its index in `centres`) a pet standing at `position` belongs to: the nearest centre.
function PetView.nearest(position: Vector3, centres: { Vector3 }): number
	local best, bestDistance = 1, math.huge
	for index, centre in centres do
		local distance = (position - centre).Magnitude
		if distance < bestDistance then
			best, bestDistance = index, distance
		end
	end
	return best
end

-- The islands whose hidden pets go now: those hidden for `holdSeconds` or longer, and the longest
-- hidden ones past the newest `maxHeld` (each island's pets are held from `heldSince`, a clock time).
-- In the order they were hidden.
function PetView.toDrop(heldSince: { [number]: number }, now: number, holdSeconds: number, maxHeld: number): { number }
	local held: { number } = {}
	for island in heldSince do
		table.insert(held, island)
	end
	-- Oldest first; one clock time for two islands keeps a steady order.
	table.sort(held, function(a, b)
		if heldSince[a] ~= heldSince[b] then
			return heldSince[a] < heldSince[b]
		end
		return a < b
	end)
	local drop: { number } = {}
	for index, island in held do
		if now - heldSince[island] >= holdSeconds or index <= #held - maxHeld then
			table.insert(drop, island)
		end
	end
	return drop
end

return table.freeze(PetView)
