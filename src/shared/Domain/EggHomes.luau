--!strict
-- Where an egg out of play belongs: its home. Most eggs belong to a nest (meteor eggs to their
-- crater); the star egg belongs to the star serpent. An egg names its home by id (CarryService
-- calls it `nestId`), and the home gives the egg its grade, takes it back when it leaves play
-- undelivered, and hears when it reached a bay. Keepers other than the nests register their
-- homes here; every other id is a nest's. Pure Luau.

local AlienConfig = require("../Config/AlienConfig")
local EggConfig = require("../Config/EggConfig")

-- A home that is not a nest.
export type Home = {
	-- The grade its eggs hatch into, or nil when it has none.
	grade: () -> number?,
	-- Its egg left play without being delivered.
	returnEgg: (rarity: EggConfig.RarityId, size: EggConfig.SizeId, variant: AlienConfig.VariantId) -> (),
	-- Its egg reached a bay.
	delivered: () -> (),
}

-- The nests: the answer for every id no keeper registered.
export type Nests = {
	grade: (id: string) -> number?,
	returnEgg: (
		id: string,
		rarity: EggConfig.RarityId,
		size: EggConfig.SizeId,
		variant: AlienConfig.VariantId
	) -> (),
	delivered: (id: string) -> (),
}

export type EggHomes = {
	-- Makes `id` the home `home`; it must not be taken.
	register: (id: string, home: Home) -> (),
	-- `id` is no longer a home of its own.
	unregister: (id: string) -> (),
	grade: (id: string) -> number?,
	returnEgg: (
		id: string,
		rarity: EggConfig.RarityId,
		size: EggConfig.SizeId,
		variant: AlienConfig.VariantId
	) -> (),
	delivered: (id: string) -> (),
}

local EggHomes = {}

function EggHomes.new(nests: Nests): EggHomes
	local homes: { [string]: Home } = {}

	return {
		register = function(id: string, home: Home)
			assert(homes[id] == nil, `egg home {id} is taken`)
			homes[id] = home
		end,
		unregister = function(id: string)
			homes[id] = nil
		end,
		grade = function(id: string): number?
			local home = homes[id]
			return if home then home.grade() else nests.grade(id)
		end,
		returnEgg = function(
			id: string,
			rarity: EggConfig.RarityId,
			size: EggConfig.SizeId,
			variant: AlienConfig.VariantId
		)
			local home = homes[id]
			if home then
				home.returnEgg(rarity, size, variant)
			else
				nests.returnEgg(id, rarity, size, variant)
			end
		end,
		delivered = function(id: string)
			local home = homes[id]
			if home then
				home.delivered()
			else
				nests.delivered(id)
			end
		end,
	}
end

return table.freeze(EggHomes)
