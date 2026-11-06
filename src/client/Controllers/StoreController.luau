--!strict
--# selene: allow(mixed_table) -- Vide declares properties and children in one table
-- The shop (decision 061): the menu button, the window with everything sold for Robux, and the
-- toasts for what a purchase gave. Prices and passes come from PurchaseState, the numbers a
-- purchase would give from the profile copy and the same formulas the server uses.

local LocalizationService = game:GetService("LocalizationService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BayConfig = require(ReplicatedStorage.Shared.Config.BayConfig)
local BigNum = require(ReplicatedStorage.Shared.Domain.BigNum)
local Button = require(script.Parent.Parent.UI.Button)
local Layout = require(script.Parent.Parent.UI.Layout)
local MonetizationConfig = require(ReplicatedStorage.Shared.Config.MonetizationConfig)
local Names = require(ReplicatedStorage.Shared.Locale.Names)
local ProfileState = require(script.Parent.Parent.State.ProfileState)
local PurchaseState = require(script.Parent.Parent.State.PurchaseState)
local Purchases = require(ReplicatedStorage.Shared.Domain.Purchases)
local StoreWindow = require(script.Parent.Parent.UI.StoreWindow)
local Text = require(ReplicatedStorage.Shared.Locale.Text)
local Theme = require(script.Parent.Parent.UI.Theme)
local ToastState = require(script.Parent.Parent.State.ToastState)
local UpgradeConfig = require(ReplicatedStorage.Shared.Config.UpgradeConfig)
local Upgrades = require(ReplicatedStorage.Shared.Domain.Upgrades)
local Vide = require(ReplicatedStorage.Packages.Vide)
local WindowState = require(script.Parent.Parent.State.WindowState)

local create = Vide.create
local source = Vide.source

local PLAYER_GUI_WAIT_TIMEOUT = 30
-- The "Egg ready now" row follows the eggs' countdowns: once a second is enough.
local CLOCK_INTERVAL = 1
local HOUR = 60 * 60

local PASS_TEXTS: { [Purchases.PassId]: { title: Text.Key, hint: Text.Key } } = {
	DoubleTraining = { title = "store.doubleTraining.title", hint = "store.doubleTraining.hint" },
	NightShift = { title = "store.nightShift.title", hint = "store.nightShift.hint" },
}
-- The training packs' titles, in MonetizationConfig.TRAINING_PACK_SECONDS order.
local TRAINING_TITLES: { Text.Key } = {
	"store.trainingHour.title",
	"store.trainingEight.title",
	"store.trainingDay.title",
}

export type Dependencies = {
	profile: ProfileState.ProfileState,
	purchases: PurchaseState.PurchaseState,
	toasts: ToastState.ToastState,
	windows: WindowState.WindowState,
}

export type StoreController = {
	name: string,
	start: () -> (),
	-- Opens the shop; `source` says where from (the analytics of the purchases made in it).
	open: (source: MonetizationConfig.ShopSource) -> (),
}

local StoreController = {}

function StoreController.new(dependencies: Dependencies): StoreController
	local profile = dependencies.profile
	local purchases = dependencies.purchases
	local isOpen = dependencies.windows.slot("Store")
	local openedFrom: MonetizationConfig.ShopSource = "Store"
	local clock = source(0)
	local locale: Text.Locale = "en"

	local function text(key: Text.Key, args: Text.Args?): string
		return Text.get(locale, key, args)
	end

	local function price(value: number?): string
		return PurchaseState.priceText(locale, value)
	end

	local function open(from: MonetizationConfig.ShopSource)
		openedFrom = from
		purchases.refreshPrices()
		isOpen(true)
	end

	-- The speed stat a training pack of `seconds` adds now (Purchases.trainingPack, as the server).
	local function packSpeed(seconds: number): BigNum.BigNum
		local upgrades = profile.upgrades()
		local rate = Purchases.trainerRate(upgrades.trainerLevel, purchases.trainerMultiplier(), UpgradeConfig.TUNING)
		local jetpack = Upgrades.jetpackMultiplier(upgrades.jetpackLevel, UpgradeConfig.TUNING)
		return Purchases.trainingPack(rate, seconds, jetpack).speed
	end

	-- The warming egg with the longest wait: what "Egg ready now" applies to from the shop (the
	-- bay window offers it for any egg).
	local function longestEgg(): ProfileState.Egg?
		local _ = clock()
		local now = workspace:GetServerTimeNow()
		local found: ProfileState.Egg? = nil
		for _, egg in profile.bay().incubator do
			if egg.hatchAt > now and (not found or egg.hatchAt > found.hatchAt) then
				found = egg
			end
		end
		return found
	end

	local function eggTier(egg: ProfileState.Egg): number
		return MonetizationConfig.readyNowTierOf(egg.grade, egg.rarity)
	end

	local function slotTier(): number
		return Purchases.slotTier(profile.bay().incubatorSlots, MonetizationConfig.SLOT_TIER_LAST)
	end

	local function passRows(): { StoreWindow.Row }
		local tuning = MonetizationConfig.PASS_TUNING
		local hintArgs: { [Purchases.PassId]: Text.Args } = {
			DoubleTraining = { factor = tuning.doubleTrainingMultiplier },
			NightShift = {
				income = tuning.nightShiftIncomeCapSeconds // HOUR,
				incomeBase = tuning.incomeCapSeconds // HOUR,
				training = tuning.nightShiftTrainingCapSeconds // HOUR,
				trainingBase = tuning.trainingCapSeconds // HOUR,
			},
		}
		local rows = {}
		for _, pass in MonetizationConfig.PASS_ORDER do
			if not purchases.sellsPass(pass) then
				continue
			end
			local texts = PASS_TEXTS[pass]
			table.insert(rows, {
				title = text(texts.title),
				hint = function()
					return text(texts.hint, hintArgs[pass])
				end,
				price = function()
					return price(purchases.passPrice(pass))
				end,
				offered = function()
					return not purchases.owns(pass)
				end,
				status = function()
					return text("store.owned.hint")
				end,
				onBuy = function()
					purchases.promptPass(openedFrom, pass)
				end,
			})
		end
		return rows
	end

	local function productRows(): { StoreWindow.Row }
		local rows = {}
		for index, seconds in MonetizationConfig.TRAINING_PACK_SECONDS do
			if not purchases.sells("Training", nil, seconds) then
				continue
			end
			table.insert(rows, {
				title = text(TRAINING_TITLES[index]),
				hint = function()
					return text("store.training.hint", { speed = BigNum.format(packSpeed(seconds)) })
				end,
				price = function()
					return price(purchases.productPrice("Training", nil, seconds))
				end,
				offered = function()
					return true
				end,
				status = function()
					return ""
				end,
				onBuy = function()
					purchases.promptProduct(openedFrom, "Training", nil, seconds)
				end,
			})
		end
		table.insert(rows, {
			title = text("store.readyNow.title"),
			hint = function()
				local egg = longestEgg()
				return if egg
					then text("store.readyNow.hint", { egg = Names.eggWithGuardian(locale, egg) })
					else text("store.readyNowNone.hint")
			end,
			price = function()
				local egg = longestEgg()
				return price(if egg then purchases.productPrice("ReadyNow", eggTier(egg)) else nil)
			end,
			offered = function()
				local egg = longestEgg()
				return egg ~= nil and purchases.sells("ReadyNow", eggTier(egg))
			end,
			status = function()
				return ""
			end,
			onBuy = function()
				local egg = longestEgg()
				if egg then
					purchases.promptProduct(openedFrom, "ReadyNow", eggTier(egg), nil, egg.uid)
				end
			end,
		})
		table.insert(rows, {
			title = text("store.slot.title"),
			hint = function()
				local slots = profile.bay().incubatorSlots
				return if slots < BayConfig.MAX_INCUBATOR_SLOTS
					then text("store.slot.hint", { count = slots })
					else text("store.slotMax.hint")
			end,
			price = function()
				return price(purchases.productPrice("IncubatorSlot", slotTier()))
			end,
			offered = function()
				return profile.bay().incubatorSlots < BayConfig.MAX_INCUBATOR_SLOTS
					and purchases.sells("IncubatorSlot", slotTier())
			end,
			status = function()
				return ""
			end,
			onBuy = function()
				purchases.promptProduct(openedFrom, "IncubatorSlot", slotTier())
			end,
		})
		return rows
	end

	-- What a granted purchase gave, as a toast.
	local function announce(granted: PurchaseState.Granted)
		if granted.hatched then
			-- The egg hatched at once: the hatch has its own announcement.
			return
		end
		local coins = BigNum.format(granted.coins)
		local speed = BigNum.format(granted.speed)
		local message = if granted.compensated
			then text("store.compensated.toast", { coins = coins })
			elseif granted.kind == "Training" then text("store.training.toast", { speed = speed })
			elseif granted.kind == "ReadyNow" then text("store.readyNow.toast")
			elseif granted.kind == "IncubatorSlot" then text("store.slot.toast")
			else text("store.double.toast", { coins = coins, speed = speed })
		dependencies.toasts.push(message, Theme.TOAST_GOOD)
	end

	local function mountUi(playerGui: Instance)
		local rows = passRows()
		for _, entry in productRows() do
			table.insert(rows, entry)
		end
		Vide.mount(function()
			return create("ScreenGui")({
				Name = "StoreUi",
				ResetOnSpawn = false,
				DisplayOrder = 11,
				Layout.placeInMenu(
					Button({
						name = "OpenStore",
						text = text("store.open.button"),
						color = Theme.TOAST_GOOD,
						onClick = function()
							if isOpen() then
								isOpen(false)
							else
								open("Store")
							end
						end,
					}),
					"Store"
				),
				StoreWindow({
					visible = function()
						return isOpen()
					end,
					title = text("store.window.title"),
					hint = text("store.window.hint"),
					rows = rows,
					onClose = function()
						isOpen(false)
					end,
				}),
			})
		end, playerGui)
	end

	local function start()
		if not purchases.available then
			-- An unpublished place sells nothing: no button, no window.
			return
		end
		locale = Text.resolveLocale(LocalizationService.RobloxLocaleId)
		local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui", PLAYER_GUI_WAIT_TIMEOUT)
		assert(playerGui, "[StoreController] PlayerGui did not appear")
		mountUi(playerGui)

		purchases.granted.connect(announce)
		purchases.passUnlocked.connect(function(pass)
			local name = text(PASS_TEXTS[pass].title)
			dependencies.toasts.push(text("store.unlocked.toast", { name = name }), Theme.TOAST_GOOD)
		end)
		local sinceTick = 0
		RunService.Heartbeat:Connect(function(deltaTime)
			sinceTick += deltaTime
			if sinceTick >= CLOCK_INTERVAL and isOpen() then
				sinceTick = 0
				clock(clock() + 1)
			end
		end)
	end

	return {
		name = "StoreController",
		start = start,
		open = open,
	}
end

return table.freeze(StoreController)
