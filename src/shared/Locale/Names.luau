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
	return Text.get(locale, AlienConfig.TIERS[alien.tier].nameKey), Text.get(locale, post.nameKey)
end

-- "<tier> · <guardian>", or nil for an unknown alien.
function Names.alien(locale: Text.Locale, alienId: string): string?
	local tier, guardian = Names.alienParts(locale, alienId)
	return if tier and guardian then `{tier} · {guardian}` else nil
end

-- The guardian whose eggs hatch into grade `grade`, or nil for an unknown grade.
function Names.guardian(locale: Text.Locale, grade: number): string?
	local post = GuardianConfig.POSTS[grade]
	return if post then Text.get(locale, post.nameKey) else nil
end

-- Nil for an unknown rarity.
function Names.egg(locale: Text.Locale, rarity: string): string?
	local config = EggConfig.RARITIES[rarity :: EggConfig.RarityId]
	return if config then Text.get(locale, config.nameKey) else nil
end

-- The jetpack of `level` (0-based). Levels past the named ones are the last name "+n".
function Names.jetpack(locale: Text.Locale, level: number): string
	assert(level >= 0 and level % 1 == 0, `jetpack level must be a whole number, got {level}`)
	local keys = UpgradeConfig.JETPACK_NAME_KEYS
	if level < #keys then
		return Text.get(locale, keys[level + 1] :: Text.Key)
	end
	local last = Text.get(locale, keys[#keys] :: Text.Key)
	return Text.get(locale, "jetpack.beyond.title", { name = last, extra = level - (#keys - 1) })
end

return table.freeze(Names)
