--!strict
-- Player-facing names of things that have no name of their own yet: an alien is "<tier> · <its
-- guardian>", an egg is "<rarity> egg", a jetpack is its jetpack's name and mark. Pure, so the names are
-- testable in Lune.

local AlienConfig = require("../Config/AlienConfig")
local EggConfig = require("../Config/EggConfig")
local GuardianConfig = require("../Config/GuardianConfig")
local Text = require("./Text")
local UpgradeConfig = require("../Config/UpgradeConfig")
local Upgrades = require("../Domain/Upgrades")

local Names = {}

-- `name` with the variant's word in front ("Meteor · Rare"); the usual variant adds nothing.
local function withVariant(locale: Text.Locale, name: string, variantKey: any): string
	return if variantKey then `{Text.get(locale, variantKey)} · {name}` else name
end

-- The two halves of an alien's name: its tier (with its variant) and its guardian. Nil for an
-- alien this build does not know.
function Names.alienParts(locale: Text.Locale, alienId: string): (string?, string?)
	local alien = AlienConfig.ALIENS[alienId]
	local post = alien and GuardianConfig.POSTS[alien.grade]
	if not alien or not post then
		return nil, nil
	end
	-- Keys from the configs are already checked at their definition; they pass through `any`
	-- because the union of every string key is too much for the type checker here.
	local tierKey: any = AlienConfig.TIERS[alien.tier].nameKey
	local postKey: any = post.nameKey
	local tier = withVariant(locale, Text.get(locale, tierKey), AlienConfig.VARIANTS[alien.variant].nameKey)
	return tier, Text.get(locale, postKey)
end

-- "<tier> · <guardian>", or nil for an unknown alien.
function Names.alien(locale: Text.Locale, alienId: string): string?
	local tier, guardian = Names.alienParts(locale, alienId)
	return if tier and guardian then `{tier} · {guardian}` else nil
end

-- The guardian whose eggs hatch into grade `grade`, or nil for an unknown grade.
function Names.guardian(locale: Text.Locale, grade: number): string?
	local post = GuardianConfig.POSTS[grade]
	if not post then
		return nil
	end
	local key: any = post.nameKey
	return Text.get(locale, key)
end

-- "Rare egg", "Meteor · Rare egg"; nil for an unknown rarity or variant.
function Names.egg(locale: Text.Locale, rarity: string, variant: string?): string?
	local config = EggConfig.RARITIES[rarity :: EggConfig.RarityId]
	local variantConfig = AlienConfig.VARIANTS[(variant or "Normal") :: AlienConfig.VariantId]
	if not config or not variantConfig then
		return nil
	end
	local key: any = config.nameKey
	return withVariant(locale, Text.get(locale, key), variantConfig.eggNameKey)
end

-- The jetpack of `level` (0-based). Levels past the named ones are the last name "+n".
-- Marks of a jetpack model, as they follow its name.
local MARKS = { "I", "II", "III", "IV" }

-- A jetpack level's name: its jetpack's name and mark ("Spark II"). The starting jetpack and
-- the last one come in one model and carry no mark.
function Names.jetpack(locale: Text.Locale, level: number): string
	local tuning = UpgradeConfig.TUNING
	local top = Upgrades.jetpackMaxLevel(tuning)
	local jetpack, mark = Upgrades.jetpackModel(math.min(level, top), tuning)
	local keys: { any } = UpgradeConfig.JETPACK_NAME_KEYS
	local name = Text.get(locale, keys[jetpack + 1])
	if jetpack == 0 or jetpack == tuning.jetpackLast then
		return name
	end
	return `{name} {assert(MARKS[mark], `no mark {mark}`)}`
end

return table.freeze(Names)
