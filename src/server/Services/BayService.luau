--!strict
-- Owns the bays on the station: one per player, taken when their profile is active and freed
-- when they leave. The profile is the source of truth; the bay model is its reflection and is
-- rebuilt from the profile after every change (`refresh`), which at this scale is cheap and
-- cannot drift. Once a second the bays pay what the pods earn and show the eggs that became
-- ready; the owner hatches a ready egg with its prompt (decision 059). The time away is paid
-- by OfflineService.

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
local MonetizationConfig = require(ReplicatedStorage.Shared.Config.MonetizationConfig)
local PlayerData = require(ReplicatedStorage.Shared.Domain.PlayerData)
local Scheduler = require(ReplicatedStorage.Shared.Runtime.Scheduler)
local Signal = require(ReplicatedStorage.Shared.Runtime.Signal)
local Text = require(ReplicatedStorage.Shared.Locale.Text)
local Wallet = require(ReplicatedStorage.Shared.Domain.Wallet)

local FOLDER_NAME = "Bays"
-- A floor alien can be picked up, and a ready egg hatched, from this far, studs; the server
-- accepts a little more.
local PROMPT_DISTANCE = 8
local PROMPT_TOLERANCE = 4
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
	-- Puts an egg into the incubator; it hatches after its rarity's random time, into an alien of
	-- `variant` (the usual one when nil), with `luck` on top of its own (EggConfig.luckOf). False
	-- without an active profile.
	addEgg: (
		player: Player,
		rarity: EggConfig.RarityId,
		size: EggConfig.SizeId,
		grade: number,
		variant: AlienConfig.VariantId?,
		luck: number?
	) -> boolean,
	-- Gives the player an alien: into a free pod, else onto the floor. Nil without an active profile.
	addAlien: (player: Player, alienId: AlienConfig.AlienId) -> Bay.Location?,
	-- Makes every egg in the incubator's slots ready now, to hatch with its prompt (playtests).
	hastenHatching: (player: Player) -> boolean,
	-- Hatches the player's ready egg `uid`, wherever the player stands (an "Egg ready now"
	-- bought at the egg); nothing if it is not there or not ready.
	hatch: (player: Player, uid: number) -> (),
	-- What the player's pods earn per second; zero without an active profile.
	getIncomePerSecond: (player: Player) -> BigNum.BigNum,
	-- How fast every incubator on the server runs: 1 normally, more during the solar storm (the
	-- egg timers then follow every tick).
	setHatchRate: (rate: number) -> (),
	-- Fires when the player hatches an egg: the player, the alien and where it went.
	hatched: Signal.Signal<Player, AlienConfig.AlienId, Bay.Location>,
	-- Fires once a player gets their bay, with its model.
	assigned: Signal.Signal<Player, Model>,
	-- Fires after the bay was rebuilt from the profile.
	changed: Signal.Signal<Player>,
	-- Fires when the player's coins change, with the new total.
	coinsChanged: Signal.Signal<Player, BigNum.BigNum>,
	-- Fires on every payout of the pods: the coins earned and the new total (analytics).
	incomePaid: Signal.Signal<Player, BigNum.BigNum, BigNum.BigNum>,
}

