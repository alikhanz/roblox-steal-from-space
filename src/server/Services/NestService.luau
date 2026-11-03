--!strict
-- Owns the nests: which ones hold an egg, of what rarity and size, and regrowing eggs in empty
-- nests. Nest state is replicated as attributes on the nest models for the simulation and the HUD.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EggConfig = require(ReplicatedStorage.Shared.Config.EggConfig)
local EggModel = require(script.Parent.Parent.World.EggModel)
local Loot = require(ReplicatedStorage.Shared.Domain.Loot)
local Scheduler = require(ReplicatedStorage.Shared.Runtime.Scheduler)
local WorldService = require(script.Parent.WorldService)

-- Respawns are measured in seconds: 10 checks per second is plenty.
local TICK_SECONDS = 0.1

export type Dependencies = {
	getNestSites: () -> { WorldService.NestSite },
	scheduler: Scheduler.Scheduler,
}

export type NestService = {
	name: string,
	start: () -> (),
	-- Removes the egg from a nest; returns its rarity and size, or nil if the nest is empty.
	takeEgg: (nestId: string) -> (EggConfig.RarityId?, EggConfig.SizeId?),
	-- Puts a dropped egg back; ignored if the nest has grown a new one meanwhile.
	returnEgg: (nestId: string, rarity: EggConfig.RarityId, size: EggConfig.SizeId) -> (),
	-- Where the egg of a nest rests, or nil for an unknown nest.
	getEggCFrame: (nestId: string) -> CFrame?,
}

type Nest = {
	site: WorldService.NestSite,
	rarity: EggConfig.RarityId?,
	size: EggConfig.SizeId?,
	egg: Part?,
	respawnAt: number?,
}

local NestService = {}

function NestService.new(dependencies: Dependencies): NestService
	local nests: { [string]: Nest } = {}
	local random = Random.new()

	local function placeEgg(nest: Nest, rarity: EggConfig.RarityId, size: EggConfig.SizeId)
		local egg = EggModel.build(rarity, size)
		egg.Anchored = true
		egg.CFrame = nest.site.eggCFrame
		egg.Parent = nest.site.model
		nest.rarity = rarity
		nest.size = size
		nest.egg = egg
		nest.respawnAt = nil
		nest.site.model:SetAttribute(EggConfig.NEST_HAS_EGG_ATTRIBUTE, true)
		nest.site.model:SetAttribute(EggConfig.NEST_RARITY_ATTRIBUTE, rarity)
		nest.site.model:SetAttribute(EggConfig.NEST_SIZE_ATTRIBUTE, size)
	end

	local function growEgg(nest: Nest)
		placeEgg(
			nest,
			Loot.pick(EggConfig.DEBRIS_BELT_LOOT, random:NextNumber()),
			Loot.pick(EggConfig.DEBRIS_BELT_SIZE_LOOT, random:NextNumber())
		)
	end

	local function takeEgg(nestId: string): (EggConfig.RarityId?, EggConfig.SizeId?)
		local nest = nests[nestId]
		if not nest or not nest.rarity or not nest.size then
			return nil, nil
		end
		local rarity, size = nest.rarity, nest.size
		if nest.egg then
			nest.egg:Destroy()
		end
		nest.rarity = nil
		nest.size = nil
		nest.egg = nil
		nest.respawnAt = os.clock() + EggConfig.RESPAWN_SECONDS
		nest.site.model:SetAttribute(EggConfig.NEST_HAS_EGG_ATTRIBUTE, false)
		nest.site.model:SetAttribute(EggConfig.NEST_RARITY_ATTRIBUTE, nil)
		nest.site.model:SetAttribute(EggConfig.NEST_SIZE_ATTRIBUTE, nil)
		return rarity, size
	end

	local function returnEgg(nestId: string, rarity: EggConfig.RarityId, size: EggConfig.SizeId)
		local nest = nests[nestId]
		if nest and not nest.rarity then
			placeEgg(nest, rarity, size)
		end
	end

	local function tick()
		local now = os.clock()
		for _, nest in nests do
			if nest.respawnAt and now >= nest.respawnAt then
				growEgg(nest)
			end
		end
	end

	local function start()
		for _, site in dependencies.getNestSites() do
			local nest: Nest = { site = site, rarity = nil, size = nil, egg = nil, respawnAt = nil }
			nests[site.id] = nest
			site.model:SetAttribute(EggConfig.NEST_EGG_POSITION_ATTRIBUTE, site.eggCFrame.Position)
			CollectionService:AddTag(site.model, EggConfig.NEST_TAG)
			growEgg(nest)
		end
		dependencies.scheduler.every(TICK_SECONDS, tick)
	end

	return {
		name = "NestService",
		start = start,
		takeEgg = takeEgg,
		returnEgg = returnEgg,
		getEggCFrame = function(nestId: string): CFrame?
			local nest = nests[nestId]
			return if nest then nest.site.eggCFrame else nil
		end,
	}
end

return table.freeze(NestService)
