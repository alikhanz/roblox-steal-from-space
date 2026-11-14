--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- The bay window and what goes with it: its tile in the HUD menu, toasts for hatches, refused
-- commands and a shelf gone full, the welcome-back screen, and the bay's prompts that open the
-- window (an alien on the shelf, an egg that cannot hatch: decision 110). Holds the selection;
-- everything else is read from ProfileState and every action is sent to the server through
-- Remotes.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AlienConfig = require(ReplicatedStorage.Shared.Config.AlienConfig)
local AlienIncome = require(ReplicatedStorage.Shared.Domain.AlienIncome)
local AlienLooks = require(ReplicatedStorage.Shared.Config.AlienLooks)
local Bay = require(ReplicatedStorage.Shared.Domain.Bay)
local BayConfig = require(ReplicatedStorage.Shared.Config.BayConfig)
local BayWindow = require(script.Parent.Parent.UI.BayWindow)
local BigNum = require(ReplicatedStorage.Shared.Domain.BigNum)
local CoachState = require(script.Parent.Parent.State.CoachState)
local Crossbreed = require(ReplicatedStorage.Shared.Domain.Crossbreed)
local Duration = require(ReplicatedStorage.Shared.Locale.Duration)
local EggIcon = require(script.Parent.Parent.UI.EggIcon)
local EggLooks = require(ReplicatedStorage.Shared.Config.EggLooks)
local IncomeRoll = require(script.Parent.Parent.UI.IncomeRoll)
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
	ShelfFull = "notice.shelfFull.toast",
	NotEnoughCoins = "notice.notEnoughCoins.toast",
	MaxPods = "notice.maxPlaces.toast",
	JetpackTop = "notice.jetpackTop.toast",
	MaxIncubatorSlots = "notice.maxIncubatorSlots.toast",
	NoSuchPod = "notice.unknownAlien.toast",
	WrongCount = "notice.wrongAliens.toast",
	MixedGrades = "notice.wrongAliens.toast",
	MixedTiers = "notice.mixedTiers.toast",
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
	-- The hint after the tutorial: "crossbreed" and "sell" light the tile, "crossbreed" the trios.
	coach: CoachState.CoachState,
}

