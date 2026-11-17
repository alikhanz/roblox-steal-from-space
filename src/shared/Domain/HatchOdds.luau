--!strict
-- What an egg hatches into, as one table: the server draws an alien from it and the odds window
-- lists it (decision 127, docs/design/screens/egg-odds.md), so the odds a player reads before
-- "Hatch for R$" are the odds the hatch uses. An egg hatches into a kind of its guardian by the
-- kinds' weights (decision 135) and a tier by its rarity and size (EggConfig.hatchEntries,
-- decision 113; the star egg's luck counts as a large egg), in its variant (a meteor egg hatches
-- meteor aliens). The income roll (AlienIncome, decisions 130 and 133) and the outfit
-- (AlienOutfit, looks only) are drawn on top. Pure Luau: rolls come in as numbers.

local AlienConfig = require("../Config/AlienConfig")
local EggConfig = require("../Config/EggConfig")
local Loot = require("./Loot")

-- An egg as the profile keeps it (PlayerData.EggRecord fits).
export type Egg = {
	read grade: number,
	read rarity: string,
	read size: string,
	read variant: string?,
	read luck: number?,
}

-- Everything a hatch draws from.
export type Draw = {
	read kinds: { Loot.Entry<AlienConfig.KindId> },
	read tiers: { Loot.Entry<AlienConfig.TierId> },
	read aliens: { [AlienConfig.KindId]: { [AlienConfig.TierId]: AlienConfig.AlienId } },
}

-- One alien that can hatch, and its chance in [0, 1].
export type Outcome = {
	alien: AlienConfig.AlienId,
	kind: AlienConfig.KindId,
	tier: AlienConfig.TierId,
	chance: number,
}

-- One tier that can hatch: its chance and its aliens, kinds in their order (the main one first).
export type TierOdds = {
	tier: AlienConfig.TierId,
	chance: number,
	outcomes: { Outcome },
}

-- The income roll as the odds window tells it: every whole percent from `min` to `max` is as
-- likely as any other, `chance` each.
export type IncomeOdds = {
	min: number,
	max: number,
	chance: number,
}

-- Roblox's rule for odds that do not come out even: show them to four or more places below the
-- first digit that is not zero (21.6667 -> 21.667, 1.63934 -> 1.6393), and say they are rounded.
local PLACES_BELOW_FIRST_DIGIT = 4
-- A shown percent this close to the true one counts as exact (floating point noise).
local EXACT_TOLERANCE = 1e-9

local HatchOdds = {}

local function total<T>(entries: { Loot.Entry<T> }): number
	local sum = 0
	for _, entry in entries do
		sum += entry.weight
	end
	assert(sum > 0, "odds need a positive total weight")
	return sum
end

-- The draw of `egg`; nil for an egg this build cannot hatch (an unknown rarity, size, grade or
-- variant).
function HatchOdds.of(egg: Egg): Draw?
	local grade = AlienConfig.GRADES[egg.grade]
	local rarity = egg.rarity :: EggConfig.RarityId
	local size = egg.size :: EggConfig.SizeId
	if not grade or not EggConfig.RARITIES[rarity] or not EggConfig.SIZES[size] then
		return nil
	end
	local aliens = grade.variants[(egg.variant or "Normal") :: AlienConfig.VariantId]
	if not aliens then
		return nil
	end
	return {
		kinds = grade.kindEntries,
		tiers = EggConfig.hatchEntries(rarity, size, egg.luck),
		aliens = aliens,
	}
end

-- The alien a hatch gives for two rolls in [0, 1): the kind's, then the tier's.
function HatchOdds.pick(draw: Draw, kindRoll: number, tierRoll: number): AlienConfig.AlienId
	local kind = Loot.pick(draw.kinds, kindRoll)
	local tier = Loot.pick(draw.tiers, tierRoll)
	return draw.aliens[kind][tier]
end

-- Every alien that can hatch from `draw`, by tier (lowest first), with its chance: the tier's
-- times the kind's share. Kinds and tiers with no chance are left out; the chances add up to 1.
function HatchOdds.list(draw: Draw): { TierOdds }
	local tierTotal = total(draw.tiers)
	local kindTotal = total(draw.kinds)
	local list: { TierOdds } = {}
	for _, tierEntry in draw.tiers do
		if tierEntry.weight > 0 then
			local tierChance = tierEntry.weight / tierTotal
			local outcomes: { Outcome } = {}
			for _, kindEntry in draw.kinds do
				if kindEntry.weight > 0 then
					table.insert(outcomes, {
						alien = draw.aliens[kindEntry.id][tierEntry.id],
						kind = kindEntry.id,
						tier = tierEntry.id,
						chance = tierChance * kindEntry.weight / kindTotal,
					})
				end
			end
			table.insert(list, { tier = tierEntry.id, chance = tierChance, outcomes = outcomes })
		end
	end
	return list
end

-- The income roll of a new alien (AlienConfig.INCOME_ROLL): one die, so every whole percent of
-- its range is equally likely.
function HatchOdds.income(): IncomeOdds
	local roll = AlienConfig.INCOME_ROLL
	assert(roll.dice == 1, "the odds window tells the income roll as even: it needs a single die")
	return { min = roll.min, max = roll.max, chance = 1 / (roll.max - roll.min + 1) }
end

-- A chance in (0, 1] as a percent the odds show, by Roblox's rule: exact ones as they are ("20",
-- "62.5"), others to four places below their first digit ("21.667", "6.6667"). Also whether it
-- was rounded (then the window says so).
function HatchOdds.percentText(chance: number): (string, boolean)
	assert(chance > 0 and chance <= 1, `a chance must be in (0, 1], got {chance}`)
	local percent = chance * 100
	local firstDigit = math.floor(math.log10(percent))
	local decimals = math.max(0, PLACES_BELOW_FIRST_DIGIT - firstDigit)
	local text = string.format(`%.{decimals}f`, percent)
	if decimals > 0 then
		text = (string.gsub(text, "0+$", ""))
		text = (string.gsub(text, "%.$", ""))
	end
	local shown = assert(tonumber(text), "a formatted percent reads back as a number")
	return text, math.abs(shown - percent) > EXACT_TOLERANCE * percent
end

return table.freeze(HatchOdds)
