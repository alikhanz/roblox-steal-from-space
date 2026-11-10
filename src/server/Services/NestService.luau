--!strict
-- Owns the nests: which ones hold an egg, of what rarity, size and variant, and regrowing eggs
-- in empty nests. A nest stays empty while its egg is away and regrows only after the egg is
-- delivered (Domain/NestCycle). Nest state is replicated as attributes on the nest models for
-- the simulation and the HUD.
--
-- Besides the nests of the world there are craters: nests a meteor makes during a meteor shower
-- (MeteorService), each with one meteor egg and a guardian of its own. A crater never regrows:
-- it is gone once its egg is delivered, or, after it is retired at the end of the shower, as
-- soon as its egg is back in it. Craters take the grade of the nearest nest of their zone.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AlienConfig = require(ReplicatedStorage.Shared.Config.AlienConfig)
local EggConfig = require(ReplicatedStorage.Shared.Config.EggConfig)
local EggLooks = require(ReplicatedStorage.Shared.Config.EggLooks)
local EggModel = require(script.Parent.Parent.World.EggModel)
local Loot = require(ReplicatedStorage.Shared.Domain.Loot)
local NestCycle = require(ReplicatedStorage.Shared.Domain.NestCycle)
local Scheduler = require(ReplicatedStorage.Shared.Runtime.Scheduler)
local Signal = require(ReplicatedStorage.Shared.Runtime.Signal)
local WorldService = require(script.Parent.WorldService)
local ZoneConfig = require(ReplicatedStorage.Shared.Config.ZoneConfig)

-- Respawns are measured in seconds: 10 checks per second is plenty.
local TICK_SECONDS = 0.1

export type Dependencies = {
	getNestSites: () -> { WorldService.NestSite },
	scheduler: Scheduler.Scheduler,
}

export type NestService = {
	name: string,
	start: () -> (),
	-- Removes the egg from a nest; returns its rarity, size and variant, or nil if the nest is
	-- empty.
	takeEgg: (nestId: string) -> (EggConfig.RarityId?, EggConfig.SizeId?, AlienConfig.VariantId?),
	-- Puts an egg that was never delivered back; ignored if the nest already holds one.
	returnEgg: (
		nestId: string,
		rarity: EggConfig.RarityId,
		size: EggConfig.SizeId,
		variant: AlienConfig.VariantId
	) -> (),
	-- The nest's egg reached a station: the nest starts growing a new one (a crater is gone).
	eggDelivered: (nestId: string) -> (),
	-- Guardian post (and alien grade) of a nest, or nil for an unknown nest.
	getGrade: (nestId: string) -> number?,
	-- Where the egg of a nest rests, or nil for an unknown nest.
	getEggCFrame: (nestId: string) -> CFrame?,
	-- Every nest's place, craters included.
	getSites: () -> { WorldService.NestSite },
	-- Makes a crater at `site` with an egg of `variant` from its zone's loot. False when its zone
	-- has no nests to take a grade from.
	addCrater: (site: WorldService.NestSite, variant: AlienConfig.VariantId) -> boolean,
	-- The crater goes once its egg is back in it (at once if it is there).
	retireCrater: (nestId: string) -> (),
	-- A nest came or went (craters): guardians follow.
	added: Signal.Signal<WorldService.NestSite>,
	removed: Signal.Signal<string>,
}

type Nest = {
	site: WorldService.NestSite,
	-- Guardian post of this nest; its eggs hatch into this grade.
	grade: number,
	rarity: EggConfig.RarityId?,
	size: EggConfig.SizeId?,
	variant: AlienConfig.VariantId?,
	egg: BasePart?,
	cycle: NestCycle.State,
	crater: boolean,
	-- A crater whose shower is over: it goes as soon as its egg is back.
	retiring: boolean,
}

local NestService = {}

