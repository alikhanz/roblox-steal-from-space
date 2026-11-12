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

-- A ready group on the shelf (decision 106): aliens of one grade and variant, how many there are,
-- and the weakest `required` of them, which the window's button crossbreeds.
export type Trio = {
	grade: number,
	variant: string,
	count: number,
	uids: { number },
}

type Owned = { uid: number, id: string }

-- Every group of `aliens` with at least `required` that go together, best group first (by its
-- best earner). `parentOf` gives an alien's grade and variant (nil: unknown, left out); `incomeOf`
-- its income per second as a comparable number.
function Crossbreed.trios(
	aliens: { Owned },
	parentOf: (id: string) -> Parent?,
	incomeOf: (id: string) -> number,
	required: number
): { Trio }
	local groups: { [string]: { Owned } } = {}
	local parents: { [string]: Parent } = {}
	for _, alien in aliens do
		local parent = parentOf(alien.id)
		if parent then
			local key = `{parent.grade}.{parent.variant}`
			groups[key] = groups[key] or {}
			table.insert(groups[key], alien)
			parents[key] = parent
		end
	end
	local weakerFirst = function(left: Owned, right: Owned): boolean
		local a, b = incomeOf(left.id), incomeOf(right.id)
		if a ~= b then
			return a < b
		end
		return left.uid < right.uid
	end
	local result: { Trio } = {}
	local best: { [Trio]: number } = {}
	for key, members in groups do
		if #members >= required then
			table.sort(members, weakerFirst)
			local uids = {}
			for position = 1, required do
				table.insert(uids, members[position].uid)
			end
			local trio: Trio =
				{ grade = parents[key].grade, variant = parents[key].variant, count = #members, uids = uids }
			best[trio] = incomeOf(members[#members].id)
			table.insert(result, trio)
		end
	end
	table.sort(result, function(left: Trio, right: Trio): boolean
		if best[left] ~= best[right] then
			return best[left] > best[right]
		end
		return left.uids[1] < right.uids[1]
	end)
	return result
end

return table.freeze(Crossbreed)
