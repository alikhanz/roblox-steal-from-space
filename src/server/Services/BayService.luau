--!strict
-- Owns the bays on the station: one per player, taken when their profile is active and freed
-- when they leave. The profile is the source of truth; the bay model is its reflection and is
-- brought up to date with the profile after every change (`refresh`): what it already shows
-- stays or moves, only what changed is built or taken away. Once a second the bays pay what the pods earn and show the eggs that became
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
local EggLooks = require(ReplicatedStorage.Shared.Config.EggLooks)
local EggModel = require(script.Parent.Parent.World.EggModel)
local Hatch = require(ReplicatedStorage.Shared.Domain.Hatch)
local Loot = require(ReplicatedStorage.Shared.Domain.Loot)
local MonetizationConfig = require(ReplicatedStorage.Shared.Config.MonetizationConfig)
local PlayerData = require(ReplicatedStorage.Shared.Domain.PlayerData)
local Scheduler = require(ReplicatedStorage.Shared.Runtime.Scheduler)
local Signal = require(ReplicatedStorage.Shared.Runtime.Signal)
local StandConfig = require(ReplicatedStorage.Shared.Config.StandConfig)
local Text = require(ReplicatedStorage.Shared.Locale.Text)
local Tutorial = require(ReplicatedStorage.Shared.Domain.Tutorial)
local TutorialConfig = require(ReplicatedStorage.Shared.Config.TutorialConfig)
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
	-- The spawn on island `index`: a player respawns on their own island (decision 068).
	getIslandSpawn: (index: number) -> SpawnLocation?,
}

export type BayService = {
	name: string,
	start: () -> (),
	-- Brings a player's bay up to date with their profile. Call after any change to the bay data.
	refresh: (player: Player) -> (),
	-- The bay's frame on the platform; nil until the player has one.
	getOrigin: (player: Player) -> CFrame?,
	-- The island the player's bay stands on (StationConfig.ISLANDS); nil until they have one.
	getIsland: (player: Player) -> number?,
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
	-- The aliens standing in it, by uid: they outlive a rebuild of the bay, which only moves
	-- them (or builds them anew when their kind or size changed). An alien is thousands of
	-- instances' worth of network: rebuilt on every change, thirty of them flooded a phone's
	-- connection and the server pulled its character back (2026-11-10).
	aliens: { [number]: ShownAlien },
	-- The rest of what stands in it outlives a rebuild too, moved or changed only where the
	-- profile changed: rebuilt on every hatch, the capsules blinked and the places jumped on
	-- screen (2026-11-10). Places by index, with the width each was built for; capsules by index;
	-- eggs by uid, and the capsule each egg warming lies in (Bay.capsulesFor).
	places: { ShownPlace },
	capsules: { Model },
	eggs: { [number]: ShownEgg },
	eggCapsules: { [number]: number },
}

type ShownPlace = {
	model: Model,
	width: number,
}

type ShownEgg = {
	part: BasePart,
	-- What it shows: "warming" or "ready" in a capsule, or "waiting" in the queue. Its prompt and
	-- light go with this, so a change builds it anew.
	state: string,
}

