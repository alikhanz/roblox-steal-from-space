--!strict
-- The pet gallery (decision 118): the bench (Domain/Bench) filled with one family's aliens, to look
-- every model of a family over, on a phone too. A family has more kinds and tiers than an island
-- has places, so it takes pages: together its pages hold every kind at every tier once, each page
-- has every kind, and every third alien is a meteor one. The pages go family after family
-- (FAMILIES) and round again.

local AlienConfig = require("../Config/AlienConfig")

local PetGallery = {}

-- The families in the gallery's order.
PetGallery.FAMILIES = table.freeze({ "slime", "crab", "worm", "ray", "swarm", "whale" }) :: { AlienConfig.FamilyId }

-- Every this many aliens is a meteor one.
local METEOR_EVERY = 3

export type Page = {
	family: AlienConfig.FamilyId,
	-- Which page of the family, from 1, and how many it has.
	part: number,
	parts: number,
	aliens: { AlienConfig.AlienId },
}

-- A family's kinds, from the first guardian on, each guardian's main kind first.
local function kindsOf(family: AlienConfig.FamilyId): { AlienConfig.Kind }
	local kinds: { AlienConfig.Kind } = {}
	for _, kind in AlienConfig.KINDS do
		if kind.family == family then
			table.insert(kinds, kind)
		end
	end
	table.sort(kinds, function(a: AlienConfig.Kind, b: AlienConfig.Kind): boolean
		return if a.grade ~= b.grade then a.grade < b.grade else a.position < b.position
	end)
	return kinds
end

-- Every kind of `family` at every tier, in the gallery's order: round after round over the kinds,
-- each kind's tier moving one on a round (a kind's first tier by its place in the list), so any
-- run of rounds shows every kind and spreads the tiers.
local function familyAliens(family: AlienConfig.FamilyId): { AlienConfig.AlienId }
	local kinds = kindsOf(family)
	local tiers = AlienConfig.TIER_ORDER
	local aliens: { AlienConfig.AlienId } = {}
	for round = 0, #tiers - 1 do
		for index, kind in kinds do
			local tier = tiers[(index - 1 + round) % #tiers + 1]
			local variant: AlienConfig.VariantId = if (#aliens + 1) % METEOR_EVERY == 0 then "Meteor" else "Normal"
			table.insert(aliens, AlienConfig.GRADES[kind.grade].variants[variant][kind.id][tier])
		end
	end
	return aliens
end

-- The pages of every family in order, for an island of `places`.
function PetGallery.pages(places: number): { Page }
	local pages: { Page } = {}
	for _, family in PetGallery.FAMILIES do
		local all = familyAliens(family)
		local parts = math.max(1, math.ceil(#all / places))
		for part = 1, parts do
			table.insert(pages, {
				family = family,
				part = part,
				parts = parts,
				aliens = table.move(all, (part - 1) * places + 1, math.min(part * places, #all), 1, {}),
			})
		end
	end
	return pages
end

-- The page after `current` (0: none shown yet), round to the first after the last.
function PetGallery.next(current: number, count: number): number
	return current % count + 1
end

-- The page's name on its button: "crab 1/2".
function PetGallery.label(page: Page): string
	return `{page.family} {page.part}/{page.parts}`
end

return table.freeze(PetGallery)
