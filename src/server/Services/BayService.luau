--!strict
-- Owns the bays on the station: one per player, taken when their profile is active and freed
-- when they leave. The profile is the source of truth; the bay model is its reflection and is
-- rebuilt from the profile after every change (`refresh`), which at this scale is cheap and
-- cannot drift.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AlienConfig = require(ReplicatedStorage.Shared.Config.AlienConfig)
local AlienModel = require(script.Parent.Parent.World.AlienModel)
local Bay = require(ReplicatedStorage.Shared.Domain.Bay)
local BayConfig = require(ReplicatedStorage.Shared.Config.BayConfig)
local BayLooks = require(ReplicatedStorage.Shared.Config.BayLooks)
local BayModel = require(script.Parent.Parent.World.BayModel)
local EggConfig = require(ReplicatedStorage.Shared.Config.EggConfig)
local EggModel = require(script.Parent.Parent.World.EggModel)
local Hatch = require(ReplicatedStorage.Shared.Domain.Hatch)
local PlayerData = require(ReplicatedStorage.Shared.Domain.PlayerData)
local Signal = require(ReplicatedStorage.Shared.Runtime.Signal)

local FOLDER_NAME = "Bays"

export type Dependencies = {
	activated: Signal.Signal<Player>,
	getData: (player: Player) -> PlayerData.PlayerData?,
	update: (player: Player, mutator: (data: PlayerData.PlayerData) -> ()) -> boolean,
}

export type BayService = {
	name: string,
	start: () -> (),
	-- Rebuilds a player's bay from their profile. Call after any change to the bay data.
	refresh: (player: Player) -> (),
	-- The bay's frame on the platform; nil until the player has one.
	getOrigin: (player: Player) -> CFrame?,
	-- Puts an egg into the incubator; it hatches after its rarity's random time. False without
	-- an active profile.
	addEgg: (player: Player, rarity: EggConfig.RarityId, size: EggConfig.SizeId, grade: number) -> boolean,
	-- Gives the player an alien: into a free pod, else onto the floor. Nil without an active profile.
	addAlien: (player: Player, alienId: AlienConfig.AlienId) -> Bay.Location?,
}

type PlayerBay = {
	slot: number,
	origin: CFrame,
	model: Model,
}

local BayService = {}