type ShownAlien = {
	model: Model,
	id: AlienConfig.AlienId,
	-- Its scale override (the floor's), or 0 for its own size.
	scale: number,
	-- The frame it stands on.
	stand: CFrame,
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

	-- A floor alien's size: all small, and no wider than its step in the floor's grid.
	local function floorScale(alienId: AlienConfig.AlienId): number
		if not AlienConfig.ALIENS[alienId] then
			return BayLooks.PILE_ALIEN_SCALE
		end
		local room = BayLooks.PILE_SPACING * BayLooks.PILE_ALIEN_FILL
		local width = AlienModel.widthOf(alienId, BayLooks.PILE_ALIEN_SCALE)
		return BayLooks.PILE_ALIEN_SCALE * math.min(1, room / math.max(width, 1e-3))
	end

	-- Shows `alien` standing on `cframe` in `bay`, its own size or `scale` (the small ones on the
	-- floor): the model it already has, moved there if it stood elsewhere, or a new one when it has
	-- none or the one it has is of another kind or size. `kept` collects the uids shown.
	local function showAlien(
		bay: PlayerBay,
		alien: PlayerData.AlienRecord,
		cframe: CFrame,
		parent: Instance,
		kept: { [number]: boolean },
		scale: number?
	): Model?
		if not AlienConfig.ALIENS[alien.id] then
			-- A profile may hold an alien this build no longer knows; it stays in the data.
			warn(`[BayService] Unknown alien {alien.id} (uid {alien.uid}); not shown`)
			return nil
		end
		kept[alien.uid] = true
		local scaleKey = scale or 0
		local shown = bay.aliens[alien.uid]
		if shown and shown.id == alien.id and shown.scale == scaleKey and shown.model.Parent then
			if not shown.stand:FuzzyEq(cframe, 1e-3) then
				AlienModel.place(shown.model, cframe)
				shown.stand = cframe
			end
			return shown.model
		end
		if shown then
			shown.model:Destroy()
		end
		local model = AlienModel.build(alien.id, alien.uid, cframe, scale)
		CollectionService:AddTag(model, BayConfig.ALIEN_TAG)
		model.Parent = parent
		bay.aliens[alien.uid] = { model = model, id = alien.id, scale = scaleKey, stand = cframe }
		return model
	end

	-- The prompt to pick a floor alien up: there while the inventory has room, gone otherwise.
	local function pickUpPromptOf(model: Model): ProximityPrompt?
		local body = model.PrimaryPart
		return if body then body:FindFirstChildOfClass("ProximityPrompt") else nil
	end

	-- Shows `egg` lying at `cframe` in `bay`: in a capsule (`hatchAt` given, for its countdown;
	-- shining once `ready`) or waiting for one on the platform. The part it already has, moved
	-- there, or a new one when it has none or what it shows changed (the second result: true for a
	-- new one, which needs its prompt). `kept` collects the uids shown.
	local function showEgg(
		bay: PlayerBay,
		egg: {
			read uid: number,
			read rarity: string,
			read size: string,
			read variant: string?,
			read luck: number?,
		},
		cframe: CFrame,
		parent: Instance,
		kept: { [number]: boolean },
		hatchAt: number?,
		ready: boolean?
	): (BasePart?, boolean)
		local state = if hatchAt == nil then "waiting" elseif ready then "ready" else "warming"
		-- `cframe` is where a medium egg lies; every egg stands on its bottom there.
		if EggConfig.SIZES[egg.size :: EggConfig.SizeId] then
			cframe += Vector3.yAxis * EggLooks.liftOf(egg.size :: EggConfig.SizeId)
		end
		local shown = bay.eggs[egg.uid]
		if shown and shown.state == state and shown.part.Parent then
			kept[egg.uid] = true
			if not shown.part.CFrame:FuzzyEq(cframe, 1e-3) then
				shown.part.CFrame = cframe
			end
			if hatchAt then
				shown.part:SetAttribute(BayConfig.EGG_HATCH_AT_ATTRIBUTE, hatchAt)
			end
			return shown.part, false
		end
		if shown then
			shown.part:Destroy()
			bay.eggs[egg.uid] = nil
		end
		if
			not EggConfig.RARITIES[egg.rarity :: EggConfig.RarityId]
			or not EggConfig.SIZES[egg.size :: EggConfig.SizeId]
		then
			warn(`[BayService] Unknown egg {egg.rarity} {egg.size} (uid {egg.uid}); not shown`)
			return nil, false
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
		kept[egg.uid] = true
		bay.eggs[egg.uid] = { part = part, state = state }
		return part, true
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
		attributes: { [string]: number | string }?
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
		local words = Text.get(Text.localeOf(player), "alien.pickUp.button")
		addOwnerPrompt(player, body, words, function()
			pickUp(player, uid, body)
		end, {
			[BayConfig.PROMPT_ACTION_ATTRIBUTE] = BayConfig.PROMPT_ACTION_PICK_UP,
		})
	end

	-- An egg's prompt hangs this far over the egg's centre: the same distance under its bottom
	-- whatever its size.
	local function eggPromptHeight(part: BasePart): number
		return -(part.Size.Y / 2 + BayConfig.EGG_PROMPT_BELOW)
	end

	local function addHatchPrompt(player: Player, part: BasePart, uid: number)
		local words = Text.get(Text.localeOf(player), "egg.hatch.button")
		addOwnerPrompt(player, part, words, function()
			if withinReach(player, part) then
				hatchReady(player, uid)
			end
		end, {
			[BayConfig.PROMPT_STUDS_ABOVE_ATTRIBUTE] = eggPromptHeight(part),
		})
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
		local locale = Text.localeOf(player)
		local unknown = Text.get(locale, "store.robux.hint", { price = "…" })
		local words = Text.get(locale, "egg.hatchNow.button", { price = unknown })
		addOwnerPrompt(player, part, words, function() end, {
			[BayConfig.READY_NOW_TIER_ATTRIBUTE] = tier,
			[BayConfig.PROMPT_STUDS_ABOVE_ATTRIBUTE] = eggPromptHeight(part),
		})
	end

	function refresh(player: Player)
		local bay = bays[player]
		local data = dependencies.getData(player)
		if not bay or not data then
			return
		end
		local contents = contentsOf(bay)
		-- What it already shows stays, moved where it now stands (showAlien, showEgg); only what
		-- changed is built anew or taken away.
		local kept: { [number]: boolean } = {}
		bay.model:SetAttribute(BayConfig.POD_COUNT_ATTRIBUTE, #data.pods)

		-- Places make room for their aliens: the layout follows their sizes (decision 068).
		local widths: { number } = {}
		for index, pod in data.pods do
			local alien = if pod.alien then AlienConfig.ALIENS[pod.alien.id] else nil
			widths[index] = if alien
				then math.max(AlienModel.widthOf(alien.id), BayLooks.MIN_PLACE_WIDTH)
				else BayLooks.EMPTY_PLACE_WIDTH
		end
		local placeFrames = BayModel.placeFrames(bay.origin, widths)
		for index, pod in data.pods do
			-- A place of the same width moves; one that got (or lost) an alien is built to its size.
			local place = bay.places[index]
			if place and place.width == widths[index] and place.model.Parent then
				BayModel.movePlace(place.model, placeFrames[index])
			else
				if place then
					place.model:Destroy()
				end
				local model = BayModel.buildPlace(placeFrames[index], widths[index], index)
				CollectionService:AddTag(model, BayConfig.PLACE_TAG)
				model.Parent = contents
				bay.places[index] = { model = model, width = widths[index] }
			end
			if pod.alien then
				local model = showAlien(bay, pod.alien, BayModel.placeAlienCFrame(placeFrames[index]), contents, kept)
				local prompt = if model then pickUpPromptOf(model) else nil
				if prompt then
					prompt:Destroy()
				end
			end
		end
		for index = #bay.places, #data.pods + 1, -1 do
			bay.places[index].model:Destroy()
			bay.places[index] = nil
		end

		-- Capsules stand still: only the bought ones are added.
		local capsuleCount = math.min(data.incubatorSlots, BayLooks.CAPSULE_POSITIONS)
		for index = #bay.capsules + 1, capsuleCount do
			local capsule = BayModel.buildCapsule(bay.origin, index)
			capsule.Parent = contents
			bay.capsules[index] = capsule
		end
		for index = #bay.capsules, capsuleCount + 1, -1 do
			bay.capsules[index]:Destroy()
			bay.capsules[index] = nil
		end

		-- Every egg stays in its own capsule (Bay.capsulesFor).
		local warming: { number } = {}
		for _, egg in data.incubator do
			table.insert(warming, egg.uid)
		end
		bay.eggCapsules = Bay.capsulesFor(warming, bay.eggCapsules, capsuleCount)
		local keptEggs: { [number]: boolean } = {}
		local current = now()
		bay.ready = 0
		for _, egg in data.incubator do
			local ready = Bay.isReady(egg, current)
			local cframe = BayModel.eggCFrame(bay.origin, bay.eggCapsules[egg.uid])
			local part, new = showEgg(bay, egg, cframe, contents, keptEggs, egg.hatchAt, ready)
			if ready then
				bay.ready += 1
			end
			if part and new then
				if ready then
					addHatchPrompt(player, part, egg.uid)
				else
					addHatchNowPrompt(player, part, egg)
				end
			end
		end
		for index, egg in data.waiting do
			if index > BayConfig.WAITING_SHOWN_MAX then
				break
			end
			showEgg(bay, egg, BayModel.waitingEggCFrame(bay.origin, index), contents, keptEggs)
		end
		for uid, shown in bay.eggs do
			if not keptEggs[uid] then
				shown.part:Destroy()
				bay.eggs[uid] = nil
			end
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
			local model =
				showAlien(bay, alien, BayModel.floorCFrame(bay.origin, index), contents, kept, floorScale(alien.id))
			if model then
				local prompt = pickUpPromptOf(model)
				if hasRoom and not prompt then
					addPickUpPrompt(player, model, alien.uid)
				elseif prompt and not hasRoom then
					prompt:Destroy()
				end
			end
		end
		-- Aliens no longer in the bay (sold, crossbred, picked up, past the floor's shown ones).
		for uid, shown in bay.aliens do
			if not kept[uid] then
				shown.model:Destroy()
				bay.aliens[uid] = nil
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

	-- Islands taken on joining, before the bay is built (it waits for the profile).
	local reserved: { [Player]: number } = {}

	-- A joining player gets their island at once (decision 068): its spawn becomes theirs before
	-- their first character appears, so they start at home.
	local function reserve(player: Player)
		if reserved[player] or bays[player] then
			return
		end
		local slot = freeSlot()
		if not slot then
			warn(`[BayService] No island for {player.Name}: all taken`)
			return
		end
		slotOwners[slot] = player
		reserved[player] = slot
		-- The simulation finds the player's own jetpack stand by it (Domain/Stand).
		player:SetAttribute(StandConfig.ISLAND_ATTRIBUTE, slot)
		local spawn = dependencies.getIslandSpawn(slot)
		if spawn then
			player.RespawnLocation = spawn
		end
	end

	-- Eggs that became ready while the player was away wait in their slots, ready to hatch.
	local function assign(player: Player)
		if bays[player] or player.Parent ~= Players then
			return
		end
		reserve(player)
		local slot = reserved[player]
		local parent = folder
		if not slot or not parent then
			warn(`[BayService] No bay for {player.Name}: {if slot then "world not built" else "all slots taken"}`)
			return
		end
		reserved[player] = nil
		local origin = BayModel.origin(slot)
		local model = BayModel.build(slot, origin)
		model:SetAttribute(BayConfig.OWNER_ID_ATTRIBUTE, player.UserId)
		model:SetAttribute(BayConfig.OWNER_NAME_ATTRIBUTE, player.DisplayName)
		CollectionService:AddTag(model, BayConfig.TAG)
		model.Parent = parent

		slotOwners[slot] = player
		bays[player] = {
			slot = slot,
			origin = origin,
			model = model,
			ready = 0,
			aliens = {},
			places = {},
			capsules = {},
			eggs = {},
			eggCapsules = {},
		}
		refresh(player)
		assigned.fire(player, model)
	end

	local function release(player: Player)
		player:SetAttribute(StandConfig.ISLAND_ATTRIBUTE, nil)
		local slot = reserved[player]
		if slot then
			reserved[player] = nil
			slotOwners[slot] = nil
		end
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
			-- The tutorial's first egg is quick, so its hatch step is not a wait (decision 065).
			local seconds = Tutorial.hatchSeconds(data.tutorialStep, duration, TutorialConfig.FIRST_EGG_SECONDS)
			-- Into a free slot, or the queue (decision 058).
			Bay.addEgg(data, rarity, size, grade, seconds, now(), variant, luck)
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

	-- An egg hatches into a kind of its grade, by the kinds' own odds, and a tier, with the tier's
	-- odds tilted by the egg's luck (luck never touches the kind: it is for the collection,
	-- decision 075).
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
		local kind = Loot.pick(grade.kindEntries, random:NextNumber())
		local tier = Hatch.pick(AlienConfig.HATCH_ENTRIES, luck, random:NextNumber())
		local alienId = variant[kind][tier]
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

		Players.PlayerAdded:Connect(reserve)
		for _, player in Players:GetPlayers() do
			reserve(player)
		end
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
		getIsland = function(player: Player): number?
			local bay = bays[player]
			return if bay then bay.slot else reserved[player]
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
