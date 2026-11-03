--!strict
-- Player-facing names of things that have no name of their own yet: an alien is "<tier> · <its
-- guardian>", an egg is "<rarity> egg", a jetpack is its level's name. Pure, so the names are
-- testable in Lune.

local AlienConfig = require("../Config/AlienConfig")
local EggConfig = require("../Config/EggConfig")
local GuardianConfig = require("../Config/GuardianConfig")
local Text = require("./Text")
local UpgradeConfig = require("../Config/UpgradeConfig")

local Names = {}

-- The two halves of an alien's name: its tier and its guardian. Nil for an alien this build
-- does not know.
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
	return Text.get(locale, tierKey), Text.get(locale, postKey)
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

-- Nil for an unknown rarity.
function Names.egg(locale: Text.Locale, rarity: string): string?
	local config = EggConfig.RARITIES[rarity :: EggConfig.RarityId]
	if not config then
		return nil
	end
	local key: any = config.nameKey
	return Text.get(locale, key)
end

-- The jetpack of `level` (0-based). Levels past the named ones are the last name "+n".
function Names.jetpack(locale: Text.Locale, level: number): string
	assert(level >= 0 and level % 1 == 0, `jetpack level must be a whole number, got {level}`)
	local keys: { any } = UpgradeConfig.JETPACK_NAME_KEYS
	if level < #keys then
		return Text.get(locale, keys[level + 1])
	end
	local last = Text.get(locale, keys[#keys])
	return Text.get(locale, "jetpack.beyond.title", { name = last, extra = level - (#keys - 1) })
end

return table.freeze(Names)
