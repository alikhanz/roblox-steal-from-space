--!strict
-- Player-facing names made of parts: an alien is "<tier> · <its kind>", an egg is "<rarity> egg",
-- a jetpack is its jetpack's name and mark. Pure, so the names are testable in Lune.

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

-- The two halves of an alien's name: its tier (with its variant) and its kind ("Crab Drone",
-- "Drone Ray"). Nil for an alien this build does not know.
function Names.alienParts(locale: Text.Locale, alienId: string): (string?, string?)
	local alien = AlienConfig.ALIENS[alienId]
	local kind = alien and AlienConfig.KINDS[alien.kind]
	if not alien or not kind then
		return nil, nil
	end
	-- Keys from the configs are already checked at their definition; they pass through `any`
	-- because the union of every string key is too much for the type checker here.
	local tierKey: any = AlienConfig.TIERS[alien.tier].nameKey
	local kindKey: any = kind.nameKey
	local tier = withVariant(locale, Text.get(locale, tierKey), AlienConfig.VARIANTS[alien.variant].nameKey)
	return tier, Text.get(locale, kindKey)
end

-- "<tier> · <kind>", or nil for an unknown alien.
function Names.alien(locale: Text.Locale, alienId: string): string?
	local tier, kind = Names.alienParts(locale, alienId)
	return if tier and kind then `{tier} · {kind}` else nil
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

-- An egg with its guardian, as the bay window and the shop list it: "Rare egg · Crab Drone",
-- and " · ★ star" for the extra luck only the star egg carries.
function Names.eggWithGuardian(
	locale: Text.Locale,
	egg: { read rarity: string, read variant: string?, read grade: number, read luck: number? }
): string
	local name = Names.egg(locale, egg.rarity, egg.variant) or "?"
	local guardian = Names.guardian(locale, egg.grade) or "?"
	local luck = if egg.luck and egg.luck > 0 then ` · {Text.get(locale, "egg.starEgg.hint")}` else ""
	return `{name} · {guardian}{luck}`
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
