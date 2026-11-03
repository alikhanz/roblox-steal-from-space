--!strict
-- Hatching: which tier an egg turns into. Eggs carry luck (from rarity and size) that tilts the
-- odds toward the top tiers without ever ruling the bottom ones out.

local Loot = require("./Loot")

export type Range = {
	read min: number,
	read max: number,
}

local Hatch = {}

-- How long an egg takes: anywhere in its rarity's range, so two eggs alike rarely hatch
-- together. `roll` is in [0, 1].
function Hatch.duration(range: Range, roll: number): number
	assert(range.min >= 0 and range.max >= range.min, "hatch range must be ordered and not negative")
	return range.min + (range.max - range.min) * math.clamp(roll, 0, 1)
end

-- Multiplies each weight by (1 + luck)^(position - 1). Entries are listed from the lowest tier
-- up, so luck 1 doubles the odds of each tier relative to the one below it.
function Hatch.shiftedWeights<T>(entries: { Loot.Entry<T> }, luck: number): { Loot.Entry<T> }
	assert(luck >= 0, "luck must not be negative")
	local shifted: { Loot.Entry<T> } = {}
	for position, entry in entries do
		shifted[position] = { id = entry.id, weight = entry.weight * (1 + luck) ^ (position - 1) }
	end
	return shifted
end

-- Picks a tier for `roll` in [0, 1) with the odds shifted by `luck`.
function Hatch.pick<T>(entries: { Loot.Entry<T> }, luck: number, roll: number): T
	return Loot.pick(Hatch.shiftedWeights(entries, luck), roll)
end

return table.freeze(Hatch)