function BayService.new(dependencies: Dependencies): BayService
	local bays: { [Player]: PlayerBay } = {}
	local slotOwners: { [number]: Player } = {}
	local folder: Folder? = nil
	local random = Random.new()

	local function contentsOf(bay: PlayerBay): Instance
		return bay.model:FindFirstChild(BayConfig.CONTENTS_NAME) or bay.model
	end

	local function placeAlien(alien: PlayerData.AlienRecord, cframe: CFrame, parent: Instance)
		if not AlienConfig.ALIENS[alien.id] then
			-- A profile may hold an alien this build no longer knows; it stays in the data.
			warn(`[BayService] Unknown alien {alien.id} (uid {alien.uid}); not shown`)
			return
		end
		local model = AlienModel.build(alien.id, alien.uid, cframe)
		CollectionService:AddTag(model, BayConfig.ALIEN_TAG)
		model.Parent = parent
	end

	local function placeEgg(egg: PlayerData.EggRecord, cframe: CFrame, parent: Instance)
		if
			not EggConfig.RARITIES[egg.rarity :: EggConfig.RarityId]
			or not EggConfig.SIZES[egg.size :: EggConfig.SizeId]
		then
			warn(`[BayService] Unknown egg {egg.rarity} {egg.size} (uid {egg.uid}); not shown`)
			return
		end
		local part = EggModel.build(egg.rarity :: EggConfig.RarityId, egg.size :: EggConfig.SizeId)
		part.Name = `Egg{egg.uid}`
		part.Anchored = true
		part.CFrame = cframe
		part:SetAttribute(BayConfig.EGG_UID_ATTRIBUTE, egg.uid)
		part:SetAttribute(BayConfig.EGG_HATCH_AT_ATTRIBUTE, egg.hatchAt)
		CollectionService:AddTag(part, BayConfig.INCUBATOR_EGG_TAG)
		part.Parent = parent
	end

	local function refresh(player: Player)
		local bay = bays[player]
		local data = dependencies.getData(player)
		if not bay or not data then
			return
		end
		local contents = contentsOf(bay)
		contents:ClearAllChildren()

		for index, pod in data.pods do
			BayModel.buildPod(bay.origin, index).Parent = contents
			if pod.alien then
				placeAlien(pod.alien, BayModel.podAlienCFrame(bay.origin, index), contents)
			end
		end
		for index, egg in data.incubator do
			placeEgg(egg, BayModel.eggCFrame(bay.origin, index), contents)
		end
		for index, alien in data.floor do
			placeAlien(alien, BayModel.floorCFrame(bay.origin, index), contents)
		end
	end

	local function freeSlot(): number?
		for slot = 1, BayLooks.BAY_COUNT do
			if not slotOwners[slot] then
				return slot
			end
		end
		return nil
	end

	local function assign(player: Player)
		if bays[player] or player.Parent ~= Players then
			return
		end
		local slot = freeSlot()
		local parent = folder
		if not slot or not parent then
			warn(`[BayService] No bay for {player.Name}: {if slot then "world not built" else "all slots taken"}`)
			return
		end
		local origin = BayModel.origin(slot)
		local model = BayModel.build(slot, origin)
		model:SetAttribute(BayConfig.OWNER_ID_ATTRIBUTE, player.UserId)
		model:SetAttribute(BayConfig.OWNER_NAME_ATTRIBUTE, player.DisplayName)
		CollectionService:AddTag(model, BayConfig.TAG)
		model.Parent = parent

		slotOwners[slot] = player
		bays[player] = { slot = slot, origin = origin, model = model }
		refresh(player)
	end

	local function release(player: Player)
		local bay = bays[player]
		if not bay then
			return
		end
		bays[player] = nil
		slotOwners[bay.slot] = nil
		bay.model:Destroy()
	end

	local function addEgg(player: Player, rarity: EggConfig.RarityId, size: EggConfig.SizeId, grade: number): boolean
		local rarityConfig = assert(EggConfig.RARITIES[rarity], `Unknown rarity {rarity}`)
		assert(EggConfig.SIZES[size], `Unknown size {size}`)
		assert(AlienConfig.GRADES[grade], `Unknown grade {grade}`)
		local duration = Hatch.duration(rarityConfig.hatchSeconds, random:NextNumber())
		local hatchAt = workspace:GetServerTimeNow() + duration
		local added = dependencies.update(player, function(data)
			table.insert(data.incubator, {
				uid = Bay.newUid(data),
				rarity = rarity,
				size = size,
				grade = grade,
				hatchAt = hatchAt,
			})
		end)
		if added then
			refresh(player)
		end
		return added
	end

	local function addAlien(player: Player, alienId: AlienConfig.AlienId): Bay.Location?
		assert(AlienConfig.ALIENS[alienId], `Unknown alien {alienId}`)
		local location: Bay.Location? = nil
		local added = dependencies.update(player, function(data)
			location = Bay.addHatched(data, { uid = Bay.newUid(data), id = alienId })
		end)
		if added then
			refresh(player)
		end
		return location
	end

	local function start()
		local world = workspace:FindFirstChild("World")
		local bayFolder = Instance.new("Folder")
		bayFolder.Name = FOLDER_NAME
		bayFolder.Parent = world or workspace
		folder = bayFolder

		dependencies.activated.connect(assign)
		Players.PlayerRemoving:Connect(release)
	end

	return {
		name = "BayService",
		start = start,
		refresh = refresh,
		getOrigin = function(player: Player): CFrame?
			local bay = bays[player]
			return if bay then bay.origin else nil
		end,
		addEgg = addEgg,
		addAlien = addAlien,
	}
end

return table.freeze(BayService)
