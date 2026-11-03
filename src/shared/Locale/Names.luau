--!strict
-- Player-facing names of things that have no name of their own yet: an alien is "<tier> · <its
-- guardian>", an egg is "<rarity> egg". Pure, so the names are testable in Lune.

local AlienConfig = require("../Config/AlienConfig")
local EggConfig = require("../Config/EggConfig")
local GuardianConfig = require("../Config/GuardianConfig")
local Text = require("./Text")

local Names = {}

-- Nil for an alien this build does not know.
function Names.alien(locale: Text.Locale, alienId: string): string?
	local alien = AlienConfig.ALIENS[alienId]
	local post = alien and GuardianConfig.DEBRIS_BELT_POSTS[alien.grade]
	if not alien or not post then
		return nil
	end
	local tier = Text.get(locale, AlienConfig.TIERS[alien.tier].nameKey)
	local guardian = Text.get(locale, GuardianConfig.KINDS[post.kind].nameKey)
	return `{tier} · {guardian}`
end

-- Nil for an unknown rarity.
function Names.egg(locale: Text.Locale, rarity: string): string?
	local config = EggConfig.RARITIES[rarity :: EggConfig.RarityId]
	return if config then Text.get(locale, config.nameKey) else nil
end

return table.freeze(Names)