export type BayWindowController = {
	name: string,
	start: () -> (),
	-- The welcome-back screen is up (other screens on login wait for it).
	welcomeOpen: () -> boolean,
	-- Opens the window with these aliens chosen (none: nothing chosen).
	openWith: (uids: { number }) -> (),
	-- Opens the window with the shelf's best ready trio chosen (the hint "crossbreed them").
	openWithTrio: () -> (),
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
	-- The selection whose sale waits for a second tap (its uids joined), or nil.
	local pendingSale = source(nil :: string?)
	local reward = source(nil :: Reward?)
	-- Optional sources are read through a plain getter: Vide types a source as an intersection
	-- of reader and writer, which is ambiguous to call without arguments when T is optional.
	local readPendingSale = pendingSale :: () -> string?
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

	-- Any number can be chosen (to sell them all); three of a kind crossbreed (decision 110).
	local function toggle(uid: number)
		pendingSale(nil)
		local list = table.clone(selection())
		local index = table.find(list, uid)
		if index then
			table.remove(list, index)
		else
			table.insert(list, uid)
		end
		selection(list)
	end

	local function clearSelection()
		selection({})
		pendingSale(nil)
	end

	-- The first selected alien when every selected one goes with it (the same grade, tier and
	-- variant, the server's rule in Domain/Crossbreed); otherwise nil and why they do not.
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
		return text("bay.selectedMany.hint", { count = #records })
	end

	local function podPrice(): BigNum.BigNum
		return Bay.podPrice(
			#profile.bay().pods,
			BayConfig.STARTING_PODS,
			BayConfig.POD_PRICE_BASE,
			BayConfig.POD_PRICE_GROWTH
		)
	end

	-- What the selected aliens sell for together.
	local function selectionPrice(): BigNum.BigNum
		local total = BigNum.ZERO
		for _, entry in selectedRecords() do
			total = BigNum.add(total, AlienIncome.saleOf(entry.record))
		end
		return total
	end

	-- The selection as one key: a sale asked for once waits for a second tap on the same aliens.
	local function selectionKey(): string
		local uids = table.clone(selection())
		table.sort(uids)
		return table.concat(uids, ",")
	end

	-- The shelf's ready trios (Domain/Crossbreed.trios), best first.
	local function shelfTrios(): { Crossbreed.Trio }
		return Crossbreed.trios(profile.bay().floor, function(alienId: string): Crossbreed.Parent?
			return AlienConfig.ALIENS[alienId]
		end, AlienIncome.numberOf, BayConfig.CROSSBREED_COUNT)
	end

	local function shelfIsFull(): boolean
		return #profile.bay().floor >= BayConfig.SHELF_SLOTS
	end

	-- Ready eggs in the incubator that cannot hatch: no free place and a full shelf (decision 110).
	local function stuckEggs(): number
		local _ = clock()
		local bay = profile.bay()
		if Bay.hasRoom(bay, BayConfig.SHELF_SLOTS) then
			return 0
		end
		local now = workspace:GetServerTimeNow()
		local stuck = 0
		for _, egg in bay.incubator do
			if egg.hatchAt <= now then
				stuck += 1
			end
		end
		return stuck
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
		for _, alien in bay.floor do
			known[alien.uid] = true
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

	-- The shelf has just gone full with no free place: from now on eggs wait (decision 110).
	local hadRoom: boolean? = nil
	local function watchRoom()
		local room = Bay.hasRoom(profile.bay(), BayConfig.SHELF_SLOTS)
		local before = hadRoom
		hadRoom = room
		if before == true and not room then
			toast(text("bay.shelfFull.toast"), "Bad")
		end
	end

	-- A pod just bought takes the best of the shelf at once: say who moved in.
	local podCount: number? = nil
	local function watchNewPod()
		local pods = profile.bay().pods
		local before = podCount
		podCount = #pods
		local newest = pods[#pods]
		if before and #pods == before + 1 and newest and newest.alien then
			toast(
				text("alien.toPlace.toast", { name = Names.alien(locale, newest.alien.id) or "?" }),
				"Alien",
				newest.alien.id
			)
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

	-- What the places bring together.
	local function podsIncome(): BigNum.BigNum
		return Bay.incomePerSecond(profile.bay(), AlienIncome.of)
	end

	-- The window's rows for `aliens`, the best earners first.
	local function rowsOf(aliens: { ProfileState.Alien }): { BayWindow.Row }
		local sorted = table.clone(aliens)
		table.sort(sorted, function(a, b)
			return BigNum.lessThan(AlienIncome.of(b), AlienIncome.of(a))
		end)
		local rows: { BayWindow.Row } = {}
		for _, record in sorted do
			local alien = AlienConfig.ALIENS[record.id]
			local _, kindName = Names.alienParts(locale, record.id)
			local row: BayWindow.Row = {
				uid = record.uid,
				alienId = record.id,
				name = kindName or "?",
				income = incomeText(AlienIncome.of(record)),
				bonus = IncomeRoll.text(locale, AlienIncome.percentOf(record)),
				bonusColor = IncomeRoll.color(AlienIncome.percentOf(record)),
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
				icon = EggIcon.ofRecord(egg),
				label = if left > 0 then Duration.clock(left) else text("egg.ready.hint"),
				ready = left <= 0,
			})
		end
		return slots
	end

	-- Every alien on the shelf is chosen ("select all" then lets go of them).
	local function allShelfSelected(): boolean
		local floor = profile.bay().floor
		if #floor == 0 then
			return false
		end
		local chosen = selection()
		for _, alien in floor do
			if not table.find(chosen, alien.uid) then
				return false
			end
		end
		return true
	end

	local function openWith(uids: { number })
		pendingSale(nil)
		selection(table.clone(uids))
		isOpen(true)
	end

	local function openWithTrio()
		local trio = shelfTrios()[1]
		openWith(if trio then trio.uids else {})
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
			Vide.effect(watchRoom)
			Vide.effect(watchNewPod)
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
						shelf = function()
							return text(
								"bay.shelf.title",
								{ count = #profile.bay().floor, max = BayConfig.SHELF_SLOTS }
							)
						end,
						shelfEmpty = text("bay.shelfEmpty.hint"),
						shelfFull = text("bay.shelfFull.hint"),
						selectAll = function()
							return if allShelfSelected()
								then text("bay.selectNone.button")
								else text("bay.selectAll.button")
						end,
						trios = text("bay.trios.title"),
						trioButton = text("bay.crossbreed.button"),
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
							local roll = IncomeRoll.text(locale, AlienIncome.percentOf(entry.record))
							return `{tier or "?"} · {incomeText(AlienIncome.of(entry.record))} · {roll}`
						end,
						sell = function()
							local count = #selectedRecords()
							local price = BigNum.format(selectionPrice())
							if readPendingSale() == selectionKey() then
								return text("bay.sellConfirm.button", { price = price })
							end
							return if count > 1
								then text("bay.sellMany.button", { count = count, price = price })
								else text("bay.sell.button")
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
					shelf = function()
						return rowsOf(profile.bay().floor)
					end,
					shelfIsFull = shelfIsFull,
					trios = function()
						local trios: { BayWindow.Trio } = {}
						for _, trio in shelfTrios() do
							local record = nil
							for _, alien in profile.bay().floor do
								if alien.uid == trio.uids[#trio.uids] then
									record = alien
								end
							end
							local alienId = if record then record.id else ""
							local alien = AlienConfig.ALIENS[alienId]
							-- Not an if-expression: it would keep only the first of the two names.
							local tierName = Names.alienParts(locale, alienId)
							table.insert(trios, {
								alienId = alienId,
								-- As aliens are named: "<tier> · <guardian>" (Names.alien).
								name = `{tierName or "?"} · {Names.guardian(locale, trio.grade) or "?"}`,
								count = `×{trio.count}`,
								color = if alien then AlienLooks.TIERS[alien.tier].color else Theme.NEON.MUTED,
							})
						end
						return trios
					end,
					triosLit = function()
						return dependencies.coach.tip() == "Crossbreed"
					end,
					onTrio = function(index: number)
						local trio = shelfTrios()[index]
						if trio then
							clearSelection()
							Remotes.Crossbreed.Fire(trio.uids)
						end
					end,
					onSelectAll = function()
						pendingSale(nil)
						if allShelfSelected() then
							selection({})
							return
						end
						local list = table.clone(selection())
						for _, alien in profile.bay().floor do
							if not table.find(list, alien.uid) then
								table.insert(list, alien.uid)
							end
						end
						selection(list)
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
					onToggle = toggle,
					canCrossbreed = canCrossbreed,
					canMoveToPod = function()
						local entry = single()
						return entry ~= nil and entry.location ~= "Pod" and freePods() > 0
					end,
					canMoveToShelf = function()
						local entry = single()
						return entry ~= nil and entry.location == "Pod" and not shelfIsFull()
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
					-- The first tap asks again with the sum, the second sells them all.
					onSell = function()
						local uids = table.clone(selection())
						if #uids == 0 then
							return
						end
						if readPendingSale() ~= selectionKey() then
							pendingSale(selectionKey())
							return
						end
						clearSelection()
						if #uids == 1 then
							Remotes.Sell.Fire(uids[1])
						else
							Remotes.SellMany.Fire({ table.unpack(uids, 1, math.min(#uids, BayConfig.SELL_MANY_MAX)) })
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
					onMoveToShelf = function()
						local entry = single()
						if entry then
							clearSelection()
							Remotes.MoveToShelf.Fire(entry.record.uid)
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

		-- An alien of the toasts: its id and income roll.
		type Born = { id: string, incomePercent: number }
		-- The second line of an alien's toast: what it earns, its roll and where it went.
		local function incomeLine(alien: Born, location: ProfileState.Location): string
			return text("alien.hatchedIncome.hint", {
				income = BigNum.format(AlienIncome.of(alien)),
				roll = IncomeRoll.text(locale, alien.incomePercent),
				place = placeText(location),
			})
		end
		local function nameOf(alienId: string): string
			return Names.alien(locale, alienId) or "?"
		end
		-- Hatches in a row are one toast (docs/design/screens/toasts-and-signs.md): while it is on
		-- screen, each hatch adds to its count and the best earner so far is the one it names. On
		-- a phone a toast per egg covered the screen (playtest, 2026-11-12).
		local hatchRun =
			{ count = 0, alien = { id = "", incomePercent = 100 } :: Born, location = "Pod" :: ProfileState.Location }
		local pendingHatches: { { alien: Born, location: ProfileState.Location } } = {}
		local function announceHatches()
			local batch = pendingHatches
			pendingHatches = {}
			if not dependencies.toasts.isShown(HATCH_TOAST_GROUP) then
				hatchRun.count = 0
			end
			for _, hatch in batch do
				if
					hatchRun.count == 0 or BigNum.lessThan(AlienIncome.of(hatchRun.alien), AlienIncome.of(hatch.alien))
				then
					hatchRun.alien = hatch.alien
					hatchRun.location = hatch.location
				end
				hatchRun.count += 1
			end
			local name = nameOf(hatchRun.alien.id)
			local line = if hatchRun.count == 1
				then text("alien.hatched.toast", { name = name })
				else text("alien.hatchedMany.toast", { count = hatchRun.count, name = name })
			toast(line, "Alien", hatchRun.alien.id, {
				detail = incomeLine(hatchRun.alien, hatchRun.location),
				group = HATCH_TOAST_GROUP,
			})
		end
		-- Hatches arrive one event each; the ones of a frame are announced together, once.
		profile.hatched.connect(function(alienId, location, incomePercent)
			table.insert(
				pendingHatches,
				{ alien = { id = alienId, incomePercent = incomePercent }, location = location }
			)
			if #pendingHatches == 1 then
				task.defer(announceHatches)
			end
		end)
		profile.crossbred.connect(function(alienId, location, incomePercent)
			toast(
				text("alien.crossbred.toast", { name = nameOf(alienId) }),
				"Alien",
				alienId,
				{ detail = incomeLine({ id = alienId, incomePercent = incomePercent }, location) }
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

		-- The tile in the HUD menu row; its key (B) is answered by MenuState. Its count: ready eggs
		-- that wait for room; it glows while the hint asks to crossbreed or sell.
		dependencies.menu.add({
			slot = "Bay",
			onPress = function()
				isOpen(not isOpen())
			end,
			badge = stuckEggs,
			pulse = function()
				local tip = dependencies.coach.tip()
				return tip == "Crossbreed" or tip == "Sell"
			end,
		})
		-- The bay's own prompts that only open the window: an alien on the shelf (chosen in it) and
		-- a ready egg that cannot hatch.
		ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
			if who ~= Players.LocalPlayer then
				return
			end
			local action = prompt:GetAttribute(BayConfig.PROMPT_ACTION_ATTRIBUTE)
			if action == BayConfig.PROMPT_ACTION_OPEN_BAY then
				local uid = prompt:GetAttribute(BayConfig.PROMPT_ALIEN_UID_ATTRIBUTE)
				openWith(if type(uid) == "number" then { uid } else {})
			elseif action == BayConfig.PROMPT_ACTION_SHELF_FULL then
				openWith({})
			end
		end)
		-- Egg countdowns while the window is open; the tile's count of stuck eggs needs the time
		-- too, less often.
		local sinceTick = 0
		RunService.Heartbeat:Connect(function(deltaTime)
			sinceTick += deltaTime
			if sinceTick >= COUNTDOWN_INTERVAL then
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
		openWith = openWith,
		openWithTrio = openWithTrio,
	}
end

return table.freeze(BayWindowController)
