--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- The bay window and what goes with it: the button that opens it, toasts for hatches and
-- refused commands, the welcome-back screen. Holds the selection; everything else is read from
-- ProfileState and every action is sent to the server through Remotes.

local LocalizationService = game:GetService("LocalizationService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local AlienConfig = require(ReplicatedStorage.Shared.Config.AlienConfig)
local AlienLooks = require(ReplicatedStorage.Shared.Config.AlienLooks)
local Bay = require(ReplicatedStorage.Shared.Domain.Bay)
local BayConfig = require(ReplicatedStorage.Shared.Config.BayConfig)
local BayWindow = require(script.Parent.Parent.UI.BayWindow)
local BigNum = require(ReplicatedStorage.Shared.Domain.BigNum)
local Button = require(script.Parent.Parent.UI.Button)
local Crossbreed = require(ReplicatedStorage.Shared.Domain.Crossbreed)
local Duration = require(ReplicatedStorage.Shared.Locale.Duration)
local Layout = require(script.Parent.Parent.UI.Layout)
local Names = require(ReplicatedStorage.Shared.Locale.Names)
local ProfileState = require(script.Parent.Parent.State.ProfileState)
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
local TOGGLE_KEY = Enum.KeyCode.B
-- Egg countdowns are whole seconds: once a second is enough.
local COUNTDOWN_INTERVAL = 1

local NOTICE_KEYS: { [ProfileState.Notice]: Text.Key } = {
	NoProfile = "notice.noProfile.toast",
	UnknownAlien = "notice.unknownAlien.toast",
	InventoryFull = "notice.inventoryFull.toast",
	NotEnoughCoins = "notice.notEnoughCoins.toast",
	MaxPods = "notice.maxPods.toast",
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
	VictimShielded = "pvp.victimShielded.toast",
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
}

export type Dependencies = {
	profile: ProfileState.ProfileState,
	toasts: ToastState.ToastState,
	windows: WindowState.WindowState,
}

export type BayWindowController = {
	name: string,
	start: () -> (),
	-- The welcome-back screen is up (other screens on login wait for it).
	welcomeOpen: () -> boolean,
}

-- What the welcome-back screen shows.
type Reward = { coins: BigNum.BigNum, speed: BigNum.BigNum, seconds: number, readyEggs: number }

local BayWindowController = {}

function BayWindowController.new(dependencies: Dependencies): BayWindowController
	local profile = dependencies.profile
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
		Pod = "place.pod.hint",
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
				then text("bay.selectedPod.hint", { name = name })
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

	-- "<egg> · <guardian>[ · ★ star]", the start of every egg's line.
	local function eggName(
		egg: { read rarity: string, read variant: string?, read grade: number, read luck: number? }
	): string
		local name = Names.egg(locale, egg.rarity, egg.variant) or "?"
		local guardian = Names.guardian(locale, egg.grade) or "?"
		-- Extra luck comes only with the star egg: it hatches luckier.
		local luck = if egg.luck and egg.luck > 0 then ` · {text("egg.starEgg.hint")}` else ""
		return `{name} · {guardian}{luck}`
	end

	local function eggLine(egg: ProfileState.Egg): string
		local _ = clock()
		local left = egg.hatchAt - workspace:GetServerTimeNow()
		local when = if left > 0
			then text("egg.hatchIn.hint", { time = Duration.clock(left) })
			else text("egg.ready.hint")
		return `{eggName(egg)} — {when}`
	end

	local function waitingLine(egg: ProfileState.WaitingEgg): string
		return `{eggName(egg)} — {text("egg.waiting.hint")}`
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
			toast(text("egg.delivered.toast"), Theme.TOAST_GOOD)
		end
	end

	local function mountUi(playerGui: Instance)
		Vide.mount(function()
			Vide.effect(pruneSelection)
			Vide.effect(watchIncubator)
			return create("ScreenGui")({
				Name = "BayUi",
				ResetOnSpawn = false,
				DisplayOrder = 10,

				-- The open button sits at the bottom of the menu column, clear of the flight buttons.
				Layout.placeInMenu(
					Button({
						name = "OpenBay",
						text = text("bay.open.button"),
						onClick = function()
							isOpen(not isOpen())
						end,
					}),
					"Bay"
				),

				BayWindow({
					visible = function()
						return isOpen()
					end,
					bay = profile.bay,
					texts = {
						title = text("bay.window.title"),
						close = text("bay.close.button"),
						pods = text("bay.pods.title"),
						emptyPod = text("bay.emptyPod.hint"),
						buyPod = function()
							return text("bay.buyPod.button", { price = BigNum.format(podPrice()) })
						end,
						incubator = function()
							local bay = profile.bay()
							return text(
								"bay.incubatorSlots.title",
								{ count = #bay.incubator, slots = bay.incubatorSlots }
							)
						end,
						incubatorEmpty = text("bay.incubatorEmpty.hint"),
						buySlot = function()
							return text("bay.buySlot.button", { price = BigNum.format(slotPrice()) })
						end,
						inventory = function()
							return text(
								"bay.inventory.title",
								{ count = #profile.bay().inventory, max = BayConfig.INVENTORY_SLOTS }
							)
						end,
						floor = function()
							return text("bay.floor.title", { count = #profile.bay().floor })
						end,
						floorHint = function()
							return if #profile.bay().inventory < BayConfig.INVENTORY_SLOTS
								then text("bay.pickUpFloor.hint")
								else text("bay.floorFull.hint")
						end,
						autoPlace = text("bay.autoPlace.button"),
						crossbreed = text("bay.crossbreed.button"),
						crossbreedHint = text("bay.crossbreed.hint"),
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
						toPod = text("bay.toPod.button"),
						toInventory = function()
							local entry = single()
							return if entry and entry.location == "Pod"
								then text("bay.fromPod.button")
								else text("bay.toInventory.button")
						end,
						status = status,
					},
					alienName = function(alienId)
						local _, guardian = Names.alienParts(locale, alienId)
						return guardian
					end,
					alienSubtitle = function(alienId)
						local alien = AlienConfig.ALIENS[alienId]
						local tier = Names.alienParts(locale, alienId)
						local income = if alien then BigNum.format(alien.income) else "?"
						return text("alien.tierIncome.hint", { tier = tier or "?", income = income })
					end,
					alienColor = function(alienId)
						local alien = AlienConfig.ALIENS[alienId]
						return if alien then AlienLooks.TIERS[alien.tier].color else Theme.MUTED
					end,
					eggLine = eggLine,
					waitingLine = waitingLine,
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
					canSell = function()
						return single() ~= nil
					end,
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
					slotForSale = function()
						return profile.bay().incubatorSlots < BayConfig.MAX_INCUBATOR_SLOTS
					end,
					canBuySlot = function()
						return profile.bay().incubatorSlots < BayConfig.MAX_INCUBATOR_SLOTS
							and not BigNum.lessThan(profile.coins(), slotPrice())
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
				}),

				Toasts({ toasts = dependencies.toasts.toasts }),

				WelcomeBack({
					visible = function()
						return readReward() ~= nil
					end,
					title = text("welcome.back.title"),
					coins = function()
						local current = readReward()
						return if current then BigNum.format(current.coins) else ""
					end,
					speed = function()
						local current = readReward()
						return if current then BigNum.format(current.speed) else ""
					end,
					details = function()
						local current = readReward()
						if not current then
							return ""
						end
						return text("welcome.earned.hint", {
							time = Duration.describe(locale, current.seconds),
							coins = BigNum.format(current.coins),
							speed = BigNum.format(current.speed),
						})
					end,
					eggs = function()
						local current = readReward()
						return if current and current.readyEggs > 0
							then text("welcome.eggsReady.hint", { count = current.readyEggs })
							else ""
					end,
					claim = text("welcome.claim.button"),
					onClaim = function()
						reward(nil)
					end,
				}),
			})
		end, playerGui)
	end

	local function start()
		locale = Text.resolveLocale(LocalizationService.RobloxLocaleId)
		local player = Players.LocalPlayer
		local playerGui = player:WaitForChild("PlayerGui", PLAYER_GUI_WAIT_TIMEOUT)
		assert(playerGui, "[BayWindowController] PlayerGui did not appear")
		mountUi(playerGui)

		local function announce(key: Text.Key, alienId: string, location: ProfileState.Location)
			local args = { name = Names.alien(locale, alienId) or "?", place = placeText(location) }
			toast(text(key, args), Theme.TOAST_GOOD)
		end
		-- Hatches arrive one event each; several at once become one toast.
		local pendingHatches: { { alienId: string, location: ProfileState.Location } } = {}
		profile.hatched.connect(function(alienId, location)
			table.insert(pendingHatches, { alienId = alienId, location = location })
			if #pendingHatches > 1 then
				return
			end
			task.defer(function()
				local batch = pendingHatches
				pendingHatches = {}
				if #batch == 1 then
					announce("alien.hatched.toast", batch[1].alienId, batch[1].location)
				else
					toast(text("alien.hatchedMany.toast", { count = #batch }), Theme.TOAST_GOOD)
				end
			end)
		end)
		profile.crossbred.connect(function(alienId, location)
			announce("alien.crossbred.toast", alienId, location)
		end)
		profile.notice.connect(function(notice)
			local key: Text.Key = (NOTICE_KEYS :: any)[notice] or "notice.unknownAlien.toast"
			toast(text(key), Theme.TOAST_BAD)
		end)
		profile.offlineReward.connect(function(coins, speed, seconds, readyEggs)
			reward({ coins = coins, speed = speed, seconds = seconds, readyEggs = readyEggs })
		end)

		UserInputService.InputBegan:Connect(function(input, gameProcessed)
			if not gameProcessed and input.KeyCode == TOGGLE_KEY then
				isOpen(not isOpen())
			end
		end)
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
