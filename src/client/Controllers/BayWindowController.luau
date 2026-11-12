--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- The bay window and what goes with it: its tile in the HUD menu, toasts for hatches and
-- refused commands, the welcome-back screen. Holds the selection; everything else is read from
-- ProfileState and every action is sent to the server through Remotes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AlienConfig = require(ReplicatedStorage.Shared.Config.AlienConfig)
local AlienLooks = require(ReplicatedStorage.Shared.Config.AlienLooks)
local Bay = require(ReplicatedStorage.Shared.Domain.Bay)
local BayConfig = require(ReplicatedStorage.Shared.Config.BayConfig)
local BayWindow = require(script.Parent.Parent.UI.BayWindow)
local BigNum = require(ReplicatedStorage.Shared.Domain.BigNum)
local Crossbreed = require(ReplicatedStorage.Shared.Domain.Crossbreed)
local Duration = require(ReplicatedStorage.Shared.Locale.Duration)
local EggLooks = require(ReplicatedStorage.Shared.Config.EggLooks)
local MenuState = require(script.Parent.Parent.State.MenuState)
local MonetizationConfig = require(ReplicatedStorage.Shared.Config.MonetizationConfig)
local Names = require(ReplicatedStorage.Shared.Locale.Names)
local ProfileState = require(script.Parent.Parent.State.ProfileState)
local PurchaseState = require(script.Parent.Parent.State.PurchaseState)
local Purchases = require(ReplicatedStorage.Shared.Domain.Purchases)
local Remotes = require(script.Parent.Parent.Net.Remotes)
local Text = require(ReplicatedStorage.Shared.Locale.Text)
local Theme = require(script.Parent.Parent.UI.Theme)
local ToastState = require(script.Parent.Parent.State.ToastState)
local Toasts = require(script.Parent.Parent.UI.Toasts)
local Vide = require(ReplicatedStorage.Packages.Vide)
local WelcomeBack = require(script.Parent.Parent.UI.WelcomeBack)
local WindowState = require(script.Parent.Parent.State.WindowState)

local create = Vide.create
local source = Vide.source

local PLAYER_GUI_WAIT_TIMEOUT = 30
-- Egg countdowns are whole seconds: once a second is enough.
local COUNTDOWN_INTERVAL = 1
-- The toasts of hatches in a row replace each other (State/ToastState).
local HATCH_TOAST_GROUP = "Hatch"

local NOTICE_KEYS: { [ProfileState.Notice]: Text.Key } = {
	NoProfile = "notice.noProfile.toast",
	UnknownAlien = "notice.unknownAlien.toast",
	InventoryFull = "notice.inventoryFull.toast",
	NotEnoughCoins = "notice.notEnoughCoins.toast",
	MaxPods = "notice.maxPlaces.toast",
	JetpackTop = "notice.jetpackTop.toast",
	MaxIncubatorSlots = "notice.maxIncubatorSlots.toast",
	NoSuchPod = "notice.unknownAlien.toast",
	WrongCount = "notice.wrongAliens.toast",
	MixedGrades = "notice.wrongAliens.toast",
	MixedVariants = "notice.mixedVariants.toast",
	TooFast = "notice.tooFast.toast",
	NotReady = "pvp.notReady.toast",
	AttackerInStation = "pvp.inStation.toast",
	VictimInStation = "pvp.inStation.toast",
	AttackerNewbie = "pvp.youAreNewbie.toast",
	VictimNewbie = "pvp.victimNewbie.toast",
	VictimJustSpawned = "pvp.victimJustSpawned.toast",
	VictimTooWeak = "pvp.victimTooWeak.toast",
	NoSuchQuest = "notice.noSuchQuest.toast",
	QuestNotDone = "notice.questNotDone.toast",
	QuestClaimed = "notice.questClaimed.toast",
	RerollUsed = "notice.rerollUsed.toast",
	QuestDone = "notice.questDone.toast",
	NoOtherQuest = "notice.noOtherQuest.toast",
	GiftTaken = "notice.giftTaken.toast",
	IndexNothing = "notice.indexNothing.toast",
	IndexClaimed = "notice.questClaimed.toast",
	StormTeleport = "notice.stormTeleport.toast",
	NoSuchEgg = "notice.noSuchEgg.toast",
	NotInCommunity = "notice.notInCommunity.toast",
}

