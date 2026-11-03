--!strict
-- Owns the bays on the station: one per player, taken when their profile is active and freed
-- when they leave. The profile is the source of truth; the bay model is its reflection and is
-- rebuilt from the profile after every change (`refresh`), which at this scale is cheap and
-- cannot drift. Once a second the bays hatch what is ready and pay what the pods earn; the
-- time away is paid by OfflineService.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AlienConfig = require(ReplicatedStorage.Shared.Config.AlienConfig)
local AlienModel = require(script.Parent.Parent.World.AlienModel)
local Bay = require(ReplicatedStorage.Shared.Domain.Bay)
local BayConfig = require(ReplicatedStorage.Shared.Config.BayConfig)
local BayLooks = require(ReplicatedStorage.Shared.Config.BayLooks)
local BayModel = require(script.Parent.Parent.World.BayModel)
local BigNum = require(ReplicatedStorage.Shared.Domain.BigNum)
local EggConfig = require(ReplicatedStorage.Shared.Config.EggConfig)
local EggModel = require(script.Parent.Parent.World.EggModel)
local Hatch = require(ReplicatedStorage.Shared.Domain.Hatch)
local PlayerData = require(ReplicatedStorage.Shared.Domain.PlayerData)
local Scheduler = require(ReplicatedStorage.Shared.Runtime.Scheduler)
local Signal = require(ReplicatedStorage.Shared.Runtime.Signal)
local Text = require(ReplicatedStorage.Shared.Locale.Text)

local FOLDER_NAME = "Bays"
-- A floor alien can be picked up from this far, studs; the server accepts a little more.
local PICK_UP_DISTANCE = 8
local PICK_UP_TOLERANCE = 4
-- Every session transition of the bay is printed in Studio to make playtests easy to follow.
local LOG = RunService:IsStudio()

export type Dependencies = {
	activated: Signal.Signal<Player>,
	getData: (player: Player) -> PlayerData.PlayerData?,
	update: (player: Player, mutator: (data: PlayerData.PlayerData) -> ()) -> boolean,
	scheduler: Scheduler.Scheduler,
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
	-- Makes every egg in the incubator ready now (playtests; later the Robux instant hatch).
	hastenHatching: (player: Player) -> boolean,
	-- What the player's pods earn per second; zero without an active profile.
	getIncomePerSecond: (player: Player) -> BigNum.BigNum,
	-- Fires when an egg hatches: the player, the alien and where it went.
	hatched: Signal.Signal<Player, AlienConfig.AlienId, Bay.Location>,
	-- Fires once a player gets their bay, with its model.
	assigned: Signal.Signal<Player, Model>,
	-- Fires after the bay was rebuilt from the profile.
	changed: Signal.Signal<Player>,
	-- Fires when the player's coins change, with the new total.
	coinsChanged: Signal.Signal<Player, BigNum.BigNum>,
}

type PlayerBay = {
	slot: number,
	origin: CFrame,
	model: Model,
}

local BayService = {}

local function incomeOf(alienId: string): BigNum.BigNum
	local alien = AlienConfig.ALIENS[alienId]
	return if alien then alien.income else BigNum.ZERO
end

local function now(): number
	return workspace:GetServerTimeNow()
end

