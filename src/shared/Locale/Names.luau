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

-- Nil for an alien this build does not know.
function Names.alien(locale: Text.Locale, alienId: string): string?
	local alien = AlienConfig.ALIENS[alienId]
	local post = alien and GuardianConfig.POSTS[alien.grade]
	if not alien or not post then
		return nil
	end
	local tier = Text.get(locale, AlienConfig.TIERS[alien.tier].nameKey)
	local guardian = Text.get(locale, post.nameKey)
	return `{tier} · {guardian}`
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
