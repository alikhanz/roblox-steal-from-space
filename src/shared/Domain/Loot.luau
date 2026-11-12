--!strict
-- Weighted random choice, e.g. which rarity a new egg gets. Pure: the random number is passed in.

local Loot = {}

export type Entry<T> = {
	read id: T,
	read weight: number,
}

-- Picks an entry for `roll` in [0, 1). Entries with zero weight are never picked.
function Loot.pick<T>(entries: { Entry<T> }, roll: number): T
	assert(#entries > 0, "Loot.pick needs at least one entry")
	local total = 0
	for _, entry in entries do
		assert(entry.weight >= 0, "Loot weights must not be negative")
		total += entry.weight
	end
	assert(total > 0, "Loot.pick needs a positive total weight")

	local target = math.clamp(roll, 0, 1) * total
	local cumulative = 0
	local lastPickable = entries[1].id
	for _, entry in entries do
		if entry.weight > 0 then
			cumulative += entry.weight
			lastPickable = entry.id
			if target < cumulative then
				return entry.id
			end
		end
	end
	-- roll == 1 (or float rounding) lands past the end: the last pickable entry.
	return lastPickable
end

-- `entries` listed from the lowest up, with nothing above `cap`: the weight of every entry past it
-- goes to `cap` (what would have rolled higher rolls `cap`). Unchanged when `cap` is not listed.
function Loot.capped<T>(entries: { Entry<T> }, cap: T): { Entry<T> }
	local capped: { Entry<T> } = {}
	local capIndex: number? = nil
	for index, entry in entries do
		if capIndex then
			local kept = capped[capIndex]
			capped[capIndex] = { id = kept.id, weight = kept.weight + entry.weight }
		else
			capped[index] = { id = entry.id, weight = entry.weight }
			if entry.id == cap then
				capIndex = index
			end
		end
	end
	return capped
end

-- Chance of each id, for UI and balance checks.
function Loot.chances<T>(entries: { Entry<T> }): { [T]: number }
	local total = 0
	for _, entry in entries do
		total += entry.weight
	end
	local chances = {}
	for _, entry in entries do
		chances[entry.id] = if total > 0 then entry.weight / total else 0
	end
	return chances
end

return table.freeze(Loot)
