--!strict
-- Hatching: how long an egg warms and which tier it turns into. An egg of a rarity hatches into
-- the alien tier of the same name, now and then one tier down or up: the ladder (decision 113).

local Loot = require("./Loot")

export type Range = {
	read min: number,
	read max: number,
}

-- Chances of one tier down and one tier up, shares in [0, 1]; the own tier takes the rest.
export type Step = {
	read down: number,
	read up: number,
}

local Hatch = {}

-- How long an egg takes: anywhere in its rarity's range, so two eggs alike rarely hatch
-- together. `roll` is in [0, 1].
function Hatch.duration(range: Range, roll: number): number
	assert(range.min >= 0 and range.max >= range.min, "hatch range must be ordered and not negative")
	return range.min + (range.max - range.min) * math.clamp(roll, 0, 1)
end

-- `step` with its chances scaled: an egg's size moves its odds (a large one climbs more often and
-- falls less often).
function Hatch.scaled(step: Step, downFactor: number, upFactor: number): Step
	assert(downFactor >= 0 and upFactor >= 0, "hatch factors must not be negative")
	return { down = step.down * downFactor, up = step.up * upFactor }
end

-- The odds of the tier at `position` of `order` (lowest first): one tier down with `step.down`,
-- one up with `step.up`, its own with the rest. Tiers with no chance are left out, so the entries
-- list only what can come out.
function Hatch.ladder<T>(order: { T }, position: number, step: Step): { Loot.Entry<T> }
	assert(position >= 1 and position <= #order and position % 1 == 0, `tier position {position} out of range`)
	assert(step.down >= 0 and step.up >= 0, "hatch chances must not be negative")
	assert(position > 1 or step.down == 0, "the lowest tier has no tier below it")
	assert(position < #order or step.up == 0, "the top tier has no tier above it")
	local own = 1 - step.down - step.up
	assert(own >= -1e-9, "hatch chances must leave the own tier a share")
	local entries: { Loot.Entry<T> } = {}
	if step.down > 0 then
		table.insert(entries, table.freeze({ id = order[position - 1], weight = step.down }))
	end
	if own > 1e-9 then
		table.insert(entries, table.freeze({ id = order[position], weight = own }))
	end
	if step.up > 0 then
		table.insert(entries, table.freeze({ id = order[position + 1], weight = step.up }))
	end
	return table.freeze(entries)
end

return table.freeze(Hatch)