function NestService.new(dependencies: Dependencies): NestService
	local nests: { [string]: Nest } = {}
	local random = Random.new()
	local added = Signal.new() :: Signal.Signal<WorldService.NestSite>
	local removed = Signal.new() :: Signal.Signal<string>

	local function placeEgg(
		nest: Nest,
		rarity: EggConfig.RarityId,
		size: EggConfig.SizeId,
		variant: AlienConfig.VariantId
	)
		local egg = EggModel.build(rarity, size, { variant = variant })
		egg.Anchored = true
		egg.CFrame = nest.site.eggCFrame + Vector3.yAxis * EggLooks.liftOf(size)
		egg.Parent = nest.site.model
		nest.rarity = rarity
		nest.size = size
		nest.variant = variant
		nest.egg = egg
		nest.cycle = NestCycle.inNest()
		nest.site.model:SetAttribute(EggConfig.NEST_HAS_EGG_ATTRIBUTE, true)
		nest.site.model:SetAttribute(EggConfig.NEST_RARITY_ATTRIBUTE, rarity)
		nest.site.model:SetAttribute(EggConfig.NEST_SIZE_ATTRIBUTE, size)
	end

	-- What grows depends on the zone: farther zones give rarer and bigger eggs.
	local function growEgg(nest: Nest, variant: AlienConfig.VariantId)
		local zone = ZoneConfig.ZONES[nest.site.zone]
		placeEgg(
			nest,
			Loot.pick(zone.rarityLoot, random:NextNumber()),
			Loot.pick(zone.sizeLoot, random:NextNumber()),
			variant
		)
	end

	local function register(nest: Nest)
		local site = nest.site
		nests[site.id] = nest
		site.model:SetAttribute(EggConfig.NEST_EGG_POSITION_ATTRIBUTE, site.eggCFrame.Position)
		site.model:SetAttribute(EggConfig.NEST_GRADE_ATTRIBUTE, nest.grade)
		CollectionService:AddTag(site.model, EggConfig.NEST_TAG)
	end

	local function removeCrater(nest: Nest)
		nests[nest.site.id] = nil
		nest.site.model:Destroy()
		removed.fire(nest.site.id)
	end

	local function takeEgg(nestId: string): (EggConfig.RarityId?, EggConfig.SizeId?, AlienConfig.VariantId?)
		local nest = nests[nestId]
		local away = nest and NestCycle.take(nest.cycle)
		if not nest or not away or not nest.rarity or not nest.size or not nest.variant then
			return nil, nil, nil
		end
		local rarity, size, variant = nest.rarity, nest.size, nest.variant
		if nest.egg then
			nest.egg:Destroy()
		end
		nest.rarity = nil
		nest.size = nil
		nest.variant = nil
		nest.egg = nil
		nest.cycle = away
		nest.site.model:SetAttribute(EggConfig.NEST_HAS_EGG_ATTRIBUTE, false)
		nest.site.model:SetAttribute(EggConfig.NEST_RARITY_ATTRIBUTE, nil)
		nest.site.model:SetAttribute(EggConfig.NEST_SIZE_ATTRIBUTE, nil)
		return rarity, size, variant
	end

	local function returnEgg(
		nestId: string,
		rarity: EggConfig.RarityId,
		size: EggConfig.SizeId,
		variant: AlienConfig.VariantId
	)
		local nest = nests[nestId]
		if not nest or not NestCycle.returned(nest.cycle) then
			return
		end
		if nest.retiring then
			removeCrater(nest)
		else
			placeEgg(nest, rarity, size, variant)
		end
	end

	local function eggDelivered(nestId: string)
		local nest = nests[nestId]
		if not nest then
			return
		end
		if nest.crater then
			removeCrater(nest)
		else
			nest.cycle = NestCycle.delivered(nest.cycle, os.clock(), EggConfig.RESPAWN_SECONDS)
		end
	end

	local function tick()
		local now = os.clock()
		for _, nest in nests do
			if NestCycle.shouldGrow(nest.cycle, now) then
				growEgg(nest, "Normal")
			end
		end
	end

	-- The world's nests, each at its post: the world laid each post's nests on a ring of their
	-- own within the zone's (Domain/NestLayout), the first innermost.
	local function assignNests(sites: { WorldService.NestSite })
		for _, site in sites do
			local post = assert(site.post, `nest {site.id} has no guardian post`)
			local nest: Nest = {
				site = site,
				grade = ZoneConfig.postIndex(site.zone, post),
				rarity = nil,
				size = nil,
				variant = nil,
				egg = nil,
				-- Grows its first egg right below.
				cycle = NestCycle.inNest(),
				crater = false,
				retiring = false,
			}
			register(nest)
			growEgg(nest, "Normal")
		end
	end

	-- The grade of the nest of `zone` nearest to `position` (craters do not count).
	local function gradeNear(zone: ZoneConfig.ZoneId, position: Vector3): number?
		local grade: number? = nil
		local nearest = math.huge
		for _, nest in nests do
			local distance = (nest.site.eggCFrame.Position - position).Magnitude
			if not nest.crater and nest.site.zone == zone and distance < nearest then
				grade, nearest = nest.grade, distance
			end
		end
		return grade
	end

	local function addCrater(site: WorldService.NestSite, variant: AlienConfig.VariantId): boolean
		local grade = gradeNear(site.zone, site.eggCFrame.Position)
		if not grade then
			return false
		end
		local nest: Nest = {
			site = site,
			grade = grade,
			rarity = nil,
			size = nil,
			variant = nil,
			egg = nil,
			cycle = NestCycle.inNest(),
			crater = true,
			retiring = false,
		}
		register(nest)
		growEgg(nest, variant)
		added.fire(site)
		return true
	end

	local function retireCrater(nestId: string)
		local nest = nests[nestId]
		if not nest or not nest.crater then
			return
		end
		nest.retiring = true
		if nest.cycle.kind == "InNest" then
			removeCrater(nest)
		end
	end

	local function start()
		assignNests(dependencies.getNestSites())
		dependencies.scheduler.every(TICK_SECONDS, tick)
	end

	return {
		name = "NestService",
		start = start,
		takeEgg = takeEgg,
		returnEgg = returnEgg,
		eggDelivered = eggDelivered,
		getGrade = function(nestId: string): number?
			local nest = nests[nestId]
			return if nest then nest.grade else nil
		end,
		getEggCFrame = function(nestId: string): CFrame?
			local nest = nests[nestId]
			return if nest then nest.site.eggCFrame else nil
		end,
		getSites = function(): { WorldService.NestSite }
			local sites = {}
			for _, nest in nests do
				table.insert(sites, nest.site)
			end
			return sites
		end,
		addCrater = addCrater,
		retireCrater = retireCrater,
		added = added,
		removed = removed,
	}
end

return table.freeze(NestService)