function BayService.new(dependencies: Dependencies): BayService
	local bays: { [Player]: PlayerBay } = {}
	local slotOwners: { [number]: Player } = {}
	local folder: Folder? = nil
	local random = Random.new()
	local hatched = Signal.new() :: Signal.Signal<Player, AlienConfig.AlienId, Bay.Location>
	local assigned = Signal.new() :: Signal.Signal<Player, Model>
	local changed = Signal.new() :: Signal.Signal<Player>
	local coinsChanged = Signal.new() :: Signal.Signal<Player, BigNum.BigNum>
	-- Defined below; picking up an alien rebuilds the bay.
	local refresh: (player: Player) -> ()

	local function contentsOf(bay: PlayerBay): Instance
		return bay.model:FindFirstChild(BayConfig.CONTENTS_NAME) or bay.model
	end

	local function placeAlien(alien: PlayerData.AlienRecord, cframe: CFrame, parent: Instance): Model?
		if not AlienConfig.ALIENS[alien.id] then
			-- A profile may hold an alien this build no longer knows; it stays in the data.
			warn(`[BayService] Unknown alien {alien.id} (uid {alien.uid}); not shown`)
			return nil
		end
		local model = AlienModel.build(alien.id, alien.uid, cframe)
		CollectionService:AddTag(model, BayConfig.ALIEN_TAG)
		model.Parent = parent
		return model
	end

	local function placeEgg(egg: PlayerData.EggRecord, cframe: CFrame, parent: Instance)
		if
			not EggConfig.RARITIES[egg.rarity :: EggConfig.RarityId]
			or not EggConfig.SIZES[egg.size :: EggConfig.SizeId]
		then
			warn(`[BayService] Unknown egg {egg.rarity} {egg.size} (uid {egg.uid}); not shown`)
			return
		end
		local part = EggModel.build(egg.rarity :: EggConfig.RarityId, egg.size :: EggConfig.SizeId, true)
		part.Name = `Egg{egg.uid}`
		part.Anchored = true
		part.CFrame = cframe
		part:SetAttribute(BayConfig.EGG_UID_ATTRIBUTE, egg.uid)
		part:SetAttribute(BayConfig.EGG_HATCH_AT_ATTRIBUTE, egg.hatchAt)
		CollectionService:AddTag(part, BayConfig.INCUBATOR_EGG_TAG)
		part.Parent = parent
	end

	-- Moves a floor alien into the inventory. An engine prompt is client input: the owner, the
	-- distance and the room are all checked here.
	local function pickUp(player: Player, uid: number, body: BasePart)
		local bay = bays[player]
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not bay or not root or not root:IsA("BasePart") then
			return
		end
		if (root.Position - body.Position).Magnitude > PICK_UP_DISTANCE + PICK_UP_TOLERANCE then
			return
		end
		local picked = false
		dependencies.update(player, function(data)
			picked = Bay.pickUp(data, uid, BayConfig.INVENTORY_SLOTS)
		end)
		if picked then
			refresh(player)
		end
	end

	local function addPickUpPrompt(player: Player, model: Model, uid: number)
		local body = model.PrimaryPart
		if not body then
			return
		end
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = Text.get(Text.resolveLocale(player.LocaleId), "alien.pickUp.button")
		prompt.ObjectText = ""
		prompt.MaxActivationDistance = PICK_UP_DISTANCE
		prompt.RequiresLineOfSight = false
		prompt.Triggered:Connect(function(who)
			if who == player then
				pickUp(player, uid, body)
			end
		end)
		prompt.Parent = body
	end

	function refresh(player: Player)
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
		local nextHatchAt: number? = nil
		for index, egg in data.incubator do
			if index <= BayConfig.INCUBATOR_SHOWN_MAX then
				placeEgg(egg, BayModel.eggCFrame(bay.origin, index), contents)
			end
			nextHatchAt = math.min(nextHatchAt or math.huge, egg.hatchAt)
		end
		local incubator = bay.model:FindFirstChild(BayConfig.INCUBATOR_NAME)
		if incubator then
			incubator:SetAttribute(BayConfig.INCUBATOR_COUNT_ATTRIBUTE, #data.incubator)
			incubator:SetAttribute(BayConfig.INCUBATOR_NEXT_HATCH_ATTRIBUTE, nextHatchAt)
		end
		-- Floor aliens can be picked up only while the inventory has room: no prompt otherwise.
		local hasRoom = #data.inventory < BayConfig.INVENTORY_SLOTS
		for index, alien in data.floor do
			if index > BayConfig.FLOOR_SHOWN_MAX then
				break
			end
			local model = placeAlien(alien, BayModel.floorCFrame(bay.origin, index), contents)
			if model and hasRoom then
				addPickUpPrompt(player, model, alien.uid)
			end
		end
		changed.fire(player)
	end

	local function freeSlot(): number?
		for slot = 1, BayLooks.BAY_COUNT do
			if not slotOwners[slot] then
				return slot
			end
		end
		return nil
	end

	local function getIncomePerSecond(player: Player): BigNum.BigNum
		local data = dependencies.getData(player)
		return if data then Bay.incomePerSecond(data, incomeOf) else BigNum.ZERO
	end

	-- Eggs that hatched while the player was away come out on the first tick, like any ready egg.
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
		assigned.fire(player, model)
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
		local hatchAt = now() + duration
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

	local function hastenHatching(player: Player): boolean
		local current = now()
		local written = dependencies.update(player, function(data)
			for _, egg in data.incubator do
				egg.hatchAt = math.min(egg.hatchAt, current)
			end
		end)
		if written then
			refresh(player)
		end
		return written
	end

	-- An egg hatches into a tier of its grade, with the odds tilted by the egg's luck.
	local function hatchEgg(
		data: PlayerData.PlayerData,
		egg: PlayerData.EggRecord
	): (AlienConfig.AlienId?, Bay.Location?)
		local rarity = EggConfig.RARITIES[egg.rarity :: EggConfig.RarityId]
		local size = EggConfig.SIZES[egg.size :: EggConfig.SizeId]
		local grade = AlienConfig.GRADES[egg.grade]
		if not rarity or not size or not grade then
			warn(`[BayService] Egg {egg.uid} ({egg.rarity} {egg.size}, grade {egg.grade}) cannot hatch; dropped`)
			return nil, nil
		end
		local tier = Hatch.pick(AlienConfig.HATCH_ENTRIES, rarity.luck + size.luck, random:NextNumber())
		local alienId = grade.aliens[tier]
		return alienId, Bay.addHatched(data, { uid = Bay.newUid(data), id = alienId })
	end

	-- One tick for every bay: hatch what is ready, pay the pods.
	local function tick(deltaTime: number)
		local current = now()
		local earnedSeconds = BigNum.fromNumber(deltaTime)
		for player in bays do
			local results: { { id: AlienConfig.AlienId, location: Bay.Location } } = {}
			local coins: BigNum.BigNum? = nil
			dependencies.update(player, function(data)
				for _, egg in Bay.takeHatched(data, current) do
					local alienId, location = hatchEgg(data, egg)
					if alienId and location then
						table.insert(results, { id = alienId, location = location })
					end
				end
				local income = Bay.incomePerSecond(data, incomeOf)
				if not BigNum.isZero(income) then
					data.coins = BigNum.add(data.coins, BigNum.mul(income, earnedSeconds))
					coins = data.coins
				end
			end)
			if coins then
				coinsChanged.fire(player, coins)
			end
			if #results > 0 then
				refresh(player)
				for _, result in results do
					if LOG then
						print(`[BayService] {player.Name} hatched {result.id} -> {result.location}`)
					end
					hatched.fire(player, result.id, result.location)
				end
			end
		end
	end

	local function start()
		local world = workspace:FindFirstChild("World")
		local bayFolder = Instance.new("Folder")
		bayFolder.Name = FOLDER_NAME
		bayFolder.Parent = world or workspace
		folder = bayFolder

		dependencies.activated.connect(assign)
		Players.PlayerRemoving:Connect(release)
		dependencies.scheduler.every(BayConfig.INCOME_TICK_SECONDS, tick)
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
		hastenHatching = hastenHatching,
		getIncomePerSecond = getIncomePerSecond,
		hatched = hatched,
		assigned = assigned,
		changed = changed,
		coinsChanged = coinsChanged,
	}
end

return table.freeze(BayService)
