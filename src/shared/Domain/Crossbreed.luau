--!strict
-- Crossbreeding: several aliens of one grade and variant become one alien of that grade and
-- variant, never below the lowest tier put in, with the odds tilted toward the top. Kinds of a
-- grade mix freely; the result is the kind of one of the parents.

local Hatch = require("./Hatch")
local Loot = require("./Loot")

export type Problem = "WrongCount" | "MixedGrades" | "MixedVariants"

-- What decides whether aliens go together: an alien of the registry fits.
export type Parent = {
	read grade: number,
	read variant: string,
}

local Crossbreed = {}

-- Why these two aliens cannot be crossbred together, or nil when they can.
function Crossbreed.mismatch(a: Parent, b: Parent): Problem?
	if a.grade ~= b.grade then
		return "MixedGrades"
	end
	if a.variant ~= b.variant then
		return "MixedVariants"
	end
	return nil
end

-- Why these aliens cannot be crossbred, or nil when they can.
function Crossbreed.check(parents: { Parent }, required: number): Problem?
	if #parents ~= required then
		return "WrongCount"
	end
	for _, parent in parents do
		local problem = Crossbreed.mismatch(parents[1], parent)
		if problem then
			return problem
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

-- The kind of the result: one of the parents' `kinds`, each parent as likely (two parents of a
-- kind make it twice as likely). `roll` is in [0, 1).
function Crossbreed.resultKind<T>(kinds: { T }, roll: number): T
	assert(#kinds > 0, "crossbreed needs at least one parent")
	return kinds[math.clamp(math.floor(roll * #kinds) + 1, 1, #kinds)]
end

return table.freeze(Crossbreed)
