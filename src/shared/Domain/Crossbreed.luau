--!strict
-- Crossbreeding: several aliens of one grade, tier and variant become one alien of that grade
-- and variant, of their tier or, with some luck, one tier up (decision 113). Kinds of a grade mix
-- freely; the result is the kind of one of the parents.

local Hatch = require("./Hatch")
local Loot = require("./Loot")

export type Problem = "WrongCount" | "MixedGrades" | "MixedTiers" | "MixedVariants"

-- What decides whether aliens go together: an alien of the registry fits.
export type Parent = {
	read grade: number,
	read tier: string,
	read variant: string,
}

local Crossbreed = {}

-- Why these two aliens cannot be crossbred together, or nil when they can.
function Crossbreed.mismatch(a: Parent, b: Parent): Problem?
	if a.grade ~= b.grade then
		return "MixedGrades"
	end
	if a.tier ~= b.tier then
		return "MixedTiers"
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

-- Odds of the result of parents of the tier at `position` of `order` (lowest first): one tier
-- up with `upChance` in [0, 1], their own tier otherwise. The top tier gives the top tier.
function Crossbreed.resultEntries<T>(order: { T }, position: number, upChance: number): { Loot.Entry<T> }
	local up = if position < #order then upChance else 0
	return Hatch.ladder(order, position, { down = 0, up = up })
end

-- The kind of the result: one of the parents' `kinds`, each parent as likely (two parents of a
-- kind make it twice as likely). `roll` is in [0, 1).
function Crossbreed.resultKind<T>(kinds: { T }, roll: number): T
	assert(#kinds > 0, "crossbreed needs at least one parent")
	return kinds[math.clamp(math.floor(roll * #kinds) + 1, 1, #kinds)]
end

-- A ready group on the shelf (decision 110): aliens of one grade, tier and variant, how many there
-- are, and the weakest `required` of them, which the window's button crossbreeds.
export type Trio = {
	grade: number,
	tier: string,
	variant: string,
	count: number,
	uids: { number },
}

type Owned = { uid: number, id: string }

-- Every group of `aliens` with at least `required` that go together, best group first (by its
-- best earner). `parentOf` gives an alien's grade, tier and variant (nil: unknown, left out);
-- `incomeOf` its income per second as a comparable number.
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
			local key = `{parent.grade}.{parent.tier}.{parent.variant}`
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
			local parent = parents[key]
			local trio: Trio = {
				grade = parent.grade,
				tier = parent.tier,
				variant = parent.variant,
				count = #members,
				uids = uids,
			}
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
