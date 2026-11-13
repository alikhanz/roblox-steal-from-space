--!strict
-- Which islands' pets a client builds, and how (decision 123). The server stands only a box for
-- each pet (World/AlienModel); a client builds the pets of an island whole while its camera is near
-- the island, plain on the next few islands, and when an island is left with neither keeps its pets
-- hidden a while, so coming back shows them at once. Pure Luau: AlienViewController feeds it the
-- distances and the clock.

local PetView = {}

-- Whether an island's pets are shown with the camera `distance` studs from its centre: they come
-- within `reach` and go only past `reach + margin`, so the edge does not flicker.
function PetView.shows(distance: number, shown: boolean, reach: number, margin: number): boolean
	return distance <= reach + (if shown then margin else 0)
end

-- How an island's pets are shown: whole (moving, with their effects) or plain (standing still,
-- body and outfit only). Not shown: no level.
export type Level = "Whole" | "Plain"

-- The distances and counts `levels` decides by (AlienLooks.VIEW).
export type Reach = {
	read REACH: number,
	read MARGIN: number,
	read NEIGHBOURS: number,
	read NEIGHBOUR_REACH: number,
}

-- How each island's pets are shown with the camera `distances[island]` studs from its centre, when
-- `was` is how they are shown now. Whole within reach (PetView.shows). Of the rest within the
-- neighbours' reach, the `NEIGHBOURS` nearest are plain; one shown already stays so until another
-- is `MARGIN` nearer than it, and past the reach by `MARGIN`, so the choice does not flicker.
function PetView.levels(distances: { number }, was: { [number]: Level }, reach: Reach): { [number]: Level }
	local levels: { [number]: Level } = {}
	local others: { number } = {}
	local ranks: { [number]: number } = {}
	for island, distance in distances do
		local shown = was[island] ~= nil
		if PetView.shows(distance, was[island] == "Whole", reach.REACH, reach.MARGIN) then
			levels[island] = "Whole"
		elseif PetView.shows(distance, shown, reach.NEIGHBOUR_REACH, reach.MARGIN) then
			table.insert(others, island)
			ranks[island] = distance - (if shown then reach.MARGIN else 0)
		end
	end
	table.sort(others, function(a, b)
		if ranks[a] ~= ranks[b] then
			return ranks[a] < ranks[b]
		end
		return a < b
	end)
	for index = 1, math.min(reach.NEIGHBOURS, #others) do
		levels[others[index]] = "Plain"
	end
	return levels
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
