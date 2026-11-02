--!strict
-- Owns the nests: which ones hold an egg and of what rarity, regrowing eggs in empty nests, and
-- each nest's alert meter (raised by jetpack noise nearby and by grab attempts).
-- Nest state is replicated as attributes on the nest models for the simulation and the HUD.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Alert = require(ReplicatedStorage.Shared.Domain.Alert)
local EggConfig = require(ReplicatedStorage.Shared.Config.EggConfig)
local EggModel = require(script.Parent.Parent.World.EggModel)
local FlightConfig = require(ReplicatedStorage.Shared.Config.FlightConfig)
local Loot = require(ReplicatedStorage.Shared.Domain.Loot)
local WorldService = require(script.Parent.WorldService)

-- Alert and respawns change slowly: 10 updates per second is plenty.
local TICK_SECONDS = 0.1
-- Skip attribute writes for alert changes smaller than this, to save replication.
local ALERT_REPLICATION_STEP = 0.01

export type Dependencies = {
	getNestSites: () -> { WorldService.NestSite },
}

export type NestService = {
	name: string,
	start: () -> (),
	-- Removes the egg from a nest; returns its rarity, or nil if the nest is empty.
	takeEgg: (nestId: string) -> EggConfig.RarityId?,
	-- Puts a dropped egg back; ignored if the nest has grown a new one meanwhile.
	returnEgg: (nestId: string, rarity: EggConfig.RarityId) -> (),
	-- Where the egg of a nest rests, or nil for an unknown nest.
	getEggCFrame: (nestId: string) -> CFrame?,
	getAlert: (nestId: string) -> number,
}

type Nest = {
	site: WorldService.NestSite,
	rarity: EggConfig.RarityId?,
	egg: Part?,
	respawnAt: number?,
	alert: number,
	replicatedAlert: number,
}

local NestService = {}

function NestService.new(dependencies: Dependencies): NestService
	local nests: { [string]: Nest } = {}
	local random = Random.new()

	local function placeEgg(nest: Nest, rarity: EggConfig.RarityId)
		local egg = EggModel.build(rarity)
		egg.Anchored = true
		egg.CFrame = nest.site.eggCFrame
		egg.Parent = nest.site.model
		nest.rarity = rarity
		nest.egg = egg
		nest.respawnAt = nil
		nest.site.model:SetAttribute(EggConfig.NEST_HAS_EGG_ATTRIBUTE, true)
		nest.site.model:SetAttribute(EggConfig.NEST_RARITY_ATTRIBUTE, rarity)
	end

	local function growEgg(nest: Nest)
		placeEgg(nest, Loot.pick(EggConfig.DEBRIS_BELT_LOOT, random:NextNumber()))
	end

	local function takeEgg(nestId: string): EggConfig.RarityId?
		local nest = nests[nestId]
		if not nest or not nest.rarity then
			return nil
		end
		local rarity = nest.rarity
		if nest.egg then
			nest.egg:Destroy()
		end
		nest.rarity = nil
		nest.egg = nil
		nest.respawnAt = os.clock() + EggConfig.RESPAWN_SECONDS
		nest.site.model:SetAttribute(EggConfig.NEST_HAS_EGG_ATTRIBUTE, false)
		nest.site.model:SetAttribute(EggConfig.NEST_RARITY_ATTRIBUTE, nil)
		return rarity
	end

	local function returnEgg(nestId: string, rarity: EggConfig.RarityId)
		local nest = nests[nestId]
		if nest and not nest.rarity then
			placeEgg(nest, rarity)
		end
	end

	-- The loudest player's noise for a nest, and whether anyone is grabbing its egg.
	local function listen(nest: Nest): (number, boolean)
		local loudest, grabbing = 0, false
		local nestPosition = nest.site.eggCFrame.Position
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if not character or not root or not root:IsA("BasePart") then
				continue
			end
			if character:GetAttribute(FlightConfig.IN_SPACE_ATTRIBUTE) == true then
				local speedFraction = root.AssemblyLinearVelocity.Magnitude / FlightConfig.TUNING.maxSpeed
				local noise = Alert.noise((root.Position - nestPosition).Magnitude, speedFraction, EggConfig.ALERT)
				loudest = math.max(loudest, noise)
			end
			local progress = character:GetAttribute(EggConfig.GRAB_PROGRESS_ATTRIBUTE)
			if
				character:GetAttribute(EggConfig.GRAB_TARGET_ATTRIBUTE) == nest.site.id
				and type(progress) == "number"
				and progress > 0
			then
				grabbing = true
			end
		end
		return loudest, grabbing
	end

	local function tick(deltaTime: number)
		local now = os.clock()
		for _, nest in nests do
			if nest.respawnAt and now >= nest.respawnAt then
				growEgg(nest)
			end
			local noise, grabbing = listen(nest)
			nest.alert = Alert.step(nest.alert, noise, grabbing, deltaTime, EggConfig.ALERT)
			if
				math.abs(nest.alert - nest.replicatedAlert) >= ALERT_REPLICATION_STEP
				or (nest.alert == 0) ~= (nest.replicatedAlert == 0)
			then
				nest.replicatedAlert = nest.alert
				nest.site.model:SetAttribute(EggConfig.NEST_ALERT_ATTRIBUTE, nest.alert)
			end
		end
	end

	local function start()
		for _, site in dependencies.getNestSites() do
			local nest: Nest = { site = site, rarity = nil, egg = nil, respawnAt = nil, alert = 0, replicatedAlert = 0 }
			nests[site.id] = nest
			site.model:SetAttribute(EggConfig.NEST_ALERT_ATTRIBUTE, 0)
			site.model:SetAttribute(EggConfig.NEST_EGG_POSITION_ATTRIBUTE, site.eggCFrame.Position)
			CollectionService:AddTag(site.model, EggConfig.NEST_TAG)
			growEgg(nest)
		end

		local elapsed = 0
		RunService.Heartbeat:Connect(function(deltaTime)
			elapsed += deltaTime
			if elapsed >= TICK_SECONDS then
				tick(elapsed)
				elapsed = 0
			end
		end)
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
		getAlert = function(nestId: string): number
			local nest = nests[nestId]
			return if nest then nest.alert else 0
		end,
	}
end

return table.freeze(NestService)