export type Dependencies = {
	profile: ProfileState.ProfileState,
	purchases: PurchaseState.PurchaseState,
	toasts: ToastState.ToastState,
	windows: WindowState.WindowState,
	menu: MenuState.MenuState,
}

export type BayWindowController = {
	name: string,
	start: () -> (),
	-- The welcome-back screen is up (other screens on login wait for it).
	welcomeOpen: () -> boolean,
}

-- What the welcome-back screen shows; doubleTier: the "Collect x2" tier on offer, 0 for none.
type Reward = {
	coins: BigNum.BigNum,
	speed: BigNum.BigNum,
	seconds: number,
	readyEggs: number,
	doubleTier: number,
}

local BayWindowController = {}

function BayWindowController.new(dependencies: Dependencies): BayWindowController
	local profile = dependencies.profile
	local purchases = dependencies.purchases
	local isOpen = dependencies.windows.slot("Bay")
	-- Selected uids, in the order they were tapped; a fresh table each change so Vide sees it.
	local selection = source({} :: { number })
	-- The alien whose sale waits for a second tap.
	local pendingSale = source(nil :: number?)
	local reward = source(nil :: Reward?)
	-- Optional sources are read through a plain getter: Vide types a source as an intersection
	-- of reader and writer, which is ambiguous to call without arguments when T is optional.
	local readPendingSale = pendingSale :: () -> number?
	local readReward = reward :: () -> Reward?
	-- Bumped every second so egg lines recompute.
	local clock = source(0)
	local locale: Text.Locale = "en"

	local function text(key: Text.Key, args: Text.Args?): string
		return Text.get(locale, key, args)
	end

	local toast = dependencies.toasts.push

	local PLACE_KEYS: { [ProfileState.Location]: Text.Key } = {
		Pod = "place.spot.hint",
		Inventory = "place.inventory.hint",
		Floor = "place.floor.hint",
	}

	local function placeText(location: ProfileState.Location): string
		-- Looked up through `any`: the union of every string key is too much for the checker.
		local key: Text.Key = (PLACE_KEYS :: any)[location] or "place.floor.hint"
		return text(key)
	end

	local function selectedRecords(): { { record: ProfileState.Alien, location: ProfileState.Location } }
		local bay = profile.bay()
		local found = {}
		for _, uid in selection() do
			for _, pod in bay.pods do
				if pod.alien and pod.alien.uid == uid then
					table.insert(found, { record = pod.alien, location = "Pod" :: ProfileState.Location })
				end
			end
			for _, alien in bay.inventory do
				if alien.uid == uid then
					table.insert(found, { record = alien, location = "Inventory" :: ProfileState.Location })
				end
			end
			for _, alien in bay.floor do
				if alien.uid == uid then
					table.insert(found, { record = alien, location = "Floor" :: ProfileState.Location })
				end
			end
		end
		return found
	end

	local function single(): { record: ProfileState.Alien, location: ProfileState.Location }?
		local records = selectedRecords()
		return if #records == 1 then records[1] else nil
	end

	local function freePods(): number
		local free = 0
		for _, pod in profile.bay().pods do
			if not pod.alien then
				free += 1
			end
		end
		return free
	end

	local function toggle(uid: number)
		pendingSale(nil)
		local list = table.clone(selection())
		local index = table.find(list, uid)
		if index then
			table.remove(list, index)
		else
			table.insert(list, uid)
			while #list > BayConfig.CROSSBREED_COUNT do
				table.remove(list, 1)
			end
		end
		selection(list)
	end

	local function clearSelection()
		selection({})
		pendingSale(nil)
	end

	-- The first selected alien when every selected one goes with it (the same grade and variant,
	-- the server's rule in Domain/Crossbreed); otherwise nil and why they do not.
	local function selectedLine(): (AlienConfig.Alien?, Crossbreed.Problem?)
		local first: AlienConfig.Alien? = nil
		for _, entry in selectedRecords() do
			local alien = AlienConfig.ALIENS[entry.record.id]
			if not alien then
				return nil, "MixedGrades"
			end
			local problem = if first then Crossbreed.mismatch(first, alien) else nil
			if problem then
				return nil, problem
			end
			first = first or alien
		end
		return first, nil
	end

	local function canCrossbreed(): boolean
		local line = selectedLine()
		return line ~= nil and #selectedRecords() == BayConfig.CROSSBREED_COUNT
	end

	-- The line above the buttons: what is selected and what can happen to it.
	local function status(): string
		local records = selectedRecords()
		if #records == 0 then
			return text("bay.select.hint")
		elseif #records == 1 then
			local entry = records[1]
			local name = Names.alien(locale, entry.record.id) or "?"
			return if entry.location == "Pod"
				then text("bay.selectedPlace.hint", { name = name })
				else text("bay.selected.hint", { name = name })
		elseif canCrossbreed() then
			return text("bay.crossbreedReady.hint")
		end
		local line, problem = selectedLine()
		if problem == "MixedVariants" then
			return text("bay.crossbreedVariants.hint")
		elseif not line then
			return text("bay.crossbreedMixed.hint")
		end
		return text("bay.crossbreedSame.hint", {
			guardian = Names.guardian(locale, line.grade) or "?",
			count = #records,
			left = BayConfig.CROSSBREED_COUNT - #records,
		})
	end

	local function podPrice(): BigNum.BigNum
		return Bay.podPrice(
			#profile.bay().pods,
			BayConfig.STARTING_PODS,
			BayConfig.POD_PRICE_BASE,
			BayConfig.POD_PRICE_GROWTH
		)
	end

	local function sellPrice(alienId: string): BigNum.BigNum
		local alien = AlienConfig.ALIENS[alienId]
		local income = if alien then alien.income else BigNum.ZERO
		return BigNum.mul(income, BigNum.fromNumber(BayConfig.SELL_INCOME_SECONDS))
	end

	local function slotPrice(): BigNum.BigNum
		return Bay.slotPrice(
			profile.bay().incubatorSlots,
			BayConfig.STARTING_INCUBATOR_SLOTS,
			BayConfig.SLOT_PRICE_BASE,
			BayConfig.SLOT_PRICE_GROWTH
		)
	end

	-- The Robux tier of the incubator's next slot.
	local function slotTier(): number
		return Purchases.slotTier(profile.bay().incubatorSlots, MonetizationConfig.SLOT_TIER_LAST)
	end

	local function robux(price: number?): string
		return PurchaseState.priceText(locale, price)
	end

	-- Drops selections of aliens that are gone (sold, crossbred, hatched into their place).
	-- An effect, so it must run inside Vide's mount scope.
	local function pruneSelection()
		local bay = profile.bay()
		local known: { [number]: boolean } = {}
		for _, pod in bay.pods do
			if pod.alien then
				known[pod.alien.uid] = true
			end
		end
		for _, list in { bay.inventory, bay.floor } do
			for _, alien in list do
				known[alien.uid] = true
			end
		end
		local current = Vide.untrack(selection)
		local kept = {}
		for _, uid in current do
			if known[uid] then
				table.insert(kept, uid)
			end
		end
		if #kept ~= #current then
			selection(kept)
		end
	end

	-- A delivered egg shows up as one more egg in the incubator or its queue: that is the moment
	-- to cheer (an egg moving from the queue into a slot is not a new one).
	local incubatorCount: number? = nil
	local function watchIncubator()
		local bay = profile.bay()
		local count = #bay.incubator + #bay.waiting
		local previous = incubatorCount
		incubatorCount = count
		if previous ~= nil and count > previous then
			toast(text("egg.delivered.toast"), "Egg")
		end
	end

	-- "8.5/s": coins a second.
	local function incomeText(income: BigNum.BigNum): string
		return text("bay.income.hint", { income = BigNum.format(income) })
	end

	-- What the pods bring together.
	local function podsIncome(): BigNum.BigNum
		local total = BigNum.ZERO
		for _, pod in profile.bay().pods do
			local alien = pod.alien and AlienConfig.ALIENS[pod.alien.id]
			if alien then
				total = BigNum.add(total, alien.income)
			end
		end
		return total
	end

	-- The window's rows for `aliens`, the best earners first.
	local function rowsOf(aliens: { ProfileState.Alien }): { BayWindow.Row }
		local sorted = table.clone(aliens)
		local function incomeOf(record: ProfileState.Alien): BigNum.BigNum
			local alien = AlienConfig.ALIENS[record.id]
			return if alien then alien.income else BigNum.ZERO
		end
		table.sort(sorted, function(a, b)
			return BigNum.lessThan(incomeOf(b), incomeOf(a))
		end)
		local rows: { BayWindow.Row } = {}
		for _, record in sorted do
			local alien = AlienConfig.ALIENS[record.id]
			local _, kindName = Names.alienParts(locale, record.id)
			local row: BayWindow.Row = {
				uid = record.uid,
				alienId = record.id,
				name = kindName or "?",
				income = incomeText(incomeOf(record)),
				color = if alien then AlienLooks.TIERS[alien.tier].color else Theme.NEON.MUTED,
				variant = nil,
			}
			if alien and alien.variant ~= "Normal" then
				row.variant = "Meteor"
			end
			table.insert(rows, row)
		end
		return rows
	end

	-- The incubator's eggs for its slots: colour, timer or "Ready!".
	local function eggSlots(): { BayWindow.EggSlot }
		local _ = clock()
		local now = workspace:GetServerTimeNow()
		local slots: { BayWindow.EggSlot } = {}
		for _, egg in profile.bay().incubator do
			local left = egg.hatchAt - now
			local look = (EggLooks.RARITIES :: any)[egg.rarity]
			table.insert(slots, {
				color = if look then look.color else Theme.NEON.MUTED,
				label = if left > 0 then Duration.clock(left) else text("egg.ready.hint"),
				ready = left <= 0,
			})
		end
		return slots
	end

	local function selectionKind(): BayWindow.Selection
		local records = selectedRecords()
		if #records == 0 then
			return "None"
		elseif #records > 1 then
			return "Many"
		end
		return if records[1].location == "Pod" then "Pod" else "Away"
	end

	local function mountUi(playerGui: Instance)
		Vide.mount(function()
			Vide.effect(pruneSelection)
			Vide.effect(watchIncubator)
			-- The window shows Robux prices: fresh ones each time it opens.
			Vide.effect(function()
				if isOpen() then
					Vide.untrack(purchases.refreshPrices)
				end
			end)
			return create("ScreenGui")({
				Name = "BayUi",
				ResetOnSpawn = false,
				DisplayOrder = 10,

				BayWindow({
					visible = function()
						return isOpen()
					end,
					coins = function()
						return BigNum.format(profile.coins())
					end,
					texts = {
						title = text("bay.window.title"),
						pods = function()
							local bay = profile.bay()
							return `{text("bay.places.title")} {#bay.pods - freePods()}/{#bay.pods}`
						end,
						podsIncome = function()
							return incomeText(podsIncome())
						end,
						freePods = function()
							local free = freePods()
							return if free > 0 then text("bay.freePlaces.hint", { count = free }) else ""
						end,
						podsEmpty = text("bay.placesEmpty.hint"),
						autoPlace = text("bay.autoPlace.button"),
						buyPod = function()
							return text("bay.buyPlace.button", { price = BigNum.format(podPrice()) })
						end,
						maxPods = text("notice.maxPlaces.toast"),
						incubator = function()
							local bay = profile.bay()
							return text(
								"bay.incubatorSlots.title",
								{ count = #bay.incubator, slots = bay.incubatorSlots }
							)
						end,
						incubatorEmpty = text("bay.incubatorEmpty.hint"),
						waiting = function()
							local count = #profile.bay().waiting
							return if count > 0 then text("bay.incubatorWaiting.hint", { count = count }) else ""
						end,
						buySlot = function()
							return text("bay.buySlot.button", { price = BigNum.format(slotPrice()) })
						end,
						buySlotRobux = function()
							return text(
								"bay.buySlotRobux.button",
								{ price = robux(purchases.productPrice("IncubatorSlot", slotTier())) }
							)
						end,
						inventory = function()
							return text(
								"bay.inventory.title",
								{ count = #profile.bay().inventory, max = BayConfig.INVENTORY_SLOTS }
							)
						end,
						inventoryEmpty = text("bay.inventoryEmpty.hint"),
						floor = function()
							return text("bay.floor.title", { count = #profile.bay().floor })
						end,
						floorHint = function()
							return if #profile.bay().inventory < BayConfig.INVENTORY_SLOTS
								then text("bay.pickUpFloor.hint")
								else text("bay.floorFull.hint")
						end,
						crossbreedHint = text("bay.crossbreed.hint"),
						status = status,
						selectedName = function()
							local entry = single()
							if not entry then
								return ""
							end
							-- Not an if-expression: it would keep only the first of the two names.
							local _, kindName = Names.alienParts(locale, entry.record.id)
							return kindName or ""
						end,
						selectedLine = function()
							local entry = single()
							local alien = entry and AlienConfig.ALIENS[entry.record.id]
							if not entry or not alien then
								return ""
							end
							local tier = Names.alienParts(locale, entry.record.id)
							return `{tier or "?"} · {incomeText(alien.income)}`
						end,
						sell = function()
							local pending = readPendingSale()
							local entry = single()
							if pending and entry and entry.record.uid == pending then
								return text(
									"bay.sellConfirm.button",
									{ price = BigNum.format(sellPrice(entry.record.id)) }
								)
							end
							return text("bay.sell.button")
						end,
						toPod = text("bay.toPlace.button"),
						fromPod = text("bay.fromPlace.button"),
						crossbreed = text("bay.crossbreed.button"),
					},
					pods = function()
						local aliens = {}
						for _, pod in profile.bay().pods do
							if pod.alien then
								table.insert(aliens, pod.alien)
							end
						end
						return rowsOf(aliens)
					end,
					inventory = function()
						return rowsOf(profile.bay().inventory)
					end,
					floor = function()
						return rowsOf(profile.bay().floor)
					end,
					eggs = eggSlots,
					slots = function()
						return profile.bay().incubatorSlots
					end,
					selection = selectionKind,
					selectedAliens = function()
						local ids = {}
						for _, found in selectedRecords() do
							table.insert(ids, found.record.id)
						end
						return ids
					end,
					isSelected = function(uid)
						return table.find(selection(), uid) ~= nil
					end,
					-- Once a guardian is picked, aliens of other guardians or variants fade: they
					-- cannot join the crossbreed (they can still be tapped for a move or a sale).
					isDimmed = function(alienId)
						local line = selectedLine()
						local alien = AlienConfig.ALIENS[alienId]
						return line ~= nil and alien ~= nil and Crossbreed.mismatch(line, alien) ~= nil
					end,
					onToggle = toggle,
					canCrossbreed = canCrossbreed,
					canMoveToPod = function()
						local entry = single()
						return entry ~= nil and entry.location ~= "Pod" and freePods() > 0
					end,
					canMoveToInventory = function()
						local entry = single()
						return entry ~= nil
							and entry.location ~= "Inventory"
							and #profile.bay().inventory < BayConfig.INVENTORY_SLOTS
					end,
					canBuyPod = function()
						return #profile.bay().pods < BayConfig.MAX_PODS
							and not BigNum.lessThan(profile.coins(), podPrice())
					end,
					podsAtMax = function()
						return #profile.bay().pods >= BayConfig.MAX_PODS
					end,
					slotForSale = function()
						return profile.bay().incubatorSlots < BayConfig.MAX_INCUBATOR_SLOTS
					end,
					canBuySlot = function()
						return profile.bay().incubatorSlots < BayConfig.MAX_INCUBATOR_SLOTS
							and not BigNum.lessThan(profile.coins(), slotPrice())
					end,
					slotForRobux = function()
						return profile.bay().incubatorSlots < BayConfig.MAX_INCUBATOR_SLOTS
							and purchases.sells("IncubatorSlot", slotTier())
					end,
					onClose = function()
						isOpen(false)
					end,
					onAutoPlace = function()
						clearSelection()
						Remotes.AutoPlace.Fire()
					end,
					onCrossbreed = function()
						local uids = table.clone(selection())
						clearSelection()
						Remotes.Crossbreed.Fire(uids)
					end,
					onSell = function()
						local entry = single()
						if not entry then
							return
						end
						if readPendingSale() == entry.record.uid then
							clearSelection()
							Remotes.Sell.Fire(entry.record.uid)
						else
							pendingSale(entry.record.uid)
						end
					end,
					onMoveToPod = function()
						local entry = single()
						if not entry then
							return
						end
						for index, pod in profile.bay().pods do
							if not pod.alien then
								clearSelection()
								Remotes.MoveToPod.Fire({ uid = entry.record.uid, pod = index })
								return
							end
						end
					end,
					onMoveToInventory = function()
						local entry = single()
						if entry then
							clearSelection()
							Remotes.MoveToInventory.Fire(entry.record.uid)
						end
					end,
					onBuyPod = function()
						Remotes.BuyPod.Fire()
					end,
					onBuySlot = function()
						Remotes.BuyIncubatorSlot.Fire()
					end,
					onBuySlotRobux = function()
						purchases.promptProduct("Bay", "IncubatorSlot", slotTier())
					end,
				}),

				Toasts({ toasts = dependencies.toasts.toasts }),

				WelcomeBack({
					visible = function()
						return readReward() ~= nil
					end,
					texts = {
						title = text("welcome.back.title"),
						away = function()
							local current = readReward()
							return if current
								then text("welcome.earned.hint", { time = Duration.describe(locale, current.seconds) })
								else ""
						end,
						pods = text("welcome.places.hint"),
						trainer = text("welcome.trainer.hint"),
						claim = text("welcome.claim.button"),
						double = function()
							local current = readReward()
							local tier = if current then current.doubleTier else 0
							return text(
								"welcome.double.button",
								{ price = robux(purchases.productPrice("CollectDouble", tier)) }
							)
						end,
					},
					coins = function()
						local current = readReward()
						return if current then BigNum.format(current.coins) else ""
					end,
					speed = function()
						local current = readReward()
						return if current then BigNum.format(current.speed) else ""
					end,
					eggs = function()
						local current = readReward()
						return if current and current.readyEggs > 0
							then text("welcome.eggsReady.hint", { count = current.readyEggs })
							else ""
					end,
					onClaim = function()
						reward(nil)
					end,
					doubleReady = function()
						local current = readReward()
						return current ~= nil and purchases.productPrice("CollectDouble", current.doubleTier) ~= nil
					end,
					canDouble = function()
						local current = readReward()
						return current ~= nil
							and current.doubleTier > 0
							and purchases.sells("CollectDouble", current.doubleTier)
					end,
					onDouble = function()
						local current = readReward()
						if current and current.doubleTier > 0 then
							purchases.promptProduct("Welcome", "CollectDouble", current.doubleTier)
						end
					end,
				}),
			})
		end, playerGui)
	end

	local function start()
		locale = Text.localeOf(Players.LocalPlayer)
		local player = Players.LocalPlayer
		local playerGui = player:WaitForChild("PlayerGui", PLAYER_GUI_WAIT_TIMEOUT)
		assert(playerGui, "[BayWindowController] PlayerGui did not appear")
		mountUi(playerGui)

		local function incomeOf(alienId: string): BigNum.BigNum
			local alien = AlienConfig.ALIENS[alienId]
			return if alien then alien.income else BigNum.ZERO
		end
		-- The second line of an alien's toast: what it earns and where it went.
		local function incomeLine(alienId: string, location: ProfileState.Location): string
			return text(
				"alien.hatchedIncome.hint",
				{ income = BigNum.format(incomeOf(alienId)), place = placeText(location) }
			)
		end
		local function nameOf(alienId: string): string
			return Names.alien(locale, alienId) or "?"
		end
		-- Hatches in a row are one toast (docs/design/screens/toasts-and-signs.md): while it is on
		-- screen, each hatch adds to its count and the best earner so far is the one it names. On
		-- a phone a toast per egg covered the screen (playtest, 2026-11-12).
		local hatchRun = { count = 0, alienId = "", location = "Pod" :: ProfileState.Location }
		local pendingHatches: { { alienId: string, location: ProfileState.Location } } = {}
		local function announceHatches()
			local batch = pendingHatches
			pendingHatches = {}
			if not dependencies.toasts.isShown(HATCH_TOAST_GROUP) then
				hatchRun.count = 0
			end
			for _, hatch in batch do
				if hatchRun.count == 0 or BigNum.lessThan(incomeOf(hatchRun.alienId), incomeOf(hatch.alienId)) then
					hatchRun.alienId = hatch.alienId
					hatchRun.location = hatch.location
				end
				hatchRun.count += 1
			end
			local name = nameOf(hatchRun.alienId)
			local line = if hatchRun.count == 1
				then text("alien.hatched.toast", { name = name })
				else text("alien.hatchedMany.toast", { count = hatchRun.count, name = name })
			toast(line, "Alien", hatchRun.alienId, {
				detail = incomeLine(hatchRun.alienId, hatchRun.location),
				group = HATCH_TOAST_GROUP,
			})
		end
		-- Hatches arrive one event each; the ones of a frame are announced together, once.
		profile.hatched.connect(function(alienId, location)
			table.insert(pendingHatches, { alienId = alienId, location = location })
			if #pendingHatches == 1 then
				task.defer(announceHatches)
			end
		end)
		profile.crossbred.connect(function(alienId, location)
			toast(
				text("alien.crossbred.toast", { name = nameOf(alienId) }),
				"Alien",
				alienId,
				{ detail = incomeLine(alienId, location) }
			)
		end)
		profile.notice.connect(function(notice)
			local key: Text.Key = (NOTICE_KEYS :: any)[notice] or "notice.unknownAlien.toast"
			toast(text(key), "Bad")
		end)
		profile.offlineReward.connect(function(coins, speed, seconds, readyEggs, doubleTier)
			purchases.refreshPrices()
			reward({ coins = coins, speed = speed, seconds = seconds, readyEggs = readyEggs, doubleTier = doubleTier })
		end)
		-- "Collect x2" bought from the screen: it shows the doubled numbers and offers no more.
		purchases.granted.connect(function(granted)
			local current = readReward()
			if current and granted.kind == "CollectDouble" and not granted.compensated then
				reward({
					coins = BigNum.add(current.coins, granted.coins),
					speed = BigNum.add(current.speed, granted.speed),
					seconds = current.seconds,
					readyEggs = current.readyEggs,
					doubleTier = 0,
				})
			end
		end)

		-- The tile in the HUD menu row; its key (B) is answered by MenuState.
		dependencies.menu.add({
			slot = "Bay",
			onPress = function()
				isOpen(not isOpen())
			end,
		})
		local sinceTick = 0
		RunService.Heartbeat:Connect(function(deltaTime)
			sinceTick += deltaTime
			if sinceTick >= COUNTDOWN_INTERVAL and isOpen() then
				sinceTick = 0
				clock(clock() + 1)
			end
		end)
	end

	return {
		name = "BayWindowController",
		start = start,
		welcomeOpen = function()
			return readReward() ~= nil
		end,
	}
end

return table.freeze(BayWindowController)