type PlayerBay = {
	slot: number,
	origin: CFrame,
	model: Model,
	-- Ready eggs when the bay was last built: the tick rebuilds it once another becomes ready.
	ready: number,
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
	-- How fast the incubators run (setHatchRate).
	local hatchRate = 1
	local slotOwners: { [number]: Player } = {}
	local folder: Folder? = nil
	local random = Random.new()
	local hatched = Signal.new() :: Signal.Signal<Player, AlienConfig.AlienId, Bay.Location>
	local assigned = Signal.new() :: Signal.Signal<Player, Model>
	local changed = Signal.new() :: Signal.Signal<Player>
	local coinsChanged = Signal.new() :: Signal.Signal<Player, BigNum.BigNum>
	local incomePaid = Signal.new() :: Signal.Signal<Player, BigNum.BigNum, BigNum.BigNum>
	-- Defined below; picking up an alien rebuilds the bay, and its prompts hatch eggs.
	local refresh: (player: Player) -> ()
	local hatchReady: (player: Player, uid: number) -> ()

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

	-- An egg's model in the bay: in a slot (`hatchAt` given, for its countdown; shining once
	-- `ready`) or waiting for one on the platform.
	local function placeEgg(
		egg: {
			read uid: number,
			read rarity: string,
			read size: string,
			read variant: string?,
			read luck: number?,
		},
		cframe: CFrame,
		parent: Instance,
		hatchAt: number?,
		ready: boolean?
	): BasePart?
		if
			not EggConfig.RARITIES[egg.rarity :: EggConfig.RarityId]
			or not EggConfig.SIZES[egg.size :: EggConfig.SizeId]
		then
			warn(`[BayService] Unknown egg {egg.rarity} {egg.size} (uid {egg.uid}); not shown`)
			return nil
		end
		local part = EggModel.build(egg.rarity :: EggConfig.RarityId, egg.size :: EggConfig.SizeId, {
			glowScale = BayLooks.INCUBATOR_GLOW_SCALE,
			variant = egg.variant :: AlienConfig.VariantId?,
			luck = egg.luck,
		})
		part.Name = `Egg{egg.uid}`
		part.Anchored = true
		part.CFrame = cframe
		part:SetAttribute(BayConfig.EGG_UID_ATTRIBUTE, egg.uid)
		if hatchAt then
			part:SetAttribute(BayConfig.EGG_HATCH_AT_ATTRIBUTE, hatchAt)
			CollectionService:AddTag(part, BayConfig.INCUBATOR_EGG_TAG)
		else
			CollectionService:AddTag(part, BayConfig.WAITING_EGG_TAG)
		end
		if ready then
			local light = Instance.new("PointLight")
			light.Color = BayLooks.READY_EGG_LIGHT_COLOR
			light.Brightness = BayLooks.READY_EGG_LIGHT_BRIGHTNESS
			light.Range = BayLooks.READY_EGG_LIGHT_RANGE
			light.Parent = part
		end
		part.Parent = parent
		return part
	end

	-- A prompt is client input: true when the player has a bay and stands within reach of `body`.
	local function withinReach(player: Player, body: BasePart): boolean
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not bays[player] or not root or not root:IsA("BasePart") then
			return false
		end
		return (root.Position - body.Position).Magnitude <= PROMPT_DISTANCE + PROMPT_TOLERANCE
	end

	-- Moves a floor alien into the inventory. The owner, the distance and the room are all
	-- checked here.
	local function pickUp(player: Player, uid: number, body: BasePart)
		if not withinReach(player, body) then
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

	-- A prompt on `body` that only the owner of the bay can use (and only their client draws).
	local function addOwnerPrompt(
		player: Player,
		body: BasePart,
		actionText: string,
		onTriggered: () -> (),
		attributes: { [string]: number }?
	)
		local prompt = Instance.new("ProximityPrompt")
		for name, value in attributes or {} do
			prompt:SetAttribute(name, value)
		end
		-- Drawn by the client in the same style as the egg prompt (PromptViewController).
		prompt.Style = Enum.ProximityPromptStyle.Custom
		prompt.ActionText = actionText
		prompt.ObjectText = ""
		prompt.MaxActivationDistance = PROMPT_DISTANCE
		prompt.RequiresLineOfSight = false
		prompt:SetAttribute(BayConfig.PROMPT_OWNER_ATTRIBUTE, player.UserId)
		prompt.Triggered:Connect(function(who)
			if who == player then
				onTriggered()
			end
		end)
		prompt.Parent = body
	end

	local function addPickUpPrompt(player: Player, model: Model, uid: number)
		local body = model.PrimaryPart
		if not body then
			return
		end
		local words = Text.get(Text.resolveLocale(player.LocaleId), "alien.pickUp.button")
		addOwnerPrompt(player, body, words, function()
			pickUp(player, uid, body)
		end)
	end

	local function addHatchPrompt(player: Player, part: BasePart, uid: number)
		local words = Text.get(Text.resolveLocale(player.LocaleId), "egg.hatch.button")
		addOwnerPrompt(player, part, words, function()
			if withinReach(player, part) then
				hatchReady(player, uid)
			end
		end)
	end

	-- A warming egg offers to hatch it now for Robux: the owner's client words the prompt with
	-- the price of this egg's tier and asks Roblox for the purchase; the receipt does the rest
	-- (PurchaseService). Only for a tier this game sells.
	local function addHatchNowPrompt(player: Player, part: BasePart, egg: PlayerData.EggRecord)
		local catalog = MonetizationConfig.catalogFor(game.GameId)
		local tier = MonetizationConfig.readyNowTierOf(egg.grade, egg.rarity)
		if not catalog or not MonetizationConfig.productIdOf(catalog, "ReadyNow", tier) then
			return
		end
		-- The price is the client's: Roblox tells each player their own.
		local locale = Text.resolveLocale(player.LocaleId)
		local unknown = Text.get(locale, "store.robux.hint", { price = "…" })
		local words = Text.get(locale, "egg.hatchNow.button", { price = unknown })
		addOwnerPrompt(player, part, words, function() end, {
			[BayConfig.READY_NOW_TIER_ATTRIBUTE] = tier,
		})
	end

	function refresh(player: Player)
		local bay = bays[player]
		local data = dependencies.getData(player)
		if not bay or not data then
			return
		end
		local contents = contentsOf(bay)
		contents:ClearAllChildren()
		bay.model:SetAttribute(BayConfig.POD_COUNT_ATTRIBUTE, #data.pods)

		for index, pod in data.pods do
			BayModel.buildPod(bay.origin, index).Parent = contents
			if pod.alien then
				placeAlien(pod.alien, BayModel.podAlienCFrame(bay.origin, index), contents)
			end
		end
		local current = now()
		bay.ready = 0
		for index, egg in data.incubator do
			local ready = Bay.isReady(egg, current)
			local part = placeEgg(egg, BayModel.eggCFrame(bay.origin, index), contents, egg.hatchAt, ready)
			if ready then
				bay.ready += 1
				if part then
					addHatchPrompt(player, part, egg.uid)
				end
			elseif part then
				addHatchNowPrompt(player, part, egg)
			end
		end
		for index, egg in data.waiting do
			if index > BayConfig.WAITING_SHOWN_MAX then
				break
			end
			placeEgg(egg, BayModel.waitingEggCFrame(bay.origin, index), contents)
		end
		local incubator = bay.model:FindFirstChild(BayConfig.INCUBATOR_NAME)
		if incubator then
			incubator:SetAttribute(BayConfig.INCUBATOR_COUNT_ATTRIBUTE, #data.incubator)
			incubator:SetAttribute(BayConfig.INCUBATOR_SLOTS_ATTRIBUTE, data.incubatorSlots)
			incubator:SetAttribute(BayConfig.INCUBATOR_WAITING_ATTRIBUTE, #data.waiting)
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

	-- Eggs that became ready while the player was away wait in their slots, ready to hatch.
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
		bays[player] = { slot = slot, origin = origin, model = model, ready = 0 }
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

	local function addEgg(
		player: Player,
		rarity: EggConfig.RarityId,
		size: EggConfig.SizeId,
		grade: number,
		variant: AlienConfig.VariantId?,
		luck: number?
	): boolean
		local rarityConfig = assert(EggConfig.RARITIES[rarity], `Unknown rarity {rarity}`)
		assert(EggConfig.SIZES[size], `Unknown size {size}`)
		assert(AlienConfig.GRADES[grade], `Unknown grade {grade}`)
		assert(variant == nil or AlienConfig.VARIANTS[variant], `Unknown variant {variant}`)
		assert(luck == nil or luck >= 0, `Negative luck {luck}`)
		local duration = Hatch.duration(rarityConfig.hatchSeconds, random:NextNumber())
		local added = dependencies.update(player, function(data)
			-- Into a free slot, or the queue (decision 058).
			Bay.addEgg(data, rarity, size, grade, duration, now(), variant, luck)
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
		local variant = grade and grade.variants[(egg.variant or "Normal") :: AlienConfig.VariantId]
		if not rarity or not size or not variant then
			warn(`[BayService] Egg {egg.uid} ({egg.rarity} {egg.size}, grade {egg.grade}) cannot hatch; dropped`)
			return nil, nil
		end
		local luck = EggConfig.luckOf(egg.rarity :: EggConfig.RarityId, egg.size :: EggConfig.SizeId, egg.luck)
		local tier = Hatch.pick(AlienConfig.HATCH_ENTRIES, luck, random:NextNumber())
		local alienId = variant[tier]
		return alienId, Bay.addHatched(data, { uid = Bay.newUid(data), id = alienId })
	end

	-- The owner hatches a ready egg (its prompt): the alien goes where it fits, and the first
	-- waiting egg takes the slot.
	function hatchReady(player: Player, uid: number)
		local alienId: AlienConfig.AlienId?, location: Bay.Location? = nil, nil
		local taken = false
		dependencies.update(player, function(data)
			local egg = Bay.hatch(data, uid, now())
			if egg then
				taken = true
				alienId, location = hatchEgg(data, egg)
			end
		end)
		if not taken then
			return
		end
		refresh(player)
		if alienId and location then
			if LOG then
				print(`[BayService] {player.Name} hatched {alienId} -> {location}`)
			end
			hatched.fire(player, alienId, location)
		end
	end

	-- After a sped-up tick moved the eggs on: the bay's egg timers and the owner's copy follow
	-- without rebuilding the bay, so the countdowns visibly run faster.
	local function syncIncubator(player: Player)
		local bay = bays[player]
		local data = dependencies.getData(player)
		if not bay or not data then
			return
		end
		local hatchAtByUid: { [number]: number } = {}
		for _, egg in data.incubator do
			hatchAtByUid[egg.uid] = egg.hatchAt
		end
		for _, part in contentsOf(bay):GetChildren() do
			local uid = part:GetAttribute(BayConfig.EGG_UID_ATTRIBUTE)
			local hatchAt = if type(uid) == "number" then hatchAtByUid[uid] else nil
			if hatchAt then
				part:SetAttribute(BayConfig.EGG_HATCH_AT_ATTRIBUTE, hatchAt)
			end
		end
		changed.fire(player)
	end

	-- One tick for every bay: run the incubator (faster in a storm), show the eggs that became
	-- ready, pay the pods.
	local function tick(deltaTime: number)
		local current = now()
		local earnedSeconds = BigNum.fromNumber(deltaTime)
		local extraHatchSeconds = deltaTime * (hatchRate - 1)
		for player, bay in bays do
			local ready = bay.ready
			local coins: BigNum.BigNum? = nil
			local earned: BigNum.BigNum? = nil
			dependencies.update(player, function(data)
				if extraHatchSeconds > 0 then
					Bay.advanceIncubator(data, extraHatchSeconds)
				end
				ready = Bay.readyCount(data, current)
				local income = Bay.incomePerSecond(data, incomeOf)
				if not BigNum.isZero(income) then
					earned = BigNum.mul(income, earnedSeconds)
					Wallet.earn(data, earned :: BigNum.BigNum)
					coins = data.coins
				end
			end)
			if coins then
				coinsChanged.fire(player, coins)
				if earned then
					incomePaid.fire(player, earned, coins)
				end
			end
			if ready ~= bay.ready then
				refresh(player)
			elseif extraHatchSeconds > 0 then
				syncIncubator(player)
			end
		end
	end

	local function setHatchRate(rate: number)
		assert(rate >= 1, "incubators do not run backwards")
		hatchRate = rate
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
		hatch = function(player: Player, uid: number)
			hatchReady(player, uid)
		end,
		getIncomePerSecond = getIncomePerSecond,
		setHatchRate = setHatchRate,
		hatched = hatched,
		assigned = assigned,
		changed = changed,
		coinsChanged = coinsChanged,
		incomePaid = incomePaid,
	}
end

return table.freeze(BayService)
