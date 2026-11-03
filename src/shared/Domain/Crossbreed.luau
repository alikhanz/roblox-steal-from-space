--!strict
-- Crossbreeding: several aliens of one grade become one alien of that grade, never below the
-- lowest tier put in, with the odds tilted toward the top.

local Hatch = require("./Hatch")
local Loot = require("./Loot")

export type Problem = "WrongCount" | "MixedGrades"

local Crossbreed = {}

-- Why these aliens cannot be crossbred, or nil when they can.
function Crossbreed.check(grades: { number }, required: number): Problem?
	if #grades ~= required then
		return "WrongCount"
	end
	for _, grade in grades do
		if grade ~= grades[1] then
			return "MixedGrades"
		end
	end
	return nil
end

-- Odds of the result: the tiers from the lowest one put in (`positions` index `entries`) upward,
-- shifted by `luck` from there.
function Crossbreed.resultEntries<T>(entries: { Loot.Entry<T> }, positions: { number }, luck: number): { Loot.Entry<T> }
	assert(#positions > 0, "crossbreed needs at least one position")
	local lowest = math.min(table.unpack(positions))
	assert(lowest >= 1 and lowest <= #entries, "crossbreed position out of range")
	local kept = {}
	for position = lowest, #entries do
		table.insert(kept, entries[position])
	end
	return Hatch.shiftedWeights(kept, luck)
end

return table.freeze(Crossbreed)
